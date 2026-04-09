/// Result of a backup attempt (native file path or web download).
class BackupResult {
  const BackupResult({required this.ok, required this.message});

  final bool ok;
  final String message;
}
