import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/services/score_queue_service.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'features/realtime/providers/centrifugo_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Načtení uložené URL backendu (pokud uživatel vybral server přes discovery)
  final backendUrl = prefs.getString('backend_url');
  final wsUrl = prefs.getString('ws_url');

  await ApiService().init(baseUrl: backendUrl, wsUrl: wsUrl);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(StorageService(prefs)),
        scoreQueueServiceProvider.overrideWithValue(ScoreQueueService(prefs)),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      // Při návratu z pozadí ověříme dostupnost serveru.
      ref.read(authControllerProvider.notifier).checkBackendHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    ref.watch(realtimeControllerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'DanceEval Judge',
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
