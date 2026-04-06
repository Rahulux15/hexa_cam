import 'dart:io';
import 'dart:typed_data';

import 'package:demo_app/data/services/file_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String norm(String path) => path.replaceAll('\\', '/');

  test('builds Android public downloads path', () {
    final path = FileService.buildPublicDownloadPath(
      filename: 'report-test.pdf',
      downloadsRoot: '/storage/emulated/0/Download',
    );

    expect(norm(path), '/storage/emulated/0/Download/report-test.pdf');
    expect(norm(path), contains('Download'));
  });

  test('builds Android fallback downloads path', () {
    final path = FileService.buildFallbackDownloadPath(
      filename: 'report-test.pdf',
      downloadsRoot: '/storage/emulated/0/MyAppDownloads',
    );

    expect(norm(path), '/storage/emulated/0/MyAppDownloads/report-test.pdf');
    expect(norm(path), contains('MyAppDownloads'));
  });

  test('builds iOS public downloads path', () {
    final path = FileService.buildPublicDownloadPath(
      filename: 'report-test.pdf',
      downloadsRoot: '/Documents/Downloads',
    );

    expect(norm(path), '/Documents/Downloads/report-test.pdf');
    expect(norm(path), contains('Downloads'));
  });

  test('builds iOS fallback downloads path', () {
    final path = FileService.buildFallbackDownloadPath(
      filename: 'report-test.pdf',
      downloadsRoot: '/Documents/MyAppDownloads',
    );

    expect(norm(path), '/Documents/MyAppDownloads/report-test.pdf');
    expect(norm(path), contains('MyAppDownloads'));
  });

  test('saves bytes and preserves content on disk', () async {
    final tempRoot = await Directory.systemTemp.createTemp('downloads_test_');
    addTearDown(() async {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    });

    final path = FileService.buildPublicDownloadPath(
      filename: 'report-test.pdf',
      downloadsRoot: tempRoot.path,
    );
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(Uint8List.fromList([1, 2, 3]), flush: true);

    expect(file.existsSync(), isTrue);
    expect(await FileService.readBytes(path), [1, 2, 3]);
    expect(norm(path), contains(norm(tempRoot.path)));
  });

  test('sanitizes invalid filename characters in public download path', () {
    final path = FileService.buildPublicDownloadPath(
      filename: 'report:test/?.pdf',
      downloadsRoot: '/storage/emulated/0/Download',
    );

    expect(norm(path), isNot(contains(':')));
    expect(norm(path), isNot(contains('/?')));
    expect(norm(path), endsWith('report-test.pdf'));
    expect(norm(path), contains('Download'));
  }
  );
}
