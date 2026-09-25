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

    // Setup ledgers & stock
    await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_1', name: 'Customer 1', groupId: 'debtors'));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_1', name: 'Supplier 1', groupId: 'creditors'));
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(id: 'item_1', name: 'Item 1', openingQuantity: const drift.Value(0.0)));

    // Create Purchase: Rs 1000
    await engine.createVoucher(
      voucherType: 'Purchase',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1000.0)),
        VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'supp_1', creditAmount: const drift.Value(1000.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'item_1', quantity: 10.0, rate: 100.0, transactionType: 'IN'),
      ],
    );

    // Create Sale: Rs 1500 (5 units @ Rs 300)
    await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'cust_1', debitAmount: const drift.Value(1500.0)),
        VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1500.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'st2', voucherId: '', stockItemId: 'item_1', quantity: 5.0, rate: 300.0, transactionType: 'OUT'),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Trial Balance balances across all ledger accounts', () async {
    final tb = await engine.getTrialBalance();
    double totalDebit = 0;
    double totalCredit = 0;
    for (final row in tb) {
      totalDebit += row.debitBalance;
      totalCredit += row.creditBalance;
    }
    expect(totalDebit, equals(totalCredit));
  });

  test('P&L Report accurately calculates Gross Profit and COGS', () async {
    final pl = await engine.getProfitLossReport();
    expect(pl.salesValue, equals(1500.0));
    expect(pl.purchaseValue, equals(1000.0));
    expect(pl.closingStockValue, equals(500.0)); // 5 units @ 100 avg cost left = 500
    // COGS = 0 + 1000 + 0 - 500 = 500
    // Gross Profit = 1500 - 500 = 1000
    expect(pl.grossProfit, equals(1000.0));
    expect(pl.netProfit, equals(1000.0));
  });

  test('Day Book query supports SQL pagination', () async {
    final page1 = await engine.getDayBook(limit: 1, offset: 0);
    expect(page1.length, equals(1));
    final page2 = await engine.getDayBook(limit: 1, offset: 1);
    expect(page2.length, equals(1));
    expect(page1.first.voucherId, isNot(equals(page2.first.voucherId)));
  });
}
