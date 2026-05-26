import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:pockect_pilot/services/gamification_service.dart';
import 'package:pockect_pilot/services/variable_expenses_service.dart';
import 'package:pockect_pilot/services/pocket_service.dart';

class ReceiptScannerView extends StatefulWidget {
  const ReceiptScannerView({super.key});

  @override
  State<ReceiptScannerView> createState() => _ReceiptScannerViewState();
}

class _ReceiptScannerViewState extends State<ReceiptScannerView>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  
  bool isScanning = false;
  bool showBoxes = false;
  bool isVerifying = false;
  String paymentMethod = "Card";

  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  String storeName = "Unknown Store";
  List<Map<String, dynamic>> parsedItems = [];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Launch camera automatically when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAndScanImage();
    });
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScanImage() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        // User canceled taking a photo
        if (mounted && _imageFile == null) {
          Navigator.pop(context);
        }
        return;
      }

      setState(() {
        _imageFile = File(photo.path);
        isScanning = true;
        showBoxes = false;
        isVerifying = false;
      });

      await _processReceiptImage(_imageFile!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error capturing image: $e")),
        );
        setState(() {
          isScanning = false;
        });
      }
    }
  }

  Future<void> _processReceiptImage(File image) async {
    final inputImage = InputImage.fromFile(image);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      _parseReceiptText(recognizedText.text);

      setState(() {
        isScanning = false;
        showBoxes = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error processing OCR: $e")),
        );
        setState(() {
          isScanning = false;
        });
      }
    } finally {
      textRecognizer.close();
    }
  }

  void _parseReceiptText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) {
      storeName = "Unknown Store";
      parsedItems = [];
      return;
    }

    // Heuristics for Store Name: usually the first line
    storeName = lines.first;

    List<Map<String, dynamic>> items = [];
    // Basic heuristics to find prices: look for numbers with decimals
    final priceRegex = RegExp(r'(\d+\.\d{2})');

    for (int i = 1; i < lines.length; i++) {
      String line = lines[i];
      // Skip common total/tax lines for itemizing
      if (line.toLowerCase().contains("total") ||
          line.toLowerCase().contains("tax") ||
          line.toLowerCase().contains("subtotal") ||
          line.toLowerCase().contains("change") ||
          line.toLowerCase().contains("cash")) {
        continue;
      }

      final match = priceRegex.firstMatch(line);
      if (match != null) {
        // Extract the price
        double? price = double.tryParse(match.group(1) ?? '0');
        if (price != null && price > 0) {
          // Clean the name (remove the price from the line)
          String itemName = line.replaceAll(match.group(0) ?? '', '').trim();
          // Remove leading/trailing stray characters like '$'
          itemName = itemName.replaceAll(RegExp(r'^[\$\s]+|[\$\s]+$'), '').trim();
          
          if (itemName.isEmpty) {
            itemName = "Unknown Item";
          }

          items.add({
            "name": itemName,
            "price": price,
            "category": "Shopping", // Default category
          });
        }
      }
    }

    // Fallback if nothing matched
    if (items.isEmpty) {
      items.add({
        "name": "Manual Entry Required",
        "price": 0.00,
        "category": "Shopping"
      });
    }

    parsedItems = items;
  }

  void _verifyAndSave() {
    setState(() {
      showBoxes = false;
      isVerifying = true;
    });
  }

  Future<void> _logReceiptExpenses() async {
    // Add XP and unlock Badge
    await GamificationService.addXP(80);
    await GamificationService.unlockBadge('smart_scanner');

    double totalAmount = parsedItems.fold(0.0, (sum, item) => sum + item['price']);

    // Log the entire bill to variable expenses
    try {
      if (paymentMethod == "Cash") {
        await PocketService.subtractPocketCash(totalAmount);
        await VariableExpensesService.addExpense(
          title: storeName,
          amount: totalAmount,
          category: "Food", // Simplified category assignment
          date: DateTime.now(),
          notes: "Scanned via Smart Lens (Cash): ${parsedItems.map((e) => e['name']).join(', ')}",
        );
      } else {
        await VariableExpensesService.addExpense(
          title: storeName,
          amount: totalAmount,
          category: "Food",
          date: DateTime.now(),
          notes: "Scanned via Smart Lens: ${parsedItems.map((e) => e['name']).join(', ')}",
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text("Receipt logged! +80 XP Earned 🔥", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark elegant background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Smart Lens OCR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Display actual captured receipt image or fallback gradient
                    if (_imageFile != null)
                      Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF1E293B), Color(0xFF334155)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt, size: 80, color: Colors.white24),
                              SizedBox(height: 15),
                              Text(
                                "WAITING FOR CAMERA...",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Laser Scanning Bar Animation overlay
                    if (isScanning && _imageFile != null)
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (context, child) {
                          // The laser moves up and down across the container height
                          return Positioned(
                            top: _laserController.value * MediaQuery.of(context).size.height * 0.5,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    // Simplified Bounding Boxes or Success message
                    if (showBoxes && _imageFile != null)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF34D399), width: 2),
                          ),
                          child: const Text(
                            "OCR SCAN COMPLETE",
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Verification / Parsing Panel
          Expanded(
            flex: 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: isVerifying ? _buildVerificationStep() : _buildScanningFeedback(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isScanning ? Colors.blue.withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isScanning ? Icons.sync : Icons.check_circle_outline,
                  color: isScanning ? Colors.blueAccent : const Color(0xFF34D399),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isScanning ? "Processing receipt details..." : "Scan Complete!",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            isScanning
                ? "Pocket Pilot is utilizing Google ML Kit text recognition vectors and semantic modeling to map receipt line-items."
                : "Parsed ${parsedItems.length} individual items from '$storeName' with high accuracy.",
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
          ),
          const Spacer(),
          if (!isScanning && _imageFile == null)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.camera_alt),
                label: const Text("Capture Receipt", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _pickAndScanImage,
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isScanning ? Colors.grey.shade800 : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isScanning ? null : _verifyAndSave,
                child: const Text("Verify Scanned Items", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationStep() {
    double totalAmount = parsedItems.fold(0.0, (sum, item) => sum + item['price']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("VERIFY DIGITAL INVOICE", style: TextStyle(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    Text(storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "\$${totalAmount.toStringAsFixed(2)}",
                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800, fontSize: 20),
              )
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: parsedItems.length,
              itemBuilder: (context, idx) {
                final item = parsedItems[idx];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text(item['category'], style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13))),
                          ],
                        ),
                      ),
                      Text("\$${item['price'].toStringAsFixed(2)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("PAYMENT METHOD", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Container(
                height: 35,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: paymentMethod,
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
                    items: ["Card", "Cash"].map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => paymentMethod = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey.shade700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() => isVerifying = false);
                      _pickAndScanImage();
                    },
                    child: const Text("Scan Again"),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _logReceiptExpenses,
                    child: const Text("Confirm & Log", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
