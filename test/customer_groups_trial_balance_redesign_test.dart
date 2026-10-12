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

  group('Customer Groups Bug Fix & Trial Balance Redesign Tests', () {
    // -------------------------------------------------------------
    // A. Basic Group Balances (Phase 8.A)
    // -------------------------------------------------------------
    test('A. Basic group balances: separates Debit and Credit customer balances correctly', () async {
      final gRetail = await groupService.createGroup('Retail Customers');

      // Create Customer A (Rs. 10000 Dr), Customer B (Rs. 5000 Dr), Customer C (Rs. 3000 Cr)
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_a',
        name: 'Customer A',
        groupId: 'debtors',
        openingBalance: const drift.Value(10000.0), // Dr 10000
      ));
      await groupService.assignCustomerToGroup('cust_a', gRetail.id);

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_b',
        name: 'Customer B',
        groupId: 'debtors',
        openingBalance: const drift.Value(5000.0), // Dr 5000
      ));
      await groupService.assignCustomerToGroup('cust_b', gRetail.id);

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_c',
        name: 'Customer C',
        groupId: 'debtors',
        openingBalance: const drift.Value(-3000.0), // Cr 3000
      ));
      await groupService.assignCustomerToGroup('cust_c', gRetail.id);

      // Generate report
      final report = await groupService.getCustomerGroupTrialBalance(gRetail.id);

      expect(report.totalCustomers, equals(3));
      expect(report.activeCustomers, equals(3));
      expect(report.rows.length, equals(3));

      // Customer A
      final rowA = report.rows.firstWhere((r) => r.customerId == 'cust_a');
      expect(rowA.closingDebit, equals(10000.0));
      expect(rowA.closingCredit, equals(0.0));
      expect(rowA.netClosing, equals(10000.0));

      // Customer B
      final rowB = report.rows.firstWhere((r) => r.customerId == 'cust_b');
      expect(rowB.closingDebit, equals(5000.0));
      expect(rowB.closingCredit, equals(0.0));
      expect(rowB.netClosing, equals(5000.0));

      // Customer C
      final rowC = report.rows.firstWhere((r) => r.customerId == 'cust_c');
      expect(rowC.closingDebit, equals(0.0));
      expect(rowC.closingCredit, equals(3000.0));
      expect(rowC.netClosing, equals(-3000.0));

      // Group totals reconciliation:
      // Total Debit balance: Rs. 15000
      // Total Credit balance: Rs. 3000
      // Net debit position: Rs. 12000
      expect(report.totals.totalClosingDebit, equals(15000.0));
      expect(report.totals.totalClosingCredit, equals(3000.0));
      expect(report.totals.netClosingOutstanding, equals(12000.0));
      expect(report.totals.totalDebitBalance, equals(15000.0));
      expect(report.totals.totalCreditBalance, equals(3000.0));

      // Reconciles with individual accounting engine balances
      expect(await engine.getLedgerBalance('cust_a'), equals(rowA.netClosing));
      expect(await engine.getLedgerBalance('cust_b'), equals(rowB.netClosing));
      expect(await engine.getLedgerBalance('cust_c'), equals(rowC.netClosing));
    });

    // -------------------------------------------------------------
    // B. Opening Balances & Reconciliations (Phase 8.B)
    // -------------------------------------------------------------
    test('B. Opening balances: handles Debit, Credit, Zero opening balances without discarding directions', () async {
      final gWholesale = await groupService.createGroup('Wholesale Dealers');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'w_debit',
        name: 'Debit Dealer',
        groupId: 'debtors',
        openingBalance: const drift.Value(25000.0), // Debit opening
      ));
      await groupService.assignCustomerToGroup('w_debit', gWholesale.id);

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'w_credit',
        name: 'Credit Dealer',
        groupId: 'debtors',
        openingBalance: const drift.Value(-8000.0), // Credit opening (advance)
      ));
      await groupService.assignCustomerToGroup('w_credit', gWholesale.id);

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'w_zero',
        name: 'Zero Balance Dealer',
        groupId: 'debtors',
        openingBalance: const drift.Value(0.0), // Zero opening
      ));
      await groupService.assignCustomerToGroup('w_zero', gWholesale.id);

      final report = await groupService.getCustomerGroupTrialBalance(gWholesale.id);

      final rDr = report.rows.firstWhere((r) => r.customerId == 'w_debit');
      expect(rDr.openingDebit, equals(25000.0));
      expect(rDr.openingCredit, equals(0.0));
      expect(rDr.netOpening, equals(25000.0));

      final rCr = report.rows.firstWhere((r) => r.customerId == 'w_credit');
      expect(rCr.openingDebit, equals(0.0));
      expect(rCr.openingCredit, equals(8000.0));
      expect(rCr.netOpening, equals(-8000.0));

      final rZero = report.rows.firstWhere((r) => r.customerId == 'w_zero');
      expect(rZero.openingDebit, equals(0.0));
      expect(rZero.openingCredit, equals(0.0));
      expect(rZero.netOpening, equals(0.0));

      expect(report.totals.totalOpeningDebit, equals(25000.0));
      expect(report.totals.totalOpeningCredit, equals(8000.0));
      expect(report.totals.netOpeningBalance, equals(17000.0));
    });

    // -------------------------------------------------------------
    // C. Date Filtering & Backdated Transactions (Phase 8.C)
    // -------------------------------------------------------------
    test('C. Date filtering: opening balance carries forward prior transactions, period movements include only eligible date range', () async {
      final gDist = await groupService.createGroup('Distributors');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'dist_1',
        name: 'Distributor 1',
        groupId: 'debtors',
        openingBalance: const drift.Value(5000.0), // Initial opening
      ));
      await groupService.assignCustomerToGroup('dist_1', gDist.id);

      // Prior transaction: March 25 Sale of Rs. 10000
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-MAR-01',
        paymentMode: 'Credit',
        partyLedgerId: 'dist_1',
        date: DateTime(2025, 3, 25),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_prior_1',
            voucherId: '',
            ledgerId: 'dist_1',
            debitAmount: const drift.Value(10000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_prior_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(10000.0),
          ),
        ],
      );

      // Period transaction 1: April 5 Sale of Rs. 6000
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-APR-01',
        paymentMode: 'Credit',
        partyLedgerId: 'dist_1',
        date: DateTime(2025, 4, 5),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_per_1',
            voucherId: '',
            ledgerId: 'dist_1',
            debitAmount: const drift.Value(6000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_per_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(6000.0),
          ),
        ],
      );

      // Period transaction 2: April 12 Receipt of Rs. 4000
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCP-APR-01',
        paymentMode: 'Bank',
        partyLedgerId: 'dist_1',
        date: DateTime(2025, 4, 12),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_per_3',
            voucherId: '',
            ledgerId: 'bank_accounts',
            debitAmount: const drift.Value(4000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_per_4',
            voucherId: '',
            ledgerId: 'dist_1',
            creditAmount: const drift.Value(4000.0),
          ),
        ],
      );

      // Subsequent transaction: May 2 Sale of Rs. 3000 (outside reporting period)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-MAY-01',
        paymentMode: 'Credit',
        partyLedgerId: 'dist_1',
        date: DateTime(2025, 5, 2),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_sub_1',
            voucherId: '',
            ledgerId: 'dist_1',
            debitAmount: const drift.Value(3000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_sub_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(3000.0),
          ),
        ],
      );

      // Filter for Month of April: 2025-04-01 to 2025-04-30
      final aprilReport = await groupService.getCustomerGroupTrialBalance(
        gDist.id,
        fromDate: DateTime(2025, 4, 1),
        toDate: DateTime(2025, 4, 30),
      );

      final row = aprilReport.rows.firstWhere((r) => r.customerId == 'dist_1');

      // Opening for April = initial opening (5000) + March sale (10000) = 15000 Dr
      expect(row.openingDebit, equals(15000.0));
      expect(row.openingCredit, equals(0.0));

      // Period movements for April = Debit 6000, Credit 4000
      expect(row.periodDebit, equals(6000.0));
      expect(row.periodCredit, equals(4000.0));

      // Closing for April = 15000 + 6000 - 4000 = 17000 Dr (May sale is excluded)
      expect(row.closingDebit, equals(17000.0));
      expect(row.closingCredit, equals(0.0));
      expect(row.netClosing, equals(17000.0));

      // Verify exact reconciliation with AccountingEngine.getLedgerBalance as-of 2025-04-30
      final engineBalApril = await engine.getLedgerBalance('dist_1', asOfDate: DateTime(2025, 4, 30));
      expect(row.netClosing, equals(engineBalApril));

      // Cumulative / All-Time Report: Includes all transactions (March, April, May)
      final allTimeReport = await groupService.getCustomerGroupTrialBalance(gDist.id);
      final allRow = allTimeReport.rows.firstWhere((r) => r.customerId == 'dist_1');
      // Opening = initial 5000 Dr
      expect(allRow.openingDebit, equals(5000.0));
      // Total Period Debit = 10000 + 6000 + 3000 = 19000
      expect(allRow.periodDebit, equals(19000.0));
      // Total Period Credit = 4000
      expect(allRow.periodCredit, equals(4000.0));
      // Closing = 5000 + 19000 - 4000 = 20000 Dr
      expect(allRow.closingDebit, equals(20000.0));
      final engineBalAll = await engine.getLedgerBalance('dist_1');
      expect(allRow.netClosing, equals(engineBalAll));
    });

    // -------------------------------------------------------------
    // D. Voucher Status: Cancelled vouchers ignored (Phase 8.D)
    // -------------------------------------------------------------
    test('D. Voucher status: cancelled vouchers are ignored in group trial balance', () async {
      final gCancel = await groupService.createGroup('Cancel Test Group');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_cancel_test',
        name: 'Cancellation Customer',
        groupId: 'debtors',
        openingBalance: const drift.Value(0.0),
      ));
      await groupService.assignCustomerToGroup('cust_cancel_test', gCancel.id);

      // Create Sale 1 (Valid)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-VALID-01',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_cancel_test',
        date: DateTime(2025, 4, 10),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_val_1',
            voucherId: '',
            ledgerId: 'cust_cancel_test',
            debitAmount: const drift.Value(8000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_val_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(8000.0),
          ),
        ],
      );

      // Create Sale 2 (To be cancelled)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-TBC-01',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_cancel_test',
        date: DateTime(2025, 4, 11),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_tbc_1',
            voucherId: '',
            ledgerId: 'cust_cancel_test',
            debitAmount: const drift.Value(5000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_tbc_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(5000.0),
          ),
        ],
      );

      // Cancel Sale 2
      await engine.cancelVoucher('INV-TBC-01');

      final report = await groupService.getCustomerGroupTrialBalance(gCancel.id);
      final row = report.rows.firstWhere((r) => r.customerId == 'cust_cancel_test');

      // Only the Rs. 8000 valid voucher is included; Rs. 5000 cancelled voucher is excluded!
      expect(row.periodDebit, equals(8000.0));
      expect(row.closingDebit, equals(8000.0));
      expect(report.totals.totalClosingDebit, equals(8000.0));
    });

    // -------------------------------------------------------------
    // E. 1970 Date Regression Test (Phase 8.E)
    // -------------------------------------------------------------
    test('E. Epoch / date parsing: parseSqliteDateTime correctly handles Unix seconds and never defaults to 1970', () {
      // 1. A typical modern Unix epoch timestamp in SECONDS (1744329600 = April 11, 2025)
      const int modernSeconds = 1744329600;
      final parsedFromSeconds = parseSqliteDateTime(modernSeconds);
      expect(parsedFromSeconds, isNotNull);
      expect(parsedFromSeconds!.year, equals(2025));
      expect(parsedFromSeconds.month, equals(4));
      expect(parsedFromSeconds.year, isNot(1970));

      // 2. A modern Unix timestamp in MILLISECONDS (1744329600000 = April 11, 2025)
      const int modernMillis = 1744329600000;
      final parsedFromMillis = parseSqliteDateTime(modernMillis);
      expect(parsedFromMillis, isNotNull);
      expect(parsedFromMillis!.year, equals(2025));
      expect(parsedFromMillis.month, equals(4));
      expect(parsedFromMillis.year, isNot(1970));

      // 3. ISO-8601 string
      final parsedFromString = parseSqliteDateTime('2025-06-15T10:30:00Z');
      expect(parsedFromString, isNotNull);
      expect(parsedFromString!.year, equals(2025));
      expect(parsedFromString.month, equals(6));

      // 4. Historical date: Year 2000 Unix timestamp in seconds (946684800 = Jan 1, 2000 UTC)
      const int y2kSeconds = 946684800;
      final parsedY2K = parseSqliteDateTime(y2kSeconds);
      expect(parsedY2K, isNotNull);
      expect(parsedY2K!.toUtc().year, equals(2000));

      // 5. Null or missing value returns null cleanly rather than inventing DateTime.now()
      final parsedFromNull = parseSqliteDateTime(null);
      expect(parsedFromNull, isNull);

      // 6. Invalid string returns null cleanly rather than inventing DateTime.now()
      final parsedFromInvalid = parseSqliteDateTime('invalid-date-string');
      expect(parsedFromInvalid, isNull);

      // 7. Empty string returns null cleanly
      final parsedFromEmpty = parseSqliteDateTime('   ');
      expect(parsedFromEmpty, isNull);
    });

    // -------------------------------------------------------------
    // F. Customer Groups CRUD & Reassignment (Phase 8.F)
    // -------------------------------------------------------------
    test('F. Customer groups: empty groups, member reassignment without corrupting ledger balances', () async {
      final gEmpty = await groupService.createGroup('Empty Group');
      final emptyReport = await groupService.getCustomerGroupTrialBalance(gEmpty.id);
      expect(emptyReport.totalCustomers, equals(0));
      expect(emptyReport.activeCustomers, equals(0));
      expect(emptyReport.rows, isEmpty);
      expect(emptyReport.totals.totalClosingDebit, equals(0.0));
      expect(emptyReport.totals.totalClosingCredit, equals(0.0));

      // Customer moved from Group A to Group B preserves ledger balance
      final gA = await groupService.createGroup('Source Group A');
      final gB = await groupService.createGroup('Target Group B');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_move',
        name: 'Movable Customer',
        groupId: 'debtors',
        openingBalance: const drift.Value(14000.0),
      ));
      await groupService.assignCustomerToGroup('cust_move', gA.id);

      var reportA = await groupService.getCustomerGroupTrialBalance(gA.id);
      expect(reportA.totalCustomers, equals(1));
      expect(reportA.rows.first.closingDebit, equals(14000.0));

      // Reassign to Group B
      await groupService.assignCustomerToGroup('cust_move', gB.id);

      reportA = await groupService.getCustomerGroupTrialBalance(gA.id);
      final reportB = await groupService.getCustomerGroupTrialBalance(gB.id);

      expect(reportA.totalCustomers, equals(0));
      expect(reportB.totalCustomers, equals(1));
      expect(reportB.rows.first.closingDebit, equals(14000.0));

      // Individual ledger balance in Accounting Engine remains intact
      expect(await engine.getLedgerBalance('cust_move'), equals(14000.0));
    });

    // -------------------------------------------------------------
    // G. PDF Export: Generates clean Trial Balance report without bill listings (Phase 8.G)
    // -------------------------------------------------------------
    test('G. PDF Export: generates balance-oriented PDF matching report totals', () async {
      final gPdf = await groupService.createGroup('Corporate Accounts');

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'corp_1',
        name: 'Zenith Corp',
        groupId: 'debtors',
        openingBalance: const drift.Value(50000.0),
      ));
      await groupService.assignCustomerToGroup('corp_1', gPdf.id);

      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'corp_2',
        name: 'Apex Industries',
        groupId: 'debtors',
        openingBalance: const drift.Value(-12000.0),
      ));
      await groupService.assignCustomerToGroup('corp_2', gPdf.id);

      final report = await groupService.getCustomerGroupTrialBalance(gPdf.id);
      final pdfBytes = await pdfService.exportCustomerGroupTrialBalancePdf(report);

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000)); // Non-empty valid PDF bytes
    });

    // -------------------------------------------------------------
    // H. Performance: Single-query aggregation benchmark (Phase 8.H)
    // -------------------------------------------------------------
    test('H. Performance: 50 customers in a group aggregate in under 50ms', () async {
      final gPerf = await groupService.createGroup('Large Wholesale Group');

      // Seed 50 customers with opening balances and vouchers
      for (int i = 1; i <= 50; i++) {
        final cid = 'perf_cust_$i';
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: cid,
          name: 'Wholesale Partner $i',
          groupId: 'debtors',
          openingBalance: drift.Value(i * 100.0),
        ));
        await groupService.assignCustomerToGroup(cid, gPerf.id);
      }

      final stopwatch = Stopwatch()..start();
      final report = await groupService.getCustomerGroupTrialBalance(gPerf.id);
      stopwatch.stop();

      expect(report.totalCustomers, equals(50));
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Fast sub-100ms execution
    });
  });
}
