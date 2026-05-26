import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/goals_service.dart';

class SharedGoalsPage extends StatefulWidget {
  const SharedGoalsPage({super.key});

  @override
  State<SharedGoalsPage> createState() => _SharedGoalsPageState();
}

class _SharedGoalsPageState extends State<SharedGoalsPage> {
  List<dynamic> _sharedGoals = [];
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;
  String? _expandedGoalId;

  @override
  void initState() {
    super.initState();
    _loadSharedGoals(showLoading: true);
    // Start client-side polling every 8 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _loadSharedGoals(showLoading: false);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSharedGoals({required bool showLoading}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final goals = await GoalsService.getSharedGoals();
      if (!mounted) return;
      setState(() {
        _sharedGoals = goals;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll("Exception: ", "");
        _isLoading = false;
      });
    }
  }

  IconData _iconFromCategory(String? category) {
    switch (category) {
      case 'Travel':
        return Icons.flight_takeoff;
      case 'Housing':
        return Icons.home;
      case 'Education':
        return Icons.school;
      default:
        return Icons.savings;
    }
  }

  Future<void> _inviteMember(String goalId) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Invite Vault Member"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your friend's email address to invite them to this collaborative goal.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: "Friend's Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Invite"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final email = controller.text.trim();
      if (email.isEmpty) return;

      try {
        await GoalsService.inviteMember(goalId: goalId, email: email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Member invited successfully! 🚀")),
        );
        _loadSharedGoals(showLoading: false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to invite: $e")),
        );
      }
    }
  }

  Future<void> _contribute(String goalId) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Contribute to Vault"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter the amount you would like to transfer into this shared savings vault.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Contribution Amount",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Contribute"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final amtText = controller.text.trim();
      final amount = double.tryParse(amtText);
      if (amount == null || amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter a valid amount")),
        );
        return;
      }

      try {
        await GoalsService.contributeToGoal(goalId: goalId, amount: amount);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contribution recorded successfully! 💰")),
        );
        _loadSharedGoals(showLoading: false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to contribute: $e")),
        );
      }
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
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.blue[300] : const Color(0xFF0055D4)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Shared Goals Vault",
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorWidget()
                : RefreshIndicator(
                    onRefresh: () => _loadSharedGoals(showLoading: true),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildIntroCard(),
                          const SizedBox(height: 25),
                          const Text(
                            "COLLABORATIVE VAULTS",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 15),
                          if (_sharedGoals.isEmpty)
                            _buildEmptyState()
                          else
                            ..._sharedGoals.map((goal) => _buildSharedGoalCard(goal)),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 15),
            const Text(
              "Sync Failed",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _loadSharedGoals(showLoading: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0055D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text("Retry Connection", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.people_outline, color: Colors.greenAccent, size: 36),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Co-Pilot Savings Vaults",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(
                  "Invite friends or family members to pool money and track your progress together in real time.",
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.group_add_outlined, size: 50, color: isDark ? Colors.grey.shade600 : Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(
            "No Shared Goals Yet",
            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade400 : Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            "Go to your Goals tab, create a goal, and invite friends to transform it into a collaborative vault!",
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedGoalCard(dynamic goal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String goalId = goal['_id'];
    final bool isExpanded = _expandedGoalId == goalId;
    final String title = goal['title'] ?? 'Vault';
    final String category = goal['category'] ?? 'General';
    final double targetAmount = (goal['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final double savedAmount = (goal['savedAmount'] as num?)?.toDouble() ?? 0.0;
    final double progress = targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

    final creator = goal['user'];
    final creatorName = creator != null ? creator['fullName'] ?? 'Owner' : 'Owner';
    
    final members = goal['members'] as List? ?? [];
    final contributions = goal['contributions'] as List? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        children: [
          // Basic Goal Info
          ListTile(
            onTap: () {
              setState(() {
                _expandedGoalId = isExpanded ? null : goalId;
              });
            },
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFromCategory(category), color: isDark ? Colors.blue[300] : const Color(0xFF0055D4)),
            ),
            title: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black),
            ),
            subtitle: Text(
              "Created by $creatorName • $category",
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
            trailing: Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey,
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFEBEFF7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.greenAccent, Colors.green],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Saved vs Target Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "\$${savedAmount.toStringAsFixed(2)} saved",
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      "Target \$${targetAmount.toStringAsFixed(2)}",
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                
                const SizedBox(height: 15),
                // Members Avatars Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Vault Members:",
                      style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    _buildMembersAvatars(creator, members),
                  ],
                ),
              ],
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _contribute(goalId),
                          icon: const Icon(Icons.add, size: 18, color: Colors.white),
                          label: const Text("Contribute", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _inviteMember(goalId),
                          icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
                          label: const Text("Invite Friend", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0055D4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  // Contributions Timeline title
                  const Text(
                    "CONTRIBUTIONS TIMELINE",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildContributionsTimeline(contributions),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersAvatars(dynamic creator, List members) {
    List<dynamic> allMembers = [];
    if (creator != null) {
      allMembers.add(creator);
    }
    allMembers.addAll(members);

    if (allMembers.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        SizedBox(
          height: 30,
          width: (allMembers.length > 4 ? 4 : allMembers.length) * 22.0 + 8.0,
          child: Stack(
            children: List.generate(
              allMembers.length > 4 ? 4 : allMembers.length,
              (index) {
                final member = allMembers[index];
                final String fullName = member['fullName'] ?? 'U';
                final String initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U';
                
                // Position each avatar slightly overlapping
                return Positioned(
                  left: index * 22.0,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.primaries[index % Colors.primaries.length].shade400,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (allMembers.length > 4)
          Padding(
            padding: const EdgeInsets.only(left: 5.0),
            child: Text(
              "+${allMembers.length - 4}",
              style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }

  Widget _buildContributionsTimeline(List contributions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (contributions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text(
          "No contributions recorded yet. Be the first to add savings!",
          style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      );
    }

    // Sort contributions by date descending
    final List sortedContribs = List.from(contributions)
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedContribs.length > 5 ? 5 : sortedContribs.length, // Show top 5
      itemBuilder: (context, index) {
        final contrib = sortedContribs[index];
        final double amount = (contrib['amount'] as num?)?.toDouble() ?? 0.0;
        final user = contrib['userId'];
        final String fullName = user != null ? user['fullName'] ?? 'Member' : 'Member';
        final rawDate = contrib['createdAt'];
        final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
        
        String timeAgo = "recently";
        if (date != null) {
          final diff = DateTime.now().difference(date);
          if (diff.inDays > 0) {
            timeAgo = "${diff.inDays}d ago";
          } else if (diff.inHours > 0) {
            timeAgo = "${diff.inHours}h ago";
          } else if (diff.inMinutes > 0) {
            timeAgo = "${diff.inMinutes}m ago";
          } else {
            timeAgo = "just now";
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.circle_notifications, size: 16, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "$fullName contributed \$${amount.toStringAsFixed(2)}",
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              Text(
                timeAgo,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }
}
