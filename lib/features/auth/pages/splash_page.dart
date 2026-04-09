import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/responsive.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _entryOpacity;
  late final Animation<Offset> _entryOffset;
  late final List<_Particle> _particles;
  Timer? _navigationTimer;
  final _random = Random();
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _entryOpacity = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entryOffset = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _particles = List.generate(
      14,
      (_) => _Particle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        driftX: (_random.nextDouble() - 0.5) * 18,
        driftY: (_random.nextDouble() - 0.5) * 30,
        size: 2.5 + _random.nextDouble() * 4.5,
        controller: AnimationController(
          duration: Duration(milliseconds: 3000 + _random.nextInt(2000)),
          vsync: this,
        )..repeat(reverse: true),
      ),
    );

    _navigateBasedOnLoginStatus();
  }

  Future<void> _navigateBasedOnLoginStatus() async {
    _navigationTimer?.cancel();
    _navigationTimer = Timer(
      const Duration(milliseconds: 2500),
      _navigateAfterSplashDelay,
    );
  }

  Future<void> _navigateAfterSplashDelay() async {
    if (!mounted) return;
    var hasLoggedInBefore = authController.isLoggedIn.value;
    if (!hasLoggedInBefore) {
      hasLoggedInBefore = await authController.hasValidSession();
      if (!mounted) return;
    }
    Get.offAllNamed<void>(hasLoggedInBefore ? '/folders' : '/login');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _scaleController.dispose();
    _entryController.dispose();
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
                  left: (MediaQuery.sizeOf(context).width * particle.x) +
                      ((particle.controller.value - 0.5) * particle.driftX),
                  top: (MediaQuery.sizeOf(context).height * particle.y) +
                      ((particle.controller.value - 0.5) * particle.driftY),
                  child: Opacity(
                    opacity: 0.18 + particle.controller.value * 0.48,
                    child: Container(
                      width: particleSize + particle.size,
                      height: particleSize + particle.size,
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
              child: FadeTransition(
                opacity: _entryOpacity,
                child: SlideTransition(
                  position: _entryOffset,
                  child: AnimatedBuilder(
                    animation: _scaleController,
                    builder: (context, _) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 164,
                          height: 164,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8F5CFF)
                                    .withValues(alpha: 0.28 + (_scaleController.value * 0.22)),
                                blurRadius: 34,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 150,
                              height: 150,
                              child: Image.asset(
                                'assets/images/logo_quasmo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 84,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _entryOpacity,
                child: const Text(
                  'Scientific Imaging & Microscopy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
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
  final double driftX;
  final double driftY;
  final double size;
  final AnimationController controller;

  _Particle({
    required this.x,
    required this.y,
    required this.driftX,
    required this.driftY,
    required this.size,
    required this.controller,
  });
}
