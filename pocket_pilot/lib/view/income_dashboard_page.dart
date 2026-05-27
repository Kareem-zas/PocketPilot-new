import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/income_service.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class IncomeDashboardPage extends StatefulWidget {
  const IncomeDashboardPage({super.key});

  @override
  State<IncomeDashboardPage> createState() => _IncomeDashboardPageState();
}

class _IncomeDashboardPageState extends State<IncomeDashboardPage> {
  List<dynamic> _incomes = [];
  bool _loading = true;
  String _currencySymbol = '\$';
  double _conversionRate = 1.0;

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  Future<void> _loadIncomes() async {
    setState(() => _loading = true);
    try {
      final list = await IncomeService.getAllIncomes();
      final symbol = await CurrencyService.getSymbol();
      final rate = await CurrencyService.getConversionRate();
      setState(() {
        _incomes = list;
        _currencySymbol = symbol;
        _conversionRate = rate;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load incomes: $e')),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<dynamic> get _recurring =>
      _incomes.where((i) => i['isRecurring'] == true).toList();

  List<dynamic> get _oneTime =>
      _incomes.where((i) => i['isRecurring'] != true).toList();

  bool _isPausedThisMonth(dynamic income) {
    final now = DateTime.now();
    final paused = income['pausedMonths'] as List<dynamic>? ?? [];
    return paused.any((p) =>
        p['year'] == now.year && p['month'] == now.month);
  }

  String _freqLabel(String? freq) {
    switch (freq) {
      case 'monthly': return 'Monthly';
      case 'quarterly': return 'Quarterly';
      case 'bi-annual': return 'Bi-Annual';
      case 'yearly': return 'Yearly';
      default: return freq ?? '';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return '';
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleActive(dynamic income) async {
    final id = income['_id'] as String;
    try {
      await IncomeService.toggleActive(id);
      await _loadIncomes();
      if (mounted) {
        final newState = !(income['isActive'] ?? true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(newState ? 'Income activated ✓' : 'Income paused'),
          backgroundColor: newState ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _togglePauseThisMonth(dynamic income) async {
    final id = income['_id'] as String;
    final now = DateTime.now();
    final paused = _isPausedThisMonth(income);
    try {
      if (paused) {
        await IncomeService.resumeMonth(id, now.year, now.month);
      } else {
        await IncomeService.pauseMonth(id, now.year, now.month);
      }
      await _loadIncomes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(paused
              ? 'This month resumed ✓'
              : 'This month paused (unpaid leave)'),
          backgroundColor: paused ? Colors.green : Colors.orange,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteIncome(dynamic income) async {
    final id = income['_id'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Income?'),
        content: Text(
          'Are you sure you want to delete "${income['source']}"?\n\nPast data will remain in reports.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await IncomeService.deleteIncome(id);
      await _loadIncomes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Income deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Income Manager',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: _loadIncomes,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0055D4)))
          : RefreshIndicator(
              onRefresh: _loadIncomes,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ── Recurring Incomes ──────────────────────────────────────
                  if (_recurring.isNotEmpty) ...[
                    _sectionHeader('🔄 Recurring Incomes', isDark),
                    const SizedBox(height: 10),
                    ..._recurring.map((inc) => _recurringCard(inc, card, isDark)),
                    const SizedBox(height: 20),
                  ],

                  // ── One-time Incomes ───────────────────────────────────────
                  if (_oneTime.isNotEmpty) ...[
                    _sectionHeader('💵 One-time Incomes', isDark),
                    const SizedBox(height: 10),
                    ..._oneTime.map((inc) => _oneTimeCard(inc, card, isDark)),
                  ],

                  if (_incomes.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 64,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'No income records yet',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade400),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white70 : Colors.black54,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _recurringCard(dynamic inc, Color card, bool isDark) {
    final isActive = inc['isActive'] ?? true;
    final pausedThisMonth = _isPausedThisMonth(inc);
    final amount = (inc['amount'] ?? 0).toDouble() * _conversionRate;
    final source = inc['source'] ?? 'Income';
    final freq = _freqLabel(inc['frequency']);
    final since = _formatDate(inc['date'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive && !pausedThisMonth
              ? const Color(0xFF0055D4).withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: source + status badge
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isActive && !pausedThisMonth
                          ? const Color(0xFF0055D4)
                          : Colors.orange)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.autorenew,
                  color: isActive && !pausedThisMonth
                      ? const Color(0xFF0055D4)
                      : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _capitalize(source),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '$_currencySymbol${amount.toStringAsFixed(2)} / $freq • since $since',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (!isActive
                          ? Colors.grey
                          : pausedThisMonth
                              ? Colors.orange
                              : Colors.green)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  !isActive
                      ? 'Inactive'
                      : pausedThisMonth
                          ? 'Paused'
                          : 'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: !isActive
                        ? Colors.grey
                        : pausedThisMonth
                            ? Colors.orange
                            : Colors.green,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              // Toggle active
              Expanded(
                child: _actionBtn(
                  icon: isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                  label: isActive ? 'Deactivate' : 'Activate',
                  color: isActive ? Colors.orange : Colors.green,
                  onTap: () => _toggleActive(inc),
                ),
              ),
              const SizedBox(width: 8),

              // Pause this month (only if active)
              if (isActive)
                Expanded(
                  child: _actionBtn(
                    icon: pausedThisMonth
                        ? Icons.event_available
                        : Icons.event_busy,
                    label: pausedThisMonth ? 'Resume Month' : 'Pause Month',
                    color:
                        pausedThisMonth ? Colors.blue : Colors.deepOrange,
                    onTap: () => _togglePauseThisMonth(inc),
                  ),
                ),
              if (isActive) const SizedBox(width: 8),

              // Delete
              _actionBtn(
                icon: Icons.delete_outline,
                label: 'Delete',
                color: Colors.red,
                onTap: () => _deleteIncome(inc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _oneTimeCard(dynamic inc, Color card, bool isDark) {
    final amount = (inc['amount'] ?? 0).toDouble() * _conversionRate;
    final source = inc['source'] ?? 'Income';
    final date = _formatDate(inc['date'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.attach_money, color: Colors.green, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _capitalize(source),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '$_currencySymbol${amount.toStringAsFixed(2)} on $date',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _deleteIncome(inc),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
