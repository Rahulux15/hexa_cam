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

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Image), findsWidgets);
  });
}
