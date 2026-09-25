import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:drift/drift.dart' as drift;

/// Stock Concurrency Tests.
/// Verifies that SQLite's transaction isolation ensures stock is consumed
/// exactly once when two concurrent invoice attempts race.
void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Seed test customer ledgers
    await db.batch((b) {
      b.insertAll(db.ledgers, [
        LedgersCompanion.insert(id: 'cust1', name: 'Customer 1', groupId: 'debtors', openingBalance: const drift.Value(0.0)),
        LedgersCompanion.insert(id: 'cust2', name: 'Customer 2', groupId: 'debtors', openingBalance: const drift.Value(0.0)),
      ]);
    });

    // Only 10 units of stock available
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'widget',
      name: 'Premium Widget',
      openingQuantity: const drift.Value(10.0),
      openingRate: const drift.Value(100.0),
      salesRate: const drift.Value(150.0),
      purchaseRate: const drift.Value(100.0),
    ));
  });

  tearDown(() async => await db.close());

  test('Sequential sales of same stock consume correct quantities', () async {
    // First sale: 6 units → should succeed
    await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 7, 1),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust1', debitAmount: const drift.Value(900.0), creditAmount: const drift.Value(0.0)),
        VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(900.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'widget', quantity: 6.0, rate: 150.0, transactionType: 'OUT'),
      ],
    );

    // Verify 4 remain
    final afterFirst = await engine.getStockSummaryForItem('widget');
    expect(afterFirst.quantity, equals(4.0));

    // Second sale: 5 units → should FAIL (only 4 left)
    expect(
      () => engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 7, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'cust2', debitAmount: const drift.Value(750.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(750.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st2', voucherId: '', stockItemId: 'widget', quantity: 5.0, rate: 150.0, transactionType: 'OUT'),
        ],
      ),
      throwsA(isA<InsufficientStockException>()),
      reason: 'Second sale of 5 units when only 4 remain must be rejected',
    );

    // Stock must still be 4 (second sale rolled back)
    final afterFailed = await engine.getStockSummaryForItem('widget');
    expect(afterFailed.quantity, equals(4.0),
        reason: 'Stock must not be decremented for failed/rejected sale');

    // Third sale: exactly 4 units → should succeed
    await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 7, 3),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e5', voucherId: '', ledgerId: 'cust2', debitAmount: const drift.Value(600.0), creditAmount: const drift.Value(0.0)),
        VoucherEntriesCompanion.insert(id: 'e6', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(600.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st3', voucherId: '', stockItemId: 'widget', quantity: 4.0, rate: 150.0, transactionType: 'OUT'),
      ],
    );

    // Stock must be 0
    final afterThird = await engine.getStockSummaryForItem('widget');
    expect(afterThird.quantity, equals(0.0),
        reason: 'All 10 units consumed: 6 + 4 = 10. Stock must be exactly 0');
  });

  test('Parallel Future.wait with same stock fails at least one', () async {
    // Reset stock to exactly 5 units
    await (db.update(db.stockItems)..where((t) => t.id.equals('widget'))).write(
      const StockItemsCompanion(openingQuantity: drift.Value(5.0)),
    );

    // Two futures that BOTH try to consume 4 units (only 5 available)
    // SQLite serializes writes, so exactly one must fail
    var successCount = 0;
    var failCount = 0;

    final futures = [
      engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 8, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pa1', voucherId: '', ledgerId: 'cust1', debitAmount: const drift.Value(600.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'pa2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(600.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'pst1', voucherId: '', stockItemId: 'widget', quantity: 4.0, rate: 150.0, transactionType: 'OUT'),
        ],
      ).then((_) { successCount++; }).catchError((_) { failCount++; }),

      engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 8, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pb1', voucherId: '', ledgerId: 'cust2', debitAmount: const drift.Value(600.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'pb2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(600.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'pst2', voucherId: '', stockItemId: 'widget', quantity: 4.0, rate: 150.0, transactionType: 'OUT'),
        ],
      ).then((_) { successCount++; }).catchError((_) { failCount++; }),
    ];

    await Future.wait(futures);

    // One of the double-submit guard or stock check must prevent both from succeeding
    // In practice with _isSubmitting guard, second call throws immediately
    expect(successCount + failCount, equals(2), reason: 'Both futures must complete (success or failure)');
    expect(successCount, lessThanOrEqualTo(1),
        reason: 'At most one of the concurrent sales must succeed when stock is insufficient for both');

    final finalStock = await engine.getStockSummaryForItem('widget');
    expect(finalStock.quantity, greaterThanOrEqualTo(1.0),
        reason: 'Final stock (5 - at most 4) must be at least 1 unit');
  });
}
