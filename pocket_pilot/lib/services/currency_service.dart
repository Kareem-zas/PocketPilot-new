import 'package:shared_preferences/shared_preferences.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;
  final String flag;

  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.name,
    required this.flag,
  });
}

class CurrencyService {
  static const String _codeKey = 'preferred_currency';
  static const String _baseCodeKey = 'base_currency';
  static const String _rateKey = 'currency_conversion_rate';
  static const String _defaultCode = 'JOD';

  /// All supported currencies
  static const List<CurrencyInfo> supportedCurrencies = [
    CurrencyInfo(code: 'JOD', symbol: 'JD',   name: 'Jordanian Dinar',  flag: '🇯🇴'),
    CurrencyInfo(code: 'SAR', symbol: '﷼',    name: 'Saudi Riyal',      flag: '🇸🇦'),
    CurrencyInfo(code: 'AED', symbol: 'د.إ',  name: 'UAE Dirham',       flag: '🇦🇪'),
    CurrencyInfo(code: 'KWD', symbol: 'KD',   name: 'Kuwaiti Dinar',    flag: '🇰🇼'),
    CurrencyInfo(code: 'EGP', symbol: 'E£',   name: 'Egyptian Pound',   flag: '🇪🇬'),
    CurrencyInfo(code: 'USD', symbol: '\$',    name: 'US Dollar',        flag: '🇺🇸'),
    CurrencyInfo(code: 'EUR', symbol: '€',    name: 'Euro',             flag: '🇪🇺'),
  ];

  // ── Code ──────────────────────────────────────────────────────────────────

  /// Returns the saved display currency code (defaults to JOD)
  static Future<String> getCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_codeKey) ?? _defaultCode;
  }

  /// Returns the base currency code that amounts are stored in (defaults to JOD)
  static Future<String> getBaseCurrencyCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseCodeKey) ?? _defaultCode;
  }

  // ── Conversion rate ───────────────────────────────────────────────────────

  /// Returns the stored conversion rate relative to the base (original) currency.
  /// e.g. if user started with JOD and now uses SAR, rate ≈ 4.92
  /// Returns 1.0 (no-op) if not set or if JOD is active.
  static Future<double> getConversionRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rateKey) ?? 1.0;
  }

  /// Saves both the currency code and the conversion rate atomically.
  static Future<void> setCurrencyWithRate(String code, double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, code);
    await prefs.setDouble(_rateKey, rate);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the full CurrencyInfo object for the saved currency
  static Future<CurrencyInfo> getCurrency() async {
    final code = await getCurrencyCode();
    return fromCode(code);
  }

  /// Returns just the symbol string (e.g. "JD", "$", "€")
  static Future<String> getSymbol() async {
    final currency = await getCurrency();
    return currency.symbol;
  }

  /// Converts a raw amount (stored in the base/original currency, JOD)
  /// to the user's currently selected display currency.
  static Future<double> convertAmount(double rawAmount) async {
    final rate = await getConversionRate();
    return rawAmount * rate;
  }

  /// Synchronous conversion using a pre-fetched rate.
  static double convertSync(double rawAmount, double rate) => rawAmount * rate;

  /// Synchronous lookup by code (for UI that already has the code)
  static CurrencyInfo fromCode(String code) {
    return supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first, // JOD fallback
    );
  }

  /// Legacy fallback, but actually we use this for onboarding now
  /// to set the initial base currency.
  static Future<void> initBaseCurrency(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseCodeKey, code);
    await prefs.setString(_codeKey, code);
    await prefs.setDouble(_rateKey, 1.0);
  }

  /// Convenience: format a raw amount with the current symbol + conversion.
  static Future<String> format(double rawAmount) async {
    final rate = await getConversionRate();
    final symbol = await getSymbol();
    final converted = rawAmount * rate;
    return '$symbol ${converted.toStringAsFixed(2)}';
  }
}
