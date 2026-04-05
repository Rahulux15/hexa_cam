import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/auth/controllers/auth_controller.dart';
import 'data/services/file_service.dart';
import 'state/providers.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sharedPreferences = await SharedPreferences.getInstance();
  Get.put(AuthController(), permanent: true);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0F0F23),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  initAppDependencies(sharedPreferences);
  if (!kIsWeb) {
    await FileService.requestStoragePermissionsAtStartup(
      prefs: sharedPreferences,
    );
  }
  runApp(const HexaCamApp());
}
