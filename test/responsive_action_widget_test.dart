import 'package:demo_app/controllers/async_action_controller.dart';
import 'package:demo_app/ui/common/responsive_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('ResponsiveActionButton disables during async work', (tester) async {
    final controller = AsyncActionController();
    Get.put(controller);
    addTearDown(Get.reset);

    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveActionButton(
            actionKey: 'save',
            asyncController: controller,
            onPressed: () async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 20));
            },
            child: const Text('Save'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('ResponsiveIconButton shows progress and re-enables', (tester) async {
    final controller = AsyncActionController();
    Get.put(controller);
    addTearDown(Get.reset);

    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveIconButton(
            actionKey: 'download',
            asyncController: controller,
            onPressed: () async {
              calls++;
              await Future<void>.delayed(const Duration(milliseconds: 20));
            },
            icon: Icons.download_outlined,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(IconButton), warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });
}
