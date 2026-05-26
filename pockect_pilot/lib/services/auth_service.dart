import 'api_service.dart';
import 'token_service.dart';

class AuthService {
  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final data = await ApiService.post("/auth/register", {
      "fullName": fullName,
      "email": email,
      "password": password,
      "phone": phone,
    });

    final token = data["token"];
    if (token != null) {
      await TokenService.saveToken(token);
    }
  }

  static Future<void> login({
    required String email,
    required String password,
  }) async {
    final data = await ApiService.post("/auth/login", {
      "email": email,
      "password": password,
    });

    final token = data["token"];
    if (token != null) {
      await TokenService.saveToken(token);
    }
  }

  static Future<void> logout() async {
    await TokenService.clearToken();
  }
}
