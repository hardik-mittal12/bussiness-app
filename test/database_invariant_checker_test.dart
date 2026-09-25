import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';

void main() {
  late AppDatabase db;
  late BackupService backupService;
  late DatabaseDiagnosticService diagnosticService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backupService = BackupService(db);
    diagnosticService = DatabaseDiagnosticService(db, backupService);
  });

  tearDown(() async {
    await db.close();
  });

  test('Automated 10-Point Database Invariant Checker returns healthy on pristine database', () async {
    final report = await diagnosticService.runInvariantCheck();
    expect(report.isHealthy, isTrue);
    expect(report.failedChecks.isEmpty, isTrue);
    expect(report.passedChecks.length, greaterThanOrEqualTo(8));
  });

  test('Invariant Checker detects orphan entries when foreign keys are bypassed', () async {
    // Disable foreign keys temporarily for corrupt injection test
    await db.customStatement('PRAGMA foreign_keys = OFF;');
    await db.customStatement("INSERT INTO voucher_entries (id, voucher_id, ledger_id, debit_amount, credit_amount) VALUES ('e_orphan', 'non_existent_v', 'cash', 100.0, 0.0);");
    await db.customStatement('PRAGMA foreign_keys = ON;');

    final report = await diagnosticService.runInvariantCheck();
    expect(report.isHealthy, isFalse);
    expect(report.failedChecks.any((f) => f.contains('Check 5 FAIL')), isTrue);
  });
}
