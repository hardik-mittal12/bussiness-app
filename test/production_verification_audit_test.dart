import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/customer_group_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';

void _isolateSetupWorker() {
  try {
    final dir = Directory.systemTemp;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    sqlite3.tempDirectory = dir.path;
  } catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testTempDir;

  setUp(() {
    testTempDir = Directory.systemTemp.createTempSync('audit_verification_');
    sqlite3.tempDirectory = testTempDir.path;
  });

  tearDown(() {
    try {
      testTempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Section 1 & 2: Production SQLite Background Isolate & Stability Audit', () {
    test('Background isolate NativeDatabase.createInBackground executes 150+ operations cleanly', () async {
      final dbFile = File('${testTempDir.path}/prod_bg_test.sqlite');

      // The exact executor used in production connection_native.dart
      final executor = NativeDatabase.createInBackground(
        dbFile,
        isolateSetup: _isolateSetupWorker,
        setup: (rawDb) {
          try {
            rawDb.execute('PRAGMA journal_mode = WAL;');
            rawDb.execute('PRAGMA busy_timeout = 30000;');
            rawDb.execute('PRAGMA foreign_keys = ON;');
            rawDb.execute('PRAGMA synchronous = NORMAL;');
            rawDb.execute('PRAGMA wal_autocheckpoint = 1000;');
          } catch (_) {}
        },
      );

      final db = AppDatabase(executor);
      final engine = AccountingEngine(db);
      final backup = BackupService(db);
      final diagnostic = DatabaseDiagnosticService(db, backup);

      try {
        // Create 20 customers
        for (int i = 1; i <= 20; i++) {
          await db.into(db.ledgers).insert(LedgersCompanion.insert(
            id: 'bg_cust_$i',
            name: 'BG Customer $i',
            groupId: 'debtors',
            openingBalance: const drift.Value(0.0),
          ));
        }

        // Create 10 items
        for (int i = 1; i <= 10; i++) {
          await db.into(db.stockItems).insert(StockItemsCompanion.insert(
            id: 'bg_item_$i',
            name: 'BG Item $i',
            openingQuantity: const drift.Value(5000.0),
            openingRate: const drift.Value(100.0),
          ));
        }

        // Post 70 sales invoices rapidly across isolate boundary
        for (int i = 1; i <= 70; i++) {
          final cid = 'bg_cust_${(i % 20) + 1}';
          final itemId = 'bg_item_${(i % 10) + 1}';

          await engine.createVoucher(
            voucherType: 'Sales',
            voucherNumber: 'BG-INV-$i',
            paymentMode: 'Credit',
            partyLedgerId: cid,
            date: DateTime(2025, 4, 1).add(Duration(hours: i)),
            entries: [
              VoucherEntriesCompanion.insert(
                id: 'bg_e_dr_$i',
                voucherId: '',
                ledgerId: cid,
                debitAmount: const drift.Value(250.0),
              ),
              VoucherEntriesCompanion.insert(
                id: 'bg_e_cr_$i',
                voucherId: '',
                ledgerId: 'sales',
                creditAmount: const drift.Value(250.0),
              ),
            ],
            stockTransactions: [
              StockTransactionsCompanion.insert(
                id: 'bg_st_$i',
                voucherId: '',
                stockItemId: itemId,
                quantity: 2.0,
                rate: 125.0,
                transactionType: 'OUT',
              ),
            ],
          );
        }

        // Post 60 receipt vouchers
        for (int i = 1; i <= 60; i++) {
          final cid = 'bg_cust_${(i % 20) + 1}';
          await engine.createVoucher(
            voucherType: 'Receipt',
            voucherNumber: 'BG-RCT-$i',
            paymentMode: 'Cash',
            partyLedgerId: cid,
            date: DateTime(2025, 4, 2).add(Duration(hours: i)),
            entries: [
              VoucherEntriesCompanion.insert(
                id: 'bg_rct_dr_$i',
                voucherId: '',
                ledgerId: 'cash',
                debitAmount: const drift.Value(100.0),
              ),
              VoucherEntriesCompanion.insert(
                id: 'bg_rct_cr_$i',
                voucherId: '',
                ledgerId: cid,
                creditAmount: const drift.Value(100.0),
              ),
            ],
          );
        }

        // Total operations = 20 + 10 + 70 + 60 = 160 operations!
        // Verify database health and diagnostics through background isolate
        final diag = await diagnostic.getPersistenceDiagnostics();
        expect(diag.isHealthy, isTrue);
        expect(diag.journalMode.toLowerCase(), equals('wal'));
        expect(diag.synchronousMode, equals('NORMAL'));
        expect(diag.busyTimeout, equals(30000));

        // Invariant check passes
        final inv = await diagnostic.runInvariantCheck();
        expect(inv.isHealthy, isTrue);
        expect(inv.failedChecks, isEmpty);
      } finally {
        await db.close();
      }
    });
  });

  group('Section 3: Database Durability & Corrupt File Handling Audit', () {
    test('Corrupt database file is NOT silently replaced or deleted by AppDatabase', () async {
      final corruptDbFile = File('${testTempDir.path}/corrupt_test.sqlite');
      // Write corrupted garbage bytes to simulate disk sector failure or partial write
      await corruptDbFile.writeAsBytes([0x00, 0x11, 0x22, 0x33, 0xDE, 0xAD, 0xBE, 0xEF]);

      final initialLength = await corruptDbFile.length();
      expect(initialLength, equals(8));

      // Attempt to open corrupted database
      final db = AppDatabase(NativeDatabase(corruptDbFile));

      // Querying the corrupt database MUST fail and throw an exception, NOT silently overwrite it
      expect(
        () async => await (db.select(db.ledgers)).get(),
        throwsA(anything),
      );

      // Verify the corrupt file still exists on disk with original content (not silently replaced with empty db)
      expect(await corruptDbFile.exists(), isTrue);
      expect(await corruptDbFile.length(), equals(initialLength));

      await db.close();
    });
  });

  group('Section 4 & 5: Customer Groups Opening Balances & Full Reconciliation Audit', () {
    test('Group statement accounts for member opening balances and reconciles with individual ledgers', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final engine = AccountingEngine(db);
      final groupService = CustomerGroupService(db);

      try {
        // Customer 1: seeded with an initial opening balance of Rs. 5000 (Dr)
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'cust_rec_1',
          name: 'Reconciled Customer 1',
          groupId: 'debtors',
          openingBalance: const drift.Value(5000.0),
        ));

        // Customer 2: seeded with an initial opening balance of Rs. 2000 (Dr)
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'cust_rec_2',
          name: 'Reconciled Customer 2',
          groupId: 'debtors',
          openingBalance: const drift.Value(2000.0),
        ));

        // Create Customer Group
        final group = await groupService.createGroup('Premium Distributors');
        await groupService.assignCustomerToGroup('cust_rec_1', group.id);
        await groupService.assignCustomerToGroup('cust_rec_2', group.id);

        // Transaction 1: Sale of Rs. 3000 to Customer 1 on April 1
        await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-REC-1',
          paymentMode: 'Credit',
          partyLedgerId: 'cust_rec_1',
          date: DateTime(2025, 4, 1),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'rec_e1',
              voucherId: '',
              ledgerId: 'cust_rec_1',
              debitAmount: const drift.Value(3000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'rec_e2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(3000.0),
            ),
          ],
        );

        // Transaction 2: Receipt of Rs. 1500 from Customer 1 on April 2
        await engine.createVoucher(
          voucherType: 'Receipt',
          voucherNumber: 'RCT-REC-1',
          paymentMode: 'Cash',
          partyLedgerId: 'cust_rec_1',
          date: DateTime(2025, 4, 2),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'rec_e3',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(1500.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'rec_e4',
              voucherId: '',
              ledgerId: 'cust_rec_1',
              creditAmount: const drift.Value(1500.0),
            ),
          ],
        );

        // Transaction 3: Sale of Rs. 4000 to Customer 2 on April 3
        await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-REC-2',
          paymentMode: 'Credit',
          partyLedgerId: 'cust_rec_2',
          date: DateTime(2025, 4, 3),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'rec_e5',
              voucherId: '',
              ledgerId: 'cust_rec_2',
              debitAmount: const drift.Value(4000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'rec_e6',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(4000.0),
            ),
          ],
        );

        // Compute individual ledger balances from AccountingEngine
        final bal1 = await engine.getLedgerBalance('cust_rec_1'); // 5000 + 3000 - 1500 = 6500
        final bal2 = await engine.getLedgerBalance('cust_rec_2'); // 2000 + 4000 = 6000
        expect(bal1, equals(6500.0));
        expect(bal2, equals(6000.0));
        final expectedGroupNet = bal1 + bal2; // 12500.0

        // Fetch consolidated group summary
        final summary = await groupService.getGroupTransactionsSummary(group.id);

        // Total opening balance for the group: 5000 + 2000 = 7000
        expect(summary.openingBalance, equals(7000.0));
        // Total debited during period: 3000 + 4000 = 7000
        expect(summary.totalDebit, equals(7000.0));
        // Total credited during period: 1500
        expect(summary.totalCredit, equals(1500.0));
        // Net group outstanding MUST match sum of customer balances: 7000 + 7000 - 1500 = 12500
        expect(summary.netOutstanding, equals(expectedGroupNet));

        // Test date-range filtering: from April 2 onwards
        final filteredSummary = await groupService.getGroupTransactionsSummary(
          group.id,
          fromDate: DateTime(2025, 4, 2),
        );

        // For period starting April 2:
        // Opening balance = base (7000) + April 1 sale (3000) = 10000
        expect(filteredSummary.openingBalance, equals(10000.0));
        // Transactions during period: Receipt 1500, Sale 4000
        expect(filteredSummary.totalDebit, equals(4000.0));
        expect(filteredSummary.totalCredit, equals(1500.0));
        // Net outstanding still equals 12500
        expect(filteredSummary.netOutstanding, equals(expectedGroupNet));
      } finally {
        await db.close();
      }
    });

    test('Cancelled and deleted vouchers are strictly excluded from group transactions', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final engine = AccountingEngine(db);
      final groupService = CustomerGroupService(db);

      try {
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'cust_cancel_1',
          name: 'Cancel Test Customer',
          groupId: 'debtors',
        ));

        final group = await groupService.createGroup('Audit Cancel Group');
        await groupService.assignCustomerToGroup('cust_cancel_1', group.id);

        // Post a voucher that will be cancelled
        final vId = await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-WILL-CANCEL',
          paymentMode: 'Credit',
          partyLedgerId: 'cust_cancel_1',
          date: DateTime(2025, 4, 1),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'c_e1',
              voucherId: '',
              ledgerId: 'cust_cancel_1',
              debitAmount: const drift.Value(1000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'c_e2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(1000.0),
            ),
          ],
        );

        var summary = await groupService.getGroupTransactionsSummary(group.id);
        expect(summary.rows.length, equals(1));
        expect(summary.netOutstanding, equals(1000.0));

        // Cancel the voucher
        await engine.cancelVoucher(vId);

        summary = await groupService.getGroupTransactionsSummary(group.id);
        expect(summary.rows.length, equals(0));
        expect(summary.netOutstanding, equals(0.0));

        // Customer ledger balance should also be 0
        final bal = await engine.getLedgerBalance('cust_cancel_1');
        expect(bal, equals(0.0));
      } finally {
        await db.close();
      }
    });
  });

  group('Section 6: Keyboard-First UX Invariants Audit', () {
    test('Simultaneous rapid submissions prevent duplicate voucher generation', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final engine = AccountingEngine(db);

      try {
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'cust_rapid_1',
          name: 'Rapid Customer',
          groupId: 'debtors',
        ));

        // Submit voucher 1
        final future1 = engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-RAPID-01',
          paymentMode: 'Credit',
          partyLedgerId: 'cust_rapid_1',
          date: DateTime(2025, 4, 1),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'r_e1',
              voucherId: '',
              ledgerId: 'cust_rapid_1',
              debitAmount: const drift.Value(100.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'r_e2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(100.0),
            ),
          ],
        );

        // Attempt simultaneous second submission while future1 is executing
        expect(
          () => engine.createVoucher(
            voucherType: 'Sales',
            voucherNumber: 'INV-RAPID-02',
            paymentMode: 'Credit',
            partyLedgerId: 'cust_rapid_1',
            date: DateTime(2025, 4, 1),
            entries: [
              VoucherEntriesCompanion.insert(
                id: 'r_e3',
                voucherId: '',
                ledgerId: 'cust_rapid_1',
                debitAmount: const drift.Value(100.0),
              ),
              VoucherEntriesCompanion.insert(
                id: 'r_e4',
                voucherId: '',
                ledgerId: 'sales',
                creditAmount: const drift.Value(100.0),
              ),
            ],
          ),
          throwsA(predicate((e) => e.toString().contains('already in progress'))),
        );

        await future1;

        final vouchers = await db.select(db.vouchers).get();
        expect(vouchers.length, equals(1));
        expect(vouchers.first.voucherNumber, equals('INV-RAPID-01'));
      } finally {
        await db.close();
      }
    });
  });
}
