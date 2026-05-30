import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import 'package:flutter/foundation.dart';

class PocketService {
  static const String baseUrl = '${AppConfig.baseUrl}/pocket';

  /// Fetch the current pocket cash balance from the backend
  static Future<double> getPocketBalance() async {
    try {
      final token = await TokenService.getToken();
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data']['balance'] ?? 0).toDouble();
      }
    } catch (e) {
      // Return 0 silently if backend connection fails so app doesn't crash on boot
    }
    return 0.0;
  }

  /// Update the pocket cash balance directly
  static Future<void> updatePocketBalance(double amount) async {
    final token = await TokenService.getToken();
    final response = await http.put(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update pocket balance');
    }
  }

  /// Add cash (e.g. ATM withdrawal detected via SMS)
  static Future<void> addPocketCash(double amount) async {
    final token = await TokenService.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/add'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      debugPrint("Add pocket cash error: \${response.statusCode} - \${response.body}");
      throw Exception('Failed to add pocket cash');
    }
  }

  /// Subtract cash (e.g. manually spending cash)
  static Future<void> subtractPocketCash(double amount) async {
    final token = await TokenService.getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/subtract'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'amount': amount}),
    );
    if (response.statusCode != 200) {
      debugPrint("Subtract pocket cash error: \${response.statusCode} - \${response.body}");
      throw Exception('Failed to subtract pocket cash');
    }
  }
}
