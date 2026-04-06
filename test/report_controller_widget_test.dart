import 'dart:async';

import 'package:demo_app/controllers/report_controller.dart';
import 'package:demo_app/controllers/async_action_controller.dart';
import 'package:demo_app/controllers/permission_controller.dart';
import 'package:demo_app/ui/common/responsive_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('save button disables while saving', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<PermissionController>(PermissionController(prefs), permanent: true);
    final asyncController = AsyncActionController();
    Get.put<ReportController>(ReportController(), permanent: true);
    Get.put<AsyncActionController>(asyncController);
    addTearDown(Get.reset);
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ResponsiveActionButton(
                actionKey: 'report_save',
                asyncController: asyncController,
                onPressed: () async {
                  await completer.future;
                },
                child: const Text('Save'),
              ),
              ResponsiveActionButton(
                actionKey: 'report_download',
                asyncController: asyncController,
                onPressed: () async {
                  await Future<void>.value();
                },
                child: const Text('Download'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
