import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pockect_pilot/config/app_config.dart';
import 'token_service.dart';

class GeminiReceiptService {
  static Future<String> analyzeReceipt(File image) async {
    final bytes = await image.readAsBytes();
    final base64Image = base64Encode(bytes);

    final token = await TokenService.getToken();
    final uri = Uri.parse('${AppConfig.baseUrl}/ai/receipt');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "imageBase64": base64Image,
        "prompt": _prompt,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend AI error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    
    // The backend returns { status: 'success', data: { ... } }
    // We should stringify the data block since the caller expects a JSON string.
    return jsonEncode(decoded['data']);
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
