import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/invoice_printer.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Seed stock items (unordered to test alphabetical sorting)
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item_zebra',
      name: 'Zebra Stripes Paper',
      openingQuantity: const drift.Value(5.0),
      openingRate: const drift.Value(50.0),
    ));

    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item_widget',
      name: 'Alpha Widget Test Item',
      openingQuantity: const drift.Value(10.0),
      openingRate: const drift.Value(100.0),
    ));

    // Seed customer ledgers (unordered to test alphabetical sorting)
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_rohit',
      name: 'Rohit Verma',
      groupId: 'debtors',
      phone: const drift.Value('9123456780'),
      address: const drift.Value('456 Ring Road, Delhi'),
    ));

    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_amit',
      name: 'Amit Sharma',
      groupId: 'debtors',
      phone: const drift.Value('9876543210'),
      address: const drift.Value('123 Test Street, Delhi'),
      taxNumber: const drift.Value('07AAAAA0000A1Z5'),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('V7 Feature: Negative Stock Support', () {
    test('allowNegativeStock: false throws InsufficientStockException when oversold', () async {
      expect(
        () => engine.createVoucher(
          voucherType: 'Sales',
          date: DateTime.now(),
          entries: [
            VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust_amit', debitAmount: const drift.Value(2000.0)),
            VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(2000.0)),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(
              id: 'st1',
              voucherId: '',
              stockItemId: 'item_widget',
              quantity: 20.0, // Available is only 10.0
              rate: 100.0,
              transactionType: 'OUT',
            ),
          ],
          allowNegativeStock: false,
        ),
        throwsA(isA<InsufficientStockException>()),
      );
    });

    test('allowNegativeStock: true successfully allows stock to go below zero', () async {
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e1', voucherId: '', ledgerId: 'cust_amit', debitAmount: const drift.Value(2500.0)),
          VoucherEntriesCompanion.insert(id: 'e2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(2500.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st1',
            voucherId: '',
            stockItemId: 'item_widget',
            quantity: 25.0, // 10.0 available - 25.0 = -15.0
            rate: 100.0,
            transactionType: 'OUT',
          ),
        ],
        allowNegativeStock: true,
      );

      final summary = await engine.getStockSummaryForItem('item_widget');
      expect(summary.quantity, equals(-15.0));
    });
  });

  group('V7 Feature: Alphabetical Ordering in Inventory and Ledgers', () {
    test('getStockSummary returns items strictly sorted alphabetically', () async {
      final summary = await engine.getStockSummary();
      expect(summary.length, equals(2));
      expect(summary[0].name, equals('Alpha Widget Test Item'));
      expect(summary[1].name, equals('Zebra Stripes Paper'));
    });

    test('Ledgers query returns debtors sorted alphabetically', () async {
      final debtors = await (db.select(db.ledgers)
            ..where((t) => t.groupId.equals('debtors'))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.name.lower())]))
          .get();
      expect(debtors.length, equals(2));
      expect(debtors[0].name, equals('Amit Sharma'));
      expect(debtors[1].name, equals('Rohit Verma'));
    });
  });

  group('V7 Feature: Alter/Edit Account Details', () {
    test('updating customer name, phone, address and tax number persists accurately', () async {
      await (db.update(db.ledgers)..where((t) => t.id.equals('cust_amit'))).write(
        const LedgersCompanion(
          name: drift.Value('Amit Kumar Sharma'),
          phone: drift.Value('9998887776'),
          address: drift.Value('789 New Colony, Gurgaon'),
          taxNumber: drift.Value('06BBBBB1111B2Z6'),
        ),
      );

      final updated = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_amit'))).getSingle();
      expect(updated.name, equals('Amit Kumar Sharma'));
      expect(updated.phone, equals('9998887776'));
      expect(updated.address, equals('789 New Colony, Gurgaon'));
      expect(updated.taxNumber, equals('06BBBBB1111B2Z6'));
    });
  });

  group('V7 Feature: Cash vs Debt Invoices & Reconciled Statements', () {
    test('Cash sale synthesizes cash entries with party details and does not leave customer with debt', () async {
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0001',
        narration: 'Cash sale to Amit',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_amit',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'c1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(1000.0)),
          VoucherEntriesCompanion.insert(id: 'c2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st_c1',
            voucherId: '',
            stockItemId: 'item_widget',
            quantity: 2.0,
            rate: 500.0,
            transactionType: 'OUT',
          ),
        ],
      );

      expect(vNo, equals('INV-2026-0001'));

      // Customer statement should show the cash sale with zero net debt impact
      final statement = await engine.getLedgerStatement('cust_amit');
      expect(statement.any((s) => s.paymentMode == 'Cash'), isTrue);
      // Net balance for customer remains 0 because it was paid by Cash
      expect(statement.last.runningBalance, equals(0.0));

      // Cash book shows Amit Sharma with cash In of 1000
      final cashRows = await engine.getCashTransactions();
      final cashSale = cashRows.firstWhere((r) => r.voucherNo == vNo);
      expect(cashSale.amount, equals(1000.0));
      expect(cashSale.isCashIn, isTrue);
      expect(cashSale.partyName, equals('Amit Sharma'));
      expect(cashSale.runningBalance, equals(1000.0));
    });

    test('Debt sale increases customer debt, subsequent Receipt voucher reduces debt', () async {
      // 1. Debt Sale of 3000 to Amit
      final debtVoucherNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-DEBT-001',
        narration: 'Debt sale on credit',
        paymentMode: 'Debt',
        partyLedgerId: 'cust_amit',
        date: DateTime.now().subtract(const Duration(days: 1)),
        entries: [
          VoucherEntriesCompanion.insert(id: 'd1', voucherId: '', ledgerId: 'cust_amit', debitAmount: const drift.Value(3000.0)),
          VoucherEntriesCompanion.insert(id: 'd2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(3000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st_d1',
            voucherId: '',
            stockItemId: 'item_widget',
            quantity: 3.0,
            rate: 1000.0,
            transactionType: 'OUT',
          ),
        ],
      );
      expect(debtVoucherNo, equals('INV-DEBT-001'));

      // Customer balance should be 3000 Dr
      var balance = await engine.getLedgerBalance('cust_amit');
      expect(balance, equals(3000.0));

      // 2. Customer pays 2000 via Receipt
      final receiptNo = await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'REC-001',
        narration: 'Partial payment received from Amit',
        partyLedgerId: 'cust_amit',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'r1', voucherId: '', ledgerId: 'cash', debitAmount: const drift.Value(2000.0)),
          VoucherEntriesCompanion.insert(id: 'r2', voucherId: '', ledgerId: 'cust_amit', creditAmount: const drift.Value(2000.0)),
        ],
      );
      expect(receiptNo, equals('REC-001'));

      // Customer balance should now be 1000 Dr
      balance = await engine.getLedgerBalance('cust_amit');
      expect(balance, equals(1000.0));
    });
  });

  group('V7 Feature: Bill Deletion & Reversal with Audit Trail', () {
    test('Deleting a voucher reverses stock effects and writes an AuditLog entry', () async {
      final vNo = await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-DEL-TEST',
        narration: 'Sale to be deleted',
        partyLedgerId: 'cust_amit',
        date: DateTime.now(),
        entries: [
          VoucherEntriesCompanion.insert(id: 'del1', voucherId: '', ledgerId: 'cust_amit', debitAmount: const drift.Value(1000.0)),
          VoucherEntriesCompanion.insert(id: 'del2', voucherId: '', ledgerId: 'sales', creditAmount: const drift.Value(1000.0)),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st_del1',
            voucherId: '',
            stockItemId: 'item_widget',
            quantity: 4.0, // Stock goes 10 - 4 = 6
            rate: 250.0,
            transactionType: 'OUT',
          ),
        ],
      );

      var stock = await engine.getStockSummaryForItem('item_widget');
      expect(stock.quantity, equals(6.0));

      // Delete the voucher using voucher number
      await engine.deleteVoucher(vNo);

      // Stock must be restored to 10.0
      stock = await engine.getStockSummaryForItem('item_widget');
      expect(stock.quantity, equals(10.0));

      // Customer balance must be restored to 0
      final balance = await engine.getLedgerBalance('cust_amit');
      expect(balance, equals(0.0));

      // Audit log must exist with the voucher number in oldValue
      final logs = await db.select(db.auditLogs).get();
      expect(logs.any((l) => l.action == 'DELETE' && l.oldValue != null && l.oldValue!.contains(vNo)), isTrue);
    });
  });

  group('V7 Feature: Multi-Copy Invoice Generation', () {
    test('generatePdfBytes produces valid PDF document bytes for 1, 2, and 3 copies', () async {
      final invoice = InvoiceViewModel(
        voucherNumber: 'INV-2026-0001',
        voucherType: 'Sales',
        financialYear: '2025-26',
        date: DateTime.now(),
        partyName: 'Amit Sharma',
        partyAddress: '123 Test Street, Delhi',
        partyTaxNumber: '07AAAAA0000A1Z5',
        partyPhone: '9876543210',
        items: [
          InvoiceItemRow(
            itemName: 'Alpha Widget Test Item',
            quantity: 5.0,
            rate: 100.0,
            amount: 500.0,
          ),
        ],
        subtotal: 500.0,
        discount: 0.0,
        cgst: 0.0,
        sgst: 0.0,
        grandTotal: 500.0,
        narration: 'V7 Release verification test',
        paymentMode: 'Cash',
      );

      final singleCopy = await InvoicePrinter.generatePdfBytes(
        db: db,
        invoice: invoice,
        copies: 1,
      );

      final doubleCopy = await InvoicePrinter.generatePdfBytes(
        db: db,
        invoice: invoice,
        copies: 2,
      );

      final tripleCopy = await InvoicePrinter.generatePdfBytes(
        db: db,
        invoice: invoice,
        copies: 3,
      );

      expect(singleCopy.isNotEmpty, isTrue);
      expect(doubleCopy.isNotEmpty, isTrue);
      expect(tripleCopy.isNotEmpty, isTrue);
      expect(doubleCopy.length, greaterThan(singleCopy.length));
      expect(tripleCopy.length, greaterThan(doubleCopy.length));
    });
  });
}
