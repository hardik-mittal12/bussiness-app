import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/financial_year_service.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Invoice numbers increment sequentially inside transactions', () async {
    final now = DateTime.now();
    final fy = FinancialYearService.getFinancialYear(now);
    final seq1 = await engine.reserveNextInvoiceNumberInTx('Sales', now);
    final seq2 = await engine.reserveNextInvoiceNumberInTx('Sales', now);
    final seq3 = await engine.reserveNextInvoiceNumberInTx('Sales', now);

    expect(seq1, equals('INV-$fy-0001'));
    expect(seq2, equals('INV-$fy-0002'));
    expect(seq3, equals('INV-$fy-0003'));
  });

  test('Purchase voucher numbers use PUR prefix and separate sequence', () async {
    final now = DateTime.now();
    final fy = FinancialYearService.getFinancialYear(now);
    final salesSeq = await engine.reserveNextInvoiceNumberInTx('Sales', now);
    final purSeq = await engine.reserveNextInvoiceNumberInTx('Purchase', now);

    expect(salesSeq, equals('INV-$fy-0001'));
    expect(purSeq, equals('PUR-$fy-0001'));
  });

  test('Duplicate voucher number per voucher type is rejected by database constraint', () async {
    final now = DateTime.now();
    final fy = FinancialYearService.getFinancialYear(now);
    await db.into(db.vouchers).insert(VouchersCompanion.insert(
      id: 'v1',
      voucherNumber: 'INV-$fy-0001',
      voucherType: 'Sales',
      financialYear: drift.Value(fy),
      date: now,
    ));

    expect(
      () async => await db.into(db.vouchers).insert(VouchersCompanion.insert(
        id: 'v2',
        voucherNumber: 'INV-$fy-0001',
        voucherType: 'Sales',
        financialYear: drift.Value(fy),
        date: now,
      )),
      throwsA(isA<Object>()),
    );
  });
}
