import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Setup master data
    await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_stress', name: 'Stress Customer', groupId: 'debtors'));
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(id: 'item_stress', name: 'Stress Stock Item', openingQuantity: const drift.Value(1000000.0), openingRate: const drift.Value(10.0)));
  });

  tearDown(() async {
    await db.close();
  });

  test('Large Dataset Performance Benchmark (1,000 to 5,000 Invoices batch stress test)', () async {
    final Stopwatch swTotal = Stopwatch()..start();

    const totalVouchersToGenerate = 1000; // Fast execution limit for automated CI test suite

    await db.transaction(() async {
      for (int i = 1; i <= totalVouchersToGenerate; i++) {
        final vId = 'v_stress_$i';
        await db.into(db.vouchers).insert(VouchersCompanion.insert(
          id: vId,
          voucherNumber: 'INV-STRESS-$i',
          voucherType: 'Sales',
          date: DateTime.now().subtract(Duration(minutes: i)),
        ));

        await db.into(db.voucherEntries).insert(VoucherEntriesCompanion.insert(
          id: 've1_$i',
          voucherId: vId,
          ledgerId: 'cust_stress',
          debitAmount: const drift.Value(100.0),
        ));

        await db.into(db.voucherEntries).insert(VoucherEntriesCompanion.insert(
          id: 've2_$i',
          voucherId: vId,
          ledgerId: 'sales',
          creditAmount: const drift.Value(100.0),
        ));

        await db.into(db.stockTransactions).insert(StockTransactionsCompanion.insert(
          id: 'st_$i',
          voucherId: vId,
          stockItemId: 'item_stress',
          quantity: 2.0,
          rate: 50.0,
          transactionType: 'OUT',
        ));
      }
    });

    final insertionTimeMs = swTotal.elapsedMilliseconds;

    // Benchmark 1: Day Book Paginated Query Speed
    final swDayBook = Stopwatch()..start();
    final dayBookPage = await engine.getDayBook(limit: 50, offset: 0);
    swDayBook.stop();
    expect(dayBookPage.length, equals(50));
    expect(swDayBook.elapsedMilliseconds, lessThan(100)); // Must execute under 100ms!

    // Benchmark 2: Ledger Balance Aggregation Speed
    final swBal = Stopwatch()..start();
    final bal = await engine.getLedgerBalance('cust_stress');
    swBal.stop();
    expect(bal, equals(totalVouchersToGenerate * 100.0));
    expect(swBal.elapsedMilliseconds, lessThan(100));

    // Benchmark 3: Trial Balance Query Speed
    final swTB = Stopwatch()..start();
    final tb = await engine.getTrialBalance();
    swTB.stop();
    expect(tb.isNotEmpty, isTrue);
    expect(swTB.elapsedMilliseconds, lessThan(150));

    print('Large Dataset Stress Test Results:');
    print('- $totalVouchersToGenerate vouchers generated in: ${insertionTimeMs}ms');
    print('- DayBook 50-row paginated fetch time: ${swDayBook.elapsedMilliseconds}ms');
    print('- Single Ledger balance SQL aggregation time: ${swBal.elapsedMilliseconds}ms');
    print('- Trial Balance SQL aggregation time: ${swTB.elapsedMilliseconds}ms');
  });
}
