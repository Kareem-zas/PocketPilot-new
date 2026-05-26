import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/gemini_chat_service.dart';
import 'package:pockect_pilot/services/home_service.dart';
import 'dart:async';

class AiPilotPage extends StatefulWidget {
  final String? initialPrompt;
  const AiPilotPage({super.key, this.initialPrompt});

  @override
  State<AiPilotPage> createState() => _AiPilotPageState();
}

class _AiPilotPageState extends State<AiPilotPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, String>> messages = [];
  bool isTyping = false;
  String systemContext = "";

  @override
  void initState() {
    super.initState();
    _loadContext();
    if (widget.initialPrompt != null) {
      _controller.text = widget.initialPrompt!;
    }
    // Default welcome message
    messages.add({
      "role": "model",
      "text": "Hello! I'm your Pocket Pilot. I'm ready to analyze your spending or give financial advice.",
      "time": _formatTime(DateTime.now()),
    });
  }

  String _formatTime(DateTime date) {
    String h = date.hour > 12 ? "${date.hour - 12}" : "${date.hour}";
    if (h == '0') h = '12';
    String m = date.minute.toString().padLeft(2, '0');
    return "$h:$m ${date.hour >= 12 ? 'PM' : 'AM'}";
  }

  Future<void> _loadContext() async {
    try {
      final dashboard = await HomeService.fetchDashboard();
      final bal = dashboard['balance'] ?? 0.0;
      final inc = dashboard['totalIncome'] ?? 0.0;
      final exp = dashboard['variableExpenses'] ?? 0.0;
      final fix = dashboard['totalFixed'] ?? 0.0;

      if (!mounted) return;
      setState(() {
        systemContext = "The user has \$$bal in balance, \$$inc monthly income, \$$exp in variable expenses, and \$$fix in fixed expenses. Formulate advice around these numbers.";
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200, // Overshoot to ensure it clears
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = text.trim();
    _controller.clear();

    setState(() {
      messages.add({
        "role": "user",
        "text": userMsg,
        "time": _formatTime(DateTime.now()),
      });
      isTyping = true;
    });

    Timer(const Duration(milliseconds: 100), _scrollToBottom);

    // Prepare history payload mapping roles precisely
    List<Map<String, String>> historyPayload = messages.map((m) => {
      "role": m["role"]!,
      "text": m["text"]!
    }).toList();

    try {
      final responseText = await GeminiChatService.sendMessage(
        history: historyPayload,
        systemContext: systemContext,
      );

      if (!mounted) return;
      setState(() {
        isTyping = false;
        messages.add({
          "role": "model",
          "text": responseText,
          "time": _formatTime(DateTime.now()),
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isTyping = false;
        messages.add({
          "role": "model",
          "text": "Sorry, I couldn't connect right now. Error: $e",
          "time": _formatTime(DateTime.now()),
        });
      });
    }

    Timer(const Duration(milliseconds: 100), _scrollToBottom);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
          ),
          child: Column(
            children: [
              _buildHeader(isDark),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: messages.length + (isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length) {
                        return _buildTypingIndicator(isDark);
                      }
                      final msg = messages[index];
                      if (msg['role'] == 'user') {
                        return _buildUserBubble(msg['text']!, msg['time']!);
                      } else {
                        return _buildModelBubble(msg['text']!, msg['time']!, isDark);
                      }
                    },
                  ),
                ),
                _buildSuggestionsRow(isDark),
                _buildInputRow(isDark),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 15),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("AI Pilot", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    const Flexible(
                      child: Text(
                        "PROCESSING REAL-TIME DATA",
                        style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const Icon(Icons.settings, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildModelBubble(String text, String time, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : Colors.orange.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy, color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(text, style: TextStyle(height: 1.5, color: isDark ? Colors.white : Colors.black87)),
                ),
                const SizedBox(height: 5),
                Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 40), // Pad right side
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 40), // Pad left side
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0055D4),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(text, style: const TextStyle(height: 1.5, color: Colors.white)),
                ),
                const SizedBox(height: 5),
                Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, size: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : Colors.orange.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy, color: isDark ? Colors.orange.shade300 : Colors.orange.shade800, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dot(), _dot(), _dot(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() => Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle));

  Widget _buildSuggestionsRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _chip("Analyze my rent hike 📈", isDark),
          const SizedBox(width: 10),
          _chip("Travel fund progress ✈️", isDark),
        ],
      ),
    );
  }

  Widget _chip(String label, bool isDark) {
    return ActionChip(
      label: Text(label, style: TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue)),
      backgroundColor: isDark ? const Color(0xFF334155) : Colors.blue.shade50,
      side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade100),
      onPressed: () => _sendMessage(label),
    );
  }

  Widget _buildInputRow(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F2F6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Ask your Pocket Pilot...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
            Icon(Icons.mic, color: isDark ? Colors.white70 : Colors.grey.shade600),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFF0055D4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
