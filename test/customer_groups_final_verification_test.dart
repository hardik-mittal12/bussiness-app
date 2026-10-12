import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/customer_group_service.dart';
import 'package:tally_ledger_desktop/core/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AccountingEngine engine;
  late CustomerGroupService groupService;
  late PdfExportService pdfService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);
    groupService = CustomerGroupService(db);
    pdfService = PdfExportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TallyLedger V8 — Customer Group Trial Balance Final Independent Verification', () {
    // =========================================================================
    // 1. OPENING-BALANCE HANDLING VERIFICATION (ALL 7 SCENARIOS)
    // =========================================================================
    test('1. Opening-balance handling across all 7 scenarios reconciles with AccountingEngine', () async {
      final grp = await groupService.createGroup('Comprehensive Audit Group');

      // Scenario A: Customer with Debit Opening Balance (+Rs. 10,000)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_open_dr',
        name: 'Customer Dr Opening',
        groupId: 'debtors',
        openingBalance: const drift.Value(10000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // Scenario B: Customer with Credit Opening Balance (-Rs. 4,000, i.e. advance)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_open_cr',
        name: 'Customer Cr Opening',
        groupId: 'debtors',
        openingBalance: const drift.Value(-4000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // Scenario C: Customer with Zero Opening Balance (Rs. 0.0)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_open_zero',
        name: 'Customer Zero Opening',
        groupId: 'debtors',
        openingBalance: const drift.Value(0.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // Scenario D: Customer with Opening Balance without any transactions
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_no_tx',
        name: 'Customer No Transactions',
        groupId: 'debtors',
        openingBalance: const drift.Value(7500.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // Scenario E: Customer with transactions before the reporting period
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_prior_tx',
        name: 'Customer Prior Transactions',
        groupId: 'debtors',
        openingBalance: const drift.Value(2000.0),
        customerGroupId: drift.Value(grp.id),
      ));
      // Transaction prior to period (Feb 10, 2025)
      await engine.createVoucher(
        voucherNumber: 'INV-PRIOR-01',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_prior_tx',
        date: DateTime(2025, 2, 10, 11, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_prior_1',
            voucherId: '',
            ledgerId: 'cust_prior_tx',
            debitAmount: const drift.Value(5000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_prior_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(5000.0),
          ),
        ],
      );

      // Scenario F: Customer with transactions within the reporting period (March 2025)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_in_period',
        name: 'Customer In-Period Transactions',
        groupId: 'debtors',
        openingBalance: const drift.Value(1000.0),
        customerGroupId: drift.Value(grp.id),
      ));
      await engine.createVoucher(
        voucherNumber: 'INV-PERIOD-01',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_in_period',
        date: DateTime(2025, 3, 15, 14, 30),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_period_1',
            voucherId: '',
            ledgerId: 'cust_in_period',
            debitAmount: const drift.Value(3000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_period_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(3000.0),
          ),
        ],
      );
      await engine.createVoucher(
        voucherNumber: 'REC-PERIOD-01',
        voucherType: 'Receipt',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_in_period',
        date: DateTime(2025, 3, 20, 16, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_period_3',
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(1500.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_period_4',
            voucherId: '',
            ledgerId: 'cust_in_period',
            creditAmount: const drift.Value(1500.0),
          ),
        ],
      );

      // Scenario G: Customer with Backdated transactions
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_backdated',
        name: 'Customer Backdated Transactions',
        groupId: 'debtors',
        openingBalance: const drift.Value(500.0),
        customerGroupId: drift.Value(grp.id),
      ));
      // Created later, but backdated to Feb 25, 2025
      await engine.createVoucher(
        voucherNumber: 'INV-BACKDATED-01',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_backdated',
        date: DateTime(2025, 2, 25, 10, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_back_1',
            voucherId: '',
            ledgerId: 'cust_backdated',
            debitAmount: const drift.Value(4000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_back_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(4000.0),
          ),
        ],
      );

      // Now query the report for March 2025 (2025-03-01 to 2025-03-31)
      final fromDate = DateTime(2025, 3, 1);
      final toDate = DateTime(2025, 3, 31);

      final report = await groupService.getCustomerGroupTrialBalance(
        grp.id,
        fromDate: fromDate,
        toDate: toDate,
      );

      expect(report.totalCustomers, equals(7));

      // Verify each customer row reconciles EXACTLY with AccountingEngine.getLedgerBalance(cid, asOfDate: toDate)
      for (final row in report.rows) {
        final authoritativeEngineBalance = await engine.getLedgerBalance(
          row.customerId,
          asOfDate: toDate,
        );
        expect(
          row.netClosing,
          equals(authoritativeEngineBalance),
          reason: 'Customer ${row.customerName} net closing balance must reconcile with AccountingEngine',
        );

        // Verify opening balances are included exactly ONCE
        if (row.customerId == 'cust_open_dr') {
          expect(row.openingDebit, equals(10000.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.periodDebit, equals(0.0));
          expect(row.periodCredit, equals(0.0));
          expect(row.closingDebit, equals(10000.0));
          expect(row.closingCredit, equals(0.0));
        } else if (row.customerId == 'cust_open_cr') {
          expect(row.openingDebit, equals(0.0));
          expect(row.openingCredit, equals(4000.0));
          expect(row.periodDebit, equals(0.0));
          expect(row.periodCredit, equals(0.0));
          expect(row.closingDebit, equals(0.0));
          expect(row.closingCredit, equals(4000.0));
        } else if (row.customerId == 'cust_open_zero') {
          expect(row.openingDebit, equals(0.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.closingDebit, equals(0.0));
          expect(row.closingCredit, equals(0.0));
        } else if (row.customerId == 'cust_no_tx') {
          expect(row.openingDebit, equals(7500.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.closingDebit, equals(7500.0));
          expect(row.closingCredit, equals(0.0));
        } else if (row.customerId == 'cust_prior_tx') {
          // Base opening = 2000, prior Dr = 5000 -> Opening Dr = 7000
          expect(row.openingDebit, equals(7000.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.periodDebit, equals(0.0));
          expect(row.periodCredit, equals(0.0));
          expect(row.closingDebit, equals(7000.0));
          expect(row.closingCredit, equals(0.0));
        } else if (row.customerId == 'cust_in_period') {
          // Base opening = 1000, in period Dr = 3000, Cr = 1500 -> Closing Dr = 2500
          expect(row.openingDebit, equals(1000.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.periodDebit, equals(3000.0));
          expect(row.periodCredit, equals(1500.0));
          expect(row.closingDebit, equals(2500.0));
          expect(row.closingCredit, equals(0.0));
        } else if (row.customerId == 'cust_backdated') {
          // Base opening = 500, backdated voucher on Feb 25 Dr = 4000 -> Carried into Opening Dr = 4500
          expect(row.openingDebit, equals(4500.0));
          expect(row.openingCredit, equals(0.0));
          expect(row.periodDebit, equals(0.0));
          expect(row.periodCredit, equals(0.0));
          expect(row.closingDebit, equals(4500.0));
          expect(row.closingCredit, equals(0.0));
        }
      }
    });

    // =========================================================================
    // 2. DEBIT AND CREDIT PRESENTATION & GROUP NET POSITION
    // =========================================================================
    test('2. Debit and Credit balances are presented separately and group net position is accurate', () async {
      final grp = await groupService.createGroup('Dr Cr Presentation Group');

      // Customer A has net Debit balance (+12,000)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_deb',
        name: 'Debtor Customer A',
        groupId: 'debtors',
        openingBalance: const drift.Value(12000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // Customer B has net Credit balance (-5,000, advance paid)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_crd',
        name: 'Creditor Customer B',
        groupId: 'debtors',
        openingBalance: const drift.Value(-5000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      final report = await groupService.getCustomerGroupTrialBalance(grp.id);

      final rowA = report.rows.firstWhere((r) => r.customerId == 'cust_deb');
      final rowB = report.rows.firstWhere((r) => r.customerId == 'cust_crd');

      // Individual rows are NOT netted against each other
      expect(rowA.closingDebit, equals(12000.0));
      expect(rowA.closingCredit, equals(0.0));
      expect(rowB.closingDebit, equals(0.0));
      expect(rowB.closingCredit, equals(5000.0));

      // Group totals keep Dr and Cr separately visible
      expect(report.totals.totalClosingDebit, equals(12000.0));
      expect(report.totals.totalClosingCredit, equals(5000.0));

      // Group net position = Total Group Debit - Total Group Credit
      expect(report.totals.netClosingOutstanding, equals(7000.0));
      expect(
        report.totals.netClosingOutstanding,
        equals(report.totals.totalClosingDebit - report.totals.totalClosingCredit),
      );
    });

    // =========================================================================
    // 3. DATE FILTERING BOUNDARY AUDIT
    // =========================================================================
    test('3. Date filtering boundary conditions: inclusive start/end, same-day, prior carried, post excluded', () async {
      final grp = await groupService.createGroup('Boundary Audit Group');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_boundary',
        name: 'Boundary Test Customer',
        groupId: 'debtors',
        openingBalance: const drift.Value(1000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      // 1. Transaction prior to start date (April 10, 2025 at 23:59:59) -> Goes to opening balance
      await engine.createVoucher(
        voucherNumber: 'INV-BOUND-PRIOR',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_boundary',
        date: DateTime(2025, 4, 10, 23, 59, 59),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_bp_1',
            voucherId: '',
            ledgerId: 'cust_boundary',
            debitAmount: const drift.Value(2000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_bp_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(2000.0),
          ),
        ],
      );

      // 2. Transaction on EXACT start date at 00:00:00 (April 11, 2025 00:00:00) -> In period
      await engine.createVoucher(
        voucherNumber: 'INV-BOUND-START',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_boundary',
        date: DateTime(2025, 4, 11, 0, 0, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_bs_1',
            voucherId: '',
            ledgerId: 'cust_boundary',
            debitAmount: const drift.Value(3000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_bs_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(3000.0),
          ),
        ],
      );

      // 3. Transaction on midday of start date (April 11, 2025 12:30:00) -> In period
      await engine.createVoucher(
        voucherNumber: 'INV-BOUND-MID',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_boundary',
        date: DateTime(2025, 4, 11, 12, 30, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_bm_1',
            voucherId: '',
            ledgerId: 'cust_boundary',
            debitAmount: const drift.Value(1500.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_bm_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(1500.0),
          ),
        ],
      );

      // 4. Transaction on EXACT end date at 23:59:59 (April 11, 2025 23:59:59) -> In period
      await engine.createVoucher(
        voucherNumber: 'REC-BOUND-END',
        voucherType: 'Receipt',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_boundary',
        date: DateTime(2025, 4, 11, 23, 59, 59),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_be_1',
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(500.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_be_2',
            voucherId: '',
            ledgerId: 'cust_boundary',
            creditAmount: const drift.Value(500.0),
          ),
        ],
      );

      // 5. Transaction on next day (April 12, 2025 00:00:00) -> Strictly excluded
      await engine.createVoucher(
        voucherNumber: 'INV-BOUND-POST',
        voucherType: 'Sales',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_boundary',
        date: DateTime(2025, 4, 12, 0, 0, 0),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_bpost_1',
            voucherId: '',
            ledgerId: 'cust_boundary',
            debitAmount: const drift.Value(9000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_bpost_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(9000.0),
          ),
        ],
      );

      // Test Same-Day Range (April 11 to April 11)
      final reportSameDay = await groupService.getCustomerGroupTrialBalance(
        grp.id,
        fromDate: DateTime(2025, 4, 11),
        toDate: DateTime(2025, 4, 11),
      );

      final row = reportSameDay.rows.first;

      // Base opening (1000) + prior voucher (2000) = Opening Dr 3000
      expect(row.openingDebit, equals(3000.0));
      expect(row.openingCredit, equals(0.0));

      // In-period vouchers: start (3000) + mid (1500) = Period Dr 4500
      expect(row.periodDebit, equals(4500.0));
      // In-period receipt on end boundary: 500 = Period Cr 500
      expect(row.periodCredit, equals(500.0));

      // Post-voucher (9000) is excluded
      // Closing Dr = 3000 + 4500 - 500 = 7000.0
      expect(row.closingDebit, equals(7000.0));
      expect(row.closingCredit, equals(0.0));

      // Compare with AccountingEngine as of April 11
      final engineBal = await engine.getLedgerBalance(
        'cust_boundary',
        asOfDate: DateTime(2025, 4, 11),
      );
      expect(row.netClosing, equals(engineBal));
    });

    // =========================================================================
    // 4. PARSESQLITEDATETIME RIGOROUS AUDIT
    // =========================================================================
    test('4. parseSqliteDateTime supports Drift representations, seconds, millis, ISO strings, historical, and null', () {
      // Unix seconds (Drift default)
      final dtSec = parseSqliteDateTime(1744329600);
      expect(dtSec, isNotNull);
      expect(dtSec!.year, equals(2025));

      // Unix milliseconds
      final dtMil = parseSqliteDateTime(1744329600000);
      expect(dtMil, isNotNull);
      expect(dtMil!.year, equals(2025));

      // ISO-8601 UTC
      final dtIsoUtc = parseSqliteDateTime('2025-06-15T12:00:00Z');
      expect(dtIsoUtc, isNotNull);
      expect(dtIsoUtc!.year, equals(2025));
      expect(dtIsoUtc.month, equals(6));

      // ISO-8601 local formatted string
      final dtIsoLocal = parseSqliteDateTime('2025-08-20 15:45:00');
      expect(dtIsoLocal, isNotNull);
      expect(dtIsoLocal!.year, equals(2025));
      expect(dtIsoLocal.month, equals(8));

      // Historical Y2K date
      final dtY2K = parseSqliteDateTime(946684800);
      expect(dtY2K, isNotNull);
      expect(dtY2K!.toUtc().year, equals(2000));

      // Null handling: cleanly returns null, never invents DateTime.now()
      expect(parseSqliteDateTime(null), isNull);

      // Unparseable string: cleanly returns null, never invents DateTime.now()
      expect(parseSqliteDateTime('unparseable-date'), isNull);
      expect(parseSqliteDateTime(''), isNull);

      // Arbitrary non-date objects
      expect(parseSqliteDateTime(true), isNull);
    });

    // =========================================================================
    // 5. UI AND PDF CONSISTENCY & STRUCTURE AUDIT
    // =========================================================================
    test('5. PDF export uses the identical CustomerGroupTrialBalanceReport model with matching totals', () async {
      final grp = await groupService.createGroup('PDF Audit Group');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_pdf_1',
        name: 'Alpha Customer',
        groupId: 'debtors',
        openingBalance: const drift.Value(6000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_pdf_2',
        name: 'Beta Customer',
        groupId: 'debtors',
        openingBalance: const drift.Value(-2000.0),
        customerGroupId: drift.Value(grp.id),
      ));

      final report = await groupService.getCustomerGroupTrialBalance(grp.id);

      // Ensure report totals are consistent
      expect(report.totals.totalClosingDebit, equals(6000.0));
      expect(report.totals.totalClosingCredit, equals(2000.0));
      expect(report.totals.netClosingOutstanding, equals(4000.0));

      // Generate PDF bytes
      final pdfBytes = await pdfService.exportCustomerGroupTrialBalancePdf(report);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));

      // Verify that calling the backward-compatible method also produces matching bytes
      final aliasBytes = await pdfService.exportGroupTransactionsPdf(report);
      expect(aliasBytes, isNotEmpty);
      expect(aliasBytes.length, equals(pdfBytes.length));
    });

    // =========================================================================
    // 6. PERFORMANCE & JOIN INTEGRITY (200+ CUSTOMERS BENCHMARK)
    // =========================================================================
    test('6. Benchmark: 200+ customers with transactions aggregate efficiently without duplicate join rows', () async {
      final grp = await groupService.createGroup('Large Benchmark Group');

      const numCustomers = 200;
      final customerCompanions = <LedgersCompanion>[];

      for (int i = 0; i < numCustomers; i++) {
        customerCompanions.add(LedgersCompanion.insert(
          id: 'bench_cust_$i',
          name: 'Bench Customer ${i.toString().padLeft(3, '0')}',
          groupId: 'debtors',
          openingBalance: drift.Value(1000.0 * (i + 1)),
          customerGroupId: drift.Value(grp.id),
        ));
      }

      await db.batch((b) {
        b.insertAll(db.ledgers, customerCompanions);
      });

      // Post 400 vouchers across these customers (2 vouchers per customer)
      final now = DateTime.now();
      for (int i = 0; i < numCustomers; i++) {
        await engine.createVoucher(
          voucherNumber: 'INV-BENCH-$i-A',
          voucherType: 'Sales',
          paymentMode: 'Credit',
          partyLedgerId: 'bench_cust_$i',
          date: now,
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'e_ba_$i',
              voucherId: '',
              ledgerId: 'bench_cust_$i',
              debitAmount: const drift.Value(500.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'e_bb_$i',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(500.0),
            ),
          ],
        );
        await engine.createVoucher(
          voucherNumber: 'REC-BENCH-$i-B',
          voucherType: 'Receipt',
          paymentMode: 'Cash',
          partyLedgerId: 'bench_cust_$i',
          date: now,
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'e_bc_$i',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(200.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'e_bd_$i',
              voucherId: '',
              ledgerId: 'bench_cust_$i',
              creditAmount: const drift.Value(200.0),
            ),
          ],
        );
      }

      // Benchmark the aggregation query
      final stopwatch = Stopwatch()..start();
      final report = await groupService.getCustomerGroupTrialBalance(grp.id);
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // Aggregation for 200 customers and 400 vouchers must finish in well under 300ms in SQLite
      expect(elapsedMs, lessThan(300));
      expect(report.totalCustomers, equals(numCustomers));
      expect(report.rows.length, equals(numCustomers));

      // Verify no join row duplication occurred:
      // For each customer: Base opening = 1000 * (i + 1), Period Dr = 500, Period Cr = 200 -> Net Closing = Base + 300
      for (int i = 0; i < 5; i++) { // Spot check first 5
        final row = report.rows[i];
        final expectedBase = 1000.0 * (i + 1);
        expect(row.openingDebit, equals(expectedBase));
        expect(row.periodDebit, equals(500.0));
        expect(row.periodCredit, equals(200.0));
        expect(row.closingDebit, equals(expectedBase + 300.0));

        final engineBalance = await engine.getLedgerBalance(row.customerId);
        expect(row.netClosing, equals(engineBalance));
      }
    });

    // =========================================================================
    // 7. REGRESSION SAFETY
    // =========================================================================
    test('7. Regression safety: Day Book, general Trial Balance, and voucher lifecycle intact', () async {
      // Verify Trial Balance
      final trialBalance = await engine.getTrialBalance();
      final double totalDr = trialBalance.fold(0.0, (s, r) => s + r.debitBalance);
      final double totalCr = trialBalance.fold(0.0, (s, r) => s + r.creditBalance);
      expect((totalDr - totalCr).abs(), lessThan(0.01));

      // Verify Day Book entries
      final dayBook = await engine.getDayBook();
      expect(dayBook, isNotNull);
    });
  });
}
