import 'package:demo_app/controllers/permission_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clearPermissionState removes startup prefs and resets counters', () async {
    SharedPreferences.setMockInitialValues({
      'startup_permissions_requested': true,
      'permission_retry_count': 4,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = PermissionController(prefs);

    await c.clearPermissionState();

    expect(prefs.containsKey('startup_permissions_requested'), isFalse);
    expect(prefs.containsKey('permission_retry_count'), isFalse);
    expect(c.isStorageGranted.value, isFalse);
  });
}
