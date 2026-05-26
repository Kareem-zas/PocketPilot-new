import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the JWT auth token in hardware-backed encrypted storage.
///
/// On Android this uses the Android Keystore system.
/// On iOS this uses the Keychain.
/// Both are inaccessible to other apps and survive basic root/jailbreak
/// attempts, unlike SharedPreferences (which is plain XML on disk).
class TokenService {
  static const _key = "auth_token";

  // Use encrypted storage (Android Keystore / iOS Keychain).
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _key, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _key);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _key);
  }
}
