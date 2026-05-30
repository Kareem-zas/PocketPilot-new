import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pockect_pilot/config/app_config.dart';
import 'token_service.dart';

class GeminiChatService {
  /// Sends a conversation history along with a system-level context injection.
  /// [history] should be a list of maps containing 'role' ('user' or 'model') and 'text'.
  static Future<String> sendMessage({
    required List<Map<String, String>> history,
    String systemContext = '',
  }) async {
    final token = await TokenService.getToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/ai/chat');

    // Combine history into a single prompt for the backend
    StringBuffer combinedPrompt = StringBuffer();
    if (systemContext.isNotEmpty) {
      combinedPrompt.writeln("System Context: $systemContext\n");
    }

    for (var msg in history) {
      final role = msg['role'] == 'user' ? 'User' : 'Assistant';
      combinedPrompt.writeln("$role: ${msg['text']}");
    }
    
    // Ask for the next response
    combinedPrompt.writeln("Assistant: ");

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({"prompt": combinedPrompt.toString()}),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend AI error: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    return decoded['data']['response'];
  }
}
