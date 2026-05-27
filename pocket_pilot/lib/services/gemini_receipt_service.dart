import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pockect_pilot/config/app_config.dart';

class GeminiReceiptService {
  static const String _apiKey = AppConfig.geminiReceiptKey;

  static Future<String> analyzeReceipt(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1/models/'
      'gemini-2.5-flash-lite:generateContent'
      '?key=$_apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": _prompt},
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);

    return decoded['candidates'][0]['content']['parts'][0]['text'];
  }

  static const String _prompt = '''
You are a receipt analysis AI.

Analyze the receipt image and return ONLY valid JSON.

Rules:
- Do not explain anything
- Do not include markdown
- Do not include extra text

JSON format:
{
  "itemName": "string",
  "total": number,
  "category": "string",
  "date": "YYYY-MM-DD"
}

Guidelines:
- itemName: store or main item
- total: final paid amount
- category: one of [Food, Transport, Shopping, Bills, General]
- date: if missing, guess based on receipt
''';
}
