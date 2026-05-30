import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/gamification_service.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class GamificationView extends StatefulWidget {
  const GamificationView({super.key});

  @override
  State<GamificationView> createState() => _GamificationViewState();
}

class _GamificationViewState extends State<GamificationView> {
  int streakDays = 0;
  int userXP = 0;
  int userLevel = 1;
  double dailyLimit = 0.0;
  double expensesToday = 0.0;
  String _currencySymbol = '\$';
  List<BadgeModel> badges = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadGameMetrics();
  }

  Future<void> _loadGameMetrics() async {
    final streak = await GamificationService.getStreak();
    final xp = await GamificationService.getXP();
    final lvl = await GamificationService.getLevel();
    final list = await GamificationService.getBadges();
    final dLimit = await GamificationService.getDailyLimit();
    final dExpenses = await GamificationService.getExpensesToday();
    final symbol = await CurrencyService.getSymbol();

    if (mounted) {
      setState(() {
        streakDays = streak;
        userXP = xp;
        userLevel = lvl;
        badges = list;
        dailyLimit = dLimit;
        expensesToday = dExpenses;
        _currencySymbol = symbol;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    int nextLevelXP = userLevel * 200;
    double progress = (userXP / nextLevelXP).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Flight Academy", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Level & XP Progress Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("PILOT LEVEL $userLevel", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.0)),
                          const SizedBox(height: 5),
                          const Text("Commander flight progress", style: TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.military_tech, color: Colors.amber, size: 24),
                      )
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$userXP XP", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                      Text("$nextLevelXP XP", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Stack(
                    children: [
                      Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4))),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(height: 8, decoration: BoxDecoration(color: Colors.cyanAccent, borderRadius: BorderRadius.circular(4))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Streaks Widget
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.orange.withValues(alpha: 0.2) : Colors.orange.shade100, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("$streakDays Day Budget Streak 🔥", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 3),
                        Text("Keep spending below budget tomorrow to keep it going!", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Daily Limit Tracker Widget
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: expensesToday > dailyLimit ? Colors.red.withValues(alpha: 0.5) : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: expensesToday > dailyLimit ? Colors.red.withValues(alpha: 0.15) : (isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(expensesToday > dailyLimit ? Icons.warning_amber_rounded : Icons.track_changes, color: expensesToday > dailyLimit ? Colors.redAccent : Colors.blue, size: 28),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Daily Limit Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 3),
                        Text(
                          expensesToday > dailyLimit 
                            ? "You've exceeded today's limit by $_currencySymbol${(expensesToday - dailyLimit).toStringAsFixed(2)}. Streak broken!"
                            : "Spent $_currencySymbol${expensesToday.toStringAsFixed(2)} of $_currencySymbol${dailyLimit.toStringAsFixed(2)} limit today. You're safe!", 
                          style: TextStyle(
                            color: expensesToday > dailyLimit ? Colors.redAccent : (isDark ? Colors.grey.shade400 : Colors.grey), 
                            fontSize: 11
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Text("Unlocked Achievement Badges", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 15),

            // Grid of Badges
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 0.85,
              ),
              itemCount: badges.length,
              itemBuilder: (context, index) {
                final badge = badges[index];
                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: badge.isUnlocked ? 1.0 : 0.25,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: badge.isUnlocked 
                              ? (isDark ? const Color(0xFF334155) : const Color(0xFFEEF2F6)) 
                              : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(badge.iconName),
                            color: badge.isUnlocked ? (isDark ? Colors.blue.shade300 : const Color(0xFF1E5BD8)) : Colors.grey,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        badge.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: badge.isUnlocked ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badge.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          color: badge.isUnlocked 
                            ? (isDark ? Colors.white70 : Colors.black54) 
                            : (isDark ? Colors.white30 : Colors.grey.shade400),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 35),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'savings':
        return Icons.savings;
      case 'assignment':
        return Icons.assignment;
      case 'timeline':
        return Icons.timeline;
      case 'qr_code_scanner':
        return Icons.qr_code_scanner;
      case 'radar':
        return Icons.radar;
      case 'flight_takeoff':
        return Icons.flight_takeoff;
      default:
        return Icons.military_tech;
    }
  }
}
