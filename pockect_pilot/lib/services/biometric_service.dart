import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_enabled';

  /// Check if the hardware supports biometrics
  static Future<bool> isDeviceCapable() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics && isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types (e.g. Face ID, Fingerprint)
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  /// Perform biometric authentication
  static Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock your Pocket Pilot cockpit',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      return didAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Get user's configuration preference (whether they enabled biometric lock or not)
  static Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to false if not set
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Set user's configuration preference
  static Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  // ─── Alias Methods (for backward-compatibility with views) ────────────────

  /// Alias for [isBiometricsEnabled] — returns whether biometric lock is on.
  static Future<bool> isEnabled() => isBiometricsEnabled();

  /// Alias for [isDeviceCapable] — returns whether the device supports biometrics.
  static Future<bool> isAvailable() => isDeviceCapable();

  /// Alias for [setBiometricsEnabled] — saves the biometric lock preference.
  static Future<void> setEnabled(bool value) => setBiometricsEnabled(value);
}
