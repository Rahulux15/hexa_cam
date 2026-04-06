import 'package:demo_app/controllers/async_action_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('run prevents re-entry and clears running state', () async {
    final controller = AsyncActionController();
    var calls = 0;

    final first = controller.run<int>('save', () async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 1;
    });

    expect(controller.isRunning('save'), isTrue);

    final second = controller.run<int>('save', () async {
      calls++;
      return 2;
    });

    await expectLater(second, throwsStateError);
    final result = await first;

    expect(result, 1);
    expect(calls, 1);
    expect(controller.isRunning('save'), isFalse);
  });

  test('run recovers after exception', () async {
    final controller = AsyncActionController();

    await expectLater(
      controller.run<void>(
        'download',
        () async {
          throw Exception('fail');
        },
        logErrors: false,
      ),
      throwsException,
    );

    expect(controller.isRunning('download'), isFalse);
  });
}
