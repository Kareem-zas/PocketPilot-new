import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class HomeService {
  static const String baseUrl = 'http://192.168.1.17:8000/api/dashboard';

  static Future<Map<String, double>> fetchDashboard() async {
    final token = await TokenService.getToken();

    final response = await http.get(
      Uri.parse(baseUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load dashboard');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'];
    final summary = data['summary'];

    final totalIncome =
        (summary['income']['total'] as num).toDouble();

    final totalVariable =
        (summary['expenses']['variable']['total'] as num).toDouble();

    final totalFixed =
        (summary['expenses']['fixed']['total'] as num).toDouble();

    final balance =
        (summary['balance'] as num).toDouble();

    return {
      'balance': balance,
      'totalIncome': totalIncome,
      'variableExpenses': totalVariable,
      'totalFixed': totalFixed,
    };
  }

  static Future<Map<String, dynamic>> fetchFullDashboard({int? year, int? month}) async {
    final token = await TokenService.getToken();

    final query = <String, String>{};
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString();

    final uri = Uri.parse(baseUrl).replace(queryParameters: query);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load full dashboard');
    }

    final decoded = jsonDecode(response.body);
    return decoded['data'] ?? {};
  }
}
