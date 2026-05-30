import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pockect_pilot/view/add_goal_page.dart';
import 'package:pockect_pilot/services/goals_service.dart';
import 'package:pockect_pilot/services/pocket_service.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  bool _isLoading = true;
  List<dynamic> _goals = [];
  double _totalSavings = 0.0;
  double _momentum = 0.0;
  double _overallProgress = 0.0;
  String? _error;
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final symbol = await CurrencyService.getSymbol();
    if (mounted) setState(() => _currencySymbol = symbol);
  }

  Future<void> _loadGoals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await GoalsService.getGoals();
      final goalsList = data['goals'] ?? [];
      double totalSaved = 0.0;
      double totalTarget = 0.0;
      for (var goal in goalsList) {
        totalSaved += (goal['savedAmount'] as num?)?.toDouble() ?? 0.0;
        totalTarget += (goal['targetAmount'] as num?)?.toDouble() ?? 0.0;
      }

      double progress = totalTarget > 0 ? (totalSaved / totalTarget) : 0.0;

      if (!mounted) return;

      setState(() {
        _goals = goalsList;
        _totalSavings = totalSaved;
        _overallProgress = progress;
        _momentum = (data['monthlyDeposit'] as num?)?.toDouble() ?? 0.0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  void _showContributionDialog(Map<String, dynamic> goal) {
    final amountController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String goalId = goal['_id'] ?? goal['id'] ?? '';
    final String goalTitle = goal['title'] ?? 'Goal';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text("Fuel your Mission", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Contribute savings to '$goalTitle'", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: "Contribution Amount ($_currencySymbol)",
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0055D4)),
              onPressed: () async {
                final amt = double.tryParse(amountController.text.trim());
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await GoalsService.addSavings(goalId: goalId, amount: amt);
                  await PocketService.subtractPocketCash(amt);
                  await _loadGoals();
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to contribute: $e")),
                  );
                }
              },
              child: const Text("Contribute", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(Map<String, dynamic> goal) {
    final String goalId = goal['_id'] ?? goal['id'] ?? '';
    final String goalTitle = goal['title'] ?? 'Goal';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text("Abort Mission?", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to permanently delete the '$goalTitle' savings goal?", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  await GoalsService.deleteGoal(goalId);
                  await _loadGoals();
                } catch (e) {
                  if (!mounted) return;
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to delete goal: $e")),
                  );
                }
              },
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 30),
              _buildTotalSavingsRow(context),
              const SizedBox(height: 20),
              _buildMomentumCard(),
              const SizedBox(height: 30),
              _buildActiveGoalsHeader(isDark),
              const SizedBox(height: 15),
              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0055D4)))
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Text(
                              "Failed to retrieve data: $_error",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: isDark ? Colors.redAccent : Colors.red),
                            ),
                          ),
                        )
                      : _goals.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40.0),
                                child: Text(
                                  "No active goals yet. Initiate a new mission below!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            )
                          : Column(
                              children: _goals.map<Widget>((goal) {
                                final String title = goal['title'] ?? 'Goal';
                                final String category = goal['category'] ?? 'General';
                                final double target = (goal['targetAmount'] as num?)?.toDouble() ?? 0.0;
                                final double current = (goal['savedAmount'] as num?)?.toDouble() ?? 0.0;
                                
                                IconData iconData = Icons.savings;
                                if (category.toLowerCase() == 'travel') {
                                  iconData = Icons.flight_takeoff;
                                } else if (category.toLowerCase() == 'housing') {
                                  iconData = Icons.home;
                                } else if (category.toLowerCase() == 'education') {
                                  iconData = Icons.school;
                                }

                                final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
                                final isShared = goal['isShared'] ?? false;
                                
                                final double pilot1Progress = (goal['pilot1Contribution'] as num?)?.toDouble() ?? current;
                                final double pilot2Progress = (goal['pilot2Contribution'] as num?)?.toDouble() ?? 0.0;
                                final String pilot1Name = goal['pilot1Name'] ?? 'You';
                                final String pilot2Name = goal['pilot2Name'] ?? 'Co-Pilot';

                                return GestureDetector(
                                  onTap: () => _showContributionDialog(goal),
                                  onLongPress: () => _showDeleteDialog(goal),
                                  child: _buildGoalCard(
                                    context,
                                    title: title,
                                    subtitle: "Mission Category: $category",
                                    icon: iconData,
                                    progressValue: progress,
                                    progressText: "${(progress * 100).toStringAsFixed(0)}%",
                                    savedAmount: "$_currencySymbol${current.toStringAsFixed(2)}",
                                    targetAmount: "$_currencySymbol${target.toStringAsFixed(2)}",
                                    isShared: isShared,
                                    user1Progress: target > 0 ? (pilot1Progress / target) : 0.0,
                                    user2Progress: target > 0 ? (pilot2Progress / target) : 0.0,
                                    user1Name: pilot1Name,
                                    user2Name: pilot2Name,
                                  ),
                                );
                              }).toList(),
                            ),
              const SizedBox(height: 10),
              _buildInsightsRow(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "Pocket Pilot",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.blue,
          ),
        ),
        const CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey,
          child: Icon(Icons.person, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildTotalSavingsRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("TOTAL SAVINGS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 5),
            Text("$_currencySymbol${_totalSavings.toStringAsFixed(2)}", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        GestureDetector(
          onTap: () async {
            final reload = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalPage()));
            if (reload == true) {
              _loadGoals();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0055D4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text("New Goal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildMomentumCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: const Color(0xFF1E5BD8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
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
                  const Text("Monthly Momentum", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text("+$_currencySymbol${_momentum.toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.trending_up, color: Colors.white),
              )
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Overall Progress", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              Text("${(_overallProgress * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: Colors.blue.shade300, borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _overallProgress.clamp(0.0, 1.0),
                child: Container(height: 8, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4))),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActiveGoalsHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Active Goals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        const Text("View All", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildGoalCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required double progressValue,
    required String progressText,
    required String savedAmount,
    required String targetAmount,
    bool isShared = false,
    double user1Progress = 0.0,
    double user2Progress = 0.0,
    String user1Name = "You",
    String user2Name = "Co-Pilot",
  }) {
    double totalProgress = isShared ? (user1Progress + user2Progress) : progressValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isShared ? Border.all(color: Colors.blue.withValues(alpha: 0.3), width: 1.5) : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7), 
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF0055D4), size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                        if (isShared) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : Colors.blue.shade50, 
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text("SHARED", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 8)),
                          )
                        ]
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Text(isShared ? "${(totalProgress * 100).toStringAsFixed(0)}%" : progressText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 25),
          if (isShared) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double user1Position = (user1Progress * totalWidth).clamp(0.0, totalWidth);
                final double user2Position = ((user1Progress + user2Progress) * totalWidth).clamp(0.0, totalWidth);

                return Column(
                  children: [
                    Stack(
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity, 
                          height: 10, 
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7), 
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: user1Progress.clamp(0.0, 1.0),
                          child: Container(height: 10, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(5))),
                        ),
                        Positioned(
                          left: user1Position,
                          child: SizedBox(
                            width: (user2Progress * totalWidth).clamp(0.0, totalWidth - user1Position),
                            height: 10,
                            child: Container(decoration: const BoxDecoration(color: Colors.cyan, borderRadius: BorderRadius.horizontal(right: Radius.circular(5)))),
                          ),
                        ),
                        Positioned(
                          left: (user1Position - 12).clamp(-12.0, totalWidth - 12.0),
                          top: -7,
                          child: Tooltip(
                            message: "$user1Name: ${(user1Progress * 100).toStringAsFixed(0)}%",
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.orange, width: 2),
                                color: isDark ? const Color(0xFF334155) : Colors.white,
                              ),
                              child: const Center(
                                child: Text("🧑‍✈️", style: TextStyle(fontSize: 10)),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: (user2Position - 12).clamp(-12.0, totalWidth - 12.0),
                          top: -7,
                          child: Tooltip(
                            message: "$user2Name: ${(user2Progress * 100).toStringAsFixed(0)}%",
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.cyan, width: 2),
                                color: isDark ? const Color(0xFF334155) : Colors.white,
                              ),
                              child: const Center(
                                child: Text("👩‍✈️", style: TextStyle(fontSize: 10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text("$user1Name (${(user1Progress * 100).toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        Row(
                          children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.cyan, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text("$user2Name (${(user2Progress * 100).toStringAsFixed(0)}%)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ],
                );
              }
            )
          ] else ...[
            Stack(
              children: [
                Container(
                  width: double.infinity, 
                  height: 8, 
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7), 
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressValue,
                  child: Container(height: 8, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4))),
                )
              ],
            ),
          ],
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SAVED", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(savedAmount, style: const TextStyle(color: Color(0xFF0055D4), fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("TARGET", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                  Text(targetAmount, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInsightsRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt, color: Colors.brown, size: 16),
                const SizedBox(height: 15),
                Text("Fastest Growth", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 5),
                Text("Vacation Fund grew 12% this week", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, color: Color(0xFF0055D4), size: 16),
                const SizedBox(height: 15),
                Text("Next Milestone", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 5),
                Text("Emergency Fund is 2.7k from target", style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.black54)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
