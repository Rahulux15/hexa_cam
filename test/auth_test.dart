import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:demo_app/controllers/auth_controller.dart';
import 'package:demo_app/data/services/api_service.dart';
import 'package:demo_app/data/models/login_model.dart';

// Generate mocks
@GenerateMocks([ApiService, FlutterSecureStorage])
import 'auth_test.mocks.dart';

void main() {
  late AuthController authController;
  late MockApiService mockApiService;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.testMode = true;

    mockApiService = MockApiService();
    mockSecureStorage = MockFlutterSecureStorage();

    // Inject mocks
    Get.put<ApiService>(mockApiService);
    Get.put<FlutterSecureStorage>(mockSecureStorage);

    // Mock secure storage
    when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).thenAnswer((_) async {});
    when(mockSecureStorage.read(key: anyNamed('key'))).thenAnswer((_) async => null);
    when(mockSecureStorage.delete(key: anyNamed('key'))).thenAnswer((_) async {});

    SharedPreferences.setMockInitialValues({});
    authController = AuthController();
  });

  tearDown(() {
    Get.reset();
  });

  group('AuthController', () {
    test('valid login succeeds', () async {
      // Arrange
      const email = 'test@example.com';
      const password = 'password';
      authController.emailController.text = email;
      authController.passwordController.text = password;

      when(mockApiService.testConnection()).thenAnswer((_) async => true);
      when(mockApiService.login(any)).thenAnswer((_) async => LoginResponse(
        success: true,
        token: 'token123',
        user: UserData(id: '1', email: email, fullName: 'Test User'),
        message: 'Success',
      ));

      // Act
      final result = await authController.login();

      // Assert
      expect(result, true);
      expect(authController.isLoggedIn.value, true);
      expect(authController.currentUser.value?.email, email);
    });

    test('invalid login fails', () async {
      // Arrange
      authController.emailController.text = 'invalid@example.com';
      authController.passwordController.text = 'wrong';

      when(mockApiService.testConnection()).thenAnswer((_) async => true);
      when(mockApiService.login(any)).thenAnswer((_) async => LoginResponse(
        success: false,
        message: 'Invalid credentials',
      ));

      // Act
      final result = await authController.login();

      // Assert
      expect(result, false);
      expect(authController.errorMessage.value, 'Invalid credentials');
      expect(authController.isLoggedIn.value, false);
    });

    test('offline login with cached credentials succeeds', () async {
      // Arrange
      const email = 'test@example.com';
      SharedPreferences.setMockInitialValues({
        'user_email': email,
        'user_id': '1',
        'user_full_name': 'Test User',
      });
      when(mockApiService.testConnection()).thenAnswer((_) async => false);
      when(mockSecureStorage.read(key: 'auth_token')).thenAnswer((_) async => 'token123');

      authController = AuthController();
      authController.emailController.text = email;
      await authController.checkLoginStatus();

      // Act
      final result = await authController.login();

      // Assert
      expect(result, true);
      expect(authController.isLoggedIn.value, true);
      expect(authController.isOfflineMode.value, true);
    });

    test('auto-login on restart succeeds with valid session', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({
        'user_email': 'test@example.com',
        'user_id': '1',
        'user_full_name': 'Test User',
      });
      authController = AuthController();

      when(mockSecureStorage.read(key: 'auth_token')).thenAnswer((_) async => 'token123');

      // Act
      await authController.checkLoginStatus();

      // Assert
      expect(authController.isLoggedIn.value, true);
      expect(authController.currentUser.value?.email, 'test@example.com');
    });

    test('auto-login fails without valid session', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      authController = AuthController();

      when(mockSecureStorage.read(key: 'auth_token')).thenAnswer((_) async => null);

      // Act
      await authController.checkLoginStatus();

      // Assert
      expect(authController.isLoggedIn.value, false);
      expect(authController.currentUser.value, null);
    });
  });
}
