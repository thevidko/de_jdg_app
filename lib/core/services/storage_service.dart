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

  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    await _prefs.clear(); // Vymaže i profilová data
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
}
