import 'backup_result.dart';
export 'backup_result.dart';
import 'backup_runner_io.dart' if (dart.library.html) 'backup_runner_web.dart'
    as runner;
import 'storage_service.dart';

/// Full local backup: folder JSON + media DB (native file or web JSON) + manifest.
class BackupService {
  BackupService._();

  static Future<BackupResult> createBackup(StorageService storage) =>
      runner.runBackup(storage);
}
