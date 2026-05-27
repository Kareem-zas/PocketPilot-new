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
import 'package:pockect_pilot/services/currency_service.dart';
import 'package:pockect_pilot/services/exchange_rate_service.dart';

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
  String email = "";
  String _selectedCurrencyCode = 'JOD';
  bool loading = true;
  int level = 1;
  int streak = 3;
  int xp = 150;

  @override
  void initState() {
    super.initState();
    loadProfile();
    _loadCurrency();
  }

  Future<void> loadProfile() async {
    try {
      final data = await UserService.getProfile();

      if (!mounted) return;

      String extractedName = "User";
      String extractedEmail = "";

      if (data['user'] != null) {
        extractedName =
            data['user']['fullName'] ??
            data['user']['name'] ??
            data['user']['username'] ??
            extractedName;
        extractedEmail = data['user']['email'] ?? "";
      } else if (data['data'] != null) {
        if (data['data']['user'] != null) {
          extractedName =
              data['data']['user']['fullName'] ??
              data['data']['user']['name'] ??
              data['data']['user']['username'] ??
              extractedName;
          extractedEmail = data['data']['user']['email'] ?? "";
        } else {
          extractedName =
              data['data']['fullName'] ??
              data['data']['name'] ??
              data['data']['username'] ??
              extractedName;
          extractedEmail = data['data']['email'] ?? "";
        }
      }

      final currentLevel = await GamificationService.getLevel();
      final currentStreak = await GamificationService.getStreak();
      final currentXP = await GamificationService.getXP();
      final biometricEnabled = await BiometricService.isEnabled();

      if (!mounted) return;

      setState(() {
        name = extractedName;
        email = extractedEmail;
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

  Future<void> _loadCurrency() async {
    final code = await CurrencyService.getCurrencyCode();
    if (mounted) setState(() => _selectedCurrencyCode = code);
  }

  Future<void> _showEditProfileSheet() async {
    String tempCode = _selectedCurrencyCode;
    double? previewRate;
    String? previewText;
    bool fetchingRate = false;
    bool rateFailed = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCode = await CurrencyService.getBaseCurrencyCode();

    // Pre-load the current balance for conversion preview
    // We show this even if we don't have it (graceful fallback)

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Triggered when user picks a different currency
            Future<void> onCurrencyChanged(String newCode) async {
              setSheetState(() {
                tempCode = newCode;
                previewText = null;
                rateFailed = false;
                fetchingRate = newCode != _selectedCurrencyCode;
              });

              if (newCode == _selectedCurrencyCode) {
                // If they re-select the current currency, we don't need a new preview
                // but technically the rate from base to this is what we already have.
                // We'll just reset.
                fetchingRate = false;
                return;
              }

              final rate = await ExchangeRateService.getRate(
                  baseCode, newCode);
              final fromInfo =
                  CurrencyService.fromCode(baseCode);
              final toInfo = CurrencyService.fromCode(newCode);

              if (!ctx.mounted) return;
              setSheetState(() {
                previewRate = rate;
                fetchingRate = false;
                rateFailed = rate == 1.0 &&
                    newCode != baseCode;
                if (rate != 1.0) {
                  previewText =
                      'Live rate: 1 ${fromInfo.code} = ${rate.toStringAsFixed(4)} ${toInfo.code}  •  '
                      'e.g. 100 ${fromInfo.symbol} → ${(100 * rate).toStringAsFixed(2)} ${toInfo.symbol}';
                }
              });
            }

            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Update your preferences',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name (read-only)
                  _profileField(
                    isDark: isDark,
                    label: 'FULL NAME',
                    value: name,
                    icon: Icons.person_outline,
                    readOnly: true,
                  ),
                  const SizedBox(height: 14),

                  // Email (read-only)
                  _profileField(
                    isDark: isDark,
                    label: 'EMAIL',
                    value: email.isEmpty ? 'Not available' : email,
                    icon: Icons.email_outlined,
                    readOnly: true,
                  ),
                  const SizedBox(height: 20),

                  // Currency label
                  Text(
                    'CURRENCY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFF1F2F6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempCode,
                        isExpanded: true,
                        dropdownColor: isDark
                            ? const Color(0xFF334155)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        items: CurrencyService.supportedCurrencies
                            .map((c) => DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Row(
                                    children: [
                                      Text(c.flag,
                                          style: const TextStyle(
                                              fontSize: 20)),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${c.code} — ${c.symbol}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            c.name,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) onCurrencyChanged(val);
                        },
                      ),
                    ),
                  ),

                  // Live rate preview
                  if (fetchingRate) ...[  
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF0055D4)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Fetching live exchange rate...',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ] else if (rateFailed) ...[  
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.orange.shade300, width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 14, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Could not fetch live rate. Balances will be saved without conversion.',
                              style: TextStyle(
                                  color: Colors.orange, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (previewText != null) ...[  
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0055D4)
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF0055D4)
                                .withValues(alpha: 0.25),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.currency_exchange,
                              size: 14,
                              color: Color(0xFF0055D4)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              previewText!,
                              style: const TextStyle(
                                color: Color(0xFF0055D4),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: fetchingRate
                          ? null
                          : () async {
                              // If previewRate is null, they didn't change it, or it failed and we use 1.0 fallback
                              // Wait, if they didn't change it, we shouldn't overwrite with 1.0!
                              // We should only overwrite if previewRate != null.
                              if (previewRate != null || tempCode == baseCode) {
                                final rateToSave = tempCode == baseCode ? 1.0 : (previewRate ?? 1.0);
                                await CurrencyService.setCurrencyWithRate(
                                    tempCode, rateToSave);
                              }
                              if (mounted) {
                                setState(
                                    () => _selectedCurrencyCode = tempCode);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                final toInfo =
                                    CurrencyService.fromCode(tempCode);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle,
                                            color: Colors.white, size: 18),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            previewRate != null && previewRate != 1.0
                                                ? 'Currency set to ${toInfo.name}. Balances converted at live rate.'
                                                : 'Currency updated to ${toInfo.name}.',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: const Color(0xFF1D9E75),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5BD8),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: fetchingRate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _profileField({
    required bool isDark,
    required String label,
    required String value,
    required IconData icon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF334155)
                : const Color(0xFFF1F2F6),
            borderRadius: BorderRadius.circular(14),
            border: readOnly
                ? Border.all(
                    color: isDark ? Colors.white12 : Colors.grey.shade200)
                : null,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: readOnly
                        ? (isDark ? Colors.white54 : Colors.black45)
                        : (isDark ? Colors.white : Colors.black87),
                    fontSize: 14,
                  ),
                ),
              ),
              if (readOnly)
                Icon(Icons.lock_outline,
                    size: 14,
                    color: isDark ? Colors.white24 : Colors.grey.shade400),
            ],
          ),
        ),
      ],
    );
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF334155)
              : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ),
            ?trailing,
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
              Text(
                "Pocket Pilot",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.blue,
                ),
              ),
              CircleAvatar(radius: 18),
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
                child: const Icon(Icons.person, size: 60, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text(
            name,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.blue, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Level $level",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text("🔥", style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      "$streak Day Streak",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: _showEditProfileSheet,
            child: Container(
              height: 45,
              width: 160,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E5BD8), Color(0xFF3A7BFF)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E5BD8).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Edit Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Academy & Tracking",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
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
            child: Text(
              "Account Settings",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 15),

          _settingTile(
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "Switch between light and dark themes",
            trailing: Switch(
              value: Provider.of<ThemeService>(context).isDarkMode,
              onChanged: (val) {
                Provider.of<ThemeService>(
                  context,
                  listen: false,
                ).toggleTheme(val);
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
                        content: Text(
                          'No biometric hardware or credentials enrolled on this device.',
                        ),
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
