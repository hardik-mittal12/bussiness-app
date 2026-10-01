import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/money_precision.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);
  });

  tearDown(() => db.close());

  group('Operational Audit: Partial Payments Lifecycle', () {
    test('Sequential partial payments reduce customer and supplier debt to zero', () async {
      // Setup Customer and Supplier
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_amit', name: 'Amit Shoes', groupId: 'debtors'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_bharat', name: 'Bharat Leather', groupId: 'creditors'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'capital', name: 'Owner Capital', groupId: 'equity'));

      // Capital injection of 50,000
      await engine.createVoucher(
        voucherType: 'Journal',
        voucherNumber: 'CAP-01',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ce1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(50000.0)),
          VoucherEntriesCompanion.insert(id: 'ce2', voucherId: '', ledgerId: 'capital', creditAmount: const drift.Value(50000.0)),
        ],
      );

      // Customer Sale: 10,000 Credit Sale
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-1001',
        partyLedgerId: 'cust_amit',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'se1', voucherId: '', ledgerId: 'cust_amit', debitAmount: const drift.Value(10000.0)),
          VoucherEntriesCompanion.insert(id: 'se2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(10000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('cust_amit'), equals(10000.0));

      // Receipt 1: 3,000 -> Outstanding = 7,000
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-01',
        partyLedgerId: 'cust_amit',
        date: DateTime(2026, 9, 3),
        entries: [
          VoucherEntriesCompanion.insert(id: 're1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 're2', voucherId: '', ledgerId: 'cust_amit', creditAmount: const drift.Value(3000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('cust_amit'), equals(7000.0));

      // Receipt 2: 4,000 -> Outstanding = 3,000
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-02',
        partyLedgerId: 'cust_amit',
        date: DateTime(2026, 9, 4),
        entries: [
          VoucherEntriesCompanion.insert(id: 're3', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(4000.0)),
          VoucherEntriesCompanion.insert(id: 're4', voucherId: '', ledgerId: 'cust_amit', creditAmount: const drift.Value(4000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('cust_amit'), equals(3000.0));

      // Receipt 3: 3,000 -> Outstanding = 0.0
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-03',
        partyLedgerId: 'cust_amit',
        date: DateTime(2026, 9, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 're5', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 're6', voucherId: '', ledgerId: 'cust_amit', creditAmount: const drift.Value(3000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('cust_amit'), equals(0.0));

      // Supplier Purchase: 10,000 Credit Purchase
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-1001',
        partyLedgerId: 'supp_bharat',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pe1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(10000.0)),
          VoucherEntriesCompanion.insert(id: 'pe2', voucherId: '', ledgerId: 'supp_bharat', creditAmount: const drift.Value(10000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('supp_bharat'), equals(-10000.0)); // 10,000 Cr

      // Payment 1: 3,000 -> Outstanding = 7,000 Cr
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-01',
        partyLedgerId: 'supp_bharat',
        date: DateTime(2026, 9, 3),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pme1', voucherId: '', ledgerId: 'supp_bharat', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 'pme2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(3000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('supp_bharat'), equals(-7000.0));

      // Payment 2: 4,000 -> Outstanding = 3,000 Cr
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-02',
        partyLedgerId: 'supp_bharat',
        date: DateTime(2026, 9, 4),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pme3', voucherId: '', ledgerId: 'supp_bharat', debitAmount: const drift.Value(4000.0)),
          VoucherEntriesCompanion.insert(id: 'pme4', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(4000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('supp_bharat'), equals(-3000.0));

      // Payment 3: 3,000 -> Outstanding = 0.0
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-03',
        partyLedgerId: 'supp_bharat',
        date: DateTime(2026, 9, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pme5', voucherId: '', ledgerId: 'supp_bharat', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 'pme6', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(3000.0)),
        ],
      );
      expect(await engine.getLedgerBalance('supp_bharat'), equals(0.0));
    });
  });

  group('Operational Audit: Customer and Supplier Advances & Balance Sheet', () {
    test('Customer advance without invoice creates credit balance and balances in Balance Sheet', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_advance', name: 'Advance Customer', groupId: 'debtors'));

      // Customer gives 5,000 advance
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-ADV-01',
        partyLedgerId: 'cust_advance',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'adv1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(5000.0)),
          VoucherEntriesCompanion.insert(id: 'adv2', voucherId: '', ledgerId: 'cust_advance', creditAmount: const drift.Value(5000.0)),
        ],
      );

      // Customer balance is 5,000 Cr (-5000.0 net balance)
      expect(await engine.getLedgerBalance('cust_advance'), equals(-5000.0));

      // Balance Sheet with customer advance: Assets (Cash 5000) == Liabilities (Customer Advance 5000)
      final bs1 = await engine.getBalanceSheetReport();
      expect(bs1.cashBalance, equals(5000.0));
      expect(bs1.totalAssets, equals(5000.0));
      expect(bs1.sundryCreditors, equals(5000.0)); // Correctly recognized as liability
      expect(bs1.capitalBalance + bs1.netProfitSurplus + bs1.totalLiabilities + bs1.sundryCreditors, equals(5000.0));

      // Later, customer is billed for 3,000
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-ADV-01',
        partyLedgerId: 'cust_advance',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 'se1', voucherId: '', ledgerId: 'cust_advance', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 'se2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(3000.0)),
        ],
      );

      // Remaining advance is 2,000 Cr (-2000.0)
      expect(await engine.getLedgerBalance('cust_advance'), equals(-2000.0));

      // Balance Sheet remains balanced:
      // Assets: Cash 5000 = Total Assets 5000
      // Liabilities & Equity: Net Profit (Sales) 3000 + Remaining Advance 2000 = 5000!
      final bs2 = await engine.getBalanceSheetReport();
      expect(bs2.totalAssets, equals(5000.0));
      expect(bs2.netProfitSurplus, equals(3000.0));
      expect(bs2.sundryCreditors, equals(2000.0));
      expect(bs2.capitalBalance + bs2.netProfitSurplus + bs2.totalLiabilities + bs2.sundryCreditors, equals(5000.0));
    });

    test('Supplier advance creates debit balance and balances in Balance Sheet', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_advance', name: 'Advance Supplier', groupId: 'creditors'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'capital', name: 'Owner Capital', groupId: 'equity'));

      // Capital 20,000 cash
      await engine.createVoucher(
        voucherType: 'Journal',
        voucherNumber: 'CAP-02',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'c1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(20000.0)),
          VoucherEntriesCompanion.insert(id: 'c2', voucherId: '', ledgerId: 'capital', creditAmount: const drift.Value(20000.0)),
        ],
      );

      // Advance paid to supplier 10,000
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-ADV-01',
        partyLedgerId: 'supp_advance',
        date: DateTime(2026, 9, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'p1', voucherId: '', ledgerId: 'supp_advance', debitAmount: const drift.Value(10000.0)),
          VoucherEntriesCompanion.insert(id: 'p2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(10000.0)),
        ],
      );

      // Supplier has a debit balance of 10,000 (Advance asset)
      expect(await engine.getLedgerBalance('supp_advance'), equals(10000.0));

      // Balance sheet balances: Cash 10,000 + Supplier Advance 10,000 = Total Assets 20,000 == Capital 20,000!
      final bs1 = await engine.getBalanceSheetReport();
      expect(bs1.cashBalance, equals(10000.0));
      expect(bs1.sundryDebtors, equals(10000.0));
      expect(bs1.totalAssets, equals(20000.0));
      expect(bs1.capitalBalance, equals(20000.0));

      // Later purchase of 7,000 from supplier
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-ADV-01',
        partyLedgerId: 'supp_advance',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 'pur1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(7000.0)),
          VoucherEntriesCompanion.insert(id: 'pur2', voucherId: '', ledgerId: 'supp_advance', creditAmount: const drift.Value(7000.0)),
        ],
      );

      // Remaining supplier advance is 3,000 Dr
      expect(await engine.getLedgerBalance('supp_advance'), equals(3000.0));
    });
  });

  group('Operational Audit: Bank vs Cash Separation', () {
    test('Bank receipt and payment do not contaminate Cash-in-hand', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'bank_hdfc', name: 'HDFC Bank', groupId: 'bank_accounts'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_rohit', name: 'Rohit Footwear', groupId: 'debtors'));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_sole', name: 'Sole World', groupId: 'creditors'));

      // Initial cash 5,000 and initial bank 20,000
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'equity_cap', name: 'Capital', groupId: 'equity'));
      await engine.createVoucher(
        voucherType: 'Journal',
        voucherNumber: 'CAP-BANK-01',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'b1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(5000.0)),
          VoucherEntriesCompanion.insert(id: 'b2', voucherId: '', ledgerId: 'bank_hdfc', debitAmount: const drift.Value(20000.0)),
          VoucherEntriesCompanion.insert(id: 'b3', voucherId: '', ledgerId: 'equity_cap', creditAmount: const drift.Value(25000.0)),
        ],
      );

      expect(await engine.getLedgerBalance('cash'), equals(5000.0));
      expect(await engine.getLedgerBalance('bank_hdfc'), equals(20000.0));

      // Customer pays 8,000 into Bank (NEFT / RTGS)
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-BANK-01',
        partyLedgerId: 'cust_rohit',
        paymentMode: 'Bank',
        date: DateTime(2026, 9, 2),
        entries: [
          VoucherEntriesCompanion.insert(id: 'br1', voucherId: '', ledgerId: 'bank_hdfc', debitAmount: const drift.Value(8000.0)),
          VoucherEntriesCompanion.insert(id: 'br2', voucherId: '', ledgerId: 'cust_rohit', creditAmount: const drift.Value(8000.0)),
        ],
      );

      // Bank increases to 28,000; Physical Cash remains EXACTLY 5,000!
      expect(await engine.getLedgerBalance('bank_hdfc'), equals(28000.0));
      expect(await engine.getLedgerBalance('cash'), equals(5000.0));

      // Cash payment of 2,000 to Supplier
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-CASH-01',
        partyLedgerId: 'supp_sole',
        paymentMode: 'Cash',
        date: DateTime(2026, 9, 3),
        entries: [
          VoucherEntriesCompanion.insert(id: 'cp1', voucherId: '', ledgerId: 'supp_sole', debitAmount: const drift.Value(2000.0)),
          VoucherEntriesCompanion.insert(id: 'cp2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(2000.0)),
        ],
      );

      // Cash reduces to 3,000; Bank remains EXACTLY 28,000!
      expect(await engine.getLedgerBalance('cash'), equals(3000.0));
      expect(await engine.getLedgerBalance('bank_hdfc'), equals(28000.0));

      // Cash Book only shows the cash payment, NOT the bank receipt!
      final cashBook = await engine.getCashTransactions();
      expect(cashBook.any((r) => r.voucherNo == 'RCT-BANK-01'), isFalse);
      expect(cashBook.any((r) => r.voucherNo == 'PAY-CASH-01'), isTrue);
    });
  });

  group('Operational Audit: GST and Discount Exact Paise Arithmetic', () {
    test('₹1,000 taxable value @ 18% GST calculates exact minor units', () {
      const taxable = 1000.0;
      const gstRate = 18.0;
      const cgst = taxable * (gstRate / 2) / 100;
      const sgst = taxable * (gstRate / 2) / 100;
      const total = taxable + cgst + sgst;

      expect(cgst, equals(90.0));
      expect(sgst, equals(90.0));
      expect(total, equals(1180.0));

      // Convert to paise
      expect(MoneyPrecision.toPaise(cgst), equals(9000));
      expect(MoneyPrecision.toPaise(sgst), equals(9000));
      expect(MoneyPrecision.toPaise(total), equals(118000));
    });

    test('Invoice-level discount applied before GST computation', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_tax', name: 'Tax Customer', groupId: 'debtors'));

      // Subtotal: 2,000; Discount: 200; Taxable: 1,800; GST 18%: 162 CGST + 162 SGST; Total: 2,124
      const subtotal = 2000.0;
      const discount = 200.0;
      const taxable = subtotal - discount; // 1800.0
      const cgst = taxable * 0.09; // 162.0
      const sgst = taxable * 0.09; // 162.0
      const grandTotal = taxable + cgst + sgst; // 2124.0

      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-TAX-01',
        partyLedgerId: 'cust_tax',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 1),
        discountAmount: discount,
        entries: [
          VoucherEntriesCompanion.insert(id: 't1', voucherId: '', ledgerId: 'cust_tax', debitAmount: const drift.Value(grandTotal)),
          VoucherEntriesCompanion.insert(id: 't2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(taxable)),
          VoucherEntriesCompanion.insert(id: 't3', voucherId: '', ledgerId: 'cgst', creditAmount: const drift.Value(cgst)),
          VoucherEntriesCompanion.insert(id: 't4', voucherId: '', ledgerId: 'sgst', creditAmount: const drift.Value(sgst)),
        ],
      );

      expect(await engine.getLedgerBalance('cust_tax'), equals(2124.0));
      expect(await engine.getLedgerBalance('sales'), equals(-1800.0)); // 1800 Cr revenue
      expect(await engine.getLedgerBalance('cgst'), equals(-162.0)); // 162 Cr liability
      expect(await engine.getLedgerBalance('sgst'), equals(-162.0)); // 162 Cr liability

      // Trial balance balances exactly
      final tb = await engine.getTrialBalance();
      final dr = tb.fold(0.0, (s, r) => s + r.debitBalance);
      final cr = tb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(dr, equals(cr));
      expect(dr, equals(2124.0));
    });
  });

  group('Operational Audit: Date Editing & Re-sequencing', () {
    test('Editing voucher date shifts chronological position and recalculates reports', () async {
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'shoe_model',
        name: 'Classic Loafer',
        openingQuantity: const drift.Value(10.0),
        openingRate: const drift.Value(100.0),
      ));
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_agra', name: 'Agra Tannery', groupId: 'creditors'));

      // Create purchase initially dated 10 September
      final vNo = await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-SHIFT-01',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_agra',
        date: DateTime(2026, 9, 10),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1500.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'supp_agra', creditAmount: const drift.Value(1500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1', voucherId: '', stockItemId: 'shoe_model', quantity: 10.0, rate: 150.0, transactionType: 'IN'),
        ],
      );

      // As of 5 September: Stock has NOT arrived yet (only 10 opening units)
      var st5Sep = await engine.getStockSummaryForItem('shoe_model', asOfDate: DateTime(2026, 9, 5));
      expect(st5Sep.quantity, equals(10.0));
      expect(await engine.getLedgerBalance('supp_agra', asOfDate: DateTime(2026, 9, 5)), equals(0.0));

      // Now edit the voucher date back to 3 September (e.g. user corrected a typo)
      final voucherRecord = await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(vNo))).getSingle();
      await engine.createVoucher(
        existingVoucherId: voucherRecord.id,
        voucherNumber: vNo,
        voucherType: 'Purchase',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_agra',
        date: DateTime(2026, 9, 3), // EDITED TO 3 SEP
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1_mod', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1500.0)),
          VoucherEntriesCompanion.insert(id: 'e2_mod', voucherId: '', ledgerId: 'supp_agra', creditAmount: const drift.Value(1500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1_mod', voucherId: '', stockItemId: 'shoe_model', quantity: 10.0, rate: 150.0, transactionType: 'IN'),
        ],
      );

      // Now as of 5 September: Stock IS present (20 units), and supplier debt IS present (1500 Cr)
      st5Sep = await engine.getStockSummaryForItem('shoe_model', asOfDate: DateTime(2026, 9, 5));
      expect(st5Sep.quantity, equals(20.0));
      expect(st5Sep.averageRate, equals(125.0)); // (1000 + 1500) / 20 = 125
      expect(await engine.getLedgerBalance('supp_agra', asOfDate: DateTime(2026, 9, 5)), equals(-1500.0));

      // Now edit date back to 10 September (restoring original date)
      await engine.createVoucher(
        existingVoucherId: voucherRecord.id,
        voucherNumber: vNo,
        voucherType: 'Purchase',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_agra',
        date: DateTime(2026, 9, 10), // RESTORED TO 10 SEP
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1_res', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(1500.0)),
          VoucherEntriesCompanion.insert(id: 'e2_res', voucherId: '', ledgerId: 'supp_agra', creditAmount: const drift.Value(1500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st1_res', voucherId: '', stockItemId: 'shoe_model', quantity: 10.0, rate: 150.0, transactionType: 'IN'),
        ],
      );

      // As of 5 September returns to 10 units and 0 debt
      st5Sep = await engine.getStockSummaryForItem('shoe_model', asOfDate: DateTime(2026, 9, 5));
      expect(st5Sep.quantity, equals(10.0));
      expect(await engine.getLedgerBalance('supp_agra', asOfDate: DateTime(2026, 9, 5)), equals(0.0));
    });
  });

  group('Operational Audit: Cancelled vs Deleted Vouchers', () {
    test('Cancelled voucher remains in DB with CANCELLED status and zero report impact', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_cancel', name: 'Cancel Test', groupId: 'debtors'));

      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-CANCEL-01',
        partyLedgerId: 'cust_cancel',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust_cancel', debitAmount: const drift.Value(5000.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(5000.0)),
        ],
      );

      final vRecord = await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(vNo))).getSingle();
      expect(await engine.getLedgerBalance('cust_cancel'), equals(5000.0));

      // Cancel the voucher
      await engine.cancelVoucher(vRecord.id);

      // 1. Voucher still exists in DB
      final vAfter = await (db.select(db.vouchers)..where((t) => t.id.equals(vRecord.id))).getSingleOrNull();
      expect(vAfter, isNotNull);
      expect(vAfter!.status, equals('CANCELLED'));

      // 2. Ledger balance ignores cancelled voucher
      expect(await engine.getLedgerBalance('cust_cancel'), equals(0.0));

      // 3. Trial balance ignores cancelled voucher
      final tb = await engine.getTrialBalance();
      expect(tb.any((r) => r.ledgerId == 'cust_cancel'), isFalse);

      // 4. Audit log records the CANCEL action
      final audit = await db.select(db.auditLogs).get();
      expect(audit.any((a) => a.action == 'CANCEL' && a.entityId == vRecord.id), isTrue);
    });

    test('Deleted voucher is permanently removed with audit log and clean rollback', () async {
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'cust_del', name: 'Delete Test', groupId: 'debtors'));

      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-DEL-01',
        partyLedgerId: 'cust_del',
        paymentMode: 'Debt',
        date: DateTime(2026, 9, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust_del', debitAmount: const drift.Value(4000.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(4000.0)),
        ],
      );

      expect(await engine.getLedgerBalance('cust_del'), equals(4000.0));

      // Permanently delete voucher
      await engine.deleteVoucher(vNo);

      // 1. Voucher completely wiped from vouchers and entries
      final vAfter = await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(vNo))).getSingleOrNull();
      expect(vAfter, isNull);

      final entriesAfter = await (db.select(db.voucherEntries)..where((t) => t.ledgerId.equals('cust_del'))).get();
      expect(entriesAfter, isEmpty);

      // 2. Ledger balance returns to 0
      expect(await engine.getLedgerBalance('cust_del'), equals(0.0));

      // 3. Audit log records the DELETE action
      final audit = await db.select(db.auditLogs).get();
      expect(audit.any((a) => a.action == 'DELETE' && (a.oldValue?.contains(vNo) ?? false)), isTrue);
    });
  });

  group('Section 24: Comprehensive Full-Month Wholesale Business Lifecycle Simulation', () {
    test('Simulates complete 20-step real-world trading month with full financial reconciliation', () async {
      // 1. Opening Masters Setup
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'shoe_formal',
        name: 'Executive Leather Shoe',
        openingQuantity: const drift.Value(50.0),
        openingRate: const drift.Value(500.0),
      )); // 50 @ 500 = 25,000 opening stock

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_sharma',
        name: 'Sharma Shoe Store',
        groupId: 'debtors',
        openingBalance: const drift.Value(15000.0), // 15,000 Dr opening debt
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_verma',
        name: 'Verma Footwear',
        groupId: 'debtors',
        openingBalance: const drift.Value(0.0),
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'supp_metro',
        name: 'Metro Leather Corp',
        groupId: 'creditors',
        openingBalance: const drift.Value(-20000.0), // 20,000 Cr opening payable
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'supp_apex',
        name: 'Apex Soles Pvt Ltd',
        groupId: 'creditors',
        openingBalance: const drift.Value(0.0),
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'bank_sbi',
        name: 'State Bank of India',
        groupId: 'bank_accounts',
        openingBalance: const drift.Value(100000.0), // 100,000 Dr
      ));

      await (db.update(db.ledgers)..where((t) => t.id.equals('cash'))).write(
        const LedgersCompanion(openingBalance: drift.Value(40000.0)), // 40,000 Dr
      );

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'stock_opening',
        name: 'Stock-in-Hand',
        groupId: 'current_assets',
        openingBalance: const drift.Value(25000.0), // 25,000 Dr opening inventory
      ));

      // Capital account balancing opening balance sheet:
      // Assets: Stock 25k + Debtors 15k + Bank 100k + Cash 40k = 180,000.
      // Liabilities: Metro Creditor 20k -> Capital = 160,000.
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'equity_owner',
        name: 'Proprietor Capital',
        groupId: 'equity',
        openingBalance: const drift.Value(-160000.0), // 160,000 Cr
      ));

      // Reconcile opening Trial Balance
      var tb = await engine.getTrialBalance();
      var drTotal = tb.fold(0.0, (s, r) => s + r.debitBalance);
      var crTotal = tb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(drTotal, equals(crTotal));

      // Step 4: Credit Purchase from Apex Soles on 3 Sep (40 @ 550 = 22,000)
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-0901',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_apex',
        date: DateTime(2026, 9, 3),
        entries: [
          VoucherEntriesCompanion.insert(id: 'p1_1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(22000.0)),
          VoucherEntriesCompanion.insert(id: 'p1_2', voucherId: '', ledgerId: 'supp_apex', creditAmount: const drift.Value(22000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st_p1', voucherId: '', stockItemId: 'shoe_formal', quantity: 40.0, rate: 550.0, transactionType: 'IN'),
        ],
      );

      // Step 5: Cash Purchase from Metro Leather on 5 Sep (20 @ 560 = 11,200)
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-CASH-0901',
        paymentMode: 'Cash',
        partyLedgerId: 'supp_metro',
        date: DateTime(2026, 9, 5),
        entries: [
          VoucherEntriesCompanion.insert(id: 'p2_1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(11200.0)),
          VoucherEntriesCompanion.insert(id: 'p2_2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(11200.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st_p2', voucherId: '', stockItemId: 'shoe_formal', quantity: 20.0, rate: 560.0, transactionType: 'IN'),
        ],
      );

      // Step 6: Credit Sale to Verma Footwear on 8 Sep (30 @ 800 = 24,000)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-0901',
        paymentMode: 'Debt',
        partyLedgerId: 'cust_verma',
        date: DateTime(2026, 9, 8),
        entries: [
          VoucherEntriesCompanion.insert(id: 's1_1', voucherId: '', ledgerId: 'cust_verma', debitAmount: const drift.Value(24000.0)),
          VoucherEntriesCompanion.insert(id: 's1_2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(24000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st_s1', voucherId: '', stockItemId: 'shoe_formal', quantity: 30.0, rate: 800.0, transactionType: 'OUT'),
        ],
      );

      // Step 7: Cash Sale to Sharma Shoe Store on 10 Sep (10 @ 850 = 8,500)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-CASH-0901',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_sharma',
        date: DateTime(2026, 9, 10),
        entries: [
          VoucherEntriesCompanion.insert(id: 's2_1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(8500.0)),
          VoucherEntriesCompanion.insert(id: 's2_2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(8500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st_s2', voucherId: '', stockItemId: 'shoe_formal', quantity: 10.0, rate: 850.0, transactionType: 'OUT'),
        ],
      );

      // Step 8: Customer Receipt from Sharma Shoe Store on 12 Sep (10,000 into Bank)
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-0901',
        paymentMode: 'Bank',
        partyLedgerId: 'cust_sharma',
        date: DateTime(2026, 9, 12),
        entries: [
          VoucherEntriesCompanion.insert(id: 'r1_1', voucherId: '', ledgerId: 'bank_sbi', debitAmount: const drift.Value(10000.0)),
          VoucherEntriesCompanion.insert(id: 'r1_2', voucherId: '', ledgerId: 'cust_sharma', creditAmount: const drift.Value(10000.0)),
        ],
      );

      // Step 9: Supplier Payment to Metro Leather on 14 Sep (15,000 from Bank)
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-0901',
        paymentMode: 'Bank',
        partyLedgerId: 'supp_metro',
        date: DateTime(2026, 9, 14),
        entries: [
          VoucherEntriesCompanion.insert(id: 'py1_1', voucherId: '', ledgerId: 'supp_metro', debitAmount: const drift.Value(15000.0)),
          VoucherEntriesCompanion.insert(id: 'py1_2', voucherId: '', ledgerId: 'bank_sbi', creditAmount: const drift.Value(15000.0)),
        ],
      );

      // Step 10: Operating Freight / Transport Expense on 16 Sep (3,000 cash)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'freight_exp', name: 'Freight Inward', groupId: 'direct_expenses'));
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'EXP-0901',
        paymentMode: 'Cash',
        date: DateTime(2026, 9, 16),
        entries: [
          VoucherEntriesCompanion.insert(id: 'ex1_1', voucherId: '', ledgerId: 'freight_exp', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 'ex1_2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(3000.0)),
        ],
      );

      // Step 18: Customer Advance on 18 Sep (Verma pays 30,000 into Bank, bill was 24,000 -> 6,000 advance)
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-0902',
        paymentMode: 'Bank',
        partyLedgerId: 'cust_verma',
        date: DateTime(2026, 9, 18),
        entries: [
          VoucherEntriesCompanion.insert(id: 'r2_1', voucherId: '', ledgerId: 'bank_sbi', debitAmount: const drift.Value(30000.0)),
          VoucherEntriesCompanion.insert(id: 'r2_2', voucherId: '', ledgerId: 'cust_verma', creditAmount: const drift.Value(30000.0)),
        ],
      );

      // Step 19: Supplier Advance on 20 Sep (Advance 5,000 cash paid to new supplier)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(id: 'supp_new', name: 'New Raw Materials', groupId: 'creditors'));
      await engine.createVoucher(
        voucherType: 'Payment',
        voucherNumber: 'PAY-0902',
        paymentMode: 'Cash',
        partyLedgerId: 'supp_new',
        date: DateTime(2026, 9, 20),
        entries: [
          VoucherEntriesCompanion.insert(id: 'py2_1', voucherId: '', ledgerId: 'supp_new', debitAmount: const drift.Value(5000.0)),
          VoucherEntriesCompanion.insert(id: 'py2_2', voucherId: '', ledgerId: 'cash', creditAmount: const drift.Value(5000.0)),
        ],
      );

      // Step 13: Backdated Purchase entered on 22 Sep with date = 4 Sep (10 pairs @ 540 = 5,400 from Apex)
      await engine.createVoucher(
        voucherType: 'Purchase',
        voucherNumber: 'PUR-BACKDATED-0901',
        paymentMode: 'Debt',
        partyLedgerId: 'supp_apex',
        date: DateTime(2026, 9, 4), // 4 SEP
        entries: [
          VoucherEntriesCompanion.insert(id: 'bp_1', voucherId: '', ledgerId: 'purchase', debitAmount: const drift.Value(5400.0)),
          VoucherEntriesCompanion.insert(id: 'bp_2', voucherId: '', ledgerId: 'supp_apex', creditAmount: const drift.Value(5400.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(id: 'st_bp', voucherId: '', stockItemId: 'shoe_formal', quantity: 10.0, rate: 540.0, transactionType: 'IN'),
        ],
      );

      // --- FULL MONTH-END OPERATIONAL RECONCILIATION ---

      // 1. Stock Reconciliation:
      // Opening: 50
      // Purchases: 40 (3 Sep) + 10 (4 Sep backdated) + 20 (5 Sep) = 70 inward
      // Sales: 30 (8 Sep) + 10 (10 Sep) = 40 outward
      // Closing Stock Qty = 50 + 70 - 40 = 80 pairs!
      final stockSummary = await engine.getStockSummaryForItem('shoe_formal');
      expect(stockSummary.quantity, equals(80.0));

      // 2. Cash Reconciliation:
      // Opening: 40,000
      // - Cash Purchase (5 Sep): -11,200
      // + Cash Sale (10 Sep): +8,500
      // - Freight Expense (16 Sep): -3,000
      // - Supplier Advance (20 Sep): -5,000
      // Expected Cash = 40,000 - 11,200 + 8,500 - 3,000 - 5,000 = 29,300.0!
      expect(await engine.getLedgerBalance('cash'), equals(29300.0));

      // 3. Bank Reconciliation:
      // Opening: 100,000
      // + Receipt Sharma (12 Sep): +10,000
      // - Payment Metro (14 Sep): -15,000
      // + Receipt Verma (18 Sep): +30,000
      // Expected Bank = 100,000 + 10,000 - 15,000 + 30,000 = 125,000.0!
      expect(await engine.getLedgerBalance('bank_sbi'), equals(125000.0));

      // 4. Customer Debts & Advances:
      // Sharma: 15,000 opening Dr - 10,000 receipt = 5,000 Dr
      expect(await engine.getLedgerBalance('cust_sharma'), equals(5000.0));
      // Verma: 24,000 bill Dr - 30,000 receipt Cr = -6,000 (6,000 Cr Customer Advance)
      expect(await engine.getLedgerBalance('cust_verma'), equals(-6000.0));

      // 5. Supplier Payables & Advances:
      // Metro: -20,000 opening Cr + 15,000 payment Dr = -5,000 (5,000 Cr payable)
      expect(await engine.getLedgerBalance('supp_metro'), equals(-5000.0));
      // Apex: -22,000 (3 Sep) + -5,400 (4 Sep) = -27,400 (27,400 Cr payable)
      expect(await engine.getLedgerBalance('supp_apex'), equals(-27400.0));
      // New Supplier: +5,000 (5,000 Dr Supplier Advance Asset)
      expect(await engine.getLedgerBalance('supp_new'), equals(5000.0));

      // 6. Trial Balance: Must strictly balance
      final monthEndTb = await engine.getTrialBalance();
      final totalDr = monthEndTb.fold(0.0, (s, r) => s + r.debitBalance);
      final totalCr = monthEndTb.fold(0.0, (s, r) => s + r.creditBalance);
      expect(totalDr, equals(totalCr));

      // 7. Balance Sheet: Total Assets == Total Liabilities + Equity
      final bs = await engine.getBalanceSheetReport();
      final totalLiabEquity = bs.capitalBalance + bs.netProfitSurplus + bs.totalLiabilities + bs.sundryCreditors;
      expect(bs.totalAssets, closeTo(totalLiabEquity, 0.01));
    });
  });
}
