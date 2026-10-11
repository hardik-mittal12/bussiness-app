import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';
import 'package:tally_ledger_desktop/core/database_diagnostic_service.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;
  late DatabaseDiagnosticService diagnosticService;
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('tally_stress_test_');
    sqlite3.tempDirectory = tempDir.path;

    final dbFile = File('${tempDir.path}/stress_test.sqlite');
    final executor = NativeDatabase(
      dbFile,
      setup: (rawDb) {
        rawDb.execute('PRAGMA journal_mode = WAL;');
        rawDb.execute('PRAGMA synchronous = NORMAL;');
        rawDb.execute('PRAGMA busy_timeout = 30000;');
        rawDb.execute('PRAGMA foreign_keys = ON;');
        rawDb.execute('PRAGMA wal_autocheckpoint = 1000;');
      },
    );

    db = AppDatabase(executor);
    engine = AccountingEngine(db);
    final backupService = BackupService(db);
    diagnosticService = DatabaseDiagnosticService(db, backupService);
  });

  tearDown(() async {
    await db.close();
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Deep Stability & Disk I/O Threshold Stress Tests', () {
    test('1. 100+ rapid sequential operations far exceed the ~10 operation threshold without Disk I/O error', () async {
      // 1. Create 25 customers
      final customerIds = <String>[];
      for (int i = 1; i <= 25; i++) {
        final cid = 'cust_$i';
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: cid,
          name: 'Stress Customer $i',
          groupId: 'debtors',
        ));
        customerIds.add(cid);
      }

      // 2. Create 10 inventory items
      final itemIds = <String>[];
      for (int i = 1; i <= 10; i++) {
        final itemId = 'item_$i';
        await db.into(db.stockItems).insert(StockItemsCompanion.insert(
          id: itemId,
          name: 'Stress Item $i',
          openingQuantity: const drift.Value(1000.0),
          openingRate: const drift.Value(50.0),
        ));
        itemIds.add(itemId);
      }

      // 3. Post 50 rapid sales invoices
      for (int i = 1; i <= 50; i++) {
        final cid = customerIds[i % customerIds.length];
        final itemId = itemIds[i % itemIds.length];

        await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-SEQ-$i',
          paymentMode: 'Credit',
          partyLedgerId: cid,
          date: DateTime(2025, 4, 1).add(Duration(hours: i)),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 've_dr_$i',
              voucherId: '',
              ledgerId: cid,
              debitAmount: const drift.Value(200.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 've_cr_$i',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(200.0),
            ),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(
              id: 'st_$i',
              voucherId: '',
              stockItemId: itemId,
              quantity: 2.0,
              rate: 100.0,
              transactionType: 'OUT',
            ),
          ],
        );
      }

      // 4. Post 25 receipts
      for (int i = 1; i <= 25; i++) {
        final cid = customerIds[i % customerIds.length];
        await engine.createVoucher(
          voucherType: 'Receipt',
          voucherNumber: 'RCT-SEQ-$i',
          paymentMode: 'Cash',
          partyLedgerId: cid,
          date: DateTime(2025, 4, 2).add(Duration(hours: i)),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'rct_dr_$i',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(150.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'rct_cr_$i',
              voucherId: '',
              ledgerId: cid,
              creditAmount: const drift.Value(150.0),
            ),
          ],
        );
      }

      // Total operations executed: 25 + 10 + 50 + 25 = 110 operations!
      // Invariant check must be completely healthy
      final invReport = await diagnosticService.runInvariantCheck();
      expect(invReport.isHealthy, isTrue, reason: 'Failed checks: ${invReport.failedChecks}');
      expect(invReport.failedChecks, isEmpty);

      // Verify trial balance equilibrium
      final tb = await engine.getTrialBalance();
      final totalDebit = tb.fold<double>(0.0, (sum, r) => sum + r.debitBalance);
      final totalCredit = tb.fold<double>(0.0, (sum, r) => sum + r.creditBalance);
      expect((totalDebit - totalCredit).abs(), lessThan(0.01));
    });

    test('2. 500+ rapid sequential operations execute with zero lock contention or disk errors', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'bulk_cust',
        name: 'Bulk Customer',
        groupId: 'debtors',
      ));
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'bulk_item',
        name: 'Bulk Item',
        openingQuantity: const drift.Value(10000.0),
        openingRate: const drift.Value(10.0),
      ));

      // Rapidly post 250 sales invoices
      for (int i = 1; i <= 250; i++) {
        await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'BULK-INV-$i',
          paymentMode: 'Credit',
          partyLedgerId: 'bulk_cust',
          date: DateTime(2025, 4, 1).add(Duration(minutes: i)),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'b_sale_dr_$i',
              voucherId: '',
              ledgerId: 'bulk_cust',
              debitAmount: const drift.Value(20.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'b_sale_cr_$i',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(20.0),
            ),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(
              id: 'b_st_$i',
              voucherId: '',
              stockItemId: 'bulk_item',
              quantity: 1.0,
              rate: 20.0,
              transactionType: 'OUT',
            ),
          ],
        );
      }

      // Rapidly post 250 receipt vouchers
      for (int i = 1; i <= 250; i++) {
        await engine.createVoucher(
          voucherType: 'Receipt',
          voucherNumber: 'BULK-RCT-$i',
          paymentMode: 'Cash',
          partyLedgerId: 'bulk_cust',
          date: DateTime(2025, 4, 2).add(Duration(minutes: i)),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'b_rct_dr_$i',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(20.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'b_rct_cr_$i',
              voucherId: '',
              ledgerId: 'bulk_cust',
              creditAmount: const drift.Value(20.0),
            ),
          ],
        );
      }

      // Customer balance should be completely settled: 250 * 20 - 250 * 20 = 0
      final balance = await engine.getLedgerBalance('bulk_cust');
      expect(balance.abs(), lessThan(0.01));

      final invReport = await diagnosticService.runInvariantCheck();
      expect(invReport.isHealthy, isTrue);
    });

    test('3. Concurrent read streams during aggressive writes do not cause lock violation or error', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'stream_cust',
        name: 'Stream Customer',
        groupId: 'debtors',
      ));

      int streamEmissionCount = 0;
      final sub = db.select(db.vouchers).watch().listen((vouchers) {
        streamEmissionCount++;
      });

      // Rapidly post 30 receipts while stream listener is active
      for (int i = 1; i <= 30; i++) {
        await engine.createVoucher(
          voucherType: 'Receipt',
          voucherNumber: 'STREAM-RCT-$i',
          paymentMode: 'Cash',
          partyLedgerId: 'stream_cust',
          date: DateTime(2025, 4, 1).add(Duration(minutes: i)),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 's_rct_dr_$i',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(100.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 's_rct_cr_$i',
              voucherId: '',
              ledgerId: 'stream_cust',
              creditAmount: const drift.Value(100.0),
            ),
          ],
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      expect(streamEmissionCount, greaterThan(0));
      final count = await (db.select(db.vouchers)..where((t) => t.partyLedgerId.equals('stream_cust'))).get();
      expect(count.length, equals(30));
    });

    test('4. Persistence diagnostics reports WAL, Normal sync, and healthy status', () async {
      final diag = await diagnosticService.getPersistenceDiagnostics();
      expect(diag.isHealthy, isTrue);
      expect(diag.journalMode.toLowerCase(), equals('wal'));
      expect(diag.synchronousMode, equals('NORMAL'));
      expect(diag.busyTimeout, equals(30000));
      expect(diag.isTempDirWritable, isTrue);
    });
  });
}
