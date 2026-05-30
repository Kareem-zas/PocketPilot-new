import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class UserService {
  static const String baseUrl = AppConfig.baseUrl;

  static Future<Map<String, dynamic>> getUserInfo() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/auth/getUser'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 401) {
      throw Exception("token");
    }

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed');
    }

    return data;
  }
}
