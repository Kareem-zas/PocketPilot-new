import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class IncomeService {
  static const String baseUrl = AppConfig.baseUrl;

  // ── Insert new income ─────────────────────────────────────────────────────
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

  // ── Get all incomes (full list, not just current month) ───────────────────
  static Future<List<dynamic>> getAllIncomes() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse('$baseUrl/income'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to fetch incomes');
    }
    return data['data']?['incomes'] ?? [];
  }

  // ── Get income (current month details from dashboard) ─────────────────────
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
    return data['data']?['summary']?['income']?['details'] ?? [];
  }

  // ── Delete income ─────────────────────────────────────────────────────────
  static Future<void> deleteIncome(String id) async {
    final token = await TokenService.getToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/income/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete income');
    }
  }

  // ── Toggle recurring income active/inactive ───────────────────────────────
  static Future<Map<String, dynamic>> toggleActive(String id) async {
    final token = await TokenService.getToken();

    final response = await http.patch(
      Uri.parse('$baseUrl/income/$id/toggle-active'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to toggle income');
    }
    return data['data']['income'];
  }

  // ── Pause a specific month (e.g. unpaid leave) ────────────────────────────
  static Future<void> pauseMonth(String id, int year, int month) async {
    final token = await TokenService.getToken();

    final response = await http.patch(
      Uri.parse('$baseUrl/income/$id/pause-month'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'year': year, 'month': month}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to pause month');
    }
  }

  // ── Resume a previously paused month ─────────────────────────────────────
  static Future<void> resumeMonth(String id, int year, int month) async {
    final token = await TokenService.getToken();

    final response = await http.patch(
      Uri.parse('$baseUrl/income/$id/resume-month'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'year': year, 'month': month}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to resume month');
    }
  }

  // ── Sync SMS income ───────────────────────────────────────────────────────
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


