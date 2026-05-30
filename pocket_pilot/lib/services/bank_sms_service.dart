import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart' as tel;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:pockect_pilot/config/app_config.dart';
import 'package:pockect_pilot/services/token_service.dart';

@pragma('vm:entry-point')
Future<void> onBackgroundMessage(tel.SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await BankSmsService.processIncomingMessage(message.body ?? '', message.address ?? 'Unknown');
}

class BankSmsService {
  static final SmsQuery _query = SmsQuery();

  static Future<bool> requestPermission() async {
    var permission = await Permission.sms.status;
    if (permission.isGranted) {
      return true;
    } else {
      var result = await Permission.sms.request();
      return result.isGranted;
    }
  }

  /// Scans the 50 most recent SMS messages and sends them to the smart backend for processing
  static Future<int> syncRecentMessages() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception("SMS permission denied. We need this to read bank messages.");
    }

    try {
      List<SmsMessage> messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );

      int processedCount = 0;

      for (var msg in messages) {
        // Only process messages from the last 24 hours
        if (msg.date != null) {
          if (DateTime.now().difference(msg.date!).inHours > 24) {
            continue;
          }
        }

        String body = msg.body?.toLowerCase() ?? '';
        
        // Basic pre-filter so we don't send useless spam to Gemini
        bool isFinancial = body.contains('purchase') || body.contains('payment') || body.contains('pos') || 
                           body.contains('deducted') || body.contains('debited') || body.contains('paid') || 
                           body.contains('spent') || body.contains('transfer') || body.contains('sent') ||
                           body.contains('withdrawn') || body.contains('atm') || body.contains('cash') || 
                           body.contains('deposited') || body.contains('credited') || body.contains('refunded') || 
                           body.contains('salary') || body.contains('received') || body.contains('added');

        if (isFinancial && msg.body != null) {
          // Process it silently (backend will deduplicate using msg.id)
          bool success = await processIncomingMessage(msg.body!, msg.address ?? 'Unknown', msg.id?.toString(), msg.date);
          if (success) {
            processedCount++;
          }
        }
      }

      return processedCount;
    } catch (e) {
      throw Exception("Failed to sync SMS: $e");
    }
  }

  /// Scans the 50 most recent SMS messages to find potential bank transactions
  static Future<List<Map<String, dynamic>>> fetchRecentBankMessages() async {
    bool hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception("SMS permission denied. We need this to read bank messages.");
    }

    try {
      List<SmsMessage> messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: 50,
      );

      List<Map<String, dynamic>> parsedTransactions = [];

      for (var msg in messages) {
        String body = msg.body?.toLowerCase() ?? '';
        
        bool isPurchase = body.contains('purchase') || body.contains('payment') || body.contains('pos') || body.contains('deducted') || body.contains('debited') || body.contains('paid') || body.contains('spent') || body.contains('transfer') || body.contains('sent');
        bool isWithdrawal = body.contains('withdrawn') || body.contains('atm') || body.contains('cash') || body.contains('cash out');
        bool isDeposit = body.contains('deposited') || body.contains('credited') || body.contains('refunded') || body.contains('salary') || body.contains('received') || body.contains('cash in') || body.contains('added');

        if (isPurchase || isWithdrawal || isDeposit) {
          RegExp amountRegex = RegExp(r'(?:sar|usd|\$|aed|egp|rs|amount:?)?\s?((?:\d{1,3}(?:,\d{3})*|\d+)(?:\.\d{1,2})?)', caseSensitive: false);
          
          final match = amountRegex.firstMatch(body);
          if (match != null) {
            String extractedAmountStr = match.group(1)?.replaceAll(',', '') ?? '0';
            double amount = double.tryParse(extractedAmountStr) ?? 0.0;
            
            if (amount > 0) {
              String txType = 'unknown';
              if (isWithdrawal) {
                txType = 'withdrawal';
              } else if (isPurchase) {
                txType = 'expense';
              } else if (isDeposit) {
                txType = 'deposit';
              }

              parsedTransactions.add({
                'id': msg.id.toString(),
                'sender': msg.address,
                'amount': amount,
                'type': txType,
                'date': msg.date,
                'body': msg.body,
              });
            }
          }
        }
      }

      return parsedTransactions;
    } catch (e) {
      throw Exception("Failed to fetch SMS: $e");
    }
  }

  /// Starts listening to incoming SMS messages
  static void startListening() {
    final telephony = tel.Telephony.instance;
    telephony.listenIncomingSms(
      onNewMessage: (tel.SmsMessage message) async {
        debugPrint("Foreground New SMS received: ${message.body}");
        await processIncomingMessage(message.body ?? '', message.address ?? 'Unknown');
      },
      onBackgroundMessage: onBackgroundMessage,
    );
  }

  static Future<bool> processIncomingMessage(String rawBody, String sender, [String? smsId, DateTime? smsDate]) async {
    try {
      // 1. Get Location
      double lat = 0.0;
      double lng = 0.0;
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
           Position position = await Geolocator.getCurrentPosition(
             locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
           );
           lat = position.latitude;
           lng = position.longitude;
        }
      }

      // 2. Send to backend
      final token = await TokenService.getToken();
      if (token == null) return false;
      
      final url = Uri.parse('${AppConfig.baseUrl}/sms/process');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rawBody': rawBody,
          'sender': sender,
          'smsId': smsId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'smsDate': smsDate?.toIso8601String(),
          'lat': lat,
          'lng': lng,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint("Successfully processed SMS via Backend");
        return true;
      } else {
        debugPrint("Failed to process SMS via Backend: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error processing SMS: $e");
      return false;
    }
  }
}
