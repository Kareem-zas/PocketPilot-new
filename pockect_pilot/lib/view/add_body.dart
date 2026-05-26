import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pockect_pilot/services/variable_expenses_service.dart';
import 'package:pockect_pilot/services/gemini_receipt_service.dart';
import 'package:pockect_pilot/services/pocket_service.dart';
import 'package:pockect_pilot/view/home_page.dart';
import 'package:pockect_pilot/view/receipt_confirmation_page.dart';

class AddBody extends StatefulWidget {
  static String? ocrTextCache;

  const AddBody({super.key});

  @override
  State<AddBody> createState() => _AddBodyState();
}

class _AddBodyState extends State<AddBody> {
  final itemNameController = TextEditingController();
  final priceController = TextEditingController();
  final categoryController = TextEditingController();
  final dateController = TextEditingController();
  final noteController = TextEditingController();

  int selectedTab = 0;
  String selectedCategory = "Food & Drink";
  String paymentMethod = "Card";

  bool _handledOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_handledOnce) {
      _handleIncomingData();
    }
  }

  void _handleIncomingData() {
    final raw = AddBody.ocrTextCache;
    if (raw == null || raw.trim().isEmpty) return;

    _handledOnce = true;
    AddBody.ocrTextCache = null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        itemNameController.text = decoded['itemName'] ?? '';
        priceController.text = decoded['total'] ?? '';
        dateController.text = decoded['date'] ?? '';
        categoryController.text = decoded['category'] ?? 'Other';
      }
    } catch (_) {}

    setState(() {});
  }

  Future<void> _openCameraWithAI() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);

    if (image == null) return;

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await GeminiReceiptService.analyzeReceipt(File(image.path));
      if (!mounted) return;
      Navigator.pop(context);

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptConfirmationPage(rawJson: result)),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: $e')),
      );
    }

  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      dateController.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
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
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.camera_alt, color: isDark ? Colors.blue[300] : Colors.blue),
                    onPressed: _openCameraWithAI,
                  ),
                ],
              ),

              Text(
                "New Expense",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
              ),

              const SizedBox(height: 15),

              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _tab(context, "Manual Entry", 0),
                    _tab(context, "Camera Scan", 1),
                    _tab(context, "SMS Reader", 2),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _form(),

              const SizedBox(height: 20),

              _camera(),

              const SizedBox(height: 20),

              _sms(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String text, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(color: selected ? (isDark ? Colors.blue[300] : Colors.blue) : (isDark ? Colors.white70 : Colors.black), fontWeight: selected ? FontWeight.bold : FontWeight.normal),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: [
          _input(itemNameController, "Transaction Name"),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _input(priceController, "Amount")),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(child: _input(dateController, "Date")),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(child: _input(categoryController, "Category")),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: paymentMethod,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                      items: ["Card", "Cash"].map((method) {
                        return DropdownMenuItem(
                          value: method,
                          child: Text(method, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => paymentMethod = val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          _input(noteController, "Notes"),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () async {
              final title = itemNameController.text.trim();
              final amount = double.tryParse(priceController.text.trim());
              final category = categoryController.text.trim();
              final dateText = dateController.text.trim();
              final notes = noteController.text.trim();

              if (title.isEmpty ||
                  amount == null ||
                  category.isEmpty ||
                  dateText.isEmpty) {
                return;
              }

              final parsedDate = DateTime.tryParse(dateText);
              if (parsedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invalid date format.")),
                );
                return;
              }

              try {
                if (paymentMethod == "Cash") {
                  await PocketService.subtractPocketCash(amount);
                  // We also add it to variable expenses for history tracking, maybe with a note
                  await VariableExpensesService.addExpense(
                    title: title,
                    amount: amount,
                    category: category,
                    date: parsedDate,
                    notes: (notes.isEmpty ? "Paid in Cash" : "$notes (Cash)"),
                  );
                } else {
                  await VariableExpensesService.addExpense(
                    title: title,
                    amount: amount,
                    category: category,
                    date: parsedDate,
                    notes: notes.isEmpty ? null : notes,
                  );
                }

                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (_) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: ${e.toString()}")),
                );
              }
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text(
                  "Save Expense",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _camera() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _openCameraWithAI,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt, size: 40, color: isDark ? Colors.blue[300] : Colors.blue),
              const SizedBox(height: 10),
              Text("Tap to scan your receipt", style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sms() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(child: Text("SMS Reader", style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold))),
    );
  }

  Widget _input(TextEditingController controller, String hint) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
