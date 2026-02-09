import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:centrifuge/centrifuge.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class CentrifugoService {
  late Client _client;
  StreamSubscription<ConnectedEvent>? _connectSub;
  StreamSubscription<DisconnectedEvent>? _disconnectSub;

  final ApiService _apiService;
  final _storage = const FlutterSecureStorage();

  // URL pro WebSocket (pozor na Android emulátor vs iOS/Web)
  final String _wsUrl = 'ws://localhost:8010/connection/websocket';

  CentrifugoService(this._apiService);

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  String _currentStatus = "Zatím žádný status...";
  String get currentStatus => _currentStatus;

  void _updateStatus(String status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  /// 1. Připojení k serveru (Vstup do budovy)
  Future<void> connect() async {
    // Načteme connection token, který jsme uložili při Loginu
    final wsToken = await _storage.read(key: 'ws_token');

    if (wsToken == null) {
      const msg = "⚠️ Centrifugo: Chybí WS token, nelze se připojit.";
      print(msg);
      _updateStatus(msg);
      return;
    }

    try {
      final parts = wsToken.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64.decode(base64.normalize(parts[1]))),
        );
        print("🕵️ WS Token Payload: $payload");
        // Check expiration
        if (payload['exp'] != null) {
          final exp = DateTime.fromMillisecondsSinceEpoch(
            payload['exp'] * 1000,
          );
          print("⏳ WS Token Expires: $exp (Local: ${exp.toLocal()})");
          if (exp.isBefore(DateTime.now())) {
            print("❌ WS Token is EXPIRED!");
            _updateStatus("⚠️ WS Token Expired. Please login again.");
          }
        }
      }
    } catch (e) {
      print("⚠️ Failed to parse WS Token: $e");
    }

    // Pokud už existuje klient, zkusíme ho jen připojit, nebo ho vytvoříme znovu?
    // Pro jednoduchost vytvoříme nový, ale nejprve uklidíme starý.
    try {
      // ignore: unnecessary_null_comparison
      if (_client != null) {
        // _client je late, takže přístup k němu před inicializací by hodil chybu.
        // Ale v Dartu nemáme snadno check 'isInitialized'.
        // Takže spoléháme na to, že toto volání connect() může být první.
        // Zjednodušení: Vždy vytvoříme nový klient.
        _connectSub?.cancel();
        _disconnectSub?.cancel();
        try {
          _client.disconnect();
        } catch (_) {}
      }
    } catch (_) {
      // Ignorujeme LateInitializationError
    }

    _client = createClient(_wsUrl, ClientConfig(token: wsToken));

    _connectSub = _client.connected.listen((event) {
      final msg = "✅ Centrifugo: Připojeno (Client ID: ${event.client})";
      print(msg);
      _updateStatus(msg);
    });

    _disconnectSub = _client.disconnected.listen((event) {
      final msg = "❌ Centrifugo: Odpojeno (${event.reason})";
      print(msg);
      _updateStatus(msg);
    });

    try {
      _updateStatus("⏳ Připojuji se k Centrifugu ($_wsUrl)...");
      await _client.connect();
    } catch (e) {
      final msg = "🔥 Centrifugo Error: $e";
      print(msg);
      _updateStatus(msg);
    }
  }

  /// 2. Odběr kanálu (Vstup do místnosti)
  /// Automaticky vyřeší auth pro privátní kanály (judges:...)
  Future<Subscription?> subscribe(String channel) async {
    String? subToken;

    // Pokud je kanál privátní (začíná na "judges:"), musíme získat token z API
    if (channel.startsWith('judges:')) {
      try {
        print("🔐 Centrifugo: Žádám o přístup do kanálu $channel...");
        subToken = await _getSubscriptionToken(channel);
      } catch (e) {
        print("⛔ Centrifugo: Přístup zamítnut pro $channel. ($e)");
        return null;
      }
    }

    // Vytvoření odběru
    final subscription = _client.newSubscription(
      channel,
      SubscriptionConfig(
        token: subToken ?? '', // Zde vložíme token získaný z API
      ),
    );

    // Nastavení listenerů - Listener pro data necháme na UI vrstvě (CompetitionDetailScreen),
    // abychom předešli chybě "Stream has already been listened to".
    // subscription.publication.listen((event) { ... });

    subscription.join.listen((event) {
      final msg = "👋 User joined $channel: ${event.user} (${event.client})";
      print(msg);
      _updateStatus(msg);
    });

    subscription.leave.listen((event) {
      final msg = "qv User left $channel: ${event.user}";
      print(msg);
      _updateStatus(msg);
    });

    subscription.subscribed.listen((event) {
      final msg = "✅ Odebírám kanál $channel";
      print(msg);
      _updateStatus(msg);
    });

    subscription.error.listen((event) {
      final msg = "🛑 Chyba odběru $channel: ${event.error}";
      print(msg);
      _updateStatus(msg);
    });

    subscription.subscribe();
    return subscription;
  }

  /// Pomocná metoda pro volání tvého Laravel endpointu /api/broadcasting/auth
  Future<String> _getSubscriptionToken(String channel) async {
    // Použijeme tvůj existující ApiService (Dio)
    // Dio automaticky přidá Bearer token (JWT) díky interceptoru, který jsme dělali minule
    try {
      final response = await _apiService.client.post(
        '/broadcasting/auth',
        data: {'channel': channel},
      );
      print("🔑 Auth Response for $channel: ${response.data}"); // LOG RESPONSE

      // Backend vrací { token: "..." } nebo { data: { token: "..." } } - zkontroluj dle Laravel response
      // Laravel default broadcast auth vrací přímo JSON s klíčem 'auth' nebo 'token'.
      return response.data['token'];
    } catch (e) {
      print("❌ Auth Request Failed: $e");
      rethrow;
    }
  }

  void disconnect() {
    _client.disconnect();
    _connectSub?.cancel();
    _disconnectSub?.cancel();
  }
}
