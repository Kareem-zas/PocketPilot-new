import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/goals_service.dart';
import 'package:pockect_pilot/services/pocket_service.dart';

class AddGoalPage extends StatefulWidget {
  const AddGoalPage({super.key});

  @override
  State<AddGoalPage> createState() => _AddGoalPageState();
}

class _AddGoalPageState extends State<AddGoalPage> {
  String selectedCategory = "Travel";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _targetAmountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _initialDepositController =
      TextEditingController();
  bool isSharedGoal = false;
  final TextEditingController _coPilotController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _dateController.dispose();
    _initialDepositController.dispose();
    _coPilotController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      setState(() {
        _dateController.text = "${date.year}-$month-$day";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0055D4)),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildHeader(context),
                    const SizedBox(height: 25),
                    buildBriefingCard(),
                    const SizedBox(height: 25),
                    buildLabel("Goal Name"),
                    buildTextField(
                      hint: "e.g., Dream Vacation",
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),
                    buildLabel("Target Amount"),
                    buildTextField(
                      hint: "0.00",
                      controller: _targetAmountController,
                      isNumber: true,
                    ),
                    const SizedBox(height: 20),
                    buildLabel("Target Date"),
                    buildTextField(
                      hint: "YYYY-MM-DD",
                      trailingIcon: Icons.calendar_today,
                      controller: _dateController,
                      readOnly: true,
                      onTap: _pickDate,
                    ),
                    // Co-Pilot Shared Goal Toggle
                    Container(
                      margin: const EdgeInsets.only(top: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : Colors.blue.shade100,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people,
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue.shade800,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    "Co-Pilot Shared Goal",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.blue.shade300
                                          : const Color(0xFF0055D4),
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: isSharedGoal,
                                onChanged: (val) {
                                  setState(() {
                                    isSharedGoal = val;
                                  });
                                },
                                activeThumbColor: isDark
                                    ? Colors.blue.shade300
                                    : Colors.blue.shade800,
                              ),
                            ],
                          ),
                          if (isSharedGoal) ...[
                            const SizedBox(height: 12),
                            Text(
                              "CO-PILOT EMAIL OR PILOT ID",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF334155)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: TextField(
                                controller: _coPilotController,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "e.g., co-pilot@pocketpilot.com",
                                  hintStyle: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Once accepted, both of you can contribute to this goal and track progress via dual-avatars.",
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    buildLabel("Mission Category"),
                    buildCategories(),
                    const SizedBox(height: 25),
                    buildBoostCard(),
                    const SizedBox(height: 30),
                    buildSubmit(context),
                    const SizedBox(height: 15),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          "New Savings Goal",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.rocket_launch,
            color: isDark ? Colors.blue.shade300 : Colors.blue.shade800,
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget buildBriefingCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A),
                  const Color(0xFF1E293B),
                  const Color(0xFF0055D4).withValues(alpha: 0.2),
                ]
              : [
                  Colors.grey.shade300,
                  Colors.grey.shade100,
                  Colors.blue.shade100,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Color(0xFF0055D4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "MISSION BRIEFING",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: isDark ? Colors.cyanAccent : Colors.black54,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            "Chart Your Course",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0055D4),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLabel(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget buildTextField({
    required String hint,
    IconData? trailingIcon,
    TextEditingController? controller,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isNumber = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEFF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey,
            fontSize: 14,
          ),
          suffixIcon: trailingIcon != null
              ? Icon(
                  trailingIcon,
                  color: isDark ? Colors.white70 : Colors.black87,
                  size: 20,
                )
              : null,
        ),
      ),
    );
  }

  Widget buildCategories() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: categoryChip("Travel", Icons.flight_takeoff)),
            const SizedBox(width: 10),
            Expanded(child: categoryChip("Housing", Icons.home)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: categoryChip("Education", Icons.school)),
            const SizedBox(width: 10),
            Expanded(child: categoryChip("General", Icons.savings)),
          ],
        ),
      ],
    );
  }

  Widget categoryChip(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSelected = selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedCategory = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0055D4)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEFF7)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white70 : Colors.black87),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBoostCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.orange.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: isDark ? Colors.orangeAccent : Colors.orange.shade800,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                "Boost Your Start",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.orangeAccent : Colors.orange.shade900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "INITIAL DEPOSIT (OPTIONAL)",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.orangeAccent : Colors.orange.shade900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _initialDepositController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "Enter amount to start today",
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            "Adding an initial deposit helps reach your goal 15% faster.",
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onCreateGoal() async {
    final title = _nameController.text.trim();
    final targetAmountText = _targetAmountController.text.trim();
    final targetDate = _dateController.text.trim();
    final initialDepositText = _initialDepositController.text.trim();

    if (title.isEmpty || targetAmountText.isEmpty || targetDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields.")),
      );
      return;
    }

    final targetAmount = double.tryParse(targetAmountText);
    if (targetAmount == null || targetAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Invalid target amount.")));
      return;
    }

    final double? initialDeposit = double.tryParse(initialDepositText);

    setState(() => _isLoading = true);

    try {
      final goal = await GoalsService.createGoal(
        title: title,
        category: selectedCategory,
        targetAmount: targetAmount,
        targetDate: targetDate,
        initialDeposit: initialDeposit,
      );

      if (initialDeposit != null && initialDeposit > 0) {
        await PocketService.subtractPocketCash(initialDeposit);
      }

      final String goalId = goal['_id'] ?? goal['id'] ?? '';

      // If shared goal and co-pilot email is specified, send invite!
      if (isSharedGoal &&
          _coPilotController.text.trim().isNotEmpty &&
          goalId.isNotEmpty) {
        await GoalsService.inviteMember(
          goalId: goalId,
          email: _coPilotController.text.trim(),
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Mission initialized! Goal created successfully. 🚀"),
        ),
      );

      Navigator.pop(context, true); // Return true to trigger reload on parent
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to initialize mission: $e")),
      );
    }
  }

  Widget buildSubmit(BuildContext context) {
    return GestureDetector(
      onTap: onCreateGoal,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF0055D4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.adjust, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Text(
              "Create Goal",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
