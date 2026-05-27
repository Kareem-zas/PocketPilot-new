import 'package:flutter/material.dart';
import 'package:pockect_pilot/view/home_body.dart';
import 'package:pockect_pilot/view/profile_body.dart';
import 'package:pockect_pilot/view/fixed_expense_page.dart';

import 'package:pockect_pilot/view/ai_pilot_page.dart';

import 'package:pockect_pilot/view/stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeBody(),
    FixedExpensePage(),
    AiPilotPage(),
    StatsPage(),
    ProfileBody(), // 🔥 مهم جدًا
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).cardColor,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(
              icon: Icon(Icons.receipt), label: "Expenses"),
          BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy), label: "AI Pilot"),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: "Stats"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
