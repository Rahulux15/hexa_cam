import 'package:demo_app/app.dart';
import 'package:demo_app/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('app boots into splash screen', (WidgetTester tester) async {
    Get.put<AuthController>(AuthController(), permanent: true);
    addTearDown(Get.reset);

    await tester.pumpWidget(const HexaCamApp());
    await tester.pump();
    // [HexaCamApp] schedules release-notes check after ~1.2s; drain timers.
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
