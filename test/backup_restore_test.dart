import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';

void main() {
  late AppDatabase db;
  late BackupService backupService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tally_backup_test_');
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Backup verification succeeds for valid database backup file', () async {
    final validPath = p.join(tempDir.path, 'valid_backup.sqlite');
    await db.customStatement("VACUUM INTO '$validPath';");

    final result = await backupService.verifyBackup(validPath);
    expect(result.isSuccess, isTrue);
    expect(result.integrityCheckOutput?.toLowerCase(), equals('ok'));
    expect(result.tableCounts.containsKey('vouchers'), isTrue);
  });

  test('Backup verification fails for corrupt file', () async {
    final corruptPath = p.join(tempDir.path, 'corrupt_backup.sqlite');
    final corruptFile = File(corruptPath);
    await corruptFile.writeAsString('THIS IS NOT A VALID SQLITE DATABASE FILE');

    final result = await backupService.verifyBackup(corruptPath);
    expect(result.isSuccess, isFalse);
  });

  test('Restore process rejects corrupt file', () async {
    final corruptPath = p.join(tempDir.path, 'corrupt_restore.sqlite');
    await File(corruptPath).writeAsString('GARBAGE');

    expect(
      () => backupService.restoreBackup(corruptPath),
      throwsException,
    );
  });
}
