import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart' as tel;
import 'package:pockect_pilot/services/variable_expenses_service.dart';
import 'package:pockect_pilot/services/income_service.dart';
import 'package:pockect_pilot/services/pocket_service.dart';

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
        
        // Define trigger keywords for three categories
        bool isPurchase = body.contains('purchase') || body.contains('payment') || body.contains('pos') || body.contains('deducted') || body.contains('debited') || body.contains('paid') || body.contains('spent') || body.contains('transfer') || body.contains('sent');
        bool isWithdrawal = body.contains('withdrawn') || body.contains('atm') || body.contains('cash') || body.contains('cash out');
        bool isDeposit = body.contains('deposited') || body.contains('credited') || body.contains('refunded') || body.contains('salary') || body.contains('received') || body.contains('cash in') || body.contains('added');

        // Only process financial SMS messages
        if (isPurchase || isWithdrawal || isDeposit) {
          // Attempt to extract the amount using a basic currency Regex
          // Matches formatted numbers like 150.00, 150, 1,500.50
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
                txType = 'expense'; // Matched with home_body.dart expectation
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

  /// Processes a single incoming message, detects type, and triggers backend services
  static Future<void> processIncomingMessage(String rawBody, String sender) async {
    String body = rawBody.toLowerCase();
    bool isPurchase = body.contains('purchase') || body.contains('payment') || body.contains('pos') || body.contains('deducted') || body.contains('debited') || body.contains('paid') || body.contains('spent') || body.contains('transfer') || body.contains('sent');
    bool isWithdrawal = body.contains('withdrawn') || body.contains('atm') || body.contains('cash') || body.contains('cash out');
    bool isDeposit = body.contains('deposited') || body.contains('credited') || body.contains('refunded') || body.contains('salary') || body.contains('received') || body.contains('cash in') || body.contains('added');

    if (!isPurchase && !isWithdrawal && !isDeposit) return;

    RegExp amountRegex = RegExp(r'(?:sar|usd|\$|aed|egp|rs|amount:?)?\s?((?:\d{1,3}(?:,\d{3})*|\d+)(?:\.\d{1,2})?)', caseSensitive: false);
    final match = amountRegex.firstMatch(body);
    
    if (match != null) {
      String extractedAmountStr = match.group(1)?.replaceAll(',', '') ?? '0';
      double amount = double.tryParse(extractedAmountStr) ?? 0.0;

      if (amount > 0) {
        try {
          if (isWithdrawal) {
            // 1. Add to pocket cash
            await PocketService.addPocketCash(amount);
            // 2. Log as an expense to deduct from main bank balance
            await VariableExpensesService.addExpense(
              title: "ATM Withdrawal",
              amount: amount,
              category: "Cash",
              date: DateTime.now(),
              notes: "Auto-detected withdrawal from $sender",
            );
          } else if (isPurchase) {
            // Log as a standard variable expense
            await VariableExpensesService.addExpense(
              title: "Auto-detected Payment",
              amount: amount,
              category: "Uncategorized",
              date: DateTime.now(),
              notes: "Payment detected via SMS from $sender",
            );
          } else if (isDeposit) {
            // Process Income
            await IncomeService.insertIncome(
              source: "Bank Transfer / Salary",
              amount: amount,
              date: DateTime.now(),
              notes: "Income detected via SMS from $sender",
            );
          }
          debugPrint("Successfully processed SMS transaction: $amount");
        } catch (e) {
          debugPrint("Failed to process SMS transaction: $e");
        }
      }
    }
  }
}
