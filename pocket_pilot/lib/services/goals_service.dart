import 'package:pockect_pilot/config/app_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class GoalsService {
  static const String baseUrl = '${AppConfig.baseUrl}/goals';

  static Future<Map<String, String>> _headers() async {
    final token = await TokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Fetch all goals + summary stats
  static Future<Map<String, dynamic>> getGoals() async {
    final headers = await _headers();
    final response = await http.get(Uri.parse(baseUrl), headers: headers);
    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to fetch goals');
    }

    return data['data'];
  }

  /// Create a new goal
  static Future<Map<String, dynamic>> createGoal({
    required String title,
    required String category,
    required double targetAmount,
    required String targetDate,
    double? initialDeposit,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: headers,
      body: jsonEncode({
        'title': title,
        'category': category,
        'targetAmount': targetAmount,
        'targetDate': targetDate,
        if (initialDeposit != null && initialDeposit > 0)
          'initialDeposit': initialDeposit,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to create goal');
    }

    return data['data']['goal'];
  }

  /// Add savings to an existing goal
  static Future<Map<String, dynamic>> addSavings({
    required String goalId,
    required double amount,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/$goalId/save'),
      headers: headers,
      body: jsonEncode({'amount': amount}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to add savings');
    }

    return data['data']['goal'];
  }

  /// Delete a goal
  static Future<void> deleteGoal(String goalId) async {
    final headers = await _headers();
    final response = await http.delete(
      Uri.parse('$baseUrl/$goalId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete goal');
    }
  }

  /// Invite a friend to join a goal
  static Future<Map<String, dynamic>> inviteMember({
    required String goalId,
    required String email,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/invite'),
      headers: headers,
      body: jsonEncode({'goalId': goalId, 'email': email}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to send invite');
    }
    return data['data']['goal'];
  }

  /// Contribute money to a shared goal
  static Future<Map<String, dynamic>> contributeToGoal({
    required String goalId,
    required double amount,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/$goalId/contribute'),
      headers: headers,
      body: jsonEncode({'amount': amount}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to contribute to goal');
    }
    return data['data']['goal'];
  }

  /// Get all shared goals
  static Future<List<dynamic>> getSharedGoals() async {
    final headers = await _headers();
    final response = await http.get(Uri.parse('$baseUrl/shared'), headers: headers);
    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to fetch shared goals');
    }
    return data['data']['goals'] ?? [];
  }
}
