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

    // Initial capital of 10,000 cash so cash balance is positive throughout
    await db.into(db.voucherEntries).insert(VoucherEntriesCompanion.insert(
      id: 'cap_cash',
      voucherId: 'v_capital',
      ledgerId: 'cash',
      debitAmount: const drift.Value(10000.0),
    ));
    await db.into(db.voucherEntries).insert(VoucherEntriesCompanion.insert(
      id: 'cap_equity',
      voucherId: 'v_capital',
      ledgerId: 'profit_loss',
      creditAmount: const drift.Value(10000.0),
    ));
    await db.into(db.vouchers).insert(VouchersCompanion.insert(
      id: 'v_capital',
      voucherNumber: 'CAP-001',
      voucherType: 'Journal',
      date: DateTime(2026, 8, 31),
    ));

    // Day 1 — 1 September: Opening stock: 10 units @ 100
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item_x',
      name: 'Item X',
      openingQuantity: const drift.Value(10.0),
      openingRate: const drift.Value(100.0),
    ));

    // Seed customer and supplier
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_rajesh',
      name: 'Rajesh Kumar',
      groupId: 'debtors',
    ));
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'supp_gupta',
      name: 'Gupta Traders',
      groupId: 'creditors',
    ));
  });

  tearDown(() => db.close());

  test('Section 24: Comprehensive Out-of-Order / Backdated Chronological Lifecycle', () async {
    // Day 2 — 3 September: Credit purchase 10 units @ 120 from Gupta Traders
    final pur1No = await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-001',
      paymentMode: 'Debt',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 3, 10, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'p1_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1200.0)),
        VoucherEntriesCompanion.insert(id: 'p1_e2', voucherId: '', ledgerId: 'supp_gupta', creditAmount: const drift.Value(1200.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'p1_st1',
          voucherId: '',
          stockItemId: 'item_x',
          quantity: 10.0,
          rate: 120.0,
          transactionType: 'IN',
        ),
      ],
    );

    // Day 3 — 5 September: Credit sale 8 units @ 200 to Rajesh Kumar
    final sale1No = await engine.createVoucher(
      voucherType: 'Sales',
      voucherNumber: 'INV-001',
      paymentMode: 'Debt',
      partyLedgerId: 'cust_rajesh',
      date: DateTime(2026, 9, 5, 11, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 's1_e1', voucherId: '', ledgerId: 'cust_rajesh', debitAmount: const drift.Value(1600.0)),
        VoucherEntriesCompanion.insert(id: 's1_e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1600.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 's1_st1',
          voucherId: '',
          stockItemId: 'item_x',
          quantity: 8.0,
          rate: 200.0,
          transactionType: 'OUT',
        ),
      ],
    );

    // Day 4 — 7 September: Customer receipt 800 from Rajesh Kumar
    final rec1No = await engine.createVoucher(
      voucherType: 'Receipt',
      voucherNumber: 'REC-001',
      partyLedgerId: 'cust_rajesh',
      date: DateTime(2026, 9, 7, 12, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'r1_e1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(800.0)),
        VoucherEntriesCompanion.insert(id: 'r1_e2', voucherId: '', ledgerId: 'cust_rajesh', creditAmount: const drift.Value(800.0)),
      ],
    );

    // Day 5 — 8 September: Cash purchase 5 units @ 130 from Gupta Traders
    final pur2No = await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-002',
      paymentMode: 'Cash',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 8, 14, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'p2_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(650.0)),
        VoucherEntriesCompanion.insert(id: 'p2_e2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(650.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'p2_st1',
          voucherId: '',
          stockItemId: 'item_x',
          quantity: 5.0,
          rate: 130.0,
          transactionType: 'IN',
        ),
      ],
    );

    // Day 6 — 10 September: Supplier payment 600 to Gupta Traders
    final pay1No = await engine.createVoucher(
      voucherType: 'Payment',
      voucherNumber: 'PAY-001',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 10, 15, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'py1_e1', voucherId: '', ledgerId: 'supp_gupta', debitAmount: const drift.Value(600.0)),
        VoucherEntriesCompanion.insert(id: 'py1_e2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(600.0)),
      ],
    );

    // Verify balances BEFORE backdated entry (as of 10 Sep)
    // Stock: 10 + 10 - 8 + 5 = 17 units.
    var stockStatus = await engine.getStockSummaryForItem('item_x');
    expect(stockStatus.quantity, equals(17.0));
    expect(stockStatus.totalValue, closeTo(1970.0, 0.01));

    // Customer balance: 1600 - 800 = 800 Dr
    expect(await engine.getLedgerBalance('cust_rajesh'), equals(800.0));

    // Supplier balance: 1200 Cr - 600 Dr = -600 (net Dr-Cr: 600 Cr)
    // Note: Cash purchase of 650 did NOT add to supplier balance!
    expect(await engine.getLedgerBalance('supp_gupta'), equals(-600.0));

    // Cash balance: 10000 + 800 - 650 - 600 = 9550
    expect(await engine.getLedgerBalance('cash'), equals(9550.0));

    // Day 7 — 12 September: ENTER BACKDATED PURCHASE DATED 4 SEPTEMBER!
    // 5 units @ 125 = 625 from Gupta Traders (Credit)
    final backdatedPurNo = await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-BACKDATED-01',
      paymentMode: 'Debt',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 4, 16, 0), // Dated 4 Sep, before 5 Sep sale!
      entries: [
        VoucherEntriesCompanion.insert(id: 'bp_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(625.0)),
        VoucherEntriesCompanion.insert(id: 'bp_e2', voucherId: '', ledgerId: 'supp_gupta', creditAmount: const drift.Value(625.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'bp_st1',
          voucherId: '',
          stockItemId: 'item_x',
          quantity: 5.0,
          rate: 125.0,
          transactionType: 'IN',
        ),
      ],
    );

    // Verify AFTER backdated insertion:
    // 1. Stock quantity: 17 + 5 = 22 units
    stockStatus = await engine.getStockSummaryForItem('item_x');
    expect(stockStatus.quantity, equals(22.0));

    // 2. Chronological Costing Verification:
    // 1 Sep: 10 @ 100 = 1000
    // 3 Sep: 10 @ 120 = 1200 -> 20 units @ 110 = 2200
    // 4 Sep (backdated): 5 @ 125 = 625 -> 25 units @ 113.0 = 2825
    // 5 Sep: Sale 8 units -> leaves 17 units @ 113.0 = 1921.0
    // 8 Sep: Purchase 5 @ 130 = 650 -> 22 units, total value = 1921 + 650 = 2571.0
    expect(stockStatus.totalValue, closeTo(2571.0, 0.01));
    expect(stockStatus.averageRate, closeTo(2571.0 / 22.0, 0.01));

    // 3. Profit & Loss:
    // Sales: 1600
    // Opening: 1000
    // Purchases: 1200 + 650 + 625 = 2475
    // Closing Stock: 2571.0
    // COGS = 1000 + 2475 - 2571 = 904.0 (exactly 8 units sold @ 113.0 average cost at time of sale!)
    // Gross Profit = 1600 - 904 = 696.0!
    final pl = await engine.getProfitLossReport();
    expect(pl.salesValue, equals(1600.0));
    expect(pl.purchaseValue, equals(2475.0));
    expect(pl.closingStockValue, closeTo(2571.0, 0.01));
    expect(pl.grossProfit, closeTo(696.0, 0.01));

    // 4. Supplier balance updated with 625 credit: 600 Cr + 625 Cr = 1225 Cr (-1225.0 net)
    expect(await engine.getLedgerBalance('supp_gupta'), equals(-1225.0));

    // 5. Day Book: All 6 vouchers appear, ordered chronologically by date
    final dayBook = await engine.getDayBook(limit: 100);
    // Vouchers include capital voucher (31 Aug), 3 Sep, 4 Sep, 5 Sep, 7 Sep, 8 Sep, 10 Sep
    expect(dayBook.length, equals(7));
    // Check order: 10 Sep is first (DESC), then 8 Sep, 7 Sep, 5 Sep, 4 Sep, 3 Sep, 31 Aug
    expect(dayBook[0].voucherNumber, equals(pay1No));
    expect(dayBook[1].voucherNumber, equals(pur2No));
    expect(dayBook[2].voucherNumber, equals(rec1No));
    expect(dayBook[3].voucherNumber, equals(sale1No));
    expect(dayBook[4].voucherNumber, equals(backdatedPurNo));
    expect(dayBook[5].voucherNumber, equals(pur1No));

    // 6. Trial balance is balanced
    final tb = await engine.getTrialBalance();
    final totalDr = tb.fold(0.0, (s, r) => s + r.debitBalance);
    final totalCr = tb.fold(0.0, (s, r) => s + r.creditBalance);
    expect(totalDr, equals(totalCr));

    // Step 8: Delete backdated purchase and verify rollback
    await engine.deleteVoucher(backdatedPurNo);

    // Stock returns to 17 units, value 1970
    stockStatus = await engine.getStockSummaryForItem('item_x');
    expect(stockStatus.quantity, equals(17.0));
    expect(stockStatus.totalValue, closeTo(1970.0, 0.01));

    // Supplier balance returns to 600 Cr (-600.0)
    expect(await engine.getLedgerBalance('supp_gupta'), equals(-600.0));

    // Profit returns to 720.0 (COGS 880)
    final plRollback = await engine.getProfitLossReport();
    expect(plRollback.purchaseValue, equals(1850.0));
    expect(plRollback.closingStockValue, closeTo(1970.0, 0.01));
    expect(plRollback.grossProfit, closeTo(720.0, 0.01));

    // Step 9: Delete credit sale and verify rollback
    await engine.deleteVoucher(sale1No);

    // Stock returns to 25 units (10 opening + 10 pur1 + 5 pur2)
    stockStatus = await engine.getStockSummaryForItem('item_x');
    expect(stockStatus.quantity, equals(25.0));

    // Customer balance returns to 800 Cr (from the 800 receipt without the sale)
    expect(await engine.getLedgerBalance('cust_rajesh'), equals(-800.0));
  });

  test('Dedicated As-Of Date and Date-Range Ledger Statement audit', () async {
    // 3 Sep: Credit purchase 10 @ 120 (Gupta ₹1,200)
    await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-01',
      paymentMode: 'Debt',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 3, 10, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'p1_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1200.0)),
        VoucherEntriesCompanion.insert(id: 'p1_e2', voucherId: '', ledgerId: 'supp_gupta', creditAmount: const drift.Value(1200.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'p1_s1', voucherId: '', stockItemId: 'item_x', quantity: 10.0, rate: 120.0, transactionType: 'IN'),
      ],
    );

    // 4 Sep: Backdated purchase 5 @ 125 (Gupta ₹625)
    await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-02',
      paymentMode: 'Debt',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 4, 11, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'p2_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(625.0)),
        VoucherEntriesCompanion.insert(id: 'p2_e2', voucherId: '', ledgerId: 'supp_gupta', creditAmount: const drift.Value(625.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'p2_s1', voucherId: '', stockItemId: 'item_x', quantity: 5.0, rate: 125.0, transactionType: 'IN'),
      ],
    );

    // 5 Sep: Credit sale 8 @ 200 (Rajesh ₹1,600)
    await engine.createVoucher(
      voucherType: 'Sales',
      voucherNumber: 'INV-01',
      paymentMode: 'Debt',
      partyLedgerId: 'cust_rajesh',
      date: DateTime(2026, 9, 5, 14, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 's1_e1', voucherId: '', ledgerId: 'cust_rajesh', debitAmount: const drift.Value(1600.0)),
        VoucherEntriesCompanion.insert(id: 's1_e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1600.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 's1_s1', voucherId: '', stockItemId: 'item_x', quantity: 8.0, rate: 200.0, transactionType: 'OUT'),
      ],
    );

    // 7 Sep: Customer receipt ₹800
    await engine.createVoucher(
      voucherType: 'Receipt',
      voucherNumber: 'REC-01',
      partyLedgerId: 'cust_rajesh',
      date: DateTime(2026, 9, 7, 10, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'r1_e1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(800.0)),
        VoucherEntriesCompanion.insert(id: 'r1_e2', voucherId: '', ledgerId: 'cust_rajesh', creditAmount: const drift.Value(800.0)),
      ],
    );

    // 8 Sep: Cash purchase 5 @ 130 (Gupta ₹650)
    await engine.createVoucher(
      voucherType: 'Purchase',
      voucherNumber: 'PUR-CASH-01',
      paymentMode: 'Cash',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 8, 11, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'pc_e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(650.0)),
        VoucherEntriesCompanion.insert(id: 'pc_e2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(650.0)),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(id: 'pc_s1', voucherId: '', stockItemId: 'item_x', quantity: 5.0, rate: 130.0, transactionType: 'IN'),
      ],
    );

    // 10 Sep: Supplier payment ₹600 (Gupta)
    await engine.createVoucher(
      voucherType: 'Payment',
      voucherNumber: 'PAY-01',
      partyLedgerId: 'supp_gupta',
      date: DateTime(2026, 9, 10, 16, 0),
      entries: [
        VoucherEntriesCompanion.insert(id: 'pay_e1', voucherId: '', ledgerId: 'supp_gupta', debitAmount: const drift.Value(600.0)),
        VoucherEntriesCompanion.insert(id: 'pay_e2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(600.0)),
      ],
    );

    // --- VERIFY POINT-IN-TIME AS-OF DATE QUERIES ---

    // 1. As of 2 Sep:
    // - Stock: only 10 opening units @ 100
    // - Supplier Gupta balance: 0.0
    // - Customer Rajesh balance: 0.0
    var stAsOf2Sep = await engine.getStockSummaryForItem('item_x', asOfDate: DateTime(2026, 9, 2));
    expect(stAsOf2Sep.quantity, equals(10.0));
    expect(stAsOf2Sep.totalValue, equals(1000.0));
    expect(await engine.getLedgerBalance('supp_gupta', asOfDate: DateTime(2026, 9, 2)), equals(0.0));
    expect(await engine.getLedgerBalance('cust_rajesh', asOfDate: DateTime(2026, 9, 2)), equals(0.0));

    // 2. As of 3 Sep:
    // - Stock: 20 units @ 110 = 2200
    // - Supplier Gupta: 1200 Cr (-1200.0)
    var stAsOf3Sep = await engine.getStockSummaryForItem('item_x', asOfDate: DateTime(2026, 9, 3));
    expect(stAsOf3Sep.quantity, equals(20.0));
    expect(stAsOf3Sep.totalValue, equals(2200.0));
    expect(await engine.getLedgerBalance('supp_gupta', asOfDate: DateTime(2026, 9, 3)), equals(-1200.0));

    // 3. As of 4 Sep:
    // - Stock: 25 units @ 113.0 = 2825
    // - Supplier Gupta: 1200 + 625 = 1825 Cr (-1825.0)
    var stAsOf4Sep = await engine.getStockSummaryForItem('item_x', asOfDate: DateTime(2026, 9, 4));
    expect(stAsOf4Sep.quantity, equals(25.0));
    expect(stAsOf4Sep.totalValue, equals(2825.0));
    expect(await engine.getLedgerBalance('supp_gupta', asOfDate: DateTime(2026, 9, 4)), equals(-1825.0));

    // 4. As of 5 Sep:
    // - Stock: 17 units @ 113.0 = 1921.0
    // - Customer Rajesh: 1600 Dr (+1600.0)
    var stAsOf5Sep = await engine.getStockSummaryForItem('item_x', asOfDate: DateTime(2026, 9, 5));
    expect(stAsOf5Sep.quantity, equals(17.0));
    expect(stAsOf5Sep.totalValue, closeTo(1921.0, 0.01));
    expect(await engine.getLedgerBalance('cust_rajesh', asOfDate: DateTime(2026, 9, 5)), equals(1600.0));

    // 5. As of 7 Sep:
    // - Customer Rajesh after receipt: 1600 - 800 = 800 Dr (+800.0)
    expect(await engine.getLedgerBalance('cust_rajesh', asOfDate: DateTime(2026, 9, 7)), equals(800.0));

    // 6. As of 8 Sep:
    // - Supplier Gupta balance: still 1825 Cr (-1825.0) because cash purchase does NOT alter debt!
    expect(await engine.getLedgerBalance('supp_gupta', asOfDate: DateTime(2026, 9, 8)), equals(-1825.0));

    // 7. As of 10 Sep:
    // - Supplier Gupta balance: 1825 Cr - 600 Dr = 1225 Cr (-1225.0)
    expect(await engine.getLedgerBalance('supp_gupta', asOfDate: DateTime(2026, 9, 10)), equals(-1225.0));

    // --- VERIFY DATE RANGE LEDGER STATEMENT ---

    // Rajesh statement filtered for period 6 Sep to 10 Sep:
    // - At 6 Sep start: brought-forward opening balance is +1600.0
    // - During period: only REC-01 (800 credit) occurs
    // - Closing balance: +800.0
    final rajeshStmtPeriod = await engine.getLedgerStatement(
      'cust_rajesh',
      startDate: DateTime(2026, 9, 6),
      endDate: DateTime(2026, 9, 10),
    );
    expect(rajeshStmtPeriod.length, equals(2));
    // First row is the brought-forward opening balance
    expect(rajeshStmtPeriod[0].voucherNo, equals('OPENING'));
    expect(rajeshStmtPeriod[0].runningBalance, equals(1600.0));
    // Second row is the receipt voucher
    expect(rajeshStmtPeriod[1].voucherNo, equals('REC-01'));
    expect(rajeshStmtPeriod[1].credit, equals(800.0));
    expect(rajeshStmtPeriod[1].runningBalance, equals(800.0));

    // Trial balance as-of 4 Sep balances exactly
    final tbAsOf4Sep = await engine.getTrialBalance(asOfDate: DateTime(2026, 9, 4));
    final dr4Sep = tbAsOf4Sep.fold(0.0, (s, r) => s + r.debitBalance);
    final cr4Sep = tbAsOf4Sep.fold(0.0, (s, r) => s + r.creditBalance);
    expect(dr4Sep, equals(cr4Sep));
  });
}
