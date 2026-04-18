import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

class DiscoveredBackend {
  final String name;
  final String url;
  final String wsUrl;

  const DiscoveredBackend({
    required this.name,
    required this.url,
    required this.wsUrl,
  });

  @override
  bool operator ==(Object other) =>
      other is DiscoveredBackend && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

class HealthResult {
  final bool reachable;
  final String? checkedPath;

  const HealthResult({required this.reachable, this.checkedPath});
}

class DiscoveryService {
  static const int _port = 42042;
  static const String _probe = 'DANCEEVAL_DISCOVER';
  static const Duration _timeout = Duration(seconds: 4);

  static const _channel = MethodChannel('danceeval/multicast');

  Future<void> _acquireMulticastLock() async {
    try {
      await _channel.invokeMethod('acquireLock');
    } catch (_) {}
  }

  Future<void> _releaseMulticastLock() async {
    try {
      await _channel.invokeMethod('releaseLock');
    } catch (_) {}
  }

  /// Broadcastuje UDP probe a sbírá odpovědi po dobu [_timeout].
  /// Vrací deduplikovaný seznam nalezených backendů.
  Future<List<DiscoveredBackend>> discover() async {
    final found = <DiscoveredBackend>{};

    final broadcastAddresses = await _getBroadcastAddresses();
    if (broadcastAddresses.isEmpty) return [];

    await _acquireMulticastLock();

    final completer = Completer<void>();
    RawDatagramSocket? socket;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final probe = utf8.encode(_probe);
      for (final addr in broadcastAddresses) {
        socket.send(probe, addr, _port);
      }

      Timer(_timeout, () {
        if (!completer.isCompleted) completer.complete();
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram == null) return;
          try {
            final json =
                jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
            found.add(
              DiscoveredBackend(
                name: json['name'] as String? ?? 'DanceEval Backend',
                url: json['url'] as String,
                wsUrl: json['ws_url'] as String,
              ),
            );
          } catch (_) {}
        }
      });

      await completer.future;
    } catch (_) {
    } finally {
      socket?.close();
      await _releaseMulticastLock();
    }

    return found.toList();
  }

  /// Ověří dostupnost backendu přes HTTP GET na /up nebo /health.
  ///
  /// Healthcheck jde na origin (bez /api/v1), protože /up a /health jsou
  /// root-level Laravel routy, ne pod API prefixem.
  /// Vrací [HealthResult] s URL, na které server odpověděl.
  Future<HealthResult> verifyBackend(String apiUrl) async {
    final origin = _origin(apiUrl);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4)
      ..idleTimeout = const Duration(seconds: 4);

    try {
      for (final path in ['/up', '/health']) {
        try {
          final uri = Uri.parse('$origin$path');
          final req = await client.getUrl(uri);
          final res = await req.close().timeout(const Duration(seconds: 4));
          await res.drain<void>();
          if (res.statusCode >= 200 && res.statusCode < 300) {
            return HealthResult(reachable: true, checkedPath: '$origin$path');
          }
        } catch (_) {
          continue;
        }
      }
      return HealthResult(reachable: false);
    } finally {
      client.close(force: true);
    }
  }

  /// Extrahuje origin (scheme + host + port) z plné API URL.
  /// 'http://192.168.10.54:8000/api/v1' → 'http://192.168.10.54:8000'
  String _origin(String url) {
    final uri = Uri.parse(url);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  /// Vrátí directed broadcast adresy pro všechna aktivní IPv4 rozhraní.
  /// Předpokládá /24 (nejčastější domácí/firemní sítě).
  Future<List<InternetAddress>> _getBroadcastAddresses() async {
    final seen = <String>{};
    final result = <InternetAddress>[];

    void add(String ip) {
      if (seen.add(ip)) result.add(InternetAddress(ip));
    }

    // Primární zdroj: standardní Dart API (spolehlivé na Android 12+).
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            add('${parts[0]}.${parts[1]}.${parts[2]}.255');
          }
        }
      }
    } catch (_) {}

    // Záložní zdroj: WifiManager přes platform channel.
    // Na Android 12+ vrátí null (NetworkInterface tam funguje spolehlivě).
    // Na Android 11 a níže doplní adresu, pokud ji NetworkInterface.list() vynechal.
    try {
      final ip = await _channel.invokeMethod<String?>('getWifiIp');
      if (ip != null) {
        final parts = ip.split('.');
        if (parts.length == 4) {
          add('${parts[0]}.${parts[1]}.${parts[2]}.255');
        }
      }
    } catch (_) {}

    // Poslední záchrana pokud oba zdroje selžou.
    if (result.isEmpty) add('255.255.255.255');

    return result;
  }
}
