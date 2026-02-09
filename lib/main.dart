import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/api_service.dart';
import 'features/realtime/providers/centrifugo_providers.dart'; // <--- Import provideru

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Načtení SharedPreferences před startem appky
  final prefs = await SharedPreferences.getInstance();

  // Inicializace API a Cookies
  await ApiService().init(); // <--- Tady se připraví cookie jar

  runApp(
    // 2. ProviderScope obaluje celou aplikaci (jako Pinia root)
    ProviderScope(
      overrides: [
        // 3. Injectneme vytvořenou instanci prefs do našeho provideru
        storageServiceProvider.overrideWithValue(StorageService(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 4. Načteme router
    final router = ref.watch(routerProvider);

    // 5. Aktivujeme realtime controller (Centrifugo)
    ref.watch(realtimeControllerProvider);

    return MaterialApp.router(
      title: 'Moje Flutter App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 6. Napojení GoRouteru
      routerConfig: router,
    );
  }
}
