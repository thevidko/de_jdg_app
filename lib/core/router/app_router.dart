import 'package:de_jdg_app/features/auth/screens/login_screen.dart';
import 'package:de_jdg_app/features/competitions/screens/competition_screen.dart';
import 'package:de_jdg_app/features/discovery/discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/controllers/auth_controller.dart';
import 'dart:async';
// Importy tvých obrazovek (zatím placeholdery)
// import '../../features/auth/screens/login_screen.dart';
// import '../../features/home/screens/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Sledujeme změny v auth storu
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(
      ref.watch(authControllerProvider.notifier).stream,
    ), // Magie pro auto-redirect

    redirect: (context, state) {
      final isLoggedIn = authState.isAuthenticated;
      final path = state.uri.toString();
      final isLoggingIn = path == '/login';
      final isDiscovery = path == '/discovery';

      // 1. Pokud není přihlášen a není na loginu nebo discovery -> šup na login
      if (!isLoggedIn && !isLoggingIn && !isDiscovery) return '/login';

      // 2. Pokud je přihlášen a je na loginu -> šup domů
      if (isLoggedIn && isLoggingIn) return '/';

      return null; // Žádný redirect
    },

    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const CompetitionsScreen(), // <--- Změna zde
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/discovery',
        builder: (context, state) => const DiscoveryScreen(),
      ),
    ],
  );
});

// Pomocná třída pro konverzi Streamu na Listenable (aby to GoRouter pochopil)

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
