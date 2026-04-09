import 'package:demo_app/ui/common/save_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SaveDialog.show skips dialog when dontAskAgain is true', (tester) async {
    SharedPreferences.setMockInitialValues({
      SaveDialog.dontAskAgainKey: true,
    });

    var saveCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  await SaveDialog.show(
                    context,
                    onSave: (_, __) async {
                      saveCalls++;
                    },
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(find.byType(Dialog), findsNothing);
  });
}
