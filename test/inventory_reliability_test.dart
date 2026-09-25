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

    // Create item & ledgers
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item_1',
      name: 'Widget A',
      openingQuantity: const drift.Value(10.0),
      openingRate: const drift.Value(50.0),
    ));

    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_1',
      name: 'Test Customer',
      groupId: 'debtors',
    ));
  });

  tearDown(() async {
    await db.close();
  });

  test('Purchase increases stock and Sale decreases stock', () async {
    final initialStatus = await engine.getStockSummaryForItem('item_1');
    expect(initialStatus.quantity, equals(10.0));

    // Create Purchase Voucher (+20 IN)
    await engine.createVoucher(
      voucherType: 'Purchase',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1000.0)),
        VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'cust_1', creditAmount: const drift.Value(1000.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'item_1', quantity: 20.0, rate: 50.0, transactionType: 'IN'),
      ],
    );

    final afterPurchase = await engine.getStockSummaryForItem('item_1');
    expect(afterPurchase.quantity, equals(30.0));

    // Create Sales Voucher (-5 OUT)
    await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'cust_1', debitAmount: const drift.Value(400.0)),
        VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(400.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st2', voucherId: '', stockItemId: 'item_1', quantity: 5.0, rate: 80.0, transactionType: 'OUT'),
      ],
    );

    final afterSale = await engine.getStockSummaryForItem('item_1');
    expect(afterSale.quantity, equals(25.0));
  });

  test('Insufficient stock throws InsufficientStockException when negative stock is disallowed', () async {
    expect(
      () => engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime.now(),
        allowNegativeStock: false,
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust_1', debitAmount: const drift.Value(2000.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(2000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'item_1', quantity: 50.0, rate: 40.0, transactionType: 'OUT'),
        ],
      ),
      throwsA(isA<InsufficientStockException>()),
    );
  });
}
