import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pockect_pilot/config/app_config.dart';

class GeminiChatService {
  static const String _apiKey = AppConfig.geminiChatKey;

  /// Sends a conversation history along with a system-level context injection.
  /// [history] should be a list of maps containing 'role' ('user' or 'model') and 'text'.
  static Future<String> sendMessage({
    required List<Map<String, String>> history,
    String systemContext = '',
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/'
      'gemini-2.5-flash-lite:generateContent'
      '?key=$_apiKey',
    );

    // Format the payload
    List<Map<String, dynamic>> contents = [];

    // Inject system context natively as the first hidden user prompt if provided
    if (systemContext.isNotEmpty && history.isEmpty) {
      contents.add({
        "role": "user",
        "parts": [
          {"text": "System Context: $systemContext. Next is my real query."},
        ],
      });
      contents.add({
        "role": "model",
        "parts": [
          {
            "text":
                "Understood. I will act as the Pocket Pilot AI assistant and keep this financial context in mind. What do you need help with?",
          },
        ],
      });
    }

    for (var msg in history) {
      contents.add({
        "role": msg['role'], // 'user' or 'model'
        "parts": [
          {"text": msg['text']},
        ],
      });
    }

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"contents": contents}),
    );

    if (response.statusCode != 200) {
      String err = response.body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded['error'] != null && decoded['error']['message'] != null) {
          err = decoded['error']['message'];
        }
      } catch (_) {}
      throw Exception('Gemini error: $err');
    }

    final decoded = jsonDecode(response.body);
    return decoded['candidates'][0]['content']['parts'][0]['text'];
  }
}
