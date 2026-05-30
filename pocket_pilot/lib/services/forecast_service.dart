import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ForecastService {
  static const String baseUrl = '${AppConfig.baseUrl}/forecast';

  static Future<Map<String, dynamic>> getForecast() async {
    try {
      final token = await TokenService.getToken();
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Failed to fetch forecast');
      }

      return data['data'];
    } catch (e) {
      // Graceful fallback for network offline
      throw Exception("Network error: Please check your internet connection.");
    }
  }
}
