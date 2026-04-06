import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../data/models/login_model.dart';
import '../../../data/services/api_service.dart';

class AuthController extends GetxController {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Form controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // Observable variables
  var isLoading = false.obs;
  var isPasswordVisible = false.obs;
  var errorMessage = ''.obs;
  var isOfflineMode = false.obs;

  // User state
  var isLoggedIn = false.obs;
  var currentUser = Rx<UserData?>(null);

  @override
  void onInit() {
    super.onInit();
    checkLoginStatus();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.toggle();
  }

  // Check if user has already logged in before (for auto-login)
  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _secureStorage.read(key: 'auth_token');
    final userEmail = prefs.getString('user_email');
    final userId = prefs.getString('user_id');
    final userName = prefs.getString('user_full_name');

    final hasValidSession =
        token != null &&
        token.isNotEmpty &&
        userEmail != null &&
        userEmail.isNotEmpty;

    if (hasValidSession) {
      currentUser.value = UserData(
        id: userId,
        email: userEmail,
        fullName: userName,
      );
      isLoggedIn.value = true;
    } else {
      currentUser.value = null;
      isLoggedIn.value = false;
    }
  }

  // Check internet connection
  Future<bool> hasInternetConnection() async {
    return await _apiService.testConnection();
  }

  // First time login (requires internet)
  Future<bool> firstTimeLogin(String email, String password) async {
    final request = LoginRequest(email: email.trim(), password: password);

    final response = await _apiService.login(request);

    if (response.success && response.token != null) {
      await _saveUserDataOffline(response, email);
      return true;
    } else {
      errorMessage.value = response.message ?? 'Login failed';
      return false;
    }
  }

  // Save user data for offline use
  Future<void> _saveUserDataOffline(
    LoginResponse response,
    String email,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Save token
    if (response.token != null) {
      await _secureStorage.write(key: 'auth_token', value: response.token!);
    }

    // Save user data
    if (response.user != null) {
      if (response.user!.id != null) {
        await prefs.setString('user_id', response.user!.id!);
      }
      if (response.user!.email != null) {
        await prefs.setString('user_email', response.user!.email!);
      }
      if (response.user!.fullName != null) {
        await prefs.setString('user_full_name', response.user!.fullName!);
      }
    } else {
      await prefs.setString('user_email', email);
    }

    // Do not persist raw passwords; keep only the secure token and profile data.

    // Save login time
    await prefs.setString('last_login', DateTime.now().toIso8601String());

    // Mark that user has logged in before
    await prefs.setBool('has_logged_in_before', true);
  }

  Future<bool> hasValidSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _secureStorage.read(key: 'auth_token');
    final userEmail = prefs.getString('user_email');
    return token != null &&
        token.isNotEmpty &&
        userEmail != null &&
        userEmail.isNotEmpty;
  }

  // Main login method
  Future<bool> login() async {
    if (emailController.text.trim().isEmpty) {
      errorMessage.value = 'Please enter your email';
      return false;
    }

    errorMessage.value = '';
    isLoading.value = true;
    isOfflineMode.value = false;

    try {
      final email = emailController.text.trim();
      final password = passwordController.text;

      final hasInternet = await hasInternetConnection();
      bool success = false;

      if (hasInternet) {
        if (password.isEmpty) {
          errorMessage.value = 'Please enter your password';
          return false;
        }
        success = await firstTimeLogin(email, password);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final token = await _secureStorage.read(key: 'auth_token');
        final savedEmail = prefs.getString('user_email');

        if (token != null && token.isNotEmpty && savedEmail == email) {
          final userId = prefs.getString('user_id');
          final userEmail = prefs.getString('user_email');
          final userName = prefs.getString('user_full_name');

          currentUser.value = UserData(
            id: userId,
            email: userEmail,
            fullName: userName,
          );
          isLoggedIn.value = true;
          isOfflineMode.value = true;
          success = true;
        } else {
          if (password.isEmpty) {
            errorMessage.value = 'Please enter your password';
            return false;
          }
          errorMessage.value = 'No internet. Please login online first.';
        }
      }

      if (success) {
        errorMessage.value = '';
        return true;
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_full_name');
    await prefs.remove('last_login');
    await prefs.remove('has_logged_in_before');
    await _secureStorage.delete(key: 'auth_token');

    isLoggedIn.value = false;
    currentUser.value = null;
    isOfflineMode.value = false;

    emailController.clear();
    passwordController.clear();
    errorMessage.value = '';
  }

  String getUserName() {
    return currentUser.value?.displayName ?? 'User';
  }
}
