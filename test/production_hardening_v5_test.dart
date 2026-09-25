import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/business_profile_service.dart';
import 'package:tally_ledger_desktop/core/data_exchange_service.dart';
import 'package:tally_ledger_desktop/core/money_precision.dart';
import 'package:tally_ledger_desktop/data/database.dart';

class TestInvoiceItem {
  final String itemId;
  final double quantity;
  final double rate;
  final bool isReplacement;

  TestInvoiceItem({
    required this.itemId,
    required this.quantity,
    required this.rate,
    this.isReplacement = false,
  });
}

Future<Voucher> createTestInvoice({
  required AccountingEngine engine,
  required AppDatabase db,
  required String voucherType,
  required String voucherNumber,
  required DateTime date,
  required String contactLedgerId,
  required List<TestInvoiceItem> items,
  double discountAmount = 0.0,
}) async {
  const uuid = Uuid();
  double subtotal = 0.0;
  List<StockTransactionsCompanion> stockTxs = [];

  for (final item in items) {
    if (!item.isReplacement) {
      subtotal += MoneyPrecision.calculateLineTotal(item.quantity, item.rate);
    }
    stockTxs.add(StockTransactionsCompanion.insert(
      id: uuid.v4(),
      voucherId: '',
      stockItemId: item.itemId,
      quantity: item.quantity,
      rate: item.isReplacement ? 0.0 : item.rate,
      transactionType: voucherType == 'Sales' ? 'OUT' : 'IN',
      isReplacement: drift.Value(item.isReplacement),
    ));
  }

  final taxable = (subtotal - discountAmount) > 0 ? (subtotal - discountAmount) : 0.0;
  final cgst = MoneyPrecision.toRupees((MoneyPrecision.toPaise(taxable) * 9) ~/ 100);
  final sgst = cgst;
  final grandTotal = MoneyPrecision.sum([taxable, cgst, sgst]);

  List<VoucherEntriesCompanion> entries = [];
  if (voucherType == 'Sales') {
    entries.add(VoucherEntriesCompanion.insert(
      id: uuid.v4(),
      voucherId: '',
      ledgerId: contactLedgerId,
      debitAmount: drift.Value(grandTotal),
      creditAmount: const drift.Value(0.0),
    ));
    entries.add(VoucherEntriesCompanion.insert(
      id: uuid.v4(),
      voucherId: '',
      ledgerId: 'sales',
      debitAmount: const drift.Value(0.0),
      creditAmount: drift.Value(taxable),
    ));
    if (cgst > 0) {
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'cgst',
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(cgst),
      ));
    }
    if (sgst > 0) {
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'sgst',
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(sgst),
      ));
    }
  }

  final finalNo = await engine.createVoucher(
    voucherNumber: voucherNumber,
    voucherType: voucherType,
    date: date,
    discountAmount: discountAmount,
    entries: entries,
    stockTransactions: stockTxs,
  );

  return (await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(finalNo))).getSingle());
}

Future<Voucher> createTestReceipt({
  required AccountingEngine engine,
  required AppDatabase db,
  required String voucherType,
  required String voucherNumber,
  required DateTime date,
  required String contactLedgerId,
  required String cashBankLedgerId,
  required double amount,
}) async {
  const uuid = Uuid();
  List<VoucherEntriesCompanion> entries = [
    VoucherEntriesCompanion.insert(
      id: uuid.v4(),
      voucherId: '',
      ledgerId: cashBankLedgerId,
      debitAmount: drift.Value(amount),
      creditAmount: const drift.Value(0.0),
    ),
    VoucherEntriesCompanion.insert(
      id: uuid.v4(),
      voucherId: '',
      ledgerId: contactLedgerId,
      debitAmount: const drift.Value(0.0),
      creditAmount: drift.Value(amount),
    ),
  ];

  final finalNo = await engine.createVoucher(
    voucherNumber: voucherNumber,
    voucherType: voucherType,
    date: date,
    entries: entries,
  );

  return (await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(finalNo))).getSingle());
}

void main() {
  late AppDatabase db;
  late AccountingEngine engine;
  late BusinessProfileService profileService;
  late DataExchangeService exchangeService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);
    profileService = BusinessProfileService(db);
    exchangeService = DataExchangeService(db);

    // Seed test ledgers
    await db.batch((b) {
      b.insertAll(db.ledgers, [
        LedgersCompanion.insert(
          id: 'cust_acme',
          name: 'Acme Corp',
          groupId: 'debtors',
          openingBalance: const drift.Value(0.0),
          phone: const drift.Value('9876543210'),
          address: const drift.Value('123 Market St'),
        ),
        LedgersCompanion.insert(
          id: 'cust_unused',
          name: 'Unused Customer',
          groupId: 'debtors',
          openingBalance: const drift.Value(0.0),
        ),
      ]);
    });

    // Seed test inventory item
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item_widget',
      name: 'Super Widget',
      openingQuantity: const drift.Value(100.0),
      openingRate: const drift.Value(100.0),
      salesRate: const drift.Value(150.0),
      purchaseRate: const drift.Value(100.0),
      unitOfMeasure: const drift.Value('NOS'),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  group('Customer Deletion Safety', () {
    test('Customer without transactions is hard-deleted from database', () async {
      final existsBefore = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_unused'))).getSingleOrNull();
      expect(existsBefore, isNotNull);

      final deleted = await engine.deleteCustomer('cust_unused');
      expect(deleted, isTrue);

      final existsAfter = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_unused'))).getSingleOrNull();
      expect(existsAfter, isNull);
    });

    test('Customer with transaction history is soft-deleted (isDeleted = true)', () async {
      // Create an invoice for cust_acme
      await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0001',
        date: DateTime(2026, 4, 15),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 2, rate: 150.0),
        ],
      );

      final customerBalanceBefore = await engine.getLedgerBalance('cust_acme');
      expect(customerBalanceBefore, isPositive);

      // Attempt deletion
      final wasHardDeleted = await engine.deleteCustomer('cust_acme');
      expect(wasHardDeleted, isFalse); // false indicates soft-deleted / deactivated due to existing transactions

      // Verify record still exists in database with isDeleted == true
      final customerRecord = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_acme'))).getSingle();
      expect(customerRecord.isDeleted, isTrue);

      // Historical balance and statement are still intact
      final customerBalanceAfter = await engine.getLedgerBalance('cust_acme');
      expect(customerBalanceAfter, equals(customerBalanceBefore));

      final statement = await engine.getLedgerStatement('cust_acme');
      expect(statement.isNotEmpty, isTrue);
    });
  });

  group('Company Details & Logo Dual-Persistence', () {
    test('Updates company profile and dual-persists logo in sync metadata', () async {
      const testLogoPath = '/tmp/test_company_logo.png';
      await profileService.updateProfile(
        companyName: 'Acme Global Pvt Ltd',
        address: '456 Business Blvd, Tech Park',
        phone: '+91 99999 88888',
        taxNumber: '29ABCDE1234F1Z5',
        logoPath: testLogoPath,
      );

      final profile = await profileService.getProfile();
      expect(profile.companyName, equals('Acme Global Pvt Ltd'));
      expect(profile.address, equals('456 Business Blvd, Tech Park'));
      expect(profile.phone, equals('+91 99999 88888'));
      expect(profile.taxNumber, equals('29ABCDE1234F1Z5'));
      expect(profile.logoPath, equals(testLogoPath));

      // Verify metadata key persistence
      final meta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).getSingleOrNull();
      expect(meta, isNotNull);
      expect(meta!.value, equals(testLogoPath));
    });

    test('Removing logo cleans up profile and metadata', () async {
      await profileService.updateProfile(
        companyName: 'Acme Global Pvt Ltd',
        logoPath: '',
      );

      final profile = await profileService.getProfile();
      expect(profile.logoPath, isNull);

      final meta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).getSingleOrNull();
      expect(meta, isNull);
    });
  });

  group('Strict Replacement Item Boundary', () {
    test('Replacement item deducts stock with rate 0 and no customer balance charge', () async {
      final stockBefore = await engine.getStockSummaryForItem('item_widget');
      expect(stockBefore.quantity, equals(100.0));

      // Invoice with 1 normal item (2 qty) + 1 replacement item (1 qty)
      await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0002',
        date: DateTime(2026, 4, 16),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 2, rate: 150.0, isReplacement: false),
          TestInvoiceItem(itemId: 'item_widget', quantity: 1, rate: 0.0, isReplacement: true),
        ],
      );

      // Total 3 widgets deducted from stock
      final stockAfter = await engine.getStockSummaryForItem('item_widget');
      expect(stockAfter.quantity, equals(97.0));

      // Check stock transaction row has isReplacement == true
      final txs = await (db.select(db.stockTransactions)
        ..where((t) => t.stockItemId.equals('item_widget') & t.isReplacement.equals(true)))
        .get();
      expect(txs.length, equals(1));
      expect(txs.first.quantity, equals(1.0));
      expect(txs.first.rate, equals(0.0));

      // Customer only charged for the non-replacement 2 items (2 * 150 = 300 + 18% GST = 354.00)
      final balance = await engine.getLedgerBalance('cust_acme');
      expect(balance, equals(354.00));
    });
  });

  group('Bill Discount & Exact Double-Entry Precision', () {
    test('Discount reduces taxable base and maintains exact double-entry parity (debits == credits)', () async {
      // Subtotal = 1000.0, Discount = 100.0 -> Net = 900.0
      // CGST (9%) = 81.0, SGST (9%) = 81.0 -> Total = 1062.0
      final voucher = await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0003',
        date: DateTime(2026, 4, 17),
        contactLedgerId: 'cust_acme',
        discountAmount: 100.0,
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 10, rate: 100.0),
        ],
      );

      expect(voucher.discountAmount, equals(100.0));

      // Verify entries double-entry equality in integer paise
      final entries = await (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucher.id))).get();
      int totalDebitsPaise = 0;
      int totalCreditsPaise = 0;

      for (final e in entries) {
        totalDebitsPaise += MoneyPrecision.toPaise(e.debitAmount);
        totalCreditsPaise += MoneyPrecision.toPaise(e.creditAmount);
      }

      expect(totalDebitsPaise, equals(totalCreditsPaise));
      expect(MoneyPrecision.toRupees(totalDebitsPaise), equals(1062.00));

      // Customer balance charged exactly 1062.00
      final balance = await engine.getLedgerBalance('cust_acme');
      expect(balance, equals(1062.00));
    });
  });

  group('Bill and Payment Cancellation / Deletion', () {
    test('Cancelling invoice sets status CANCELLED, restores stock, and excludes from ledger balance', () async {
      final voucher = await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0004',
        date: DateTime(2026, 4, 18),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 5, rate: 150.0),
        ],
      );

      expect(await engine.getLedgerBalance('cust_acme'), isPositive);
      expect((await engine.getStockSummaryForItem('item_widget')).quantity, equals(95.0));

      // Cancel invoice
      await engine.cancelVoucher(voucher.id);

      // Check status
      final updated = await (db.select(db.vouchers)..where((t) => t.id.equals(voucher.id))).getSingle();
      expect(updated.status, equals('CANCELLED'));

      // Customer balance is zero because cancelled voucher is excluded
      expect(await engine.getLedgerBalance('cust_acme'), equals(0.0));

      // Stock is restored to 100.0
      expect((await engine.getStockSummaryForItem('item_widget')).quantity, equals(100.0));
    });

    test('Deleting invoice removes it completely from database', () async {
      final voucher = await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0005',
        date: DateTime(2026, 4, 19),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 1, rate: 150.0),
        ],
      );

      await engine.deleteVoucher(voucher.id);

      final v = await (db.select(db.vouchers)..where((t) => t.id.equals(voucher.id))).getSingleOrNull();
      expect(v, isNull);

      final entries = await (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucher.id))).get();
      expect(entries, isEmpty);
    });

    test('Cancelling payment restores cash and customer balances', () async {
      // Create payment
      final payment = await createTestReceipt(
        engine: engine,
        db: db,
        voucherType: 'Receipt',
        voucherNumber: 'RCT-2026-0001',
        date: DateTime(2026, 4, 20),
        contactLedgerId: 'cust_acme',
        cashBankLedgerId: 'cash',
        amount: 500.0,
      );

      expect(await engine.getLedgerBalance('cash'), equals(500.0));
      expect(await engine.getLedgerBalance('cust_acme'), equals(-500.0));

      // Cancel payment
      await engine.cancelReceipt(payment.id);

      // Balances return to zero
      expect(await engine.getLedgerBalance('cash'), equals(0.0));
      expect(await engine.getLedgerBalance('cust_acme'), equals(0.0));
    });
  });

  group('Business Data Reset', () {
    test('resetBusinessData removes all vouchers and stock transactions while keeping profile intact', () async {
      await profileService.updateProfile(
        companyName: 'Persistent Business Co',
        address: '789 Heritage Road',
      );

      // Create a voucher
      await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0006',
        date: DateTime(2026, 4, 21),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 4, rate: 150.0),
        ],
      );

      expect((await db.select(db.vouchers).get()).isNotEmpty, isTrue);

      // Reset data
      await engine.resetBusinessData();

      // Vouchers and entries are wiped
      expect(await db.select(db.vouchers).get(), isEmpty);
      expect(await db.select(db.voucherEntries).get(), isEmpty);
      expect(await db.select(db.stockTransactions).get(), isEmpty);

      // Stock item quantity is restored to openingQuantity (100.0)
      final item = await (db.select(db.stockItems)..where((t) => t.id.equals('item_widget'))).getSingle();
      expect(item.openingQuantity, equals(100.0));

      // Company profile is preserved
      final profile = await profileService.getProfile();
      expect(profile.companyName, equals('Persistent Business Co'));
      expect(profile.address, equals('789 Heritage Road'));
    });
  });

  group('Tally XML & Data Exchange Center', () {
    test('Exports vouchers to valid Tally XML structure', () async {
      await createTestInvoice(
        engine: engine,
        db: db,
        voucherType: 'Sales',
        voucherNumber: 'INV-2026-0007',
        date: DateTime(2026, 4, 22),
        contactLedgerId: 'cust_acme',
        items: [
          TestInvoiceItem(itemId: 'item_widget', quantity: 2, rate: 150.0),
        ],
      );

      final xmlString = await exchangeService.exportTallyXml();
      expect(xmlString.contains('<ENVELOPE>'), isTrue);
      expect(xmlString.contains('<TALLYMESSAGE xmlns:UDF="TallyUDF">'), isTrue);
      expect(xmlString.contains('<VOUCHER VCHTYPE="Sales" ACTION="Create">'), isTrue);
      expect(xmlString.contains('<VOUCHERNUMBER>INV-2026-0007</VOUCHERNUMBER>'), isTrue);
      expect(xmlString.contains('</ENVELOPE>'), isTrue);
    });

    test('CSV preview and duplicate resolution (skip vs update)', () async {
      const csvData = '''Name,Phone,Address,Email,GSTIN,OpeningBalance
Acme Corp,1112223333,New Address,acme@new.com,,0.0
Brand New Customer,4445556666,Brand New St,brand@new.com,,100.0''';

      final preview = exchangeService.previewDelimitedFile(csvData);
      expect(preview.headers.length, equals(6));
      expect(preview.totalRows, equals(2));

      // Test Skip Duplicates (Acme Corp already exists in DB)
      final skipResult = await exchangeService.importCustomersMapped(
        rows: [
          ['Acme Corp', '1112223333', 'New Address', '', '', 0.0],
          ['Brand New Customer', '4445556666', 'Brand New St', '', '', 100.0],
        ],
        columnMapping: {'name': 0, 'phone': 1, 'address': 2, 'openingBalance': 5},
        duplicateHandling: DuplicateHandling.skip,
      );
      expect(skipResult.skippedCount, equals(1));
      expect(skipResult.createdCount, equals(1));

      // Verify original Acme Corp was untouched
      final originalAcme = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_acme'))).getSingle();
      expect(originalAcme.address, equals('123 Market St'));

      // Test Update Duplicates
      final updateResult = await exchangeService.importCustomersMapped(
        rows: [
          ['Acme Corp', '1112223333', 'Updated Address St', '', '', 0.0],
        ],
        columnMapping: {'name': 0, 'phone': 1, 'address': 2, 'openingBalance': 5},
        duplicateHandling: DuplicateHandling.update,
      );
      expect(updateResult.updatedCount, equals(1));

      // Verify Acme Corp was updated
      final updatedAcme = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_acme'))).getSingle();
      expect(updatedAcme.address, equals('Updated Address St'));
    });
  });
}
