import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

/// Simple badge model used by the gamification views.
class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final bool isUnlocked;

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.isUnlocked,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) => BadgeModel(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? json['name'] ?? '',
        description: json['description'] ?? '',
        iconName: json['iconName'] ?? json['icon'] ?? 'military_tech',
        isUnlocked: json['isUnlocked'] == true || json['unlocked'] == true,
      );
}

class GamificationService {
  static const String baseUrl = 'http://192.168.1.17:8000/api/gamification';

  static Future<Map<String, String>> _headers() async {
    final token = await TokenService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // ─── Core API Methods ─────────────────────────────────────────────────────

  /// Fetches the full gamification status from the server.
  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final headers = await _headers();
      final response = await http
          .get(Uri.parse(baseUrl), headers: headers)
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Failed to fetch gamification status');
      }

      return data['data'] ?? data;
    } catch (_) {
      return {};
    }
  }

  /// Triggers the server-side streak / badge check.
  static Future<Map<String, dynamic>> checkStatus() async {
    try {
      final headers = await _headers();
      final response = await http
          .post(Uri.parse('$baseUrl/check'), headers: headers)
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(response.body);

      if (response.statusCode != 200) {
        throw Exception(data['message'] ?? 'Failed to run gamification check');
      }

      return data['data'] ?? data;
    } catch (_) {
      return {};
    }
  }

  // ─── Convenience Getters (used by views) ─────────────────────────────────

  /// Returns the current streak day count.
  static Future<int> getStreak() async {
    final data = await getStatus();
    return (data['streak'] as num?)?.toInt() ?? 0;
  }

  /// Returns the current XP (experience points).
  static Future<int> getXP() async {
    final data = await getStatus();
    return (data['xp'] as num?)?.toInt() ?? 0;
  }

  /// Returns the current level number.
  static Future<int> getLevel() async {
    final data = await getStatus();
    return (data['level'] as num?)?.toInt() ?? 1;
  }

  /// Returns all badges (locked and unlocked).
  static Future<List<BadgeModel>> getBadges() async {
    final data = await getStatus();
    final rawBadges = data['badges'];
    if (rawBadges is List) {
      return rawBadges
          .whereType<Map<String, dynamic>>()
          .map(BadgeModel.fromJson)
          .toList();
    }
    return [];
  }

  // ─── Mutation Methods (used by views) ─────────────────────────────────────

  /// Awards XP to the current user.
  static Future<void> addXP(int amount) async {
    try {
      final headers = await _headers();
      await http
          .post(
            Uri.parse('$baseUrl/xp'),
            headers: headers,
            body: jsonEncode({'amount': amount}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fail silently — gamification is non-critical
    }
  }

  /// Unlocks a badge by its identifier string.
  static Future<void> unlockBadge(String badgeId) async {
    try {
      final headers = await _headers();
      await http
          .post(
            Uri.parse('$baseUrl/badge'),
            headers: headers,
            body: jsonEncode({'badgeId': badgeId}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fail silently — gamification is non-critical
    }
  }
}
