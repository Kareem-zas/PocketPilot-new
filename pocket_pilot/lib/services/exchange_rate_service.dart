import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Fetches live exchange rates from open.er-api.com (free, no API key).
/// Results are cached in memory for the duration of the app session.
class ExchangeRateService {
  // In-memory cache: base currency -> { target -> rate }
  static final Map<String, Map<String, double>> _cache = {};

  /// Returns the exchange rate from [from] to [to].
  /// e.g. getRate('JOD', 'SAR') → ~4.92
  /// Returns 1.0 on failure (safe fallback = no conversion).
  static Future<double> getRate(String from, String to) async {
    if (from == to) return 1.0;

    // Return cached value if available
    if (_cache[from] != null && _cache[from]!.containsKey(to)) {
      return _cache[from]![to]!;
    }

    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/$from');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('ExchangeRateService: HTTP ${response.statusCode}');
        return 1.0;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['result'] != 'success') {
        debugPrint('ExchangeRateService: API result not success');
        return 1.0;
      }

      final rates = Map<String, dynamic>.from(data['rates'] as Map);

      // Cache all rates for this base
      _cache[from] = {};
      for (final entry in rates.entries) {
        final r = (entry.value as num?)?.toDouble();
        if (r != null) _cache[from]![entry.key] = r;
      }

      return _cache[from]![to] ?? 1.0;
    } catch (e) {
      debugPrint('ExchangeRateService error: $e');
      return 1.0;
    }
  }

  /// Clears the in-memory cache (call on logout or after long idle).
  static void clearCache() => _cache.clear();
}
