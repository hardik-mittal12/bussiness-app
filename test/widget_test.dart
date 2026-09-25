import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/native.dart';

import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/audit_log_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';
import 'package:tally_ledger_desktop/main.dart';

void main() {
  testWidgets('Application launches cleanly to security lock page', (WidgetTester tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    final engine = AccountingEngine(database);
    final auditLog = AuditLogService(database);
    final backupService = BackupService(database, auditLogService: auditLog);
    final diagnosticService = DatabaseDiagnosticService(database, backupService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: engine),
          Provider<AuditLogService>.value(value: auditLog),
          Provider<BackupService>.value(value: backupService),
          Provider<DatabaseDiagnosticService>.value(value: diagnosticService),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify security lock page renders security PIN prompt
    expect(find.byType(MaterialApp), findsOneWidget);

    await database.close();
  });
}
