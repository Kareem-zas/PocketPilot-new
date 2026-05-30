/// Centralized application configuration.
///
/// API keys and the backend URL are injected at compile-time via --dart-define
/// to keep them out of source code and APK binaries.
///
/// Use the helper script to run with the correct local IP automatically:
///   powershell -ExecutionPolicy Bypass -File run_dev.ps1
///
/// Or supply manually:
///   flutter run \
///     --dart-define=BASE_URL=http://YOUR_IP:8000/api \
///     --dart-define=GEMINI_CHAT_KEY=YOUR_KEY \
///     --dart-define=GEMINI_RECEIPT_KEY=YOUR_KEY
///
/// For development, fallback values are used automatically if no
/// --dart-define argument is supplied.
class AppConfig {
  AppConfig._();

  // ─── Backend ─────────────────────────────────────────────────────────────
  /// Backend base URL — injected at build time via --dart-define=BASE_URL.
  /// Falls back to 10.0.2.2 (Android emulator loopback to host machine).
  /// When running on a physical device use run_dev.ps1 to auto-detect the IP.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );
  // Switch to https:// once the backend server is behind SSL/TLS (e.g., Let's Encrypt + Nginx).

  // ─── Security ────────────────────────────────────────────────────────────
  /// Maximum login attempts before a temporary lockout is enforced.
  static const int maxLoginAttempts = 5;

  /// Lockout duration in seconds after [maxLoginAttempts] is reached.
  static const int loginLockoutSeconds = 30;
}
