/// Centralized application configuration.
///
/// API keys are injected at compile-time via --dart-define to keep them
/// out of source code and APK binaries.
///
/// Build command:
///   flutter run \
///     --dart-define=GEMINI_CHAT_KEY=YOUR_KEY \
///     --dart-define=GEMINI_RECEIPT_KEY=YOUR_KEY
///
/// For development, fallback values are used automatically if no
/// --dart-define argument is supplied.
class AppConfig {
  AppConfig._();

  // ─── Backend ─────────────────────────────────────────────────────────────
  static const String baseUrl = 'http://192.168.1.17:8000/api';
  // Switch to https:// once the backend server is behind SSL/TLS (e.g., Let's Encrypt + Nginx).

  // ─── Gemini AI ───────────────────────────────────────────────────────────
  // Keys injected at build time; fallback used for local dev only.
  static const String geminiChatKey = String.fromEnvironment(
    'GEMINI_CHAT_KEY',
    defaultValue: 'AIzaSyDla_OJ6RVFQDmnRK9cMfRT9F6hWgoTaao',
  );

  static const String geminiReceiptKey = String.fromEnvironment(
    'GEMINI_RECEIPT_KEY',
    defaultValue: 'AIzaSyCOaqXPCVD8b3Et8TEO9ImwBrOGlVaeh-k',
  );

  // ─── Security ────────────────────────────────────────────────────────────
  /// Maximum login attempts before a temporary lockout is enforced.
  static const int maxLoginAttempts = 5;

  /// Lockout duration in seconds after [maxLoginAttempts] is reached.
  static const int loginLockoutSeconds = 30;
}
