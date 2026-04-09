import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/auth_controller.dart';
import 'controllers/permission_controller.dart';
import 'state/app_registry.dart';
import 'app.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  initAppDependencies(sharedPreferences);
  if (!Get.isRegistered<AuthController>()) {
    Get.put(AuthController(), permanent: true);
  }

  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F0F23),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  runApp(const HexaCamApp());
  // Let the first frame paint (splash / route) so system permission sheets
  // are not competing with a blank screen; then ask for everything once.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>(() async {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          await Get.find<PermissionController>().runStartupPermissionFlow();
        } catch (_) {
          // Keep startup resilient in release even if OS permission API fails.
        }
      }),
    );
  });
}
