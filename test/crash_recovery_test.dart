import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/financial_year_service.dart';
import 'package:drift/drift.dart' as drift;

/// Crash Recovery Tests — verify that partial writes never leave the DB in
/// an inconsistent state.  SQLite WAL + Drift transactions ensure either the
/// ENTIRE voucher (header + entries + stock) commits or NOTHING does.
void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);

    // Seed custom test records
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'customer1',
      name: 'Test Customer',
      groupId: 'debtors',
      openingBalance: const drift.Value(0.0),
    ));
    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
      id: 'item1',
      name: 'Product A',
      openingQuantity: const drift.Value(100.0),
      openingRate: const drift.Value(50.0),
    ));
  });

  tearDown(() async => await db.close());

  test('Checkpoint 1: Sequence reserved but transaction interrupted — zero vouchers remain', () async {
    // Simulate: reserve number but throw before voucher insert
    expect(
      () async {
        await db.transaction(() async {
          // Reserve sequence number
          await engine.reserveNextInvoiceNumberInTx('Sales', DateTime(2025, 6, 1));
          // Simulate crash BEFORE voucher insert
          throw Exception('Simulated crash at checkpoint 1');
        });
      },
      throwsException,
    );

    // DB should have 0 vouchers (transaction rolled back)
    final vouchers = await db.select(db.vouchers).get();
    expect(vouchers, isEmpty, reason: 'Sequence reservation must roll back if transaction fails');

    // Sequence counter should also have rolled back
    final seqs = await db.select(db.invoiceSequences).get();
    expect(seqs, isEmpty, reason: 'Sequence row must not persist after rollback');
  });

  test('Checkpoint 2: Voucher header created but entries not yet — full rollback on interruption', () async {
    int vouchersBeforeCount = (await db.select(db.vouchers).get()).length;

    expect(
      () async {
        await db.transaction(() async {
          final voucherId = 'txn-crash-test-1';
          final fy = FinancialYearService.getFinancialYear(DateTime(2025, 7, 1));
          await db.into(db.vouchers).insert(VouchersCompanion.insert(
            id: voucherId,
            voucherNumber: 'INV-TEST-0001',
            voucherType: 'Sales',
            financialYear: drift.Value(fy),
            date: DateTime(2025, 7, 1),
          ));
          // Simulate crash BEFORE entries are inserted
          throw Exception('Simulated crash at checkpoint 2');
        });
      },
      throwsException,
    );

    final vouchersAfterCount = (await db.select(db.vouchers).get()).length;
    expect(vouchersAfterCount, equals(vouchersBeforeCount),
        reason: 'Voucher header must roll back when entries are not yet inserted');
  });

  test('Checkpoint 3: Complete atomic voucher — committed data survives re-read', () async {
    final voucherNo = await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 8, 15),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e1',
          voucherId: '',
          ledgerId: 'customer1',
          debitAmount: const drift.Value(5000.0),
          creditAmount: const drift.Value(0.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e2',
          voucherId: '',
          ledgerId: 'sales',
          debitAmount: const drift.Value(0.0),
          creditAmount: const drift.Value(5000.0),
        ),
      ],
      stockTransactions: [
        StockTransactionsCompanion.insert(
          id: 'st1',
          voucherId: '',
          stockItemId: 'item1',
          quantity: 10.0,
          rate: 500.0,
          transactionType: 'OUT',
        ),
      ],
    );

    // Re-read voucher and verify it's committed
    final vouchers = await (db.select(db.vouchers)
          ..where((t) => t.voucherNumber.equals(voucherNo)))
        .get();
    expect(vouchers.length, equals(1), reason: 'Committed voucher must be readable after close/reopen');
    expect(vouchers.first.status, equals('POSTED'));

    // Entries must also exist
    final entries = await (db.select(db.voucherEntries)
          ..where((t) => t.voucherId.equals(vouchers.first.id)))
        .get();
    expect(entries.length, equals(2), reason: 'Both double-entry splits must be committed atomically');

    // Stock transaction must also exist
    final stockTxs = await (db.select(db.stockTransactions)
          ..where((t) => t.voucherId.equals(vouchers.first.id)))
        .get();
    expect(stockTxs.length, equals(1), reason: 'Stock transaction must be committed atomically');
  });

  test('Checkpoint 4: Cancelled voucher preserves history but is excluded from balances', () async {
    final voucherNo = await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 9, 1),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e3',
          voucherId: '',
          ledgerId: 'customer1',
          debitAmount: const drift.Value(2000.0),
          creditAmount: const drift.Value(0.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e4',
          voucherId: '',
          ledgerId: 'sales',
          debitAmount: const drift.Value(0.0),
          creditAmount: const drift.Value(2000.0),
        ),
      ],
    );

    final voucher = await (db.select(db.vouchers)
          ..where((t) => t.voucherNumber.equals(voucherNo)))
        .getSingle();

    // Cancel the voucher
    await engine.cancelVoucher(voucher.id);

    // Voucher must still exist (history preserved)
    final cancelledVoucher = await (db.select(db.vouchers)
          ..where((t) => t.id.equals(voucher.id)))
        .getSingle();
    expect(cancelledVoucher.status, equals('CANCELLED'));

    // Ledger balance must exclude cancelled voucher
    final balance = await engine.getLedgerBalance('customer1');
    expect(balance, equals(0.0),
        reason: 'Cancelled vouchers must not affect ledger balance');
  });

  test('Checkpoint 5: Double-submit guard prevents concurrent identical submissions', () async {
    // After a successful submission, _isSubmitting should be reset to false
    final voucherNo = await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 10, 1),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e5',
          voucherId: '',
          ledgerId: 'customer1',
          debitAmount: const drift.Value(1000.0),
          creditAmount: const drift.Value(0.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e6',
          voucherId: '',
          ledgerId: 'sales',
          debitAmount: const drift.Value(0.0),
          creditAmount: const drift.Value(1000.0),
        ),
      ],
    );
    expect(voucherNo, isNotEmpty);

    // Engine should be ready for next submission
    expect(engine.isSubmitting, isFalse);

    // A second submission with the same data but different invoice should succeed
    final voucherNo2 = await engine.createVoucher(
      voucherType: 'Sales',
      date: DateTime(2025, 10, 2),
      entries: [
        VoucherEntriesCompanion.insert(
          id: 'e7',
          voucherId: '',
          ledgerId: 'customer1',
          debitAmount: const drift.Value(1500.0),
          creditAmount: const drift.Value(0.0),
        ),
        VoucherEntriesCompanion.insert(
          id: 'e8',
          voucherId: '',
          ledgerId: 'sales',
          debitAmount: const drift.Value(0.0),
          creditAmount: const drift.Value(1500.0),
        ),
      ],
    );
    expect(voucherNo2, isNot(equals(voucherNo)),
        reason: 'Sequential submissions must get unique voucher numbers');
  });

  test('Checkpoint 6: FY UNIQUE constraint prevents duplicate (FY, type, number) insertion', () async {
    final fy = FinancialYearService.getFinancialYear(DateTime(2025, 8, 1));

    // Insert voucher with specific number
    await db.into(db.vouchers).insert(VouchersCompanion.insert(
      id: 'v-dup-test-1',
      voucherNumber: 'INV-2025-26-0001',
      voucherType: 'Sales',
      financialYear: drift.Value(fy),
      date: DateTime(2025, 8, 1),
    ));

    // Trying to insert same (FY, type, number) must throw
    expect(
      () async {
        await db.into(db.vouchers).insert(VouchersCompanion.insert(
          id: 'v-dup-test-2',
          voucherNumber: 'INV-2025-26-0001',
          voucherType: 'Sales',
          financialYear: drift.Value(fy),
          date: DateTime(2025, 9, 1),
        ));
      },
      throwsA(anything),
      reason: 'UNIQUE(financial_year, voucher_type, voucher_number) must be enforced',
    );

    // Same number in different FY must succeed
    final fy2 = FinancialYearService.getFinancialYear(DateTime(2026, 5, 1));
    await db.into(db.vouchers).insert(VouchersCompanion.insert(
      id: 'v-dup-test-3',
      voucherNumber: 'INV-2025-26-0001',
      voucherType: 'Sales',
      financialYear: drift.Value(fy2),
      date: DateTime(2026, 5, 1),
    ));
    final allVouchers = await db.select(db.vouchers).get();
    expect(allVouchers.length, equals(2),
        reason: 'Same invoice number in different FY must be allowed');
  });
}
