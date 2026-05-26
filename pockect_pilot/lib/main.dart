import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pockect_pilot/view/splash_view.dart';
import 'package:pockect_pilot/view/login_view.dart';
import 'package:pockect_pilot/view/home_page.dart';
import 'package:pockect_pilot/utils/notification_helper.dart';
import 'package:pockect_pilot/services/theme_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:pockect_pilot/services/notification_service.dart';
import 'package:pockect_pilot/services/ai_insights_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.initialize();
      final insights = await AiInsightsService.fetchDailyInsights();
      if (insights.isNotEmpty) {
        await NotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Daily Financial Insight',
          body: insights[0],
        );
        for (int i = 1; i < insights.length; i++) {
          await NotificationService.scheduleNotification(
            id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + i,
            title: 'Smart AI Advice',
            body: insights[i],
            delay: Duration(hours: i * 3),
          );
        }
      }
    } catch (e) {
      debugPrint('Background task error: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationHelper.init();
  await NotificationService.initialize();
  
  Workmanager().initialize(
    callbackDispatcher,
  );
  Workmanager().registerPeriodicTask(
    "daily_ai_insights",
    "fetch_ai_insights",
    frequency: const Duration(hours: 24),
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pocket Pilot',
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        primaryColor: const Color(0xFF0055D4),
        cardColor: Colors.white,
        dividerColor: const Color(0xFFE2E8F0),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1E293B)),
          bodyMedium: TextStyle(color: Color(0xFF475569)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF3B82F6),
        cardColor: const Color(0xFF1E293B),
        dividerColor: const Color(0xFF334155),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      home: const SplashView(),
      routes: {
        '/login': (context) => const LoginView(),
        '/home': (context) => const HomePage(),
      },
    );
  }
}
