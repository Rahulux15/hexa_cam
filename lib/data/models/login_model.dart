// lib/core/models/login_model.dart
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
  };
}

class LoginResponse {
  final bool success;
  final String? message;
  final String? token;
  final UserData? user;

  LoginResponse({
    required this.success,
    this.message,
    this.token,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // Your API response format:
    // {
    //   "message": "Login successful",
    //   "user": {
    //     "id": "69d15f6f60c4229b4b2691f1",
    //     "fullName": "John Doe",
    //     "email": "johndoe@example.com"
    //   },
    //   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    // }

    final String? message = json['message'];
    final String? token = json['token'];
    final Map<String, dynamic>? userData = json['user'];

    // If we have a token, login is successful
    final bool isSuccess = token != null && token.isNotEmpty;

    return LoginResponse(
      success: isSuccess,
      message: message ?? (isSuccess ? 'Login successful' : 'Login failed'),
      token: token,
      user: userData != null ? UserData.fromJson(userData) : null,
    );
  }
}

class UserData {
  final String? id;
  final String? email;
  final String? fullName;
  final String? name;

  UserData({
    this.id,
    this.email,
    this.fullName,
    this.name,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'] ?? json['full_name'],
      name: json['name'] ?? json['fullName'],
    );
  }

  // Get display name (prefer fullName, fallback to name, then email)
  String get displayName => fullName ?? name ?? email ?? 'User';
}