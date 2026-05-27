import 'package:flutter/material.dart';
import 'package:pockect_pilot/services/auth_service.dart';

class SignUpProvider extends ChangeNotifier {
  final fullName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();

  String? error;
  bool loading = false;

  bool showPassword = false;
  bool showConfirm = false;

  void togglePassword() {
    showPassword = !showPassword;
    notifyListeners();
  }

  void toggleConfirm() {
    showConfirm = !showConfirm;
    notifyListeners();
  }

  // 🔥 REAL-TIME VALIDATION
  void validate() {
    if (email.text.isNotEmpty && !email.text.contains("@")) {
      error = "Invalid email address";
    } else if (password.text.isNotEmpty && password.text.length < 8) {
      error = "Password must be at least 8 characters";
    } else if (confirm.text.isNotEmpty &&
        password.text != confirm.text) {
      error = "Passwords do not match";
    } else {
      error = null;
    }
    notifyListeners();
  }

  Future<bool> register() async {
    if (loading) return false;

    if (fullName.text.isEmpty ||
        email.text.isEmpty ||
        phone.text.isEmpty ||
        password.text.isEmpty ||
        confirm.text.isEmpty) {
      error = "All fields are required";
      notifyListeners();
      return false;
    }

    if (password.text.length < 8) {
      error = "Password must be at least 8 characters";
      notifyListeners();
      return false;
    }

    if (password.text != confirm.text) {
      error = "Passwords do not match";
      notifyListeners();
      return false;
    }

    loading = true;
    notifyListeners();

    try {
      await AuthService.register(
        fullName: fullName.text,
        email: email.text,
        password: password.text,
        phone: phone.text,
      );

      return true;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
