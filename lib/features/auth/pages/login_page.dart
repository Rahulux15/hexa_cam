import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../controllers/auth_controller.dart';
import '../../../config/theme.dart';
import '../../../utils/responsive.dart';
import '../../../ui/common/hexa_toast.dart';



class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final AuthController authController = Get.find<AuthController>();

  late AnimationController _glowController;
  late List<_Particle> _particles;
  final _random = Random();

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _particles = List.generate(
      8,
          (_) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        controller: AnimationController(
          duration: Duration(milliseconds: 4000 + _random.nextInt(2000)),
          vsync: this,
        )..repeat(reverse: true),
      ),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    for (final p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final success = await authController.login();

    if (success && mounted) {
      HexaToast.show(
        context,
        'Welcome to Hexa-Cam!',
        type: HexaToastType.success,
      );
      // Navigate to folders page after successful login
      context.go('/folders');
    } else if (mounted) {
      HexaToast.show(
        context,
        authController.errorMessage.value,
        type: HexaToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final fieldFontSize = isTab ? 15.0 : 13.0;
    final btnHeight = Responsive.buttonHeight(context);
    final cardMaxWidth = Responsive.value3(
      context,
      phone: 420.0,
      tablet: 520.0,
      desktop: 560.0,
    );
    final logoSize = Responsive.isLandscape(context)
        ? (isTab ? 122.0 : 108.0)
        : (isTab ? 132.0 : 116.0);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.bgPrimary,
              AppTheme.bgSecondary,
              AppTheme.bgTertiary
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ..._particles.map((p) => AnimatedBuilder(
              animation: p.controller,
            builder: (context, _) => Positioned(
                left: MediaQuery.sizeOf(context).width * p.x,
                top: MediaQuery.sizeOf(context).height * p.y,
                child: Opacity(
                  opacity: 0.2 + p.controller.value * 0.3,
                  child: Container(
                    width: isTab ? 6 : 4,
                    height: isTab ? 6 : 4,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            )),

            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.sizeOf(context).height,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.pagePadding(context),
                      vertical: isTab ? 40 : 24,
                    ),
                    child: Center(
                      child: Container(
                        constraints: BoxConstraints(maxWidth: cardMaxWidth),
                        padding: EdgeInsets.all(isTab ? 30.0 : 22.0),
                        child: Column(
                          children: [
                            // Logo
                            Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: logoSize,
                                    height: logoSize,
                                    child: Image.asset(
                                      'assets/images/app_logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Hexa-Cam",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    "Scientific Imaging & Microscopy",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Error message
                            Obx(() => authController.errorMessage.value.isNotEmpty
                                ? Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      authController.errorMessage.value,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                                : const SizedBox.shrink()),

                            // Email field
                            _buildLabel('Email Address'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              authController.emailController,
                              'Enter your email',
                              Icons.mail_outline,
                              fontSize: fieldFontSize,
                            ),
                            SizedBox(height: isTab ? 24 : 20),

                            // Password field
                            _buildLabel('Password'),
                            const SizedBox(height: 8),
                            Obx(() => _buildTextField(
                              authController.passwordController,
                              'Enter your password',
                              Icons.lock_outline,
                              isPassword: true,
                              fontSize: fieldFontSize,
                              obscureText: !authController.isPasswordVisible.value,
                              onToggleVisibility: authController.togglePasswordVisibility,
                            )),
                            const SizedBox(height: 24),

                            // Sign In button
                            Obx(() => SizedBox(
                              width: double.infinity,
                              height: btnHeight,
                              child: ElevatedButton(
                                onPressed: authController.isLoading.value ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: Colors.transparent,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: authController.isLoading.value
                                        ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: isTab ? 16 : 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )),

                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final isTab = Responsive.isTablet(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: isTab ? 15 : 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        bool isPassword = false,
        double fontSize = 16,
        bool obscureText = false,
        VoidCallback? onToggleVisibility,
      }) {
    final isTab = Responsive.isTablet(context);
    return TextField(
      controller: controller,
      obscureText: isPassword && obscureText,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: fontSize),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: isTab ? 22 : 20),
        suffixIcon: isPassword
            ? IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscureText ? Icons.visibility_off : Icons.visibility,
            color: AppTheme.textMuted,
            size: isTab ? 22 : 20,
          ),
        )
            : null,
        filled: true,
        fillColor: AppTheme.bgTertiary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primary),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isTab ? 16 : 14,
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final AnimationController controller;
  _Particle({required this.x, required this.y, required this.controller});
}

