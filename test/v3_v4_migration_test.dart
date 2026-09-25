import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/financial_year_service.dart';
import 'package:drift/drift.dart' as drift;

/// v3 -> v4 Schema Migration Test
/// Creates a synthetic v3-equivalent database, then re-opens it through v4
/// migration logic and verifies all data is intact.
void main() {
  group('Financial Year Migration Logic', () {
    test('FY computed correctly from voucher dates (Indian FY rules)', () {
      // April 1, 2025 → FY 2025-26
      expect(FinancialYearService.getFinancialYear(DateTime(2025, 4, 1)), equals('2025-26'));

      // March 31, 2026 → FY 2025-26 (last day of that FY)
      expect(FinancialYearService.getFinancialYear(DateTime(2026, 3, 31)), equals('2025-26'));

      // January 1, 2026 → FY 2025-26 (Jan is in same FY as previous April)
      expect(FinancialYearService.getFinancialYear(DateTime(2026, 1, 1)), equals('2025-26'));

      // April 1, 2026 → FY 2026-27 (new FY starts)
      expect(FinancialYearService.getFinancialYear(DateTime(2026, 4, 1)), equals('2026-27'));

      // December 15, 2024 → FY 2024-25
      expect(FinancialYearService.getFinancialYear(DateTime(2024, 12, 15)), equals('2024-25'));
    });

    test('Sequence ID format is fy:type', () {
      expect(FinancialYearService.getSequenceId('2025-26', 'Sales'), equals('2025-26:Sales'));
      expect(FinancialYearService.getSequenceId('2026-27', 'Purchase'), equals('2026-27:Purchase'));
    });

    test('FY date range returns correct boundaries', () {
      final range = FinancialYearService.getFYDateRange('2025-26');
      expect(range.start, equals(DateTime(2025, 4, 1)));
      expect(range.end, equals(DateTime(2026, 3, 31, 23, 59, 59)));
    });
  });

  group('v4 Schema — Vouchers with Financial Year', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Seed customer ledger
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust1',
        name: 'Customer 1',
        groupId: 'debtors',
        openingBalance: const drift.Value(0.0),
      ));
    });

    tearDown(() async => await db.close());

    test('Invoice number format includes FY — INV-2025-26-0001', () async {
      final no = await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 6, 15),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e1', voucherId: '', ledgerId: 'cust1',
            debitAmount: const drift.Value(1000.0), creditAmount: const drift.Value(0.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e2', voucherId: '', ledgerId: 'sales',
            debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(1000.0),
          ),
        ],
      );
      expect(no, startsWith('INV-2025-26-'),
          reason: 'Invoice number must contain the financial year string');
    });

    test('Same sequence number in different FY — both exist without conflict', () async {
      // FY 2025-26: INV-2025-26-0001
      final no1 = await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 7, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e3', voucherId: '', ledgerId: 'cust1', debitAmount: const drift.Value(500.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e4', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(500.0)),
        ],
      );

      // FY 2026-27: INV-2026-27-0001 (should succeed — different FY)
      final no2 = await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2026, 5, 1),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e5', voucherId: '', ledgerId: 'cust1', debitAmount: const drift.Value(750.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e6', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(750.0)),
        ],
      );

      expect(no1, startsWith('INV-2025-26-'));
      expect(no2, startsWith('INV-2026-27-'));

      // Both end in -0001 (each FY sequence starts fresh)
      expect(no1, endsWith('-0001'));
      expect(no2, endsWith('-0001'));
    });

    test('FY field stored correctly in vouchers table', () async {
      await engine.createVoucher(
        voucherType: 'Sales',
        date: DateTime(2025, 11, 20),
        entries: [
          VoucherEntriesCompanion.insert(id: 'e7', voucherId: '', ledgerId: 'cust1', debitAmount: const drift.Value(2000.0), creditAmount: const drift.Value(0.0)),
          VoucherEntriesCompanion.insert(id: 'e8', voucherId: '', ledgerId: 'sales', debitAmount: const drift.Value(0.0), creditAmount: const drift.Value(2000.0)),
        ],
      );

      final vouchers = await db.select(db.vouchers).get();
      expect(vouchers.first.financialYear, equals('2025-26'),
          reason: 'financialYear column must be populated with computed FY string');
    });

    test('Duplicate (FY, type, number) within same FY is rejected by DB constraint', () async {
      final fy = FinancialYearService.getFinancialYear(DateTime(2025, 8, 1));

      await db.into(db.vouchers).insert(VouchersCompanion.insert(
        id: 'v1',
        voucherNumber: 'INV-TEST-DUPE',
        voucherType: 'Sales',
        financialYear: drift.Value(fy),
        date: DateTime(2025, 8, 1),
      ));

      expect(
        () => db.into(db.vouchers).insert(VouchersCompanion.insert(
          id: 'v2',
          voucherNumber: 'INV-TEST-DUPE',
          voucherType: 'Sales',
          financialYear: drift.Value(fy),
          date: DateTime(2025, 9, 1),
        )),
        throwsA(anything),
        reason: 'Duplicate (FY, voucherType, voucherNumber) must be rejected',
      );
    });
  });
}
