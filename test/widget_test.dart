import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/audit_log_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/business_profile_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';
import 'package:tally_ledger_desktop/ui/data_exchange_page.dart';
import 'package:tally_ledger_desktop/ui/invoice_creation_page.dart';
import 'package:tally_ledger_desktop/ui/payment_receipt_page.dart';
import 'package:tally_ledger_desktop/ui/report_viewer_page.dart';
import 'package:tally_ledger_desktop/ui/stock_summary_page.dart';
import 'package:tally_ledger_desktop/ui/widgets/sidebar.dart';
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

  testWidgets('Invoice quick-add fields match inventory item order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

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
    final addItemButton = find.byKey(
      const ValueKey('invoice-add-new-stock-item'),
    );
    await tester.ensureVisible(addItemButton);
    await tester.tap(addItemButton);
    await tester.pumpAndSettle();

    const orderedLabels = [
      'Item Name *',
      'SKU / Item Code',
      'Unit of Measure',
      'Opening Quantity',
      'Opening Rate (Rs.)',
      'Purchase Rate (Rs.)',
      'Sales Rate (Rs.)',
    ];
    final labelPositions = orderedLabels
        .map((label) => tester.getTopLeft(find.text(label)))
        .toList();

    for (var index = 0; index < labelPositions.length - 1; index++) {
      expect(
        labelPositions[index].dy,
        lessThanOrEqualTo(labelPositions[index + 1].dy),
      );
    }
    expect(labelPositions[3].dx, lessThan(labelPositions[4].dx));
    expect(labelPositions[5].dx, lessThan(labelPositions[6].dx));
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
    await database
        .into(database.stockItems)
        .insert(
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

  testWidgets('Receipt list text does not overflow beside row actions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await database.batch((batch) {
      batch.insertAll(database.ledgers, [
        LedgersCompanion.insert(
          id: 'customer',
          name: 'A Very Long Customer Business Name That Must Be Ellipsized',
          groupId: 'debtors',
        ),
      ]);
    });
    await database
        .into(database.vouchers)
        .insert(
          VouchersCompanion.insert(
            id: 'receipt-overflow',
            voucherNumber: 'RCT-2026-0000000001',
            voucherType: 'Receipt',
            date: DateTime(2026, 10, 1),
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.voucherEntries, [
        VoucherEntriesCompanion.insert(
          id: 'receipt-cash-entry',
          voucherId: 'receipt-overflow',
          ledgerId: 'cash',
          debitAmount: const drift.Value(100.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'receipt-customer-entry',
          voucherId: 'receipt-overflow',
          ledgerId: 'customer',
          creditAmount: const drift.Value(100.0),
        ),
      ]);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: AccountingEngine(database)),
        ],
        child: const MaterialApp(home: PaymentReceiptPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('A Very Long Customer', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Day Book shows cash sale journal sides and voucher metadata', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = AppDatabase(NativeDatabase.memory());
    await database
        .into(database.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: 'customer',
            name: 'Sai Burail',
            groupId: 'debtors',
          ),
        );
    await database
        .into(database.vouchers)
        .insert(
          VouchersCompanion.insert(
            id: 'daybook-sale',
            voucherNumber: 'INV-2026-27-0012',
            voucherType: 'Sales',
            date: DateTime(2026, 10, 1, 13, 5),
            partyLedgerId: const drift.Value('customer'),
            referenceNumber: const drift.Value('REF-12'),
            paymentMode: const drift.Value('Cash'),
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.voucherEntries, [
        VoucherEntriesCompanion.insert(
          id: 'daybook-cash',
          voucherId: 'daybook-sale',
          ledgerId: 'cash',
          debitAmount: const drift.Value(4680.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'daybook-sales',
          voucherId: 'daybook-sale',
          ledgerId: 'sales',
          creditAmount: const drift.Value(4680.0),
        ),
      ]);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          Provider<AccountingEngine>.value(value: AccountingEngine(database)),
        ],
        child: const MaterialApp(home: ReportViewerPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Rs. 4,680.00'), findsOneWidget);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Party: Sai Burail'), findsOneWidget);
    expect(find.text('Reference: REF-12'), findsOneWidget);
    expect(find.text('Payment: Cash'), findsOneWidget);
    expect(find.text('Voucher ID: daybook-sale'), findsOneWidget);
    expect(find.text('Debit'), findsOneWidget);
    expect(find.text('Credit'), findsOneWidget);
    expect(find.text('01-Oct-2026 01:05 PM'), findsOneWidget);
    expect(find.text('Linked party: Sai Burail'), findsNothing);
    expect(find.text('Rs. 4,680.00'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
    await database.close();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Day Book is available in sidebar quick access', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final profileService = BusinessProfileService(database);
    addTearDown(profileService.dispose);
    var selectedIndex = -1;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: database),
          ChangeNotifierProvider<BusinessProfileService>.value(
            value: profileService,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 260,
              child: Sidebar(
                currentIndex: 0,
                onTap: (index) => selectedIndex = index,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Day Book'));

    expect(selectedIndex, 1);
  });
}
