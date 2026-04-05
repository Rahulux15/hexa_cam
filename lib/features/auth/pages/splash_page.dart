import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../../../utils/responsive.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final List<_Particle> _particles;
  final _random = Random();
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _particles = List.generate(
      10,
      (_) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        controller: AnimationController(
          duration: Duration(milliseconds: 3000 + _random.nextInt(2000)),
          vsync: this,
        )..repeat(reverse: true),
      ),
    );

    _navigateBasedOnLoginStatus();
  }

  Future<void> _navigateBasedOnLoginStatus() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    final hasLoggedInBefore =
        authController.isLoggedIn.value || await authController.hasValidSession();
    if (!mounted) return;
    context.go(hasLoggedInBefore ? '/folders' : '/login');
  }

  @override
  void dispose() {
    _scaleController.dispose();
    for (final particle in _particles) {
      particle.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTab = Responsive.isTablet(context);
    final particleSize = isTab ? 6.0 : 4.0;

    return Scaffold(
      body: Container(
        constraints: const BoxConstraints(
          minWidth: double.infinity,
          minHeight: double.infinity,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0F23), Color(0xFF1A1A2E), Color(0xFF16213E)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            ..._particles.map(
              (particle) => AnimatedBuilder(
                animation: particle.controller,
                builder: (context, _) => Positioned(
                  left: MediaQuery.sizeOf(context).width * particle.x,
                  top: MediaQuery.sizeOf(context).height * particle.y,
                  child: Opacity(
                    opacity: 0.2 + particle.controller.value * 0.4,
                    child: Container(
                      width: particleSize,
                      height: particleSize,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFA78BFA),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _scaleController,
                builder: (context, _) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final AnimationController controller;

  _Particle({
    required this.x,
    required this.y,
    required this.controller,
  });
}
