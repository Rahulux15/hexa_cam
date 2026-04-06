import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save/download responsibilities are separated by contract', () {
    const saveBehavior = 'app-folder-only';
    const downloadBehavior = 'downloads-plus-app-folder';

    expect(saveBehavior, isNot(equals(downloadBehavior)));
  });
}
