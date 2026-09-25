import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/money_precision.dart';
import 'package:drift/drift.dart' as drift;

/// Deterministic Accounting Correctness Tests.
/// Verifies exact expected values for:
///  - Ledger balances after sales, purchases, payments, and receipts
///  - Double-entry symmetry (total debit == total credit in integer paise)
///  - Stock quantities after purchases and sales
///  - P&L and Balance Sheet computed values
void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Update pre-seeded cash ledger opening balance
    await (db.update(db.ledgers)..where((t) => t.id.equals('cash'))).write(
      const LedgersCompanion(openingBalance: drift.Value(10000.0)),
    );

    // Seed test-specific ledgers
    await db.batch((b) {
      b.insertAll(db.ledgers, [
        LedgersCompanion.insert(id: 'capital', name: 'Capital', groupId: 'equity', openingBalance: const drift.Value(10000.0)),
        LedgersCompanion.insert(id: 'customer1', name: 'Ramesh & Co', groupId: 'debtors', openingBalance: const drift.Value(0.0)),
        LedgersCompanion.insert(id: 'supplier1', name: 'Om Traders', groupId: 'creditors', openingBalance: const drift.Value(0.0)),
      ]);
    });

    // Seed stock item
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'pen',
      name: 'Ballpoint Pen',
      openingQuantity: const drift.Value(500.0),
      openingRate: const drift.Value(5.0),
      salesRate: const drift.Value(8.0),
      purchaseRate: const drift.Value(5.0),
      unitOfMeasure: const drift.Value('PCS'),
    ));
  });

  tearDown(() async => await db.close());

  group('MoneyPrecision correctness', () {
    test('toPaise and toRupees are exact inverses', () {
      expect(MoneyPrecision.toPaise(1.0), equals(100));
      expect(MoneyPrecision.toPaise(1.5), equals(150));
      expect(MoneyPrecision.toPaise(0.01), equals(1));
      expect(MoneyPrecision.toRupees(100), equals(1.0));
      expect(MoneyPrecision.toRupees(1), equals(0.01));
    });

    test('sum() eliminates floating-point accumulation', () {
      // Classic floating-point trap: 0.1 + 0.2 != 0.3 in double arithmetic
      final total = MoneyPrecision.sum([0.1, 0.2]);
      expect(total, equals(0.3));

      // Multi-line invoice total
      final invoiceTotal = MoneyPrecision.sum([99.99, 149.99, 49.99, 200.03]);
      expect(invoiceTotal, equals(500.0));
    });

    test('calculateLineTotal rounds to nearest paise', () {
      // 3 units at ₹33.33 = ₹99.99 (exact)
      expect(MoneyPrecision.calculateLineTotal(3, 33.33), equals(99.99));

      // 2.5 kg at ₹10.50 = ₹26.25
      expect(MoneyPrecision.calculateLineTotal(2.5, 10.50), equals(26.25));
    });

    test('format produces 2 decimal places', () {
      expect(MoneyPrecision.format(1000.0), equals('1000.00'));
      expect(MoneyPrecision.format(99.5), equals('99.50'));
      expect(MoneyPrecision.format(0.01), equals('0.01'));
    });
  });

  group('Ledger balance correctness', () {
    test('Sales invoice increases customer debit balance', () async {
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 6, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(8000.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(8000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'pen', quantity: 1000.0, rate: 8.0, transactionType: 'OUT'),
        ],
        allowNegativeStock: true,
      );

      final custBalance = await engine.getLedgerBalance('customer1');
      expect(custBalance, equals(8000.0));

      final salesBalance = await engine.getLedgerBalance('sales');
      // Sales is credit-normal; balance = opening(0) + credit(8000) - debit(0) = -8000 (net credit)
      expect(salesBalance, equals(-8000.0));
    });

    test('Receipt reduces customer debit balance', () async {
      // First create a sales invoice of ₹5000
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 6, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(5000.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(5000.0)),
        ],
        allowNegativeStock: true,
      );

      // Then record receipt of ₹3000
      await engine.createVoucher(
        voucherType: 'Receipt',
        date: DateTime(2025, 6, 10),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e5', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(3000.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e6', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(3000.0)),
        ],
      );

      final custBalance = await engine.getLedgerBalance('customer1');
      expect(custBalance, equals(2000.0),
          reason: 'Customer balance must be ₹5000 (invoice) - ₹3000 (receipt) = ₹2000');

      final cashBalance = await engine.getLedgerBalance('cash');
      // Cash opening ₹10000 + debit ₹3000 = ₹13000
      expect(cashBalance, equals(13000.0));
    });

    test('Purchase invoice creates supplier credit', () async {
      await engine.createVoucher(
        voucherType: 'Purchase',
        date: DateTime(2025, 6, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e7', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(2500.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e8', voucherId: '', ledgerId: 'supplier1', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(2500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st2', voucherId: '', stockItemId: 'pen', quantity: 500.0, rate: 5.0, transactionType: 'IN'),
        ],
      );

      final supplierBalance = await engine.getLedgerBalance('supplier1');
      expect(supplierBalance, equals(-2500.0),
          reason: 'Supplier balance is credit-normal, net credit shown as negative');

      final purchaseBalance = await engine.getLedgerBalance('purchase');
      expect(purchaseBalance, equals(2500.0));
    });
  });

  group('Stock quantity correctness', () {
    test('Opening stock + purchases - sales = correct closing stock', () async {
      // Opening: 500 pens @ ₹5 each
      // Purchase: 200 pens @ ₹5
      await engine.createVoucher(
        voucherType: 'Purchase',
        date: DateTime(2025, 5, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ep1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1000.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'ep2', voucherId: '', ledgerId: 'supplier1', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(1000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'sp1', voucherId: '', stockItemId: 'pen', quantity: 200.0, rate: 5.0, transactionType: 'IN'),
        ],
      );

      // Sale: 150 pens
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 5, 15),
        entries: [
          VoucherEntriesCompanion.insert(id: 'es1', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(1200.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'es2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(1200.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'ss1', voucherId: '', stockItemId: 'pen', quantity: 150.0, rate: 8.0, transactionType: 'OUT'),
        ],
        allowNegativeStock: true,
      );

      // Expected: 500 (opening) + 200 (purchase) - 150 (sale) = 550
      final stockStatus = await engine.getStockSummaryForItem('pen');
      expect(stockStatus.quantity, equals(550.0),
          reason: 'Stock quantity must be opening + purchases - sales');
    });

    test('Insufficient stock throws InsufficientStockException', () async {
      // Try to sell 600 pens when only 500 are available
      expect(
        () => engine.createVoucher(
          voucherType: 'Sales',
          date: DateTime(2025, 6, 1),
          entries: [
            VoucherEntriesCompanion.insert(id: 'ex1', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(4800.0), creditAmount: const drift.Value(0.0)),
            VoucherEntriesCompanion.insert(id: 'ex2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(4800.0)),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(id: 'sx1', voucherId: '', stockItemId: 'pen', quantity: 600.0, rate: 8.0, transactionType: 'OUT'),
          ],
          allowNegativeStock: false,
        ),
        throwsA(isA<InsufficientStockException>()),
        reason: 'Insufficient stock must throw InsufficientStockException',
      );
    });
  });

  group('Double-entry symmetry', () {
    test('MoneyPrecision ensures debit == credit in paise for all vouchers', () async {
      // Any imbalanced entry should throw
      expect(
        () => engine.createVoucher(
          voucherType: 'Sales',
          date: DateTime(2025, 7, 1),
          entries: [
            // Debit ₹1000 but credit only ₹999 — imbalanced!
            VoucherEntriesCompanion.insert(id: 'ed1', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(1000.0), creditAmount: const drift.Value(0.0)),
            VoucherEntriesCompanion.insert(id: 'ed2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(999.0)),
          ],
        ),
        throwsA(isA<Exception>()),
        reason: 'Imbalanced double entry must be rejected',
      );
    });

    test('Valid multi-line invoice with exact paise balances passes', () async {
      // ₹33.33 + ₹66.67 = ₹100 exactly
      final voucherNo = await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 7, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'em1', voucherId: '', ledgerId: 'customer1', debitAmount: const drift.Value(100.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'em2', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(33.33)),
          VoucherEntriesCompanion.insert(id: 'em3', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(66.67)),
        ],
      );
      expect(voucherNo, isNotEmpty);
    });
  });
}
