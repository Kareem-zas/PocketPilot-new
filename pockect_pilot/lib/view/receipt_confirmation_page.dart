import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/variable_expenses_service.dart';
import 'package:pockect_pilot/view/home_page.dart';

class ReceiptConfirmationPage extends StatefulWidget {
  final String rawJson;

  const ReceiptConfirmationPage({super.key, required this.rawJson});

  @override
  State<ReceiptConfirmationPage> createState() => _ReceiptConfirmationPageState();
}

class _ReceiptConfirmationPageState extends State<ReceiptConfirmationPage> {
  final itemNameController = TextEditingController();
  final priceController = TextEditingController();
  final categoryController = TextEditingController();
  final dateController = TextEditingController();
  final noteController = TextEditingController();

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      final decoded = jsonDecode(widget.rawJson);
      if (decoded is Map<String, dynamic>) {
        itemNameController.text = decoded['itemName']?.toString() ?? '';
        priceController.text = decoded['total']?.toString() ?? '';
        dateController.text = decoded['date']?.toString() ?? '';
        categoryController.text = decoded['category']?.toString() ?? 'Other';
      }
    } catch (e) {
      // In case of invalid JSON, leave fields blank
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _saveExpense() async {
    final title = itemNameController.text.trim();
    final amount = double.tryParse(priceController.text.trim());
    final category = categoryController.text.trim();
    final dateText = dateController.text.trim();
    final notes = noteController.text.trim();

    if (title.isEmpty || amount == null || category.isEmpty || dateText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields correctly.")),
      );
      return;
    }

    final parsedDate = DateTime.tryParse(dateText);
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid date format.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await VariableExpensesService.addExpense(
        title: title,
        amount: amount,
        category: category,
        date: parsedDate,
        notes: notes.isEmpty ? null : notes,
      );

      if (!mounted) return;
      // Navigate back to HomePage and refresh
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("Confirm Receipt", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.document_scanner, color: Colors.blueAccent, size: 50),
                          const SizedBox(height: 10),
                          Text(
                            "Please review the extracted data and make any necessary corrections.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14),
                          ),
                          const SizedBox(height: 25),
                          _buildDarkInput(itemNameController, "Transaction Name", Icons.title, isDark: isDark),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(child: _buildDarkInput(priceController, "Amount", Icons.attach_money, isNumber: true, isDark: isDark)),
                              const SizedBox(width: 15),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _pickDate,
                                  child: AbsorbPointer(
                                    child: _buildDarkInput(dateController, "Date", Icons.calendar_today, isDark: isDark),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _buildDarkInput(categoryController, "Category", Icons.category, isDark: isDark),
                          const SizedBox(height: 15),
                          _buildDarkInput(noteController, "Notes (Optional)", Icons.note, isDark: isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              height: 55,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: isDark ? Colors.white54 : Colors.black54),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Center(
                                child: Text("Retake", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: _saveExpense,
                            child: Container(
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1E5BD8), Color(0xFF0055D4)],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  )
                                ],
                              ),
                              child: const Center(
                                child: Text("Save Expense", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDarkInput(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, required bool isDark}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}
