import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/home_service.dart';
import 'package:pockect_pilot/services/income_service.dart';
import 'package:pockect_pilot/view/add_income_body.dart';
import 'package:pockect_pilot/view/add_body.dart';
import 'package:pockect_pilot/services/variable_expenses_service.dart';
import 'package:pockect_pilot/view/goals_page.dart';
import 'package:pockect_pilot/view/add_goal_page.dart';
import 'package:pockect_pilot/services/pocket_service.dart';
import 'package:pockect_pilot/services/bank_sms_service.dart';
import 'package:pockect_pilot/services/token_service.dart';
import 'package:pockect_pilot/view/login_view.dart';
import 'package:pockect_pilot/view/receipt_scanner_view.dart';
import 'package:pockect_pilot/view/gamification_view.dart';
import 'package:pockect_pilot/services/gamification_service.dart';
import 'package:pockect_pilot/services/goals_service.dart';
import 'package:pockect_pilot/view/income_dashboard_page.dart';
import 'package:pockect_pilot/view/ai_notifications_page.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class HomeBody extends StatefulWidget {
  const HomeBody({super.key});

  @override
  State<HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<HomeBody>
    with SingleTickerProviderStateMixin {
  double balance = 0;
  double totalIncome = 0;
  double variableExpenses = 0;
  double totalFixed = 0;
  double pocketCash = 0;
  List incomes = [];
  List expenses = [];
  List goalsContributions = [];
  bool loading = true;
  int level = 1;
  int streak = 3;
  int xp = 150;
  List activeGoals = [];
  String _currencySymbol = 'JD'; // default JOD
  double _conversionRate = 1.0;

  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    loadDashboard();
    _loadCurrency();
    
    // Start listening for incoming bank SMS automatically
    BankSmsService.startListening();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  Future<void> loadDashboard() async {
    await _loadCurrency();
    try {
      final dashboard = await HomeService.fetchDashboard();
      final incomeList = await IncomeService.getIncome();
      final expenseList = await VariableExpensesService.getVariableExpenses();
      final cashLocal = await PocketService.getPocketBalance();

      final currentLevel = await GamificationService.getLevel();
      final currentStreak = await GamificationService.getStreak();
      final currentXP = await GamificationService.getXP();

      Map<String, dynamic> goalsData = {};
      try {
        goalsData = await GoalsService.getGoals();
      } catch (e) {
        // Ignore if goals fail
      }
      final fetchedGoals = goalsData['goals'] ?? [];

      if (!mounted) return;

      // Flatten all goal contributions for the Goals History section
      List<Map<String, dynamic>> contributions = [];
      for (var goal in fetchedGoals) {
        final contribs = goal['contributions'] as List<dynamic>? ?? [];
        for (var c in contribs) {
          contributions.add({
            'goalTitle': goal['title'] ?? 'Goal',
            'goalCategory': goal['category'] ?? 'General',
            'amount': c['amount'] ?? 0,
            'date': c['createdAt'] ?? '',
          });
        }
      }
      contributions.sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });

      setState(() {
        pocketCash = cashLocal;
        balance = dashboard['balance'] ?? 0;
        totalIncome = dashboard['totalIncome'] ?? 0;
        variableExpenses = dashboard['variableExpenses'] ?? 0;
        totalFixed = dashboard['totalFixed'] ?? 0;
        incomes = incomeList;
        expenses = expenseList;
        goalsContributions = contributions;
        level = currentLevel;
        streak = currentStreak;
        xp = currentXP;
        activeGoals = fetchedGoals;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
      
      final err = e.toString().toLowerCase();
      if (err.contains("token") || err.contains("jwt") || err.contains("unauthorized")) {
        await TokenService.clearToken();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginView()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _syncSMS() async {
    try {
      final msgs = await BankSmsService.fetchRecentBankMessages();
      if (msgs.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
            title: const Text("Bank Messages Found"),
            content: Text("Detected ${msgs.length} recent transactions. Process any ATM withdrawals into your Pocket Money?"),
            actions: [
               TextButton(onPressed:() => Navigator.pop(ctx), child: const Text("Cancel")),
               ElevatedButton(
                 style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                 onPressed: () async {
                   double totalCashAdded = 0;
                   for(var msg in msgs) {
                      if(msg['type'] == 'expense' || msg['body'].toString().toLowerCase().contains('withdraw')) {
                          totalCashAdded += msg['amount'];
                      }
                   }
                   if (totalCashAdded <= 0) {
                     if (!ctx.mounted) return;
                     Navigator.pop(ctx);
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No valid withdrawals found in recent messages.")));
                     return;
                   }
                   await PocketService.addPocketCash(totalCashAdded);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!mounted) return;
                   loadDashboard();
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Transferred \$${totalCashAdded.toStringAsFixed(2)} to Pocket Cash!")));
                 }, 
                 child: const Text("Sync to Pocket", style: TextStyle(color: Colors.white))
               )
            ]
          )
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No new bank messages.")));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _loadCurrency() async {
    final symbol = await CurrencyService.getSymbol();
    final rate = await CurrencyService.getConversionRate();
    if (mounted) {
      setState(() {
        _currencySymbol = symbol;
        _conversionRate = rate;
      });
    }
  }

  Future<void> _quickScan() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReceiptScannerView()),
    );
    if (result == true) {
      loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.menu, color: Colors.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Pocket Pilot",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // AI Notifications bell
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: Colors.blue),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiNotificationsPage(),
                        ),
                      );
                    },
                    visualDensity: VisualDensity.compact,
                    tooltip: 'AI Notifications',
                  ),
                  IconButton(
                    icon: const Icon(Icons.sync_outlined, color: Colors.blue),
                    onPressed: _syncSMS,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt, color: Colors.blue),
                    onPressed: _quickScan,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  const CircleAvatar(radius: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1F35), Color(0xFF1E5BD8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Decorative circles
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pocket Pilot Card", style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 25),
                      // EMV Chip
                      Container(
                        width: 40,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade300,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.orange.shade400),
                        ),
                        child: Center(
                          child: Container(
                            width: 25, height: 15,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange.shade600, width: 0.5),
                            )
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "****  ****  ****  7421",
                        style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 2),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("TOTAL BALANCE", style: TextStyle(color: Colors.white54, fontSize: 10)),
                              const SizedBox(height: 5),
                              Text(
                                "$_currencySymbol ${(balance * _conversionRate).toStringAsFixed(2)}",
                                style: const TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("POCKET MONEY 💵", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(
                                "$_currencySymbol ${(pocketCash * _conversionRate).toStringAsFixed(2)}",
                                style: const TextStyle(fontSize: 18, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ],
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _button(
                  text: "Add Expense",
                  color: Colors.orange,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddBody(),
                      ),
                    );
                    loadDashboard();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _button(
                  text: "Add Income",
                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
                  textColor: Colors.blue,
                  border: true,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddIncomeBody(),
                      ),
                    );
                    loadDashboard();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          // Level & Streak Banner
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GamificationView()),
              );
              loadDashboard();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      "🔥",
                      style: TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Level $level Financial Pilot",
                                style: TextStyle(
                                  color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "$streak Day Streak",
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: ((xp % 200) / 200.0).clamp(0.0, 1.0),
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.cyan, Colors.blueAccent],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.cyan.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${xp % 200} / 200 XP to Level ${level + 1}",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white30,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Active Goals",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  GestureDetector(
                    child: const Text("View All", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage()));
                      loadDashboard();
                    },
                  ),
                  const SizedBox(width: 15),
                  GestureDetector(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.blue, size: 16),
                    ),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddGoalPage()));
                      loadDashboard();
                    },
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 15),
          if (activeGoals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("No active goals yet. Start a new mission!"),
            )
          else
            ...activeGoals.take(3).map((goal) {
              final String title = goal['title'] ?? 'Goal';
              final String category = goal['category'] ?? 'General';
              final double target = ((goal['targetAmount'] as num?)?.toDouble() ?? 0.0) * _conversionRate;
              final double current = ((goal['savedAmount'] as num?)?.toDouble() ?? 0.0) * _conversionRate;
              
              IconData iconData = Icons.savings;
              if (category.toLowerCase() == 'travel') {
                iconData = Icons.flight_takeoff;
              } else if (category.toLowerCase() == 'housing') {
                iconData = Icons.home;
              } else if (category.toLowerCase() == 'education') {
                iconData = Icons.school;
              }

              final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

              return GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage()));
                  loadDashboard();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFEBEFF7), borderRadius: BorderRadius.circular(10)),
                        child: Icon(iconData, color: const Color(0xFF0055D4), size: 18),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Stack(
                              children: [
                                Container(width: double.infinity, height: 4, decoration: BoxDecoration(color: const Color(0xFFEBEFF7), borderRadius: BorderRadius.circular(2))),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: progress,
                                  child: Container(height: 4, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(2))),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 15),
                      Text("${(progress * 100).toStringAsFixed(0)}%", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0055D4))),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Income History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () async {
                  final refresh = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IncomeDashboardPage()),
                  );
                  if (refresh == true) loadDashboard();
                },
                child: const Text(
                  "Manage →",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          incomes.isEmpty
              ? const Text("No income yet")
              : Column(
                  children:
                      incomes.map((e) => _historyItem(e)).toList(),
                ),
          const SizedBox(height: 25),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Regular Expense History",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          expenses.isEmpty
              ? const Text("No expenses yet")
              : Column(
                  children:
                      expenses.map((e) => _expenseItem(e)).toList(),
                ),
          const SizedBox(height: 25),
          // ── Goals Contribution History ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Goals History",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsPage()));
                  loadDashboard();
                },
                child: const Text("View All Goals", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          goalsContributions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("No goal contributions yet."),
                )
              : Column(
                  children: goalsContributions
                      .take(10)
                      .map((c) => _goalContributionItem(c))
                      .toList(),
                ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _button({
    required String text,
    required Color color,
    Color? textColor,
    bool border = false,
    required VoidCallback onTap,
  }) {
    final tColor = textColor ?? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: border ? Border.all(color: Colors.grey.shade300) : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: tColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _historyItem(dynamic item) {
    final date = DateTime.tryParse(item['date'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F2F6)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.work, color: Colors.blue),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['source'] ?? 'Income'),
                  Text(
                    date != null
                        ? "${date.day}/${date.month}/${date.year}"
                        : "",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            "+$_currencySymbol ${((double.tryParse(item['amount']?.toString() ?? '') ?? 0.0) * _conversionRate).toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseItem(dynamic item) {
    final date = DateTime.tryParse(item['date'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F2F6)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_bag, color: Colors.orange),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title'] ?? 'Expense'),
                  Text(
                    date != null
                        ? "${date.day}/${date.month}/${date.year}"
                        : "",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(
            "-$_currencySymbol ${((double.tryParse(item['amount']?.toString() ?? '') ?? 0.0) * _conversionRate).toStringAsFixed(2)}",
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  Widget _goalContributionItem(Map<String, dynamic> item) {
    final date = DateTime.tryParse(item['date'] ?? '');
    final String title = item['goalTitle'] ?? 'Goal';
    final String category = item['goalCategory'] ?? 'General';
    final double amount = (item['amount'] as num?)?.toDouble() ?? 0.0;

    IconData iconData = Icons.savings;
    Color iconColor = Colors.purple;
    if (category.toLowerCase() == 'travel') {
      iconData = Icons.flight_takeoff;
      iconColor = Colors.teal;
    } else if (category.toLowerCase() == 'housing') {
      iconData = Icons.home;
      iconColor = Colors.blue;
    } else if (category.toLowerCase() == 'education') {
      iconData = Icons.school;
      iconColor = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E293B)
            : Colors.white),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: iconColor, size: 18),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date != null
                      ? "${date.day}/${date.month}/${date.year}"
                      : "Goal Contribution",
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            "+$_currencySymbol ${(amount * _conversionRate).toStringAsFixed(2)}",
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
