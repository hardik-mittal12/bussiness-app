import 'dart:io';
import 'platform/sqlite_verifier.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../data/database.dart';
import '../data/path_resolver.dart';
import 'audit_log_service.dart';

class BackupVerificationResult {
  final bool isSuccess;
  final String message;
  final String? integrityCheckOutput;
  final Map<String, int> tableCounts;

  BackupVerificationResult({
    required this.isSuccess,
    required this.message,
    this.integrityCheckOutput,
    this.tableCounts = const {},
  });
}

class BackupMetadataInfo {
  final String filePath;
  final String fileName;
  final DateTime createdAt;
  final int fileSizeBytes;
  final bool isVerified;

  BackupMetadataInfo({
    required this.filePath,
    required this.fileName,
    required this.createdAt,
    required this.fileSizeBytes,
    required this.isVerified,
  });
}

class BackupService {
  final AppDatabase db;
  final AuditLogService? auditLogService;

  BackupService(this.db, {this.auditLogService});

  Future<String> getBackupDirectoryPath() async {
    final activeDbPath = await getCustomDatabasePath('tally_ledger');
    final activeDir = File(activeDbPath).parent;
    final backupDir = Directory(p.join(activeDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir.path;
  }

  // 1. Perform atomic backup using VACUUM INTO with temp file staging
  Future<BackupMetadataInfo> createBackup({String? label}) async {
    final backupDirPath = await getBackupDirectoryPath();
    final now = DateTime.now();
    final timestampStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    final suffix = label != null ? '_$label' : '';

    // Ensure unique target filename
    String backupFileName = 'tally_backup_$timestampStr$suffix.sqlite';
    String backupFilePath = p.join(backupDirPath, backupFileName);
    int counter = 1;
    while (File(backupFilePath).existsSync()) {
      backupFileName = 'tally_backup_${timestampStr}_$counter$suffix.sqlite';
      backupFilePath = p.join(backupDirPath, backupFileName);
      counter++;
    }

    final tempFilePath = '$backupFilePath.tmp_${now.microsecondsSinceEpoch}';
    final escapedTempPath = tempFilePath.replaceAll("'", "''");

    try {
      // Execute atomic SQLite VACUUM INTO to temporary file
      await db.customStatement("VACUUM INTO '$escapedTempPath';");

      final tempFile = File(tempFilePath);
      if (!await tempFile.exists()) {
        throw Exception('Backup failed: Generated file does not exist at $tempFilePath');
      }

      // Verify temporary file integrity before publishing
      final verification = await verifyBackup(tempFilePath);
      if (!verification.isSuccess) {
        await tempFile.delete();
        throw Exception('Backup verification failed: ${verification.message}');
      }

      // Atomically promote temporary file to final backup destination
      await tempFile.rename(backupFilePath);
    } catch (e) {
      final tempFile = File(tempFilePath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      rethrow;
    }

    final backupFile = File(backupFilePath);
    final metadata = BackupMetadataInfo(
      filePath: backupFilePath,
      fileName: backupFileName,
      createdAt: DateTime.now(),
      fileSizeBytes: await backupFile.length(),
      isVerified: true,
    );

    // Log to Audit Trail
    if (auditLogService != null) {
      await auditLogService!.logAction(
        action: 'BACKUP',
        entityType: 'SystemDatabase',
        entityId: backupFileName,
        metadata: 'Size: ${metadata.fileSizeBytes} bytes',
      );
    }

    await _applyRetentionPolicy(backupDirPath);
    return metadata;
  }

  // 2. Verify Backup File integrity and schema directly via sqlite3
  Future<BackupVerificationResult> verifyBackup(String backupFilePath) async {
    final res = await SqliteVerifier.verifyDatabaseFile(backupFilePath);
    return BackupVerificationResult(
      isSuccess: res['isSuccess'] as bool? ?? false,
      message: res['message'] as String? ?? 'Verification completed',
      integrityCheckOutput: res['integrityCheckOutput'] as String?,
      tableCounts: (res['tableCounts'] as Map?)?.cast<String, int>() ?? const {},
    );
  }

  // 3. List all backups
  Future<List<BackupMetadataInfo>> listBackups() async {
    final backupDirPath = await getBackupDirectoryPath();
    final dir = Directory(backupDirPath);
    if (!await dir.exists()) return [];

    final files = await dir.list().where((e) => e is File && e.path.endsWith('.sqlite')).toList();
    List<BackupMetadataInfo> list = [];

    for (final f in files) {
      final file = f as File;
      final stat = await file.stat();
      final name = p.basename(file.path);
      list.add(BackupMetadataInfo(
        filePath: file.path,
        fileName: name,
        createdAt: stat.modified,
        fileSizeBytes: stat.size,
        isVerified: true,
      ));
    }

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // 4. Safe Restore Process
  Future<bool> restoreBackup(String backupFilePath) async {
    final verifyRes = await verifyBackup(backupFilePath);
    if (!verifyRes.isSuccess) {
      throw Exception('Cannot restore corrupt or invalid backup file: ${verifyRes.message}');
    }

    final activeDbPath = await getCustomDatabasePath('tally_ledger');
    final activeFile = File(activeDbPath);

    if (await activeFile.exists()) {
      final preRestoreName = 'pre_restore_${DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now())}.sqlite';
      final preRestorePath = p.join(await getBackupDirectoryPath(), preRestoreName);
      await activeFile.copy(preRestorePath);
    }

    await File(backupFilePath).copy(activeDbPath);

    final walFile = File('$activeDbPath-wal');
    final shmFile = File('$activeDbPath-shm');
    if (await walFile.exists()) await walFile.delete();
    if (await shmFile.exists()) await shmFile.delete();

    if (auditLogService != null) {
      await auditLogService!.logAction(
        action: 'RESTORE',
        entityType: 'SystemDatabase',
        entityId: p.basename(backupFilePath),
        metadata: 'Restored successfully from $backupFilePath',
      );
    }

    return true;
  }

  Future<void> _applyRetentionPolicy(String backupDirPath) async {
    try {
      final backups = await listBackups();
      if (backups.length > 50) {
        for (int i = 50; i < backups.length; i++) {
          final file = File(backups[i].filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Retention policy cleanup error: $e');
    }
  }
}
