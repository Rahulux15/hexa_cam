import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';

class HexaCamApp extends StatelessWidget {
  const HexaCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Hexa-cam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,

    );
  }
}
