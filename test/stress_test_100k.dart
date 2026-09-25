import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/financial_year_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';

/// 100,000 INVOICE / 500,000+ LINE ITEM STRESS TEST HARNESS
///
/// Execution:
///   flutter test test/stress_test_100k.dart --timeout=15m
///
/// Can override count via environment variable:
///   STRESS_INVOICES=50000 flutter test test/stress_test_100k.dart
void main() {
  test('100,000 Invoices & 500,000+ Entries Scalability & Latency Benchmark', () async {
    final int invoiceCount = int.tryParse(Platform.environment['STRESS_INVOICES'] ?? '') ?? 100000;
    print('\n===============================================================');
    print('  100,000-INVOICE PRODUCTION STRESS & SCALABILITY HARNESS');
    print('  Target Invoices: $invoiceCount');
    print('===============================================================');

    final tempDir = await Directory.systemTemp.createTemp('tally_stress_100k_');
    final dbFile = File('${tempDir.path}/stress_test.db');

    final db = AppDatabase(NativeDatabase(dbFile));
    final engine = AccountingEngine(db);

    // Track baseline memory
    final int initialRss = ProcessInfo.currentRss;

    // 1. Seed Master Data (10 Customers, 5 Suppliers, 20 Stock Items)
    final numCustomers = 10;
    final numItems = 20;

    await db.batch((batch) {
      for (int i = 1; i <= numCustomers; i++) {
        batch.insert(
          db.ledgers,
          LedgersCompanion.insert(
            id: 'cust_$i',
            name: 'Customer $i Enterprises',
            groupId: 'debtors',
            openingBalance: const drift.Value(0.0),
          ),
        );
      }

      for (int i = 1; i <= numItems; i++) {
        batch.insert(
          db.stockItems,
          StockItemsCompanion.insert(
            id: 'item_$i',
            name: 'Stock Product SKU-$i',
            openingQuantity: const drift.Value(10000000.0),
            openingRate: drift.Value(50.0 + i),
            salesRate: drift.Value(100.0 + i * 2),
            purchaseRate: drift.Value(50.0 + i),
            unitOfMeasure: const drift.Value('PCS'),
          ),
        );
      }
    });

    print('✓ Master catalog seeded: $numCustomers customers, $numItems stock products.');

    // 2. Bulk Ingestion: Generate $invoiceCount invoices in chunks of 5,000
    final chunkSize = 5000;
    final totalBatches = (invoiceCount / chunkSize).ceil();
    final swIngest = Stopwatch()..start();

    int totalLineItems = 0;
    int totalEntries = 0;

    final startDate = DateTime(2025, 4, 1);

    for (int batchIdx = 0; batchIdx < totalBatches; batchIdx++) {
      final batchStart = batchIdx * chunkSize + 1;
      final batchEnd = math.min((batchIdx + 1) * chunkSize, invoiceCount);

      await db.batch((batch) {
        for (int i = batchStart; i <= batchEnd; i++) {
          final custId = 'cust_${((i - 1) % numCustomers) + 1}';
          final voucherId = 'v_$i';
          final voucherDate = startDate.add(Duration(minutes: i * 3));
          final fy = FinancialYearService.getFinancialYear(voucherDate);
          final voucherNo = 'INV-$fy-${i.toString().padLeft(6, '0')}';

          // 1 Sales voucher
          batch.insert(
            db.vouchers,
            VouchersCompanion.insert(
              id: voucherId,
              voucherNumber: voucherNo,
              voucherType: 'Sales',
              financialYear: drift.Value(fy),
              date: voucherDate,
              narration: drift.Value('Bulk stress test invoice #$i'),
              status: const drift.Value('POSTED'),
            ),
          );

          // 3 Line Items per invoice = 3 stock transactions
          double invoiceTotal = 0.0;
          for (int itemIdx = 1; itemIdx <= 3; itemIdx++) {
            final itemId = 'item_${((i + itemIdx) % numItems) + 1}';
            final qty = 2.0;
            final rate = 100.0 + itemIdx * 10;
            final lineTotal = qty * rate;
            invoiceTotal += lineTotal;

            batch.insert(
              db.stockTransactions,
              StockTransactionsCompanion.insert(
                id: 'st_${i}_$itemIdx',
                voucherId: voucherId,
                stockItemId: itemId,
                quantity: qty,
                rate: rate,
                transactionType: 'OUT',
              ),
            );
            totalLineItems++;
          }

          // 2 Voucher Entries (Debit customer, Credit sales)
          batch.insert(
            db.voucherEntries,
            VoucherEntriesCompanion.insert(
              id: 've_${i}_dr',
              voucherId: voucherId,
              ledgerId: custId,
              debitAmount: drift.Value(invoiceTotal),
              creditAmount: const drift.Value(0.0),
            ),
          );

          batch.insert(
            db.voucherEntries,
            VoucherEntriesCompanion.insert(
              id: 've_${i}_cr',
              voucherId: voucherId,
              ledgerId: 'sales',
              debitAmount: const drift.Value(0.0),
              creditAmount: drift.Value(invoiceTotal),
            ),
          );
          totalEntries += 2;
        }
      });

      if ((batchIdx + 1) % 4 == 0 || (batchIdx + 1) == totalBatches) {
        final progress = (batchEnd / invoiceCount * 100).toStringAsFixed(1);
        final elapsedSec = (swIngest.elapsedMilliseconds / 1000).toStringAsFixed(1);
        print('  -> Ingested $batchEnd / $invoiceCount invoices ($progress%) in ${elapsedSec}s...');
      }
    }

    swIngest.stop();
    final double ingestSec = swIngest.elapsedMilliseconds / 1000.0;
    final double throughput = invoiceCount / (ingestSec > 0 ? ingestSec : 1.0);

    final dbSizeBytes = await dbFile.length();
    final walFile = File('${dbFile.path}-wal');
    final walSizeBytes = walFile.existsSync() ? await walFile.length() : 0;
    final int postIngestRss = ProcessInfo.currentRss;

    print('\n===============================================================');
    print('  BULK INGESTION METRICS');
    print('===============================================================');
    print('• Invoices Inserted:       $invoiceCount');
    print('• Line Items Inserted:     $totalLineItems');
    print('• Voucher Entries:         $totalEntries');
    print('• Ingestion Duration:      ${ingestSec.toStringAsFixed(2)} seconds');
    print('• Bulk Throughput:         ${throughput.toStringAsFixed(1)} invoices/sec');
    print('• DB File Size:            ${(dbSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    print('• WAL File Size:           ${(walSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    print('• RSS Memory Delta:        ${((postIngestRss - initialRss) / (1024 * 1024)).toStringAsFixed(2)} MB');

    // 3. Query Performance & Latency Benchmarks (P50, P95, P99)
    print('\n===============================================================');
    print('  QUERY LATENCY BENCHMARKS (P50, P95, P99)');
    print('===============================================================');

    // Benchmark A: Single Invoice Point Lookup by Indexed Voucher Number
    final List<int> pointLookupTimes = [];
    final testLookupIds = [1, 500, 25000, 50000, 75000, 99999];
    for (final id in testLookupIds) {
      if (id <= invoiceCount) {
        final sw = Stopwatch()..start();
        final res = await (db.select(db.vouchers)..where((t) => t.id.equals('v_$id'))).getSingleOrNull();
        sw.stop();
        expect(res, isNotNull);
        pointLookupTimes.add(sw.elapsedMicroseconds);
      }
    }
    pointLookupTimes.sort();
    final p50Lookup = pointLookupTimes[pointLookupTimes.length ~/ 2] / 1000.0;
    final p95Lookup = pointLookupTimes[(pointLookupTimes.length * 0.95).floor()] / 1000.0;
    print('• Point Lookup by PK/Indexed ID:  P50: ${p50Lookup.toStringAsFixed(2)}ms | P95: ${p95Lookup.toStringAsFixed(2)}ms');
    expect(p50Lookup, lessThan(20.0), reason: 'Indexed point lookup must be under 20ms');

    // Benchmark B: Day Book Paginated Query (50 items across different offsets)
    final List<int> dayBookTimes = [];
    final testOffsets = [0, 1000, 10000, 25000, 50000];
    for (final off in testOffsets) {
      if (off < invoiceCount) {
        final sw = Stopwatch()..start();
        final rows = await engine.getDayBook(limit: 50, offset: off);
        sw.stop();
        expect(rows.length, equals(50));
        dayBookTimes.add(sw.elapsedMicroseconds);
      }
    }
    dayBookTimes.sort();
    final p50DayBook = dayBookTimes[dayBookTimes.length ~/ 2] / 1000.0;
    final p95DayBook = dayBookTimes[(dayBookTimes.length * 0.95).floor()] / 1000.0;
    print('• Day Book (50 rows paginated):    P50: ${p50DayBook.toStringAsFixed(2)}ms | P95: ${p95DayBook.toStringAsFixed(2)}ms');
    expect(p50DayBook, lessThan(50.0), reason: 'Paginated Day Book query must be under 50ms');

    // Benchmark C: Ledger Balance SQL Aggregation (over ~10,000+ entries per customer)
    final swLedger = Stopwatch()..start();
    final cust1Balance = await engine.getLedgerBalance('cust_1');
    swLedger.stop();
    final ledgerLatencyMs = swLedger.elapsedMicroseconds / 1000.0;
    print('• Ledger Balance Aggregation:     ${ledgerLatencyMs.toStringAsFixed(2)}ms (Balance: ₹${cust1Balance.toStringAsFixed(2)})');
    expect(cust1Balance, greaterThan(0.0));
    expect(ledgerLatencyMs, lessThan(100.0), reason: 'SQL aggregation for customer ledger must be under 100ms');

    // Benchmark D: Trial Balance SQL Aggregation across entire ledger system
    final swTB = Stopwatch()..start();
    final trialBalance = await engine.getTrialBalance();
    swTB.stop();
    final tbLatencyMs = swTB.elapsedMicroseconds / 1000.0;
    print('• Trial Balance Full Aggregation: ${tbLatencyMs.toStringAsFixed(2)}ms (${trialBalance.length} active ledgers)');
    expect(trialBalance.isNotEmpty, isTrue);
    expect(tbLatencyMs, lessThan(150.0), reason: 'Trial Balance must aggregate in under 150ms');

    // Benchmark E: Atomic Backup Creation Time
    print('\n===============================================================');
    print('  BACKUP & RECOVERY UNDER 100K VOLUME');
    print('===============================================================');
    final backupService = BackupService(db);
    final swBackup = Stopwatch()..start();
    final backupResult = await backupService.createBackup();
    swBackup.stop();
    final backupSec = swBackup.elapsedMilliseconds / 1000.0;

    expect(File(backupResult.filePath).existsSync(), isTrue);
    print('• Backup Creation Time:           ${backupSec.toStringAsFixed(2)}s');
    print('• Backup File Size:               ${((backupResult.fileSizeBytes) / (1024 * 1024)).toStringAsFixed(2)} MB');

    // Verify Backup Integrity with PRAGMA integrity_check
    final swVerify = Stopwatch()..start();
    final verifyResult = await backupService.verifyBackup(backupResult.filePath);
    swVerify.stop();
    expect(verifyResult.isSuccess, isTrue);
    print('• Backup Integrity Verification:  ${swVerify.elapsedMilliseconds}ms (${verifyResult.message})');

    print('\n===============================================================');
    print('  ✓ 100,000-INVOICE STRESS TEST COMPLETED SUCCESSFULLY');
    print('===============================================================\n');

    await db.close();
    await tempDir.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
