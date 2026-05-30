import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pockect_pilot/services/gamification_service.dart';
import 'package:pockect_pilot/services/home_service.dart';
import 'package:pockect_pilot/services/gemini_chat_service.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class TimeTravelPage extends StatefulWidget {
  const TimeTravelPage({super.key});

  @override
  State<TimeTravelPage> createState() => _TimeTravelPageState();
}

class _TimeTravelPageState extends State<TimeTravelPage> {
  double currentBalance = 3200;
  double monthlyIncome = 2500;
  double monthlyExpenses = 1800; // variable + fixed

  // Velocity factor: 0 = Frugal (-20%), 1 = Steady (Normal), 2 = Splurge (+20%)
  double velocityIndex = 1; 
  final List<String> velocities = ["Frugal (-20%)", "Steady (Normal)", "Splurge (+20%)"];

  bool isCalculating = false;
  String aiRecommendation = "";
  bool loadingDashboard = true;
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _loadBalanceAndMetrics();
    _loadCurrency();
    // Award Time Traveler Badge Structurally!
    GamificationService.unlockBadge('time_traveler');
  }

  Future<void> _loadCurrency() async {
    final symbol = await CurrencyService.getSymbol();
    if (mounted) setState(() => _currencySymbol = symbol);
  }

  Future<void> _loadBalanceAndMetrics() async {
    try {
      final data = await HomeService.fetchDashboard();
      if (mounted) {
        setState(() {
          currentBalance = data['balance'] ?? currentBalance;
          monthlyIncome = data['totalIncome'] ?? monthlyIncome;
          monthlyExpenses = (data['variableExpenses'] ?? 1000) + (data['totalFixed'] ?? 800);
          loadingDashboard = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => loadingDashboard = false);
      }
    }
  }

  double get adjustedVelocity {
    if (velocityIndex == 0) return 0.8; // Frugal
    if (velocityIndex == 2) return 1.2; // Splurge
    return 1.0; // Steady
  }

  List<FlSpot> _getHistoricalSpots() {
    // 3 Months of mock history back from index 0 to 2
    return [
      FlSpot(0, currentBalance - (monthlyIncome - monthlyExpenses) * 3),
      FlSpot(1, currentBalance - (monthlyIncome - monthlyExpenses) * 2),
      FlSpot(2, currentBalance - (monthlyIncome - monthlyExpenses)),
      FlSpot(3, currentBalance),
    ];
  }

  List<FlSpot> _getForecastSpots() {
    double netVelocity = monthlyIncome - (monthlyExpenses * adjustedVelocity);
    List<FlSpot> spots = [FlSpot(3, currentBalance)];
    
    // Project 6 months out (index 4 to 9)
    for (int i = 1; i <= 6; i++) {
      double projected = currentBalance + (netVelocity * i);
      spots.add(FlSpot((3 + i).toDouble(), projected > 0 ? projected : 0));
    }
    return spots;
  }

  Future<void> _consultPilot() async {
    setState(() {
      isCalculating = true;
      aiRecommendation = "";
    });

    double netVelocity = monthlyIncome - (monthlyExpenses * adjustedVelocity);
    double targetSixMonthBalance = currentBalance + (netVelocity * 6);

    String velocityName = velocities[velocityIndex.toInt()];

    String systemContext = "You are a professional financial planning AI. The user has an active bank balance of $_currencySymbol$currentBalance. "
        "Their monthly income is $_currencySymbol$monthlyIncome, and their monthly expenses are $_currencySymbol$monthlyExpenses. "
        "They have selected the '$velocityName' spending velocity, projecting a monthly spending velocity of $_currencySymbol${(monthlyExpenses * adjustedVelocity).toStringAsFixed(0)}. "
        "This yields a net cash flow of $_currencySymbol${netVelocity.toStringAsFixed(0)} per month.";

    String prompt = "Consult on my 6-month time-travel forecast. Based on this spending velocity, "
        "my balance is projected to reach $_currencySymbol${targetSixMonthBalance.toStringAsFixed(2)} in 6 months. "
        "Formulate a brief 3-sentence action plan (with bullet points) advising me on how to optimize this flight path.";

    try {
      final result = await GeminiChatService.sendMessage(
        history: [
          {"role": "user", "text": prompt}
        ],
        systemContext: systemContext,
      );

      if (mounted) {
        setState(() {
          aiRecommendation = result;
          isCalculating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          aiRecommendation = "At your current spending velocity ($velocityName), your 6-month trajectory is stable. "
              "To boost savings, aim to allocate an extra 10% to your shared vault goals and review fixed subscriptions.";
          isCalculating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (loadingDashboard) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final double netVelocity = monthlyIncome - (monthlyExpenses * adjustedVelocity);
    final double targetSixMonthBalance = currentBalance + (netVelocity * 6);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "AI Financial Time-Travel",
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Forecast Projection Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E5BD8), Color(0xFF3F82FD)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("6-MONTH FORECAST RANGE", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  Text(
                    "$_currencySymbol${targetSixMonthBalance.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    netVelocity >= 0 
                      ? "Monthly Growth Velocity: +$_currencySymbol${netVelocity.toStringAsFixed(2)} 📈" 
                      : "Monthly Deficit Velocity: -$_currencySymbol${netVelocity.abs().toStringAsFixed(2)} 📉",
                    style: TextStyle(
                      color: netVelocity >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Forecast double-line chart
            Container(
              height: 240,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          const months = ["Past 3M", "Past 2M", "Last M", "TODAY", "Month 1", "Month 2", "Month 3", "Month 4", "Month 5", "Month 6"];
                          if (value.toInt() >= 0 && value.toInt() < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                months[value.toInt()],
                                style: const TextStyle(color: Colors.grey, fontSize: 8, fontWeight: FontWeight.bold),
                              ),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    // Historical Line (Solid Blue)
                    LineChartBarData(
                      spots: _getHistoricalSpots(),
                      isCurved: true,
                      color: const Color(0xFF1E5BD8),
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                    ),
                    // Forecast Line (Dotted Amber)
                    LineChartBarData(
                      spots: _getForecastSpots(),
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            // Spending Velocity Slider Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white, 
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Spending Velocity", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.blue.shade50, 
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          velocities[velocityIndex.toInt()],
                          style: TextStyle(
                            color: isDark ? Colors.blue.shade300 : const Color(0xFF1E5BD8), 
                            fontSize: 11, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: velocityIndex,
                    min: 0,
                    max: 2,
                    divisions: 2,
                    activeColor: const Color(0xFF1E5BD8),
                    onChanged: (val) {
                      setState(() {
                        velocityIndex = val;
                      });
                    },
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Frugal (-20%)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text("Steady", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      Text("Splurge (+20%)", style: TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),

            // AI Co-Pilot Advice Block
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2F6),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Color(0xFF1E5BD8), shape: BoxShape.circle),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Time-Travel Copilot Advice", 
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (aiRecommendation.isEmpty && !isCalculating)
                    Text(
                      "Adjust your Spending Velocity and consult the AI Pilot to outline a personalized, high-performance saving path.",
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 12, height: 1.4),
                    )
                  else if (isCalculating)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    Text(
                      aiRecommendation,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12, height: 1.5),
                    ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: isCalculating ? null : _consultPilot,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E5BD8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Center(
                        child: Text(
                          "Consult AI Pilot",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
