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

    // Create a customer ledger
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_1',
      name: 'Test Customer',
      groupId: 'debtors',
    ));
  });

  tearDown(() async {
    await db.close();
  });

  test('Unbalanced voucher (Debits != Credits) throws validation exception', () async {
    final entries = [
      VoucherEntriesCompanion.insert(
        id: 'e1',
        voucherId: '',
        ledgerId: 'cust_1',
        debitAmount: const drift.Value(100.0),
        creditAmount: const drift.Value(0.0),
      ),
      VoucherEntriesCompanion.insert(
        id: 'e2',
        voucherId: '',
        ledgerId: 'sales',
        debitAmount: const drift.Value(0.0),
        creditAmount: const drift.Value(90.0), // Unbalanced by 10.0!
      ),
    ];

    expect(
      () => engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime.now(),
        entries: entries,
      ),
      throwsException,
    );

    final vouchers = await db.select(db.vouchers).get();
    expect(vouchers.isEmpty, isTrue);
  });

  test('Atomic transaction rolls back completely on invalid stock item failure', () async {
    final entries = [
      VoucherEntriesCompanion.insert(
        id: 'e1',
        voucherId: '',
        ledgerId: 'cust_1',
        debitAmount: const drift.Value(100.0),
        creditAmount: const drift.Value(0.0),
      ),
      VoucherEntriesCompanion.insert(
        id: 'e2',
        voucherId: '',
        ledgerId: 'sales',
        debitAmount: const drift.Value(0.0),
        creditAmount: const drift.Value(100.0),
      ),
    ];

    final invalidStockTxs = [
      StockTransactionsCompanion.insert(
        id: 'st1',
        voucherId: '',
        stockItemId: 'non_existent_item_id', // Causes Foreign Key Failure!
        quantity: 10.0,
        rate: 10.0,
        transactionType: 'OUT',
      ),
    ];

    expect(
      () => engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime.now(),
        entries: entries,
        stockTransactions: invalidStockTxs,
      ),
      throwsA(isA<Object>()),
    );

    // Verify ZERO orphan voucher or entries exist after failure
    final vouchers = await db.select(db.vouchers).get();
    final voucherEntries = await db.select(db.voucherEntries).get();
    final stockTxs = await db.select(db.stockTransactions).get();

    expect(vouchers.isEmpty, isTrue);
    expect(voucherEntries.isEmpty, isTrue);
    expect(stockTxs.isEmpty, isTrue);
  });
}
