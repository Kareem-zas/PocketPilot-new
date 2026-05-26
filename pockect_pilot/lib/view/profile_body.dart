import 'package:flutter/material.dart';
import 'package:pockect_pilot/view/login_view.dart';
import 'package:pockect_pilot/services/token_service.dart';
import 'package:pockect_pilot/services/user_service.dart';
import 'package:pockect_pilot/view/gamification_view.dart';
import 'package:pockect_pilot/view/geospatial_view.dart';
import 'package:pockect_pilot/services/gamification_service.dart';
import 'package:pockect_pilot/services/biometric_service.dart';
import 'package:provider/provider.dart';
import 'package:pockect_pilot/services/theme_service.dart';

class ProfileBody extends StatefulWidget {
  const ProfileBody({super.key});

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> {
  bool darkMode = false;
  bool notifications = true;
  bool biometric = false;

  String name = "User";
  bool loading = true;
  int level = 1;
  int streak = 3;
  int xp = 150;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final data = await UserService.getProfile();

      if (!mounted) return;

      String extractedName = "User";

      if (data['user'] != null) {
        extractedName =
            data['user']['fullName'] ??
            data['user']['name'] ??
            data['user']['username'] ??
            extractedName;
      } else if (data['data'] != null) {
        if (data['data']['user'] != null) {
          extractedName =
              data['data']['user']['fullName'] ??
              data['data']['user']['name'] ??
              data['data']['user']['username'] ??
              extractedName;
        } else {
          extractedName =
              data['data']['fullName'] ??
              data['data']['name'] ??
              data['data']['username'] ??
              extractedName;
        }
      }

      final currentLevel = await GamificationService.getLevel();
      final currentStreak = await GamificationService.getStreak();
      final currentXP = await GamificationService.getXP();
      final biometricEnabled = await BiometricService.isEnabled();

      if (!mounted) return;

      setState(() {
        name = extractedName;
        level = currentLevel;
        streak = currentStreak;
        xp = currentXP;
        biometric = biometricEnabled;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains("token")) {
        await TokenService.clearToken();
        _goLogin();
        return;
      }

      setState(() {
        loading = false;
      });
    }
  }

  void _goLogin() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginView()),
      (route) => false,
    );
  }

  Future<void> _logout() async {
    await TokenService.clearToken();
    _goLogin();
  }

  Widget _settingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(Icons.menu, color: Colors.blue),
              Text("Pocket Pilot",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue)),
              CircleAvatar(radius: 18)
            ],
          ),

          const SizedBox(height: 30),

          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.person,
                    size: 60, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit,
                    size: 16, color: Colors.white),
              )
            ],
          ),

          const SizedBox(height: 20),

          Text(
            name,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.blue, size: 14),
                    const SizedBox(width: 4),
                    Text("Level $level", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text("$streak Day Streak", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            height: 45,
            width: 160,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E5BD8), Color(0xFF3A7BFF)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
              child: Text(
                "Edit Profile",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Align(
            alignment: Alignment.centerLeft,
            child: Text("Academy & Tracking",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 15),

          _settingTile(
            icon: Icons.emoji_events,
            title: "Financial Flight Academy",
            subtitle: "View Streaks, XP, and unlockable Badges",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GamificationView()),
              );
              loadProfile();
            },
          ),

          _settingTile(
            icon: Icons.pin_drop,
            title: "GPS Auto-Reminders",
            subtitle: "Manage geo-spatial smart notifications",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GeospatialView()),
              );
            },
          ),

          const SizedBox(height: 15),

          Align(
            alignment: Alignment.centerLeft,
            child: Text("Account Settings",
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),

          const SizedBox(height: 15),

          _settingTile(
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "Switch between light and dark themes",
            trailing: Switch(
              value: Provider.of<ThemeService>(context).isDarkMode,
              onChanged: (val) {
                Provider.of<ThemeService>(context, listen: false).toggleTheme(val);
              },
            ),
          ),

          _settingTile(
            icon: Icons.notifications,
            title: "Notifications",
            subtitle: "Real-time alerts for your spending",
            trailing: Switch(
              value: notifications,
              onChanged: (val) {
                setState(() => notifications = val);
              },
            ),
          ),

          _settingTile(
            icon: Icons.fingerprint,
            title: "Biometric Login",
            subtitle: "Face ID or fingerprint unlock",
            trailing: Switch(
              value: biometric,
              onChanged: (val) async {
                if (val) {
                  // Capture messenger before any async gap
                  final messenger = ScaffoldMessenger.of(context);
                  // Check if hardware is capable before enabling
                  final available = await BiometricService.isAvailable();
                  if (!available) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('No biometric hardware or credentials enrolled on this device.'),
                      ),
                    );
                    return;
                  }
                  // Ask the user to authenticate once to confirm they want to enable it
                  final confirmed = await BiometricService.authenticate();
                  if (!confirmed) return;
                }
                await BiometricService.setEnabled(val);
                if (mounted) setState(() => biometric = val);
              },
            ),
          ),

          _settingTile(
            icon: Icons.security,
            title: "Privacy & Security",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),

          _settingTile(
            icon: Icons.help_outline,
            title: "Help Center",
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFFF8D7DA),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            "POCKET PILOT V2.4.0",
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
