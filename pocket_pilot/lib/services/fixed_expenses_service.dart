import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class FixedExpensesService {
  static const String baseUrl = '${AppConfig.baseUrl}/subscriptions';

  static Future<void> addFixedExpenseItem({
    required String title,
    required double amount,
    required String frequency,
    required DateTime startDate,
  }) async {
    final token = await TokenService.getToken();

    final body = jsonEncode({
      'title': title,
      'amount': amount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'isActive': true,
    });

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: body,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      String msg = 'Status ${response.statusCode}: Failed to add fixed expense';
      try {
        final data = jsonDecode(response.body);
        msg = data['message'] ?? msg;
      } catch (_) {
        msg = response.body.isNotEmpty ? response.body : msg;
      }
      throw Exception(msg);
    }
  }

  static Future<List<dynamic>> getFixedExpenseItems() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load fixed expenses');
    }

    final data = jsonDecode(response.body);
    final List<dynamic> items = data['data'] != null ? (data['data']['subscriptions'] ?? []) : [];
    
    return items.map((item) {
      item['title'] = item['vendor'] ?? 'Unknown';
      return item;
    }).toList();
  }

  static Future<void> updateFixedExpenseActivity({
    required String itemId,
    required bool isActive,
  }) async {
    final token = await TokenService.getToken();

    final response = await http.patch(
      Uri.parse('$baseUrl/$itemId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'isActive': isActive}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update fixed expense activity');
    }
  }
}
