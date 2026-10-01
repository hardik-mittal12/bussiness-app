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
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: 'cust_1',
            name: 'Customer 1',
            groupId: 'debtors',
          ),
        );
    await db
        .into(db.ledgers)
        .insert(
          LedgersCompanion.insert(
            id: 'supp_1',
            name: 'Supplier 1',
            groupId: 'creditors',
          ),
        );
    await db
        .into(db.stockItems)
        .insert(
          StockItemsCompanion.insert(
            id: 'item_1',
            name: 'Item 1',
            openingQuantity: const drift.Value(0.0),
          ),
        );

    // Create Purchase: Rs 1000
    await engine.createVoucher(
      voucherType: 'Purchase',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e1',
          voucherId: '',
          ledgerId: 'purchase',
          debitAmount: const drift.Value(1000.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e2',
          voucherId: '',
          ledgerId: 'supp_1',
          creditAmount: const drift.Value(1000.0),
        ),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'st1',
          voucherId: '',
          stockItemId: 'item_1',
          quantity: 10.0,
          rate: 100.0,
          transactionType: 'IN',
        ),
      ],
    );

    // Create Sale: Rs 1500 (5 units @ Rs 300)
    await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime.now(),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e3',
          voucherId: '',
          ledgerId: 'cust_1',
          debitAmount: const drift.Value(1500.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e4',
          voucherId: '',
          ledgerId: 'sales',
          creditAmount: const drift.Value(1500.0),
        ),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'st2',
          voucherId: '',
          stockItemId: 'item_1',
          quantity: 5.0,
          rate: 300.0,
          transactionType: 'OUT',
        ),
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
    expect(
      pl.closingStockValue,
      equals(500.0),
    ); // 5 units @ 100 avg cost left = 500
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

  test('Day Book total ignores balanced party-reference rows', () async {
    await engine.createVoucher(
      voucherNumber: 'SALE-REFERENCE-1',
      voucherType: 'Sales',
      date: DateTime(2026, 10, 1, 12),
      partyLedgerId: 'cust_1',
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'cash_entry',
          voucherId: '',
          ledgerId: 'cust_1',
          debitAmount: const drift.Value(100.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'party_reference',
          voucherId: '',
          ledgerId: 'cust_1',
          debitAmount: const drift.Value(100.0),
          creditAmount: const drift.Value(100.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'sales_entry',
          voucherId: '',
          ledgerId: 'cust_1',
          creditAmount: const drift.Value(100.0),
        ),
      ],
    );

    final rows = await engine.getDayBook(limit: 20);
    final row = rows.singleWhere(
      (entry) => entry.voucherNumber == 'SALE-REFERENCE-1',
    );

    expect(row.totalAmount, 100.0);
  });

  test(
    'Day Book lifecycle matrix matches vouchers, ledgers, and inventory',
    () async {
      await db.batch((batch) {
        batch.insertAll(db.ledgers, [
          LedgersCompanion.insert(
            id: 'bank_test',
            name: 'Test Bank',
            groupId: 'bank_accounts',
          ),
          LedgersCompanion.insert(
            id: 'expense_test',
            name: 'Office Expense',
            groupId: 'direct_expenses',
          ),
        ]);
      });
      await db
          .into(db.stockItems)
          .insert(
            StockItemsCompanion.insert(
              id: 'item_2',
              name: 'Second Matrix Item',
              openingQuantity: const drift.Value(20.0),
              openingRate: const drift.Value(10.0),
            ),
          );
      await db
          .into(db.ledgers)
          .insert(
            LedgersCompanion.insert(
              id: 'opening_test',
              name: 'Opening Balance Account',
              groupId: 'cash_in_hand',
              openingBalance: const drift.Value(50.0),
            ),
          );

      VoucherEntriesCompanion entry(
        String id,
        String ledgerId, {
        double debit = 0,
        double credit = 0,
      }) => VoucherEntriesCompanion.insert(
        id: id,
        voucherId: '',
        ledgerId: ledgerId,
        debitAmount: drift.Value(debit),
        creditAmount: drift.Value(credit),
      );

      StockTransactionsCompanion movement(
        String id,
        String itemId, {
        required double quantity,
        required double rate,
        required String type,
      }) => StockTransactionsCompanion.insert(
        id: id,
        voucherId: '',
        stockItemId: itemId,
        quantity: quantity,
        rate: rate,
        transactionType: type,
      );

      Future<Voucher> postAndVerify({
        required String number,
        required String type,
        required DateTime date,
        required List<VoucherEntriesCompanion> entries,
        String? partyLedgerId,
        String? paymentMode,
        String? referenceNumber,
        List<StockTransactionsCompanion> stockTransactions = const [],
      }) async {
        final ledgerBalancesBefore = <String, double>{};
        for (final line in entries) {
          final ledgerId = line.ledgerId.value;
          if (!ledgerBalancesBefore.containsKey(ledgerId)) {
            ledgerBalancesBefore[ledgerId] = await engine.getLedgerBalance(
              ledgerId,
            );
          }
        }
        final stockBefore = <String, double>{};
        for (final movement in stockTransactions) {
          final itemId = movement.stockItemId.value;
          if (!stockBefore.containsKey(itemId)) {
            stockBefore[itemId] = (await engine.getStockSummaryForItem(
              itemId,
            )).quantity;
          }
        }

        await engine.createVoucher(
          voucherNumber: number,
          voucherType: type,
          date: date,
          narration: 'Matrix: $number',
          referenceNumber: referenceNumber,
          paymentMode: paymentMode,
          partyLedgerId: partyLedgerId,
          entries: entries,
          stockTransactions: stockTransactions,
        );

        final voucher = await (db.select(
          db.vouchers,
        )..where((row) => row.voucherNumber.equals(number))).getSingle();
        expect(voucher.voucherType, type);
        expect(voucher.date, date);
        expect(voucher.partyLedgerId, partyLedgerId);
        expect(voucher.referenceNumber, referenceNumber);
        expect(voucher.paymentMode, paymentMode);
        expect(voucher.narration, 'Matrix: $number');

        final savedEntries = await (db.select(
          db.voucherEntries,
        )..where((row) => row.voucherId.equals(voucher.id))).get();
        expect(savedEntries, hasLength(entries.length));
        final expectedDebit = entries.fold<double>(
          0,
          (sum, line) => sum + line.debitAmount.value,
        );
        final expectedCredit = entries.fold<double>(
          0,
          (sum, line) => sum + line.creditAmount.value,
        );
        expect(expectedDebit, expectedCredit);

        for (final ledgerId in ledgerBalancesBefore.keys) {
          final debit = savedEntries
              .where((line) => line.ledgerId == ledgerId)
              .fold<double>(0, (sum, line) => sum + line.debitAmount);
          final credit = savedEntries
              .where((line) => line.ledgerId == ledgerId)
              .fold<double>(0, (sum, line) => sum + line.creditAmount);
          expect(
            await engine.getLedgerBalance(ledgerId),
            closeTo(ledgerBalancesBefore[ledgerId]! + debit - credit, 0.001),
            reason: '$number ledger balance for $ledgerId',
          );
        }

        for (final itemId in stockBefore.keys) {
          final quantityChange = stockTransactions
              .where((line) => line.stockItemId.value == itemId)
              .fold<double>(
                0,
                (sum, line) =>
                    sum +
                    (line.transactionType.value == 'IN'
                        ? line.quantity.value
                        : -line.quantity.value),
              );
          expect(
            (await engine.getStockSummaryForItem(itemId)).quantity,
            closeTo(stockBefore[itemId]! + quantityChange, 0.001),
            reason: '$number stock quantity for $itemId',
          );
        }

        final dayRows = await engine.getDayBook(limit: 500);
        final matches = dayRows.where((row) => row.voucherId == voucher.id);
        expect(matches, hasLength(1), reason: 'One Day Book row for $number');
        final dayRow = matches.single;
        expect(dayRow.totalDebit, expectedDebit);
        expect(dayRow.totalCredit, expectedCredit);
        expect(dayRow.totalAmount, expectedDebit);
        expect(dayRow.partyLedgerId, partyLedgerId);
        expect(dayRow.partyName, partyLedgerId == null ? isNull : isNotNull);
        if (partyLedgerId != null) {
          final expectedParty = await (db.select(
            db.ledgers,
          )..where((ledger) => ledger.id.equals(partyLedgerId))).getSingle();
          expect(dayRow.partyName, expectedParty.name);
        }
        expect(dayRow.referenceNumber, referenceNumber);
        expect(dayRow.paymentMode, paymentMode);
        return voucher;
      }

      final dayOne = DateTime(2026, 10, 10, 9, 15);
      final dayTwo = DateTime(2026, 10, 11, 14, 30);
      final dayThree = DateTime(2026, 10, 12, 16, 45);
      final dayFour = DateTime(2026, 10, 13, 11, 5);

      final cashSale = await postAndVerify(
        number: 'MATRIX-CASH-SALE',
        type: 'Sales',
        date: dayOne,
        partyLedgerId: 'cust_1',
        paymentMode: 'Cash',
        referenceNumber: 'POS-100',
        entries: [
          entry('cash_sale_dr', 'cash', debit: 100),
          entry('cash_sale_cr', 'sales', credit: 100),
        ],
        stockTransactions: [
          movement(
            'cash_sale_stock',
            'item_1',
            quantity: 1,
            rate: 100,
            type: 'OUT',
          ),
        ],
      );

      final creditSale = await postAndVerify(
        number: 'MATRIX-CREDIT-SALE',
        type: 'Sales',
        date: dayOne,
        partyLedgerId: 'cust_1',
        paymentMode: 'Debt',
        entries: [
          entry('credit_sale_dr', 'cust_1', debit: 200),
          entry('credit_sale_cr', 'sales', credit: 200),
        ],
        stockTransactions: [
          movement(
            'credit_sale_stock_1',
            'item_1',
            quantity: 2,
            rate: 50,
            type: 'OUT',
          ),
          movement(
            'credit_sale_stock_2',
            'item_2',
            quantity: 3,
            rate: 50,
            type: 'OUT',
          ),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-CASH-PURCHASE',
        type: 'Purchase',
        date: dayOne,
        partyLedgerId: 'supp_1',
        paymentMode: 'Cash',
        entries: [
          entry('cash_purchase_dr', 'purchase', debit: 75),
          entry('cash_purchase_cr', 'cash', credit: 75),
        ],
        stockTransactions: [
          movement(
            'cash_purchase_stock',
            'item_1',
            quantity: 5,
            rate: 15,
            type: 'IN',
          ),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-CREDIT-PURCHASE',
        type: 'Purchase',
        date: dayTwo,
        partyLedgerId: 'supp_1',
        paymentMode: 'Debt',
        entries: [
          entry('credit_purchase_dr', 'purchase', debit: 90),
          entry('credit_purchase_cr', 'supp_1', credit: 90),
        ],
        stockTransactions: [
          movement(
            'credit_purchase_stock',
            'item_2',
            quantity: 3,
            rate: 30,
            type: 'IN',
          ),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-RECEIPT',
        type: 'Receipt',
        date: dayTwo,
        partyLedgerId: 'cust_1',
        paymentMode: 'NEFT',
        referenceNumber: 'UTR-200',
        entries: [
          entry('receipt_bank_dr', 'bank_test', debit: 40),
          entry('receipt_customer_cr', 'cust_1', credit: 40),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-SUPPLIER-PAYMENT',
        type: 'Payment',
        date: dayTwo,
        partyLedgerId: 'supp_1',
        paymentMode: 'UPI',
        referenceNumber: 'UPI-201',
        entries: [
          entry('payment_supplier_dr', 'supp_1', debit: 25),
          entry('payment_bank_cr', 'bank_test', credit: 25),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-EXPENSE',
        type: 'Expense',
        date: dayThree,
        paymentMode: 'Cash',
        entries: [
          entry('expense_dr', 'expense_test', debit: 12),
          entry('expense_cash_cr', 'cash', credit: 12),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-SALES-RETURN',
        type: 'Sales Return',
        date: dayThree,
        partyLedgerId: 'cust_1',
        entries: [
          entry('sales_return_dr', 'sales', debit: 8),
          entry('sales_return_customer_cr', 'cust_1', credit: 8),
        ],
        stockTransactions: [
          movement(
            'sales_return_stock',
            'item_1',
            quantity: 1,
            rate: 8,
            type: 'IN',
          ),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-PURCHASE-RETURN',
        type: 'Purchase Return',
        date: dayFour,
        partyLedgerId: 'supp_1',
        entries: [
          entry('purchase_return_supplier_dr', 'supp_1', debit: 5),
          entry('purchase_return_cr', 'purchase', credit: 5),
        ],
        stockTransactions: [
          movement(
            'purchase_return_stock',
            'item_1',
            quantity: 1,
            rate: 5,
            type: 'OUT',
          ),
        ],
      );

      await postAndVerify(
        number: 'MATRIX-JOURNAL-ADJUSTMENT',
        type: 'Journal',
        date: dayFour,
        entries: [
          entry('adjustment_dr', 'expense_test', debit: 2),
          entry('adjustment_cr', 'bank_test', credit: 2),
        ],
      );

      final rowsBeforeLifecycle = await engine.getDayBook(limit: 500);
      expect(
        rowsBeforeLifecycle.map((row) => row.voucherId).toSet().length,
        rowsBeforeLifecycle.length,
      );
      for (var index = 0; index < rowsBeforeLifecycle.length - 1; index++) {
        expect(
          rowsBeforeLifecycle[index].date.isAfter(
                rowsBeforeLifecycle[index + 1].date,
              ) ||
              rowsBeforeLifecycle[index].date.isAtSameMomentAs(
                rowsBeforeLifecycle[index + 1].date,
              ),
          isTrue,
        );
      }
      final dayStart = DateTime(2026, 10, 10);
      final dayEnd = DateTime(2026, 10, 10, 23, 59, 59, 999);
      final rawDateMatches = await db
          .customSelect(
            'SELECT id FROM vouchers WHERE date >= ? AND date <= ?',
            variables: [
              drift.Variable.withDateTime(dayStart),
              drift.Variable.withDateTime(dayEnd),
            ],
          )
          .get();
      expect(rawDateMatches, hasLength(3));

      final dayOneRows = await engine.getDayBook(
        startDate: dayStart,
        endDate: dayEnd,
        limit: 500,
      );
      expect(dayOneRows.where((row) => row.date.day == 10).length, 3);

      expect(await engine.getLedgerBalance('opening_test'), 50.0);
      expect(
        rowsBeforeLifecycle.any((row) => row.partyLedgerId == 'opening_test'),
        isFalse,
      );

      final oldCashBalance = await engine.getLedgerBalance('cash');
      final oldSalesBalance = await engine.getLedgerBalance('sales');
      final oldItemQuantity = (await engine.getStockSummaryForItem(
        'item_1',
      )).quantity;
      await engine.createVoucher(
        voucherNumber: cashSale.voucherNumber,
        existingVoucherId: cashSale.id,
        voucherType: 'Sales',
        date: DateTime(2026, 10, 15, 10),
        partyLedgerId: 'cust_1',
        paymentMode: 'Cash',
        narration: 'Edited cash sale',
        entries: [
          entry('edited_cash_sale_dr', 'cash', debit: 90),
          entry('edited_cash_sale_cr', 'sales', credit: 90),
        ],
        stockTransactions: [
          movement(
            'edited_cash_sale_stock',
            'item_1',
            quantity: 2,
            rate: 45,
            type: 'OUT',
          ),
        ],
      );
      final editedRows = await engine.getDayBook(limit: 500);
      final editedCashRows = editedRows.where(
        (row) => row.voucherId == cashSale.id,
      );
      expect(editedCashRows, hasLength(1));
      expect(editedCashRows.single.date, DateTime(2026, 10, 15, 10));
      expect(editedCashRows.single.totalDebit, 90.0);
      expect(editedCashRows.single.totalCredit, 90.0);
      expect(await engine.getLedgerBalance('cash'), oldCashBalance - 10);
      expect(await engine.getLedgerBalance('sales'), oldSalesBalance + 10);
      expect(
        await engine.getStockSummaryForItem('item_1').then((s) => s.quantity),
        oldItemQuantity - 1,
      );

      final customerBeforeCancel = await engine.getLedgerBalance('cust_1');
      final stockBeforeCancel = (await engine.getStockSummaryForItem(
        'item_1',
      )).quantity;
      await engine.cancelVoucher(creditSale.id);
      expect(
        (await engine.getDayBook(
          limit: 500,
        )).any((row) => row.voucherId == creditSale.id),
        isFalse,
      );
      expect(
        await engine.getLedgerBalance('cust_1'),
        customerBeforeCancel - 200,
      );
      expect(
        (await engine.getStockSummaryForItem('item_1')).quantity,
        stockBeforeCancel + 2,
      );

      await engine.deleteVoucher(cashSale.id);
      expect(
        await (db.select(
          db.vouchers,
        )..where((row) => row.id.equals(cashSale.id))).getSingleOrNull(),
        isNull,
      );
      expect(
        await (db.select(
          db.voucherEntries,
        )..where((row) => row.voucherId.equals(cashSale.id))).get(),
        isEmpty,
      );
      expect(
        (await engine.getDayBook(
          limit: 500,
        )).any((row) => row.voucherId == cashSale.id),
        isFalse,
      );
    },
  );
}
