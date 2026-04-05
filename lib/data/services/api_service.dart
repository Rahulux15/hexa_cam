import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../utils/app_logger.dart';
import '../models/login_model.dart';

class ApiService {
  static const String loginEndpoint = '/hexa-auth/login';

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      _log('Attempting login request');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$loginEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ).timeout(const Duration(seconds: 30));

      _log('Response status code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return LoginResponse.fromJson(data);
      } else {
        // Try to parse error message from response
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          return LoginResponse(
            success: false,
            message: errorData['message'] ?? 'Login failed. Please try again.',
          );
        } catch (e) {
          return LoginResponse(
            success: false,
            message: 'Server error (${response.statusCode}). Please try again.',
          );
        }
      }
    } catch (e) {
      _log('Login error');
      return LoginResponse(
        success: false,
        message: 'Network error. Please check your connection.',
      );
    }
  }

  void _log(String message) {
    logDebug(message);
  }

  // Test connection to server
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$loginEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }
}
