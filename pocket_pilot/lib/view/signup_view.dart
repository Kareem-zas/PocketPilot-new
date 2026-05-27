import 'package:flutter/material.dart';

import 'package:pockect_pilot/view/money_info_view.dart';

import 'package:provider/provider.dart';

import 'signup_provider.dart';

class SignUpView extends StatelessWidget {
  const SignUpView({super.key});

  Widget _input({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required Function(String) onChanged,
    bool obscure = false,
    bool toggle = false,
    VoidCallback? onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
            filled: true,
            fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
            prefixIcon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
            suffixIcon: toggle
                ? IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignUpProvider(),
      child: Consumer<SignUpProvider>(
        builder: (context, p, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // HEADER
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.explore,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            "Pocket Pilot",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      Text(
                        "Create your account",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        "Your personal financial cockpit starts here.",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                      ),

                      const SizedBox(height: 30),

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
                            _input(
                              context: context,
                              label: "Name",
                              hint: "John Doe",
                              icon: Icons.person,
                              controller: p.fullName,
                              onChanged: (_) => p.validate(),
                            ),
                            const SizedBox(height: 12),

                            _input(
                              context: context,
                              label: "Email",
                              hint: "pilot@example.com",
                              icon: Icons.email,
                              controller: p.email,
                              onChanged: (_) => p.validate(),
                            ),
                            const SizedBox(height: 12),

                            _input(
                              context: context,
                              label: "Phone",
                              hint: "+1 (555)",
                              icon: Icons.phone,
                              controller: p.phone,
                              onChanged: (_) {},
                            ),
                            const SizedBox(height: 12),

                            _input(
                              context: context,
                              label: "Password",
                              hint: "••••••",
                              icon: Icons.lock,
                              controller: p.password,
                              obscure: !p.showPassword,
                              toggle: true,
                              onToggle: p.togglePassword,
                              onChanged: (_) => p.validate(),
                            ),
                            const SizedBox(height: 12),

                            _input(
                              context: context,
                              label: "Confirm",
                              hint: "••••••",
                              icon: Icons.verified_user,
                              controller: p.confirm,
                              obscure: !p.showConfirm,
                              toggle: true,
                              onToggle: p.toggleConfirm,
                              onChanged: (_) => p.validate(),
                            ),

                            if (p.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  p.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),

                            const SizedBox(height: 20),

                            GestureDetector(
                              onTap: () async {
                                bool success = await p.register();
                                if (success && context.mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const MoneyInfoView(),
                                    ),
                                  );
                                }
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 55,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: p.loading
                                      ? Colors.blue.shade300
                                      : Colors.blue,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: Text(
                                    p.loading ? "Loading..." : "Sign Up →",
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
