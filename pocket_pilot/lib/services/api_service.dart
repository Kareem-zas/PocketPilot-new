import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import 'package:pockect_pilot/config/app_config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  static Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final token = await TokenService.getToken();

    final response = await http
        .post(
          Uri.parse("$baseUrl$endpoint"),
          headers: {
            "Content-Type": "application/json",
            if (token != null) "Authorization": "Bearer $token",
          },
          body: jsonEncode(data),
        )
        .timeout(
          _timeout,
          onTimeout: () => throw Exception(
            'Connection timed out. Please check your network and try again.',
          ),
        );

    final json = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    } else {
      throw Exception(json["message"] ?? "Something went wrong");
    }
  }
}
