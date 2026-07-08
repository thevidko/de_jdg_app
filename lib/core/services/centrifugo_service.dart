import 'dart:async';
import 'dart:convert';
import 'package:centrifuge/centrifuge.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class CentrifugoService {
  Client? _client;
  StreamSubscription<ConnectedEvent>? _connectSub;
  StreamSubscription<DisconnectedEvent>? _disconnectSub;

  final Map<String, Subscription> _subscriptions = {};

  final ApiService _apiService;
  final _storage = const FlutterSecureStorage();

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
      const msg = "Centrifugo: Chybí WS token, nelze se připojit.";
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
        print("WS Token Payload: $payload");
        if (payload['sub'] != null) {
          print("Token Subject (User UUID): ${payload['sub']}");
        }
        // Check expiration
        if (payload['exp'] != null) {
          final exp = DateTime.fromMillisecondsSinceEpoch(
            payload['exp'] * 1000,
          );
          print("WS Token Expires: $exp (Local: ${exp.toLocal()})");
          if (exp.isBefore(DateTime.now())) {
            print("WS Token is EXPIRED!");
            _updateStatus("WS Token Expired. Please login again.");
          }
        }
      }
    } catch (e) {
      print("Failed to parse WS Token: $e");
    }

    // Vždy čisté odpojení před novým připojením
    await disconnect();

    print("Vytvářím nový Centrifugo Client...");
    _client = createClient(_apiService.wsUrl, ClientConfig(token: wsToken));

    _connectSub = _client?.connected.listen((event) {
      final msg = "Centrifugo: Připojeno (Client ID: ${event.client})";
      print(msg);
      _updateStatus(msg);
    });

    _disconnectSub = _client?.disconnected.listen((event) {
      final msg = "Centrifugo: Odpojeno (${event.reason})";
      print(msg);
      _updateStatus(msg);
    });

    try {
      _updateStatus("Připojuji se k Centrifugu (${_apiService.wsUrl})...");
      await _client?.connect();
    } catch (e) {
      final msg = "Centrifugo Error: $e";
      print(msg);
      _updateStatus(msg);
    }
  }

  /// 2. Odběr kanálu (Vstup do místnosti)
  Future<Subscription?> subscribe(String channel) async {
    if (_client == null) {
      _updateStatus("Nemohu odebírat $channel - klient není připojen.");
      return null;
    }

    String? subToken;

    // Pokud je kanál privátní (začíná na "judges:"), musíme získat token z API
    if (channel.startsWith('judges:')) {
      try {
        print("Centrifugo: Žádám o přístup do kanálu $channel...");
        subToken = await _getSubscriptionToken(channel);
      } catch (e) {
        print("Centrifugo: Přístup zamítnut pro $channel. ($e)");
        return null;
      }
    }

    final existing = _subscriptions[channel];
    if (existing != null) {
      try {
        _client!.removeSubscription(existing);
      } catch (_) {}
      _subscriptions.remove(channel);
    }

    // Vytvoření odběru
    final subscription = _client!.newSubscription(
      channel,
      SubscriptionConfig(
        token: subToken ?? '',
      ),
    );
    _subscriptions[channel] = subscription;



    subscription.join.listen((event) {
      final msg = "User joined $channel: ${event.user} (${event.client})";
      print(msg);
      _updateStatus(msg);
    });

    subscription.leave.listen((event) {
      final msg = "qv User left $channel: ${event.user}";
      print(msg);
      _updateStatus(msg);
    });

    subscription.subscribed.listen((event) {
      final msg = "Odebírám kanál $channel";
      print(msg);
      _updateStatus(msg);
    });

    subscription.error.listen((event) {
      final msg = "Chyba odběru $channel: ${event.error}";
      print(msg);
      _updateStatus(msg);
    });

    subscription.subscribe();
    return subscription;
  }

  Future<String> _getSubscriptionToken(String channel) async {
    try {
      final response = await _apiService.client.post(
        '/broadcasting/auth',
        data: {'channel': channel},
      );
      print("Auth Response for $channel: ${response.data}");

      return response.data['token'];
    } on DioException catch (e) {
      print("Auth Request Failed: ${e.message}");
      if (e.response != null) {
        print("Status: ${e.response?.statusCode}");
        print("Headers: ${e.response?.headers}");
        print("Data: ${e.response?.data}");
      }
      rethrow;
    } catch (e) {
      print("Auth Request Failed: $e");
      rethrow;
    }
  }


  Future<void> removeChannel(String channel) async {
    final sub = _subscriptions.remove(channel);
    if (sub == null || _client == null) return;
    try {
      _client!.removeSubscription(sub);
    } catch (_) {}
  }

  Future<void> disconnect() async {
    _connectSub?.cancel();
    _disconnectSub?.cancel();
    if (_client != null) {

      for (final sub in _subscriptions.values) {
        try {
          _client!.removeSubscription(sub);
        } catch (_) {}
      }
      _subscriptions.clear();
      try {
        _client!.disconnect();
      } catch (_) {}
      _client = null;
    }
  }
}
