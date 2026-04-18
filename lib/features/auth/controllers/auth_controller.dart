import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/models/user.dart';

// Provider pro AuthController
final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final storage = ref.watch(storageServiceProvider);
    return AuthController(storage);
  },
);

// 1. Rozšíříme AuthState o Usera
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final User? user; // <--- Přidáno

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.user,
  });
}

class AuthController extends StateNotifier<AuthState> {
  final StorageService _storage;
  final _api = ApiService();
  late final StreamSubscription<void> _authFailureSub;

  AuthController(this._storage) : super(AuthState()) {
    checkAuthStatus();
    // Naslouchá nenávratnému selhání refreshe (smazaný/expirovaný token na serveru).
    // ApiService zavolá logout() (smaže tokeny) a emituje sem → přesměrujeme na login.
    _authFailureSub = _api.authFailureStream.listen((_) {
      if (mounted) state = AuthState(isAuthenticated: false);
    });
  }

  @override
  void dispose() {
    _authFailureSub.cancel();
    super.dispose();
  }

  Future<void> checkAuthStatus() async {
    state = AuthState(isLoading: true);
    final token = await _storage.getToken();

    if (token == null) {
      state = AuthState(isAuthenticated: false, isLoading: false);
      return;
    }

    // Ověříme dostupnost backendu před tím, než uživatele pustíme dál.
    final backendOk = await _api.checkHealth();
    if (!backendOk) {
      await _api.logout();
      await _storage.clearAll();
      await _storage.clearBackendConfig();
      _api.resetUrls();
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: 'Server není dostupný. Zkontrolujte Wi-Fi nebo vyberte jiný server.',
      );
      return;
    }

    final cachedUser = _storage.getUser();
    state = AuthState(isAuthenticated: true, isLoading: false, user: cachedUser);
  }

  /// Voláno při návratu aplikace do popředí.
  /// Pokud server přestal odpovídat, odhlásí uživatele.
  Future<void> checkBackendHealth() async {
    if (!state.isAuthenticated) return;
    final ok = await _api.checkHealth();
    if (!ok && mounted) {
      await _api.logout();
      await _storage.clearAll();
      await _storage.clearBackendConfig();
      _api.resetUrls();
      state = AuthState(
        isAuthenticated: false,
        error: 'Spojení se serverem bylo přerušeno. Přihlaste se znovu.',
      );
    }
  }

  Future<void> login(String email, String password) async {
    state = AuthState(isLoading: true);
    try {
      // 1. Získání dat z API
      final attributes = await _api.login(email, password);

      // attributes obsahuje to JSON pole, co jsi poslal
      final accessToken = attributes['access_token'];
      // final refreshToken = attributes['expires_in']; // Refresh token je nyní v HttpOnly Cookie

      final wsToken = attributes['ws_connection_token'];
      final userId = attributes['id'];
      final name = attributes['name'];
      final surname = attributes['surname'];

      // 2. Uložení do Storage
      if (accessToken != null) await _storage.setToken(accessToken);
      if (wsToken != null) await _storage.setWsToken(wsToken);

      // Uložení profilu
      await _storage.saveUserProfile(userId, name, surname);

      // 3. Vytvoření User objektu pro State
      final user = User(id: userId, name: name, surname: surname);

      // 4. Update stavu
      state = AuthState(isAuthenticated: true, isLoading: false, user: user);
    } catch (e) {
      state = AuthState(
        isAuthenticated: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _api.logout(); // Vymaže cookies a tokeny v API service
    await _storage.clearAll(); // Vymaže tokeny i profil v StorageService
    state = AuthState(isAuthenticated: false);
  }
}
