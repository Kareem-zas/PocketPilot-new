import 'package:flutter/material.dart';

import 'package:pockect_pilot/view/otp_verification_page.dart';
import 'package:pockect_pilot/services/income_service.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class MoneyInfoView extends StatefulWidget {
  const MoneyInfoView({super.key});

  @override
  State<MoneyInfoView> createState() => _MoneyInfoViewState();
}

class _MoneyInfoViewState extends State<MoneyInfoView> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool isRecurring = false;
  String? frequency;
  DateTime? selectedDate;
  String _selectedCurrencyCode = 'JOD'; // default

  final Map<String, String> frequencies = {
    'Monthly': 'monthly',
    'Yearly': 'yearly',
  };

  bool get _isAmountValid {
    final text = amountController.text.trim();
    return text.isNotEmpty && double.tryParse(text) != null;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _saveIncome() async {
    try {
      if (!_isAmountValid || selectedDate == null) {
        throw Exception('Please fill required fields');
      }

      if (isRecurring && frequency == null) {
        throw Exception('Please select frequency');
      }

      // Save the chosen currency as the user's base currency (rate = 1.0
      // because all stored amounts will be in this currency from the start)
      await CurrencyService.initBaseCurrency(_selectedCurrencyCode);

      await IncomeService.insertIncome(
        source: sourceController.text.trim().isEmpty
            ? 'General'
            : sourceController.text.trim(),
        amount: double.parse(amountController.text.trim()),
        date: selectedDate!,
        isRecurring: isRecurring,
        frequency: isRecurring ? frequency : null,
        notes: notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OTPVerificationPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Widget _input(String label, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: isDark ? Colors.white70 : Colors.black87),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _box(Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      height: 55,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // HEADER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.menu, color: Colors.blue),
                  const Text("Pocket Pilot",
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  )
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Welcome to POCKET PILOT",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
              ),

              const SizedBox(height: 6),

              Text(
                "Let's get started by setting your primary income.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
              ),

              const SizedBox(height: 25),

              // CARD
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black12,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // CURRENCY SELECTOR
                    _input(
                      "Currency",
                      _box(
                        DropdownButton<String>(
                          value: _selectedCurrencyCode,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: CurrencyService.supportedCurrencies
                              .map((c) => DropdownMenuItem(
                                    value: c.code,
                                    child: Row(
                                      children: [
                                        Text(c.flag,
                                            style: const TextStyle(
                                                fontSize: 18)),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${c.code}  ${c.symbol}  —  ${c.name}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(
                                  () => _selectedCurrencyCode = val);
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // AMOUNT
                    _input(
                      "Primary Income Amount",
                      _box(
                        Row(
                          children: [
                            Text(
                              CurrencyService.fromCode(
                                      _selectedCurrencyCode)
                                  .symbol,
                              style: const TextStyle(
                                  color: Colors.blue, fontSize: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: amountController,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87),
                                decoration: InputDecoration(
                                  hintText: "0.00",
                                  hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black38),
                                  border: InputBorder.none,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // TYPE
                    _input(
                      "Income Type",
                      _box(
                        DropdownButton<String>(
                          value: sourceController.text.isEmpty
                              ? "Salary"
                              : sourceController.text,
                          dropdownColor: Theme.of(context).cardColor,
                          underline: const SizedBox(),
                          isExpanded: true,
                          items: ["Salary", "Business", "Other"]
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                  ))
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              sourceController.text = val!;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // DATE
                    _input(
                      "Received Date",
                      GestureDetector(
                        onTap: _pickDate,
                        child: _box(
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDate == null
                                    ? "mm/dd/yyyy"
                                    : selectedDate!
                                        .toString()
                                        .split(" ")[0],
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
                              ),
                              Icon(Icons.calendar_today, color: isDark ? Colors.white70 : Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // RECURRING
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.autorenew,
                                  color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text("Is Recurring Income?", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              ),
                              Switch(
                                value: isRecurring,
                                onChanged: (val) {
                                  setState(() {
                                    isRecurring = val;
                                    if (!val) frequency = null;
                                  });
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => frequency = "monthly"),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: frequency == "monthly"
                                              ? Colors.blue
                                              : (isDark ? Colors.grey[700]! : Colors.grey)),
                                      borderRadius:
                                          BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                        child: Text("MONTHLY", style: TextStyle(color: frequency == "monthly" ? Colors.blue : (isDark ? Colors.white70 : Colors.black87)))),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                      () => frequency = "yearly"),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: frequency == "yearly"
                                              ? Colors.blue
                                              : (isDark ? Colors.grey[700]! : Colors.grey)),
                                      borderRadius:
                                          BorderRadius.circular(15),
                                    ),
                                    child: Center(
                                        child: Text("YEARLY", style: TextStyle(color: frequency == "yearly" ? Colors.blue : (isDark ? Colors.white70 : Colors.black87)))),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

                    // NOTES
                    _input(
                      "Navigator Notes",
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: notesController,
                          maxLines: 3,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText:
                                "e.g. Main job salary after tax...",
                            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveIncome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("Complete Setup", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
