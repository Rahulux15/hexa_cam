import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'config/app_pages.dart';
import 'config/theme.dart';
import 'ui/common/release_notes_dialog.dart';

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class HexaCamApp extends StatefulWidget {
  const HexaCamApp({super.key});

  @override
  State<HexaCamApp> createState() => _HexaCamAppState();
}

class _HexaCamAppState extends State<HexaCamApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>(() async {
          await Future<void>.delayed(const Duration(milliseconds: 1200));
          final ctx = Get.context;
          if (ctx != null && ctx.mounted) {
            await showReleaseNotesIfNeeded(ctx);
          }
        }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Hexa-cam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const _AppScrollBehavior(),
      initialRoute: '/',
      getPages: AppPages.routes,
    );
  }
}
