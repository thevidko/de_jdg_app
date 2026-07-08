import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/centrifugo_service.dart';
import '../../auth/controllers/auth_controller.dart';

// Provider pro samotnou službu
final centrifugoServiceProvider = Provider<CentrifugoService>((ref) {
  // Potřebujeme ApiService pro volání auth endpointu
  return CentrifugoService(ApiService());
});

// Controller, který řídí životní cyklus spojení na základě Auth stavu
final realtimeControllerProvider = Provider<void>((ref) {
  final authState = ref.watch(authControllerProvider);
  final centrifugo = ref.read(centrifugoServiceProvider);

  // Zkontrolujeme, zda máme autentikovaného uživatele a zda máme ws_token
  if (authState.isAuthenticated) {
    // Pokud je uživatel přihlášen, připojíme socket
    print("Spouštím Realtime spojení...");
    centrifugo.connect();
  } else {
    // Pokud se odhlásí, odpojíme
    centrifugo.disconnect();
  }
});
