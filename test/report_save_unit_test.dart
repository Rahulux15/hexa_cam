import 'dart:io';
import 'dart:typed_data';

import 'package:demo_app/controllers/permission_controller.dart';
import 'package:demo_app/controllers/report_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    Get.put<PermissionController>(PermissionController(prefs), permanent: true);
    tempDir = await Directory.systemTemp.createTemp('report_save_test_');
    Get.put<ReportController>(
      ReportController(
        appDocumentsDirectory: () async => tempDir,
      ),
      permanent: true,
    );
  });

  tearDown(() async {
    Get.reset();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saveReport writes to app folder only', () async {
    final controller = Get.find<ReportController>();

    final ok = await controller.saveReport(
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'report.pdf',
      folderName: 'folder',
      showMessage: (message, color) {},
    );

    expect(ok, isTrue);
    expect(controller.isSaving.value, isFalse);
    final files = tempDir.listSync(recursive: true).whereType<File>().toList();
    expect(files, isNotEmpty);
    expect(files.first.path, contains('report.pdf'));
    expect(await files.first.readAsBytes(), [1, 2, 3]);
  });
}
