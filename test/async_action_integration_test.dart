import 'package:demo_app/controllers/async_action_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rapid taps execute only once for the same key', () async {
    final controller = AsyncActionController();
    var calls = 0;

    Future<void> tap() async {
      try {
        await controller.run<void>('report_save', () async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
      } catch (_) {}
    }

    await Future.wait([tap(), tap(), tap()]);
    expect(calls, 1);
  });
}
