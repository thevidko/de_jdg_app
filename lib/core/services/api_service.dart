import 'dart:async';
import 'dart:io';
import 'package:de_jdg_app/core/models/active_state.dart';
import 'package:de_jdg_app/core/models/competition.dart';
import 'package:de_jdg_app/core/models/round.dart';
import 'package:de_jdg_app/core/services/score_queue_service.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();
  late final PersistCookieJar _cookieJar;

  /// Emituje při nenávratném selhání autentizace (refresh selhal nebo vrátil chybu).
  /// AuthController naslouchá a přesměruje uživatele na přihlášení.
  final _authFailureController = StreamController<void>.broadcast();
  Stream<void> get authFailureStream => _authFailureController.stream;

  static const String _defaultBaseUrl = 'http://localhost:8000/api/v1';
  static const String _defaultWsUrl =
      'ws://localhost:8010/connection/websocket';

  String _baseUrl = _defaultBaseUrl;
  String _wsUrl = _defaultWsUrl;

  String get wsUrl => _wsUrl;

  ApiService._internal();

  /// Zkontroluje dostupnost backendu přes GET /up (Laravel built-in health endpoint).
  ///
  /// Jde přímo na origin (bez /api/v1), timeout 5 s.
  /// Vrací true pokud server odpoví 200.
  Future<bool> checkHealth() async {
    try {
      final uri = Uri.parse(_baseUrl);
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final upUrl = Uri.parse('${uri.scheme}://${uri.host}:$port/up');
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(upUrl);
        final res = await req.close().timeout(const Duration(seconds: 5));
        await res.drain<void>();
        return res.statusCode == 200;
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      return false;
    }
  }

  /// Aktualizuje base URL za běhu (po výběru serveru v discovery screenu).
  void updateUrls(String baseUrl, String wsUrl) {
    _baseUrl = baseUrl;
    _wsUrl = wsUrl;
    _dio.options.baseUrl = baseUrl;
  }

  /// Resetuje URL na výchozí hodnoty (localhost) — voláno při výmazu konfigurace serveru.
  void resetUrls() {
    _baseUrl = _defaultBaseUrl;
    _wsUrl = _defaultWsUrl;
    _dio.options.baseUrl = _defaultBaseUrl;
  }

  // Tuto metodu musíme zavolat v main.dart před spuštěním aplikace!
  Future<void> init({String? baseUrl, String? wsUrl}) async {
    if (baseUrl != null && baseUrl.isNotEmpty) _baseUrl = baseUrl;
    if (wsUrl != null && wsUrl.isNotEmpty) _wsUrl = wsUrl;
    // 1. Nastavení cesty pro ukládání cookies
    final appDocDir = await getApplicationDocumentsDirectory();
    final cookiePath = "${appDocDir.path}/.cookies/";

    // Vytvoření složky, pokud neexistuje
    await Directory(cookiePath).create(recursive: true);

    _cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));

    // 2. Nastavení Dio
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/vnd.api+json',
          'Accept': 'application/vnd.api+json',
        },
      ),
    );

    // 3. Přidání Cookie Manageru (Jako první interceptor!)
    _dio.interceptors.add(CookieManager(_cookieJar));

    _setupInterceptors();
  }

  Dio get client => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          // Access token stále posíláme ručně v Headeru (pokud ho máme)
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },

        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Refresh endpoint sám vrátil 401 → token je nenávratně neplatný.
            if (e.requestOptions.path.contains('/auth/refresh')) {
              await logout();
              _authFailureController.add(null);
              return handler.next(e);
            }

            // Pokus o refresh
            final refreshed = await _refreshToken();
            if (refreshed) {
              // Opakování requestu s novým tokenem
              final newToken = await _storage.read(key: 'jwt_token');
              e.requestOptions.headers['Authorization'] = 'Bearer $newToken';

              final opts = Options(
                method: e.requestOptions.method,
                headers: e.requestOptions.headers,
              );
              final cloneReq = await _dio.request(
                e.requestOptions.path,
                options: opts,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
              );
              return handler.resolve(cloneReq);
            }

            // Refresh selhal (server vrátil 5xx nebo jiná chyba) → odhlásit.
            await logout();
            _authFailureController.add(null);
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<bool> _refreshToken() async {
    try {
      print("🔄 Refreshing token via Cookie...");

      // Separátní Dio instance se sdíleným CookieJar – CookieManager automaticky
      // přiloží HttpOnly refresh_token cookie k požadavku.
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _baseUrl,
          headers: {
            'Content-Type': 'application/vnd.api+json',
            'Accept': 'application/vnd.api+json',
          },
        ),
      );
      refreshDio.interceptors.add(CookieManager(_cookieJar));

      final response = await refreshDio.post('/auth/refresh');
      print("🔄 Refresh response status: ${response.statusCode}");
      print("🔄 Refresh response data: ${response.data}");

      if (response.statusCode == 200) {
        // Backend může vracet buď:
        //   (A) JSON:API: { data: { attributes: { access_token: "...", ws_connection_token: "..." } } }
        //   (B) Jednoduchý JSON: { access_token: "..." }
        String? newAccessToken;
        String? newWsToken;

        final data = response.data;
        if (data is Map) {
          if (data['data'] is Map && data['data']['attributes'] is Map) {
            // Varianta A – JSON:API (stejný formát jako /auth/login)
            final attrs = data['data']['attributes'] as Map;
            newAccessToken = attrs['access_token']?.toString();
            newWsToken = attrs['ws_connection_token']?.toString();
          } else {
            // Varianta B – jednoduchý JSON
            newAccessToken = data['access_token']?.toString();
            newWsToken = data['ws_connection_token']?.toString();
          }
        }

        if (newAccessToken == null || newAccessToken.isEmpty) {
          print("❌ Refresh: access_token nebyl nalezen v odpovědi");
          return false;
        }

        await _storage.write(key: 'jwt_token', value: newAccessToken);
        if (newWsToken != null && newWsToken.isNotEmpty) {
          await _storage.write(key: 'ws_token', value: newWsToken);
        }

        print("✅ Token obnoven");
        return true;
      }
    } catch (e) {
      print("❌ Refresh failed: $e");
    }
    return false;
  }

  // ... uvnitř ApiService class

  Future<List<Competition>> getMyCompetitions() async {
    print("🚀 API: Getting my competitions...");
    try {
      final response = await _dio.get(
        '/competitions',
        queryParameters: {
          'filter[my_judgements]': 'true',
          'sort': '-dateStart',
        },
      );
      print("✅ API: Response received: ${response.statusCode}");
      // print("📦 Data: ${response.data}"); // Okomentováno pro přehlednost

      final List<dynamic> data = response.data['data'];
      print("📊 Parsing ${data.length} competitions");

      return data.map((json) => Competition.fromJson(json)).toList();
    } on DioException catch (e) {
      print("❌ API Error in getMyCompetitions: ${e.message}");
      if (e.response != null) {
        print("📥 Response Status: ${e.response?.statusCode}");
        print("📥 Response Data: ${e.response?.data}");
        print("📤 Request Headers: ${e.requestOptions.headers}");
      }
      rethrow;
    } catch (e) {
      print("❌ Unknown Error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    // 1. Zavoláme login
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );

    // CookieManager automaticky zachytí 'Set-Cookie' s refresh tokenem
    // a uloží ho do telefonu. My se o to nestaráme.

    return response.data['data']['attributes'];
  }

  Future<void> logout() async {
    // Smazat Access Token
    await _storage.deleteAll();
    // Smazat Cookies (Refresh Token)
    await _cookieJar.deleteAll();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Judging API metody
  // ─────────────────────────────────────────────────────────────────────────

  /// Načte detail kola – disciplínu a seznam párů (startovní čísla).
  ///
  /// Volá se po přijetí START_ROUND Centrifugo eventu.
  /// Záměrně načítáme jen co potřebujeme: název kola, disciplínu, páry.
  Future<RoundDetail> getRound(String roundUuid) async {
    final response = await _dio.get(
      '/rounds/$roundUuid',
      queryParameters: {
        'include': 'discipline,discipline.disciplinePairs',
      },
    );
    return RoundDetail.fromJsonApi(response.data as Map<String, dynamic>);
  }

  /// Načte aktivní stav disciplíny z Redis cache.
  ///
  /// Volá se po přijetí START_DANCE eventu (action: PULL_ACTIVE_STATE)
  /// nebo při opětovném připojení (reconnect).
  Future<ActiveState> getActiveState(String disciplineUuid) async {
    final response = await _dio.get('/disciplines/$disciplineUuid/active-state');
    return ActiveState.fromJson(response.data as Map<String, dynamic>);
  }

  /// Načte aktivní stav soutěže – projde disciplíny soutěže a vrátí první aktivní stav z cache.
  ///
  /// Formát odpovědi je identický s [getActiveState].
  /// Volá se při připojení do rozjetého kola, kdy porotce nezná UUID disciplíny.
  Future<ActiveState> getCompetitionActiveState(String competitionId) async {
    final response = await _dio.get('/competitions/$competitionId/active-state');
    return ActiveState.fromJson(response.data as Map<String, dynamic>);
  }

  /// Odešle hromadné hodnocení párů na server.
  ///
  /// Endpoint je idempotentní (upsert) – bezpečné volat opakovaně.
  /// Porotce je identifikován z JWT tokenu na backendu.
  ///
  /// Throws [DioException] při síťové chybě – volající pak uloží do offline fronty.
  Future<void> submitScores(ScorePayload payload) async {
    await _dio.post('/scores/bulk', data: payload.toJson());
  }
}
