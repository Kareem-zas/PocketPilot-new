import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class IncomeService {
  static const String baseUrl = 'http://192.168.1.17:8000/api';

  static Future<Map<String, dynamic>> insertIncome({
    required String source,
    required double amount,
    required DateTime date,
    bool isRecurring = false,
    String? frequency,
    String? notes,
  }) async {
    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse('$baseUrl/income'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'source': source,
        'amount': amount,
        'date': date.toIso8601String(),
        'isRecurring': isRecurring,
        'frequency': frequency,
        'notes': notes,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to add income');
    }

    return data;
  }

  static Future<List<dynamic>> getIncome() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/dashboard'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to fetch income');
    }

    // 🔥 القراءة الصحيحة من Dashboard API
    return data['data']
            ?['summary']
            ?['income']
            ?['details'] ??
        [];
  }

  // ✅ SYNC SMS INCOME
  static Future<int> syncSmsIncome(List<Map<String, dynamic>> transactions) async {
    final token = await TokenService.getToken();

    final encodedTransactions = transactions.map((t) {
      final copy = Map<String, dynamic>.from(t);
      if (copy['date'] is DateTime) {
        copy['date'] = (copy['date'] as DateTime).toIso8601String();
      }
      return copy;
    }).toList();

    final response = await http.post(
      Uri.parse('$baseUrl/income/sms-sync'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'transactions': encodedTransactions}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to sync SMS income');
    }

    final data = jsonDecode(response.body);
    return data['data']['addedCount'] ?? 0;
  }
}
