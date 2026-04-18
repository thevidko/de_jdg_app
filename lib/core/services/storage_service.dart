import 'package:de_jdg_app/core/models/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider pro přístup ke službě v celé appce
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(); // Inicializujeme v main.dart
});

class StorageService {
  final SharedPreferences _prefs;
  final _secureStorage = const FlutterSecureStorage();

  StorageService(this._prefs);

  // --- Secure Data (Tokeny) ---
  Future<void> setToken(String token) =>
      _secureStorage.write(key: 'jwt_token', value: token);
  Future<String?> getToken() => _secureStorage.read(key: 'jwt_token');

  Future<void> setWsToken(String token) =>
      _secureStorage.write(key: 'ws_token', value: token);
  Future<String?> getWsToken() => _secureStorage.read(key: 'ws_token');

  /// Smaže auth data (tokeny, profil, sezení) ale zachová konfiguraci serveru.
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.remove('user_id');
    await _prefs.remove('user_name');
    await _prefs.remove('user_surname');
    await _prefs.remove('locale');
    await _prefs.remove('first_run');
    // backend_url a ws_url záměrně zachováváme — server zůstane nastaven pro další přihlášení
  }

  // --- Normal Data (Settings, Flags) ---
  Future<void> setLocale(String code) => _prefs.setString('locale', code);
  String? getLocale() => _prefs.getString('locale');

  Future<void> setFirstRun(bool isFirst) =>
      _prefs.setBool('first_run', isFirst);
  bool get isFirstRun => _prefs.getBool('first_run') ?? true;

  // --- UŽIVATELSKÁ DATA (SharedPreferences) ---
  // Ukládáme jako jednotlivé klíče pro jednoduchost
  Future<void> saveUserProfile(String id, String name, String surname) async {
    await _prefs.setString('user_id', id);
    await _prefs.setString('user_name', name);
    await _prefs.setString('user_surname', surname);
  }

  // Načtení celého User objektu
  User? getUser() {
    final id = _prefs.getString('user_id');
    final name = _prefs.getString('user_name');
    final surname = _prefs.getString('user_surname');

    if (id != null && name != null && surname != null) {
      return User(id: id, name: name, surname: surname);
    }
    return null;
  }

  // --- Backend konfigurace (URL serveru) ---
  static const String _backendUrlKey = 'backend_url';
  static const String _wsUrlKey = 'ws_url';

  Future<void> setBackendUrl(String url) =>
      _prefs.setString(_backendUrlKey, url);
  String? getBackendUrl() => _prefs.getString(_backendUrlKey);

  Future<void> setWsUrl(String url) => _prefs.setString(_wsUrlKey, url);
  String? getWsUrl() => _prefs.getString(_wsUrlKey);

  Future<void> clearBackendConfig() async {
    await _prefs.remove(_backendUrlKey);
    await _prefs.remove(_wsUrlKey);
  }

  // --- Aktivní sezení porotce (pro obnovu stavu po restartu) ---
  // Klíče jsou scopované na competitionId, aby více soutěží nesdílelo stejná data.

  /// Uloží UUID aktivního kola a disciplíny – volá se po úspěšném START_ROUND.
  Future<void> saveActiveSession(String roundUuid, String disciplineUuid, {required String competitionId}) async {
    await _prefs.setString('active_round_uuid_$competitionId', roundUuid);
    await _prefs.setString('active_discipline_uuid_$competitionId', disciplineUuid);
  }

  String? getActiveRoundUuid({required String competitionId}) =>
      _prefs.getString('active_round_uuid_$competitionId');
  String? getActiveDisciplineUuid({required String competitionId}) =>
      _prefs.getString('active_discipline_uuid_$competitionId');

  /// Smaže aktivní sezení – volá se po END_ROUND.
  Future<void> clearActiveSession({required String competitionId}) async {
    await _prefs.remove('active_round_uuid_$competitionId');
    await _prefs.remove('active_discipline_uuid_$competitionId');
  }
}
