import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/income_service.dart';
import 'package:pockect_pilot/view/home_page.dart';
import 'package:pockect_pilot/services/currency_service.dart';

class AddIncomeBody extends StatefulWidget {
  const AddIncomeBody({super.key});

  @override
  State<AddIncomeBody> createState() => _AddIncomeBodyState();
}

class _AddIncomeBodyState extends State<AddIncomeBody> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController sourceController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool isRecurring = false;
  String? frequency;
  DateTime? selectedDate;
  String _currencySymbol = '\$';

  @override
  void initState() {
    super.initState();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final symbol = await CurrencyService.getSymbol();
    if (mounted) setState(() => _currencySymbol = symbol);
  }

  @override
  void dispose() {
    amountController.dispose();
    sourceController.dispose();
    notesController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return amountController.text.isNotEmpty && selectedDate != null;
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

  Future<void> _addIncome() async {
    if (!_isValid) return;

    await IncomeService.insertIncome(
      source: sourceController.text.isEmpty ? 'General' : sourceController.text,
      amount: double.parse(amountController.text),
      date: selectedDate!,
      isRecurring: isRecurring,
      frequency: isRecurring ? frequency : null,
      notes: notesController.text.isEmpty ? null : notesController.text,
    );

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Widget _input(String label, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
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

              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text("Pocket Pilot",
                      style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold)),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Add Your Income",
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),

              const SizedBox(height: 10),

              Text(
                "Track your income to improve insights",
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
              ),

              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  children: [
                    _input(
                      "Primary Income Amount",
                      _box(
                        Row(
                          children: [
                            Text(_currencySymbol, style: const TextStyle(color: Colors.blue)),
                            const SizedBox(width: 10),
                            Expanded(
                                child: TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "0.00",
                                  ),
                                ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    _input(
                      "Income Type",
                      _box(
                        TextField(
                          controller: sourceController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(
                            hintText: "Salary",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    _input(
                      "Received Date",
                      GestureDetector(
                        onTap: _pickDate,
                        child: _box(
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedDate == null
                                  ? "mm/dd/yyyy"
                                  : selectedDate!
                                      .toString()
                                      .split(" ")[0],
                                  style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                              Icon(Icons.calendar_today, color: isDark ? Colors.white70 : Colors.black54),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

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
                                  child: Text("Is Recurring Income?", style: TextStyle(color: isDark ? Colors.white : Colors.black))),
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
                          if (isRecurring)
                            Column(
                              children: [
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => frequency = "monthly"),
                                        child: _freqBox("MONTHLY", frequency == "monthly"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => frequency = "quarterly"),
                                        child: _freqBox("QUARTERLY", frequency == "quarterly"),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => frequency = "bi-annual"),
                                        child: _freqBox("BI-ANNUAL", frequency == "bi-annual"),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => frequency = "yearly"),
                                        child: _freqBox("YEARLY", frequency == "yearly"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),

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
                            hintText: "Optional notes...",
                            hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isValid ? _addIncome : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        child: const Text("Add Income", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _freqBox(String text, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(
            color: active ? (isDark ? Colors.blue[300]! : Colors.blue) : (isDark ? Colors.grey.shade700 : Colors.grey)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Text(text,
            style: TextStyle(
                color: active ? (isDark ? Colors.blue[300] : Colors.blue) : (isDark ? Colors.grey.shade500 : Colors.grey))),
      ),
    );
  }
}
