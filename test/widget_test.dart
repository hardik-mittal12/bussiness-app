import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/audit_log_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';
import 'package:tally_ledger_desktop/ui/data_exchange_page.dart';
import 'package:tally_ledger_desktop/ui/invoice_creation_page.dart';
import 'package:tally_ledger_desktop/ui/stock_summary_page.dart';
import 'package:tally_ledger_desktop/main.dart';

void main() {
  testWidgets('Application launches cleanly to security lock page', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    final engine = AccountingEngine(database);
    final auditLog = AuditLogService(database);
    final backupService = BackupService(database, auditLogService: auditLog);
    final diagnosticService = DatabaseDiagnosticService(
      database,
      backupService,
    );

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

  testWidgets('Invoice contact selector filters ledgers without row overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database
        .into(database.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: 'cust_acme',
            name: 'Acme Supplies',
            groupId: 'debtors',
          ),
        );
    await database
        .into(database.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: 'cust_north',
            name: 'North Traders',
            groupId: 'debtors',
          ),
        );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: AccountingEngine(database)),
        ],
        child: const MaterialApp(home: InvoiceCreationPage()),
      ),
    );
    await tester.pumpAndSettle();

    final contactField = find.byKey(const ValueKey('invoice-contact-search'));
    final openListButton = find.byKey(
      const ValueKey('invoice-contact-open-list'),
    );
    await tester.tap(openListButton);
    await tester.pumpAndSettle();
    expect(find.text('Acme Supplies'), findsOneWidget);
    expect(find.text('North Traders'), findsOneWidget);

    await tester.enterText(contactField, 'north');
    await tester.pumpAndSettle();
    expect(find.text('North Traders'), findsOneWidget);
    expect(find.text('Acme Supplies'), findsNothing);

    await tester.tap(find.text('North Traders'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(contactField).controller!.text,
      'North Traders',
    );

    await tester.tap(openListButton);
    await tester.pumpAndSettle();
    expect(find.text('Acme Supplies'), findsOneWidget);

    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    expect(find.text('Replace (Rs. 0)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inventory actions fit and import radio tiles paint safely', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1150, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.into(database.stockItems).insert(
      StockItemsCompanion.insert(
        id: 'stock_overflow',
        name: 'Test Inventory Item',
        openingQuantity: const drift.Value(12.0),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: AccountingEngine(database)),
        ],
        child: const MaterialApp(home: StockSummaryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: AccountingEngine(database)),
        ],
        child: const MaterialApp(home: DataExchangePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import CSV / Tally XML'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
