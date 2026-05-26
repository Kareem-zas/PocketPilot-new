import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pockect_pilot/services/home_service.dart';
import 'package:pockect_pilot/services/goals_service.dart';
import 'package:pockect_pilot/services/gemini_chat_service.dart';

class AiInsightsService {
  static Future<List<String>> fetchDailyInsights() async {
    try {
      final dashboard = await HomeService.fetchFullDashboard();
      final goalsData = await GoalsService.getGoals();
      final goalsList = goalsData['goals'] as List<dynamic>? ?? [];

      String dashboardSummary = "";
      if (dashboard['summary'] != null) {
        final sum = dashboard['summary'];
        final inc = sum['income']['total'];
        final exp = sum['expenses']['total'];
        final bal = sum['balance'];
        dashboardSummary = "Income: \$$inc, Expenses: \$$exp, Balance: \$$bal.";
      }

      String goalsSummary = "";
      if (goalsList.isNotEmpty) {
        goalsSummary = "Goals: ";
        for (var g in goalsList) {
          goalsSummary += "${g['title']} (\${g['savedAmount']}/\${g['targetAmount']}), ";
        }
      }

      final prompt = '''
You are a highly intelligent financial AI assistant. 
Here is the user's current financial state:
$dashboardSummary
$goalsSummary

Based on this, generate exactly 5 distinct, highly actionable notifications/advice snippets to send to the user today.
Cover topics such as nearing expense limits, tips to increase savings, and steps to reach goals faster.
Return ONLY a valid JSON array of strings. Do not use markdown blocks or any extra text.
Example: ["Insight 1", "Insight 2", "Insight 3", "Insight 4", "Insight 5"]
''';

      final response = await GeminiChatService.sendMessage(
        history: [{'role': 'user', 'text': prompt}],
      );

      // Clean up markdown block if the model accidentally adds it
      String cleanJson = response.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      } else if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.substring(3);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      
      final List<dynamic> decoded = jsonDecode(cleanJson.trim());
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint("AiInsightsService Error: $e");
      return [];
    }
  }
}
