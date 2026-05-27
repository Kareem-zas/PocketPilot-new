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
          goalsSummary += "${g['title']} (\$${g['savedAmount']}/\$${g['targetAmount']}), ";
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

      String cleanJson = _cleanJson(response);
      final List<dynamic> decoded = jsonDecode(cleanJson);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint("AiInsightsService Error: $e");
      return [];
    }
  }

  /// Generates a personalized Pilot Tip for the Fixed Expenses page.
  /// Uses the user's real subscription list, totals, and due dates.
  static Future<String> fetchFixedExpenseTip({
    required List<dynamic> activeItems,
    required double monthlyTotal,
    required String currencySymbol,
  }) async {
    try {
      // Build a summary of subscriptions
      final now = DateTime.now();

      // Find items due in the next 7 days
      final List<String> dueSoon = [];
      final List<String> itemNames = [];
      double inactiveTotal = 0;

      for (final item in activeItems) {
        final title = item['title']?.toString() ?? 'Subscription';
        final amount = (item['amount'] as num?)?.toDouble() ?? 0;
        final isActive = item['isActive'] == true;
        final freq = item['frequency']?.toString().toLowerCase() ?? 'monthly';

        // Normalize amount to monthly
        double monthly = amount;
        if (freq == 'weekly') monthly = amount * 4.33;
        if (freq == 'yearly') monthly = amount / 12;

        if (isActive) {
          itemNames.add('$title ($currencySymbol ${amount.toStringAsFixed(0)}/$freq)');

          // Check if due date is within 7 days
          final dateStr = item['startDate']?.toString() ?? item['nextDate']?.toString() ?? '';
          if (dateStr.isNotEmpty) {
            final date = DateTime.tryParse(dateStr);
            if (date != null) {
              final daysUntil = date.difference(now).inDays.abs() % 30;
              if (daysUntil <= 7) {
                dueSoon.add('$title ($currencySymbol ${amount.toStringAsFixed(2)})');
              }
            }
          }
        } else {
          inactiveTotal += monthly;
        }
      }

      final int activeCount = activeItems.where((i) => i['isActive'] == true).length;
      final int inactiveCount = activeItems.length - activeCount;

      String dueSoonText = dueSoon.isEmpty
          ? 'No subscriptions are due in the next 7 days.'
          : 'Due in the next 7 days: ${dueSoon.join(', ')}.';

      String subscriptionList = itemNames.isEmpty
          ? 'No active subscriptions.'
          : itemNames.join('; ');

      String inactiveNote = inactiveCount > 0
          ? 'There are $inactiveCount paused subscriptions that could save $currencySymbol ${inactiveTotal.toStringAsFixed(0)} per month if permanently cancelled.'
          : '';

      final prompt = '''
You are PocketPilot, a smart financial assistant. Generate a SINGLE concise Pilot Tip (2-3 sentences, max 60 words) for a user managing their fixed/recurring expenses.

User's data:
- Total active subscriptions: $activeCount
- Monthly commitment total: $currencySymbol ${monthlyTotal.toStringAsFixed(2)}
- Active subscriptions: $subscriptionList
- $dueSoonText
- $inactiveNote

Write a personalized, specific, actionable tip addressing their actual situation. Mention real numbers and subscription names. Do not use markdown. Return ONLY the tip text.
''';

      final response = await GeminiChatService.sendMessage(
        history: [{'role': 'user', 'text': prompt}],
      );

      return response.trim();
    } catch (e) {
      debugPrint("AiInsightsService.fetchFixedExpenseTip error: $e");
      return "Review your active subscriptions and consider pausing any unused services to reduce your monthly commitment.";
    }
  }

  static String _cleanJson(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    return cleaned.trim();
  }
}
