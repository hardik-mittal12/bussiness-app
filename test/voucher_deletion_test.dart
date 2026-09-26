import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/data/database.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Seed test-specific ledgers
    await db.batch((b) {
      b.insertAll(db.ledgers, [
        LedgersCompanion.insert(id: 'customer_del', name: 'Delete Test Customer', groupId: 'debtors', openingBalance: const drift.Value(0.0)),
        LedgersCompanion.insert(id: 'supplier_del', name: 'Delete Test Supplier', groupId: 'creditors', openingBalance: const drift.Value(0.0)),
      ]);
    });

    // Seed stock item with 100 units
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'widget_del',
      name: 'Test Widget Item',
      openingQuantity: const drift.Value(100.0),
      openingRate: const drift.Value(10.0),
      salesRate: const drift.Value(20.0),
      purchaseRate: const drift.Value(10.0),
      unitOfMeasure: const drift.Value('PCS'),
    ));
  });

  tearDown(() async => await db.close());

  group('Voucher Deletion & Reversal Tests', () {
    test('Deleting a Sales Invoice restores inventory and reverses customer balance', () async {
      // Check initial conditions
      final initialStock = await engine.getStockSummaryForItem('widget_del');
      expect(initialStock.quantity, equals(100.0));

      final initialBal = await engine.getLedgerBalance('customer_del');
      expect(initialBal, equals(0.0));

      // Post a Sales Invoice: 30 widgets @ 20.0 = 600.0
      final voucherId = await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2026, 4, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'customer_del', debitAmount: const drift.Value(600.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(600.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'widget_del', quantity: 30.0, rate: 20.0, transactionType: 'OUT'),
        ],
      );

      // Verify intermediate state after sale
      final stockAfterSale = await engine.getStockSummaryForItem('widget_del');
      expect(stockAfterSale.quantity, equals(70.0));

      final balAfterSale = await engine.getLedgerBalance('customer_del');
      expect(balAfterSale, equals(600.0)); // Customer owes 600

      // Now permanently DELETE the voucher
      await engine.deleteVoucher(voucherId);

      // Verify that voucher is completely gone
      final v = await (db.select(db.vouchers)..where((t) => t.id.equals(voucherId))).getSingleOrNull();
      expect(v, isNull);

      final entries = await (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucherId))).get();
      expect(entries, isEmpty);

      final stockTxs = await (db.select(db.stockTransactions)..where((t) => t.voucherId.equals(voucherId))).get();
      expect(stockTxs, isEmpty);

      // Verify that stock is completely RESTORED to 100.0
      final stockRestored = await engine.getStockSummaryForItem('widget_del');
      expect(stockRestored.quantity, equals(100.0));

      // Verify that customer ledger balance is completely REVERSED to 0.0
      final balRestored = await engine.getLedgerBalance('customer_del');
      expect(balRestored, equals(0.0));
    });

    test('Deleting a Receipt voucher restores customer balance', () async {
      // Setup customer with debit balance of 500
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2026, 4, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'customer_del', debitAmount: const drift.Value(500.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st2', voucherId: '', stockItemId: 'widget_del', quantity: 25.0, rate: 20.0, transactionType: 'OUT'),
        ],
      );

      var bal = await engine.getLedgerBalance('customer_del');
      expect(bal, equals(500.0));

      // Post Receipt of 300
      final receiptId = await engine.createVoucher(
        voucherType: 'Receipt',
        date: DateTime(2026, 4, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e5', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(300.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e6', voucherId: '', ledgerId: 'customer_del', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(300.0)),
        ],
      );

      bal = await engine.getLedgerBalance('customer_del');
      expect(bal, equals(200.0)); // 500 - 300 = 200

      // Delete the Receipt
      await engine.deleteVoucher(receiptId);

      // Customer balance should be restored to 500.0
      bal = await engine.getLedgerBalance('customer_del');
      expect(bal, equals(500.0));
    });

    test('Deleting a Purchase voucher restores inventory and supplier balance', () async {
      final initialStock = await engine.getStockSummaryForItem('widget_del');
      expect(initialStock.quantity, equals(100.0));

      // Post Purchase of 50 units @ 10.0 = 500.0
      final purchaseId = await engine.createVoucher(
        voucherType: 'Purchase',
        date: DateTime(2026, 4, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e7', voucherId: '', ledgerId: 'purchases', debitAmount: const drift.Value(500.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e8', voucherId: '', ledgerId: 'supplier_del', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st3', voucherId: '', stockItemId: 'widget_del', quantity: 50.0, rate: 10.0, transactionType: 'IN'),
        ],
      );

      var stock = await engine.getStockSummaryForItem('widget_del');
      expect(stock.quantity, equals(150.0));

      var supplierBal = await engine.getLedgerBalance('supplier_del');
      expect(supplierBal, equals(-500.0)); // Credit balance of 500

      // Delete Purchase
      await engine.deleteVoucher(purchaseId);

      // Verify stock returns to 100.0
      stock = await engine.getStockSummaryForItem('widget_del');
      expect(stock.quantity, equals(100.0));

      // Verify supplier balance returns to 0.0
      supplierBal = await engine.getLedgerBalance('supplier_del');
      expect(supplierBal, equals(0.0));
    });
  });
}
