import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/fixed_expenses_service.dart';
import 'package:pockect_pilot/view/subscription_radar_view.dart';

class FixedExpensePage extends StatefulWidget {
  const FixedExpensePage({super.key});

  @override
  State<FixedExpensePage> createState() => _FixedExpensePageState();
}

class _FixedExpensePageState extends State<FixedExpensePage> {
  final ScrollController _scrollController = ScrollController();
  bool loading = true;
  List<dynamic> activeItems = [];
  double monthlyTotal = 0;

  final nameController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final amountController = TextEditingController();
  String selectedFrequency = 'Monthly';
  DateTime? selectedDate;
  final List<String> frequencies = ['Weekly', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final items = await FixedExpensesService.getFixedExpenseItems();
      
      double total = 0;
      for (var item in items) {
        if (item['isActive'] == true) {
          final amt = double.tryParse(item['amount']?.toString() ?? '') ?? 0;
          final freq = item['frequency']?.toString().toLowerCase() ?? 'monthly';
          
          if (freq == 'weekly') {
            total += amt * 4.33;
          } else if (freq == 'yearly') {
            total += amt / 12;
          } else {
            total += amt;
          }
        }
      }

      if (mounted) {
        setState(() {
          activeItems = items;
          monthlyTotal = total;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _toggleSubscription(int index, bool value) async {
    final item = activeItems[index];
    final String itemId = item['_id'] ?? item['id'] ?? '';
    if (itemId.isEmpty) return;

    // Optimistic UI update
    setState(() {
      activeItems[index]['isActive'] = value;
      // Recalculate total locally quickly
      _recalculateTotal();
    });

    try {
      await FixedExpensesService.updateFixedExpenseActivity(
        itemId: itemId,
        isActive: value,
      );
    } catch (e) {
      if (!mounted) return;
      // Revert on error
      setState(() {
        activeItems[index]['isActive'] = !value;
        _recalculateTotal();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update subscription status')),
      );
    }
  }

  void _recalculateTotal() {
    double total = 0;
    for (var item in activeItems) {
      if (item['isActive'] == true) {
        final amt = double.tryParse(item['amount']?.toString() ?? '') ?? 0;
        final freq = item['frequency']?.toString().toLowerCase() ?? 'monthly';
        
        if (freq == 'weekly') {
          total += amt * 4.33;
        } else if (freq == 'yearly') {
          total += amt / 12;
        } else {
          total += amt;
        }
      }
    }
    monthlyTotal = total;
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<void> _addExpense() async {
    final name = nameController.text.trim();
    final amountText = amountController.text.trim();
    
    if (name.isEmpty || amountText.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select a date.')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid amount.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FixedExpensesService.addFixedExpenseItem(
        title: name,
        amount: amount,
        frequency: selectedFrequency.toLowerCase(),
        startDate: selectedDate!,
      );
      nameController.clear();
      amountController.clear();
      selectedDate = null;
      selectedFrequency = 'Monthly';
      await _loadExpenses();
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (loading && activeItems.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    int activeCount = activeItems.where((i) => i['isActive'] == true).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.menu, color: isDark ? Colors.blue.shade300 : Colors.blue),
                    Text(
                      "Pocket Pilot",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.blue.shade300 : Colors.blue,
                      ),
                    ),
                    const CircleAvatar(radius: 18),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      "MONTHLY COMMITMENT",
                      style: TextStyle(
                        color: Color(0xFFC0704F),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "\$${monthlyTotal.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1B2128),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Your recurring flight path. We've identified $activeCount active subscriptions currently fueling your ecosystem.",
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Button to add expense
                    SizedBox(
                      width: 200,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF246AF3),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          nameFocusNode.requestFocus();
                          _scrollController.animateTo(
                            _scrollController.position.maxScrollExtent,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                          );
                        },
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text("Add Fixed Expense", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Active Subscriptions",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF333333)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const SubscriptionRadarView()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                )
                              ]
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.radar, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text(
                                  "SMS Radar Scan",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    
                    // List
                    ...activeItems.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      bool isActive = item['isActive'] ?? true;
                      
                      IconData iconData = Icons.receipt;
                      Color iconBg = isDark ? const Color(0xFF2D3748) : const Color(0xFFE8EAF6);
                      Color iconColor = isDark ? Colors.blue.shade300 : const Color(0xFF3F51B5);
                      
                      final t = (item['title']?.toString().toLowerCase() ?? '');
                      if (t.contains('netflix') || t.contains('movie')) {
                        iconData = Icons.movie;
                      } else if (t.contains('adobe') || t.contains('cloud')) {
                        iconData = Icons.cloud;
                      } else if (t.contains('insurance') || t.contains('car')) {
                        iconData = Icons.shield;
                      } else if (t.contains('yoga') || t.contains('gym')) {
                        iconData = Icons.fitness_center;
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(iconData, color: iconColor, size: 22),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? 'Subscription',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${(item['frequency'] ?? 'MONTHLY').toString().toUpperCase()} - NEXT: TBD",
                                    style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              "\$${double.tryParse(item['amount']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'}",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: isActive,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF1E5BD8),
                              onChanged: (val) => _toggleSubscription(i, val),
                            )
                          ],
                        ),
                      );
                    }),
                  ],
                )
              ),
              
              const SizedBox(height: 25),

              // Quick Navigator / Form
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF0F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bar_chart, color: isDark ? Colors.orangeAccent : const Color(0xFF9E6515)),
                        const SizedBox(width: 10),
                        Text("Quick Navigator", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    Text("EXPENSE NAME", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      focusNode: nameFocusNode,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "e.g. Spotify Family",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("AMOUNT", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                              const SizedBox(height: 8),
                              TextField(
                                controller: amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: "0.00",
                                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                                  filled: true,
                                  fillColor: isDark ? const Color(0xFF334155) : Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                ),
                              ),
                            ],
                          )
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("FREQUENCY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 15),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF334155) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedFrequency,
                                    isExpanded: true,
                                    dropdownColor: isDark ? const Color(0xFF334155) : Colors.white,
                                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                    items: frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: isDark ? Colors.white : Colors.black87)))).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => selectedFrequency = val);
                                    },
                                  )
                                )
                              ),
                            ],
                          )
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    Text("NEXT DUE DATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(selectedDate != null 
                              ? "${selectedDate!.month.toString().padLeft(2,'0')}/${selectedDate!.day.toString().padLeft(2,'0')}/${selectedDate!.year}" 
                              : "mm/dd/yyyy", 
                              style: TextStyle(color: selectedDate != null ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white30 : Colors.black45))
                            ),
                            Icon(Icons.calendar_today, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: loading ? null : _addExpense,
                        child: loading ? const SizedBox(height:20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Deploy Subscription", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Pilot Tip Bottom Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D52D6),
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/pocket-pilot-logo.png'), 
                    opacity: 0.1, 
                    alignment: Alignment.bottomRight,
                    fit: BoxFit.none
                  )
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Pilot Tip", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                      "You've got 3 subscriptions due in the next 48 hours. Ensure your wallet has at least \$124.50 to maintain smooth operations.",
                      style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          )
        )
      )
    );
  }

  @override
  void dispose() {
    nameFocusNode.dispose();
    nameController.dispose();
    amountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
