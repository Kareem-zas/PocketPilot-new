import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class VariableExpensesService {
  static const String baseUrl =
      'http://192.168.1.17:8000/api/variable-expenses';

  // ✅ ADD EXPENSE (هذا اللي كان ناقص)
  static Future<void> addExpense({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final token = await TokenService.getToken();

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'amount': amount,
        'category': category,
        'date': date.toIso8601String(),
        'notes': notes,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to add expense');
    }
  }

  // ✅ FETCH VARIABLE EXPENSES (Dashboard)
  static Future<List<dynamic>> getVariableExpenses({
    int? year,
    int? month,
  }) async {
    final token = await TokenService.getToken();

    final query = <String, String>{};
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString();

    final uri = Uri.parse('http://192.168.1.17:8000/api/dashboard')
        .replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load variable expenses');
    }

    final data = jsonDecode(response.body);
    return data['data']['summary']['expenses']['variable']['details'] ?? [];
  }

  // ✅ SYNC SMS EXPENSES
  static Future<int> syncSmsExpenses(List<Map<String, dynamic>> transactions) async {
    final token = await TokenService.getToken();

    // Ensure dates are stringified for JSON encoding
    final encodedTransactions = transactions.map((t) {
      final copy = Map<String, dynamic>.from(t);
      if (copy['date'] is DateTime) {
        copy['date'] = (copy['date'] as DateTime).toIso8601String();
      }
      return copy;
    }).toList();

    final response = await http.post(
      Uri.parse('$baseUrl/sms-sync'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'transactions': encodedTransactions}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to sync SMS transactions');
    }

    final data = jsonDecode(response.body);
    return data['data']['addedCount'] ?? 0;
  }
}
