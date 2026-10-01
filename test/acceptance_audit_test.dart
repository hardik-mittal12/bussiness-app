import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/data_exchange_service.dart';

void main() {
  group('1. Cash Invoice Reconciliation Audit', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Seed customer
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_rajesh',
        name: 'Rajesh Kumar',
        groupId: 'debtors',
        phone: const drift.Value('9811122233'),
      ));

      // Seed item
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_laptop',
        name: 'Dell Laptop 15',
        openingQuantity: const drift.Value(10.0),
        openingRate: const drift.Value(40000.0),
      ));
    });

    tearDown(() => db.close());

    test('Named Cash Customer: Complete reconciliation', () async {
      final preBalCust = await engine.getLedgerBalance('cust_rajesh');
      final preBalCash = await engine.getLedgerBalance('cash');
      final preBalSales = await engine.getLedgerBalance('sales');

      expect(preBalCust, equals(0.0));
      expect(preBalCash, equals(0.0));
      expect(preBalSales, equals(0.0));

      // Create named cash invoice of Rs. 50,000 (1 laptop)
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-CASH-001',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_rajesh',
        date: DateTime.now(),
        narration: 'Cash sale of Dell Laptop to Rajesh',
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e1',
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(50000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(50000.0),
          ),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st1',
            voucherId: '',
            stockItemId: 'item_laptop',
            quantity: 1.0,
            rate: 50000.0,
            transactionType: 'OUT',
          ),
        ],
      );

      // 1. Sale appears in Day Book exactly once
      final dayBook = await engine.getDayBook();
      final dayBookMatches = dayBook.where((r) => r.voucherNumber == vNo).toList();
      expect(dayBookMatches.length, equals(1), reason: 'Sale must appear in Day Book exactly once');
      expect(dayBookMatches.first.partyName, equals('Rajesh Kumar'), reason: 'Day Book must show customer party name');
      expect(dayBookMatches.first.totalAmount, equals(50000.0));
      expect(dayBookMatches.first.paymentMode, equals('Cash'));

      // 2. Sale appears in customer statement with CASH (PAID)
      final statement = await engine.getLedgerStatement('cust_rajesh');
      expect(statement.length, equals(1));
      expect(statement.first.voucherNumber, equals(vNo));
      expect(statement.first.paymentMode, equals('Cash'));
      expect(statement.first.runningBalance, equals(0.0), reason: 'Cash sale must NOT leave customer in debt');

      // 3. Customer balance remains zero
      final postBalCust = await engine.getLedgerBalance('cust_rajesh');
      expect(postBalCust, equals(0.0), reason: 'Customer balance must not increase');

      // 4. Cash balance increases by 50,000
      final postBalCash = await engine.getLedgerBalance('cash');
      expect(postBalCash, equals(50000.0));

      // 5. Sales balance credit increases by 50,000
      final postBalSales = await engine.getLedgerBalance('sales');
      expect(postBalSales, equals(-50000.0)); // credit balance is negative in net Dr-Cr

      // 6. Cash Book shows Rajesh Kumar with Cash In of 50,000
      final cashTxs = await engine.getCashTransactions();
      final cashMatch = cashTxs.firstWhere((r) => r.voucherNo == vNo);
      expect(cashMatch.partyName, equals('Rajesh Kumar'));
      expect(cashMatch.isCashIn, isTrue);
      expect(cashMatch.amount, equals(50000.0));
      expect(cashMatch.runningBalance, equals(50000.0));

      // 7. Trial balance remains balanced
      final tb = await engine.getTrialBalance();
      final totalDr = tb.fold(0.0, (s, r) => s + r.debitBalance);
      final totalCr = tb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(totalDr, equals(totalCr), reason: 'Trial balance must be exactly balanced');
      expect(totalDr, equals(50000.0));

      // 8. No synthetic debit=credit rows exist
      final allEntries = await db.select(db.voucherEntries).get();
      expect(allEntries.length, equals(2));
      expect(allEntries.any((e) => e.debitAmount == e.creditAmount && e.debitAmount > 0), isFalse,
          reason: 'No fake balancing entries allowed');
    });

    test('Generic / Walk-in Cash Customer: Complete reconciliation', () async {
      // Create anonymous cash invoice of Rs. 15,000 (no partyLedgerId)
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-WALKIN-001',
        paymentMode: 'Cash',
        partyLedgerId: null, // anonymous walk-in
        date: DateTime.now(),
        narration: 'Counter cash sale to walk-in customer',
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'w1',
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(15000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'w2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(15000.0),
          ),
        ],
      );

      final dayBook = await engine.getDayBook();
      final match = dayBook.firstWhere((r) => r.voucherNumber == vNo);
      expect(match.totalAmount, equals(15000.0));

      final cashTxs = await engine.getCashTransactions();
      final cashMatch = cashTxs.firstWhere((r) => r.voucherNo == vNo);
      expect(cashMatch.partyName, equals('Cash Counter / Walk-in'));
      expect(cashMatch.amount, equals(15000.0));
      expect(cashMatch.isCashIn, isTrue);

      final tb = await engine.getTrialBalance();
      final totalDr = tb.fold(0.0, (s, r) => s + r.debitBalance);
      final totalCr = tb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(totalDr, equals(totalCr));
    });
  });

  group('2. Bill Deletion & Cancellation Lifecycle Reversal Audit', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Seed items
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_a',
        name: 'Item Alpha',
        openingQuantity: const drift.Value(100.0),
        openingRate: const drift.Value(10.0),
      ));
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_b',
        name: 'Item Beta',
        openingQuantity: const drift.Value(50.0),
        openingRate: const drift.Value(20.0),
      ));

      // Seed customer & supplier
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_sharma',
        name: 'Sharma Bros',
        groupId: 'debtors',
      ));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'supp_gupta',
        name: 'Gupta Traders',
        groupId: 'creditors',
      ));
    });

    tearDown(() => db.close());

    test('Multi-item Credit Sale deletion: full state reversal', () async {
      // 1. Record BEFORE state
      final preStockA = (await engine.getStockSummaryForItem('item_a')).quantity;
      final preStockB = (await engine.getStockSummaryForItem('item_b')).quantity;
      final preCustBal = await engine.getLedgerBalance('cust_sharma');
      final preSalesBal = await engine.getLedgerBalance('sales');
      final preProfit = (await engine.getProfitLossReport()).netProfit;

      expect(preStockA, equals(100.0));
      expect(preStockB, equals(50.0));
      expect(preCustBal, equals(0.0));
      expect(preSalesBal, equals(0.0));

      // 2. Create multi-item credit invoice: 10 of item_a @ 15 = 150, 5 of item_b @ 30 = 150. Total = 300
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-REV-01',
        paymentMode: 'Debt',
        partyLedgerId: 'cust_sharma',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e1',
            voucherId: '',
            ledgerId: 'cust_sharma',
            debitAmount: const drift.Value(300.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(300.0),
          ),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st1',
            voucherId: '',
            stockItemId: 'item_a',
            quantity: 10.0,
            rate: 15.0,
            transactionType: 'OUT',
          ),
          StockTransactionsCompanion.insert(
            id: 'st2',
            voucherId: '',
            stockItemId: 'item_b',
            quantity: 5.0,
            rate: 30.0,
            transactionType: 'OUT',
          ),
        ],
      );

      // Verify AFTER values
      expect((await engine.getStockSummaryForItem('item_a')).quantity, equals(90.0));
      expect((await engine.getStockSummaryForItem('item_b')).quantity, equals(45.0));
      expect(await engine.getLedgerBalance('cust_sharma'), equals(300.0));
      expect(await engine.getLedgerBalance('sales'), equals(-300.0));

      // 3. Delete the voucher
      await engine.deleteVoucher(vNo);

      // 4. Verify REVERSED state matches BEFORE exactly
      expect((await engine.getStockSummaryForItem('item_a')).quantity, equals(preStockA));
      expect((await engine.getStockSummaryForItem('item_b')).quantity, equals(preStockB));
      expect(await engine.getLedgerBalance('cust_sharma'), equals(preCustBal));
      expect(await engine.getLedgerBalance('sales'), equals(preSalesBal));
      expect((await engine.getProfitLossReport()).netProfit, equals(preProfit));

      // No orphan entries
      final remainingEntries = await (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(vNo))).get();
      expect(remainingEntries.isEmpty, isTrue);
      final remainingStockTx = await (db.select(db.stockTransactions)..where((t) => t.voucherId.equals(vNo))).get();
      expect(remainingStockTx.isEmpty, isTrue);
      final dayBook = await engine.getDayBook();
      expect(dayBook.any((r) => r.voucherNumber == vNo), isFalse);
    });

    test('Purchase deletion: full stock and creditor balance reversal', () async {
      final preStockA = (await engine.getStockSummaryForItem('item_a')).quantity;
      final preSuppBal = await engine.getLedgerBalance('supp_gupta');

      // Purchase 20 units of item_a @ 12 = 240
      final vNo = await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-REV-01',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_gupta',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pe1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(240.0)),
          VoucherEntriesCompanion.insert(id: 'pe2', voucherId: '', ledgerId: 'supp_gupta', creditAmount: const drift.Value(240.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'pst1',
            voucherId: '',
            stockItemId: 'item_a',
            quantity: 20.0,
            rate: 12.0,
            transactionType: 'IN',
          ),
        ],
      );

      expect((await engine.getStockSummaryForItem('item_a')).quantity, equals(120.0));
      expect(await engine.getLedgerBalance('supp_gupta'), equals(-240.0)); // credit balance

      // Delete the purchase
      await engine.deleteVoucher(vNo);

      expect((await engine.getStockSummaryForItem('item_a')).quantity, equals(preStockA));
      expect(await engine.getLedgerBalance('supp_gupta'), equals(preSuppBal));
    });

    test('Receipt and Payment deletion: cash and party balances restored', () async {
      // Create Receipt: cust_sharma pays 500
      final rNo = await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'REC-REV-01',
        partyLedgerId: 'cust_sharma',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 're1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(500.0)),
          VoucherEntriesCompanion.insert(id: 're2', voucherId: '', ledgerId: 'cust_sharma', creditAmount: const drift.Value(500.0)),
        ],
      );

      expect(await engine.getLedgerBalance('cash'), equals(500.0));
      expect(await engine.getLedgerBalance('cust_sharma'), equals(-500.0));

      await engine.deleteVoucher(rNo);

      expect(await engine.getLedgerBalance('cash'), equals(0.0));
      expect(await engine.getLedgerBalance('cust_sharma'), equals(0.0));
    });
  });

  group('3. Audit Log Validation', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);
    });

    tearDown(() => db.close());

    test('Deletion writes indelible AuditLog without polluting financial reports', () async {
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-AUDIT-01',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ae1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(100.0)),
          VoucherEntriesCompanion.insert(id: 'ae2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(100.0)),
        ],
      );

      await engine.deleteVoucher(vNo);

      final logs = await db.select(db.auditLogs).get();
      expect(logs.isNotEmpty, isTrue);

      final log = logs.firstWhere((l) => l.action == 'DELETE');
      expect(log.entityType, equals('Voucher'));
      expect(log.oldValue, contains('INV-AUDIT-01'));
      expect(log.userDevice, isNotEmpty);
      expect(log.timestamp, isNotNull);

      // Audit logs do NOT affect Day Book
      final dayBook = await engine.getDayBook();
      expect(dayBook.isEmpty, isTrue);

      // Audit logs do NOT affect Trial Balance
      final tb = await engine.getTrialBalance();
      expect(tb.isEmpty, isTrue);

      // Audit logs do NOT affect Profit & Loss
      final pl = await engine.getProfitLossReport();
      expect(pl.salesValue, equals(0.0));
      expect(pl.netProfit, equals(0.0));
    });
  });

  group('4. Negative Stock Progression & Valuation Audit', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Opening stock = 5 units @ 100 = 500
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_gear',
        name: 'Industrial Gear',
        openingQuantity: const drift.Value(5.0),
        openingRate: const drift.Value(100.0),
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_vikram',
        name: 'Vikram Singh',
        groupId: 'debtors',
      ));
    });

    tearDown(() => db.close());

    test('Progression: 5 -> sell 8 (-3) -> purchase 10 (7) with costing verification', () async {
      // Step 1: Verify Initial
      var stock = await engine.getStockSummaryForItem('item_gear');
      expect(stock.quantity, equals(5.0));
      expect(stock.averageRate, equals(100.0));
      expect(stock.totalValue, equals(500.0));

      // Step 2: Sell 8 units @ 150 each = 1200 (allowNegativeStock: true)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-NEG-01',
        paymentMode: 'Debt',
        partyLedgerId: 'cust_vikram',
        date: DateTime.now(),
        allowNegativeStock: true,
        entries: [
          VoucherEntriesCompanion.insert(id: 'ne1', voucherId: '', ledgerId: 'cust_vikram', debitAmount: const drift.Value(1200.0)),
          VoucherEntriesCompanion.insert(id: 'ne2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1200.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'nst1',
            voucherId: '',
            stockItemId: 'item_gear',
            quantity: 8.0,
            rate: 150.0,
            transactionType: 'OUT',
          ),
        ],
      );

      stock = await engine.getStockSummaryForItem('item_gear');
      expect(stock.quantity, equals(-3.0), reason: 'Stock quantity must be exactly -3');
      // Rate remains 100.0; totalValue is -3 * 100 = -300
      expect(stock.totalValue, equals(-300.0));

      // Check Profit & Loss at negative stock state:
      // sales = 1200
      // openingStockVal = 500
      // purchases = 0
      // closingStockVal = -300
      // COGS = 500 + 0 - (-300) = 800 (exactly 8 units * 100 cost!)
      // Gross Profit = 1200 - 800 = 400!
      var pl = await engine.getProfitLossReport();
      expect(pl.salesValue, equals(1200.0));
      expect(pl.closingStockValue, equals(-300.0));
      expect(pl.grossProfit, equals(400.0), reason: 'COGS = 800, Profit = 400');

      // Step 3: Purchase 10 units @ 120 each = 1200
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-NEG-01',
        date: DateTime.now().add(const Duration(minutes: 5)),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ne3', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1200.0)),
          VoucherEntriesCompanion.insert(id: 'ne4', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(1200.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'nst2',
            voucherId: '',
            stockItemId: 'item_gear',
            quantity: 10.0,
            rate: 120.0,
            transactionType: 'IN',
          ),
        ],
      );

      stock = await engine.getStockSummaryForItem('item_gear');
      expect(stock.quantity, equals(7.0), reason: '-3 + 10 = 7 units');
      // Total value: -300 + 1200 = 900.
      // Average cost: 900 / 7 = 128.5714...
      expect(stock.totalValue, closeTo(900.0, 0.01));
      expect(stock.averageRate, closeTo(900.0 / 7.0, 0.01));

      // Check Profit & Loss after purchase:
      // sales = 1200
      // openingStockVal = 500
      // purchases = 1200
      // closingStockVal = 900
      // COGS = 500 + 1200 - 900 = 800 (still 8 units * 100 cost!)
      // Gross Profit = 1200 - 800 = 400!
      pl = await engine.getProfitLossReport();
      expect(pl.salesValue, equals(1200.0));
      expect(pl.purchaseValue, equals(1200.0));
      expect(pl.closingStockValue, closeTo(900.0, 0.01));
      expect(pl.grossProfit, closeTo(400.0, 0.01));
    });
  });

  group('7. Day Book Date Presets & Filtering Audit', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0);
      final yesterday = today.subtract(const Duration(days: 1));
      final lastMonth = DateTime(now.year, now.month - 1, 15, 10, 0);

      // Voucher 1: Today
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'DB-TODAY',
        date: today,
        entries: [
          VoucherEntriesCompanion.insert(id: 'd1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(100.0)),
          VoucherEntriesCompanion.insert(id: 'd2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(100.0)),
        ],
      );

      // Voucher 2: Yesterday
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'DB-YEST',
        date: yesterday,
        entries: [
          VoucherEntriesCompanion.insert(id: 'd3', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(200.0)),
          VoucherEntriesCompanion.insert(id: 'd4', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(200.0)),
        ],
      );

      // Voucher 3: Last Month
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'DB-PAST',
        date: lastMonth,
        entries: [
          VoucherEntriesCompanion.insert(id: 'd5', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(300.0)),
          VoucherEntriesCompanion.insert(id: 'd6', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(300.0)),
        ],
      );
    });

    tearDown(() => db.close());

    test('Date filtering correctly restricts boundaries', () async {
      final now = DateTime.now();
      final startToday = DateTime(now.year, now.month, now.day);
      final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final todayRows = await engine.getDayBook(startDate: startToday, endDate: endToday);
      expect(todayRows.length, equals(1));
      expect(todayRows.first.voucherNumber, equals('DB-TODAY'));

      // Empty range in the future
      final futureRows = await engine.getDayBook(
        startDate: now.add(const Duration(days: 30)),
        endDate: now.add(const Duration(days: 40)),
      );
      expect(futureRows.isEmpty, isTrue);

      // All range
      final allRows = await engine.getDayBook();
      expect(allRows.length, equals(3));
    });
  });

  group('9. Realistic Performance Stress Audit (1,000 Vouchers)', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);
    });

    tearDown(() => db.close());

    test('Measures latency for Day Book, Trial Balance, Ledger Balances on 1,000 vouchers', () async {
      final swTotal = Stopwatch()..start();

      // Batch insert 100 stock items and 100 ledgers
      await db.batch((batch) {
        for (int i = 0; i < 100; i++) {
          batch.insert(db.stockItems, StockItemsCompanion.insert(
            id: 'item_$i',
            name: 'Stock Item #$i',
            openingQuantity: const drift.Value(50.0),
            openingRate: const drift.Value(100.0),
          ));
          batch.insert(db.ledgers, LedgersCompanion.insert(
            id: 'cust_$i',
            name: 'Customer Account #$i',
            groupId: 'debtors',
          ));
        }
      });

      // Insert 1,000 vouchers with stock transactions
      final now = DateTime.now();
      await db.batch((batch) {
        for (int i = 0; i < 1000; i++) {
          final vid = 'v_$i';
          final vno = 'INV-${10000 + i}';
          final custId = 'cust_${i % 100}';
          final itemId = 'item_${i % 100}';

          batch.insert(db.vouchers, VouchersCompanion.insert(
            id: vid,
            voucherNumber: vno,
            voucherType: 'Sales',
            financialYear: const drift.Value('2025-26'),
            date: now.subtract(Duration(minutes: i)),
            status: const drift.Value('POSTED'),
            partyLedgerId: drift.Value(custId),
            paymentMode: drift.Value(i % 2 == 0 ? 'Cash' : 'Debt'),
          ));

          batch.insert(db.voucherEntries, VoucherEntriesCompanion.insert(
            id: 've_dr_$i',
            voucherId: vid,
            ledgerId: i % 2 == 0 ? 'cash' : custId,
            debitAmount: const drift.Value(1000.0),
          ));
          batch.insert(db.voucherEntries, VoucherEntriesCompanion.insert(
            id: 've_cr_$i',
            voucherId: vid,
            ledgerId: 'sales',
            creditAmount: const drift.Value(1000.0),
          ));

          batch.insert(db.stockTransactions, StockTransactionsCompanion.insert(
            id: 'st_$i',
            voucherId: vid,
            stockItemId: itemId,
            quantity: 1.0,
            rate: 1000.0,
            transactionType: 'OUT',
          ));
        }
      });
      swTotal.stop();

      // Measure 1: Opening Day Book (50 paginated rows)
      final swDayBook = Stopwatch()..start();
      final pagedDayBook = await engine.getDayBook(limit: 50, offset: 0);
      swDayBook.stop();
      expect(pagedDayBook.length, equals(50));

      // Measure 2: Single Ledger Statement
      final swLedger = Stopwatch()..start();
      final statement = await engine.getLedgerStatement('cust_0');
      swLedger.stop();
      expect(statement.isNotEmpty, isTrue);

      // Measure 3: Trial Balance calculation
      final swTB = Stopwatch()..start();
      final tb = await engine.getTrialBalance();
      swTB.stop();
      expect(tb.isNotEmpty, isTrue);

      // Measure 4: Cash Transactions fetch
      final swCash = Stopwatch()..start();
      final cashTxs = await engine.getCashTransactions();
      swCash.stop();
      expect(cashTxs.length, equals(500)); // 500 cash sales out of 1000

      // Performance assertions: All SQL queries should run under 50ms in-memory
      expect(swDayBook.elapsedMilliseconds, lessThan(50), reason: 'DayBook 50 rows must load in < 50ms');
      expect(swLedger.elapsedMilliseconds, lessThan(50), reason: 'Ledger statement must load in < 50ms');
      expect(swTB.elapsedMilliseconds, lessThan(50), reason: 'Trial Balance must aggregate in < 50ms');
      expect(swCash.elapsedMilliseconds, lessThan(100), reason: 'Cash book must load in < 100ms');
    });
  });

  group('10. Backup & Restore Compatibility Audit', () {
    late AppDatabase sourceDb;
    late AppDatabase targetDb;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('tally_audit_restore_test_');
      sourceDb = AppDatabase(NativeDatabase.memory());
      targetDb = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await sourceDb.close();
      await targetDb.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Full application backup archive restores schema V7 database intact', () async {
      // Seed source database with V7 fields
      await sourceDb.into(sourceDb.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_audit',
        name: 'Audit Customer',
        groupId: 'debtors',
      ));
      await sourceDb.into(sourceDb.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_audit',
        name: 'Audit Item',
      ));
      await sourceDb.into(sourceDb.vouchers).insert(VouchersCompanion.insert(
        id: 'v_audit_1',
        voucherNumber: 'INV-AUDIT-BKP',
        voucherType: 'Sales',
        date: DateTime.now(),
        partyLedgerId: const drift.Value('cust_audit'),
        paymentMode: const drift.Value('Cash'),
      ));
      await sourceDb.into(sourceDb.voucherEntries).insert(VoucherEntriesCompanion.insert(
        id: 've_audit_1',
        voucherId: 'v_audit_1',
        ledgerId: 'cash',
        debitAmount: const drift.Value(100.0),
      ));

      final snapshotPath = '${tempDir.path}${Platform.pathSeparator}audit_snapshot.sqlite';
      await sourceDb.customStatement("VACUUM INTO '$snapshotPath'");
      final snapshotBytes = await File(snapshotPath).readAsBytes();
      final manifestBytes = utf8.encode(jsonEncode({'app': 'Tally Ledger Desktop'}));
      final archive = Archive()
        ..addFile(ArchiveFile('tally_ledger.sqlite', snapshotBytes.length, snapshotBytes))
        ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      final archiveBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final restored = await DataExchangeService(targetDb).restoreFullApplicationBackup(archiveBytes);
      expect(restored, isTrue);

      final vouchers = await targetDb.select(targetDb.vouchers).get();
      expect(vouchers.length, equals(1));
      expect(vouchers.first.voucherNumber, equals('INV-AUDIT-BKP'));
      expect(vouchers.first.partyLedgerId, equals('cust_audit'));
      expect(vouchers.first.paymentMode, equals('Cash'));
    });
  });

  group('12. Accounting Invariants Explicit Assertions Audit', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Seed 2 customers, 1 item
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'c1', name: 'Customer 1', groupId: 'debtors'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'c2', name: 'Customer 2', groupId: 'debtors'));
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 's1',
        name: 'Item 1',
        openingQuantity: const drift.Value(20.0),
        openingRate: const drift.Value(100.0),
      ));
    });

    tearDown(() => db.close());

    test('All 7 accounting invariants hold across mixed operations', () async {
      // Op 1: Credit Sale 5 units @ 150 = 750 to c1
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-INV-01',
        partyLedgerId: 'c1',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ie1', voucherId: '', ledgerId: 'c1', debitAmount: const drift.Value(750.0)),
          VoucherEntriesCompanion.insert(id: 'ie2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(750.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'ist1', voucherId: '', stockItemId: 's1', quantity: 5.0, rate: 150.0, transactionType: 'OUT'),
        ],
      );

      // Op 2: Cash Sale 3 units @ 150 = 450 to c2
      final v2 = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-INV-02',
        partyLedgerId: 'c2',
        paymentMode: 'Cash',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ie3', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(450.0)),
          VoucherEntriesCompanion.insert(id: 'ie4', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(450.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'ist2', voucherId: '', stockItemId: 's1', quantity: 3.0, rate: 150.0, transactionType: 'OUT'),
        ],
      );

      // Invariant Check 1: Stock is 20 - 5 - 3 = 12
      final stockS1 = await engine.getStockSummaryForItem('s1');
      expect(stockS1.quantity, equals(12.0));

      // Invariant Check 2: c1 balance is 750, c2 balance is 0
      expect(await engine.getLedgerBalance('c1'), equals(750.0));
      expect(await engine.getLedgerBalance('c2'), equals(0.0));

      // Invariant Check 3: Trial balance exactly balances
      final tb = await engine.getTrialBalance();
      final totalDr = tb.fold(0.0, (s, r) => s + r.debitBalance);
      final totalCr = tb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(totalDr, equals(totalCr));
      expect(totalDr, equals(1200.0)); // 750 c1 + 450 cash = 1200 sales Cr

      // Invariant Check 4: Day Book total equals 1200
      final dayBook = await engine.getDayBook();
      final totalDayBook = dayBook.fold(0.0, (s, r) => s + r.totalAmount);
      expect(totalDayBook, equals(1200.0));

      // Invariant Check 5: Deleting v2 restores 3 units of stock and reverses cash
      await engine.deleteVoucher(v2);
      expect((await engine.getStockSummaryForItem('s1')).quantity, equals(15.0));
      expect(await engine.getLedgerBalance('cash'), equals(0.0));

      final tb2 = await engine.getTrialBalance();
      final totalDr2 = tb2.fold(0.0, (s, r) => s + r.debitBalance);
      final totalCr2 = tb2.fold(0.0, (s, r) => s + r.creditBalance);
      expect(totalDr2, equals(totalCr2));
      expect(totalDr2, equals(750.0));
    });
  });
}
