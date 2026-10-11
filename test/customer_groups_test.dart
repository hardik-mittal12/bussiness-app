import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/customer_group_service.dart';

void main() {
  late AppDatabase db;
  late AccountingEngine engine;
  late CustomerGroupService groupService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    engine = AccountingEngine(db);
    groupService = CustomerGroupService(db);

    // Seed customers
    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_alpha',
      name: 'Alpha Traders',
      groupId: 'debtors',
      openingBalance: const drift.Value(0.0),
    ));

    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_beta',
      name: 'Beta Enterprises',
      groupId: 'debtors',
      openingBalance: const drift.Value(0.0),
    ));

    await db.into(db.ledgers).insert(LedgersCompanion.insert(
      id: 'cust_gamma',
      name: 'Gamma Stores',
      groupId: 'debtors',
      openingBalance: const drift.Value(0.0),
    ));
  });

  tearDown(() => db.close());

  group('Customer Groups & Group-wise Entries Verification', () {
    test('1. Create, rename, and retrieve customer groups', () async {
      final g1 = await groupService.createGroup('Wholesale North', description: 'Northern region wholesalers');
      expect(g1.id, isNotEmpty);
      expect(g1.name, equals('Wholesale North'));
      expect(g1.description, equals('Northern region wholesalers'));

      // Case-insensitive duplicate rejection
      expect(
        () => groupService.createGroup('wholesale north'),
        throwsA(isA<ArgumentError>()),
      );

      // Rename
      await groupService.updateGroup(g1.id, 'Wholesale Region North', description: 'Updated desc');
      final updated = await groupService.getGroupById(g1.id);
      expect(updated?.name, equals('Wholesale Region North'));
      expect(updated?.description, equals('Updated desc'));

      // Retrieve all
      final all = await groupService.getAllGroups();
      expect(all.length, equals(1));
    });

    test('2. Assign customers to group, move between groups, and leave ungrouped', () async {
      final gWholesale = await groupService.createGroup('Wholesale');
      final gRetail = await groupService.createGroup('Retail');

      // Initially all are ungrouped
      var ungrouped = await groupService.getUngroupedCustomers();
      expect(ungrouped.length, equals(3));

      // Assign Alpha and Beta to Wholesale
      await groupService.assignCustomerToGroup('cust_alpha', gWholesale.id);
      await groupService.assignCustomerToGroup('cust_beta', gWholesale.id);

      var wholesaleMembers = await groupService.getCustomersInGroup(gWholesale.id);
      expect(wholesaleMembers.map((m) => m.id).toList(), containsAll(['cust_alpha', 'cust_beta']));
      expect(wholesaleMembers.length, equals(2));

      ungrouped = await groupService.getUngroupedCustomers();
      expect(ungrouped.length, equals(1));
      expect(ungrouped.first.id, equals('cust_gamma'));

      // Move Beta from Wholesale to Retail
      await groupService.assignCustomerToGroup('cust_beta', gRetail.id);
      wholesaleMembers = await groupService.getCustomersInGroup(gWholesale.id);
      final retailMembers = await groupService.getCustomersInGroup(gRetail.id);
      expect(wholesaleMembers.length, equals(1));
      expect(wholesaleMembers.first.id, equals('cust_alpha'));
      expect(retailMembers.length, equals(1));
      expect(retailMembers.first.id, equals('cust_beta'));

      // Unassign Alpha (set group to null)
      await groupService.assignCustomerToGroup('cust_alpha', null);
      ungrouped = await groupService.getUngroupedCustomers();
      expect(ungrouped.length, equals(2));
    });

    test('3. Deleting a customer group safely unlinks customers without deleting them', () async {
      final group = await groupService.createGroup('Temporary Group');
      await groupService.assignCustomerToGroup('cust_alpha', group.id);
      await groupService.assignCustomerToGroup('cust_beta', group.id);

      // Post transaction to cust_alpha
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-SAFE-01',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_alpha',
        date: DateTime(2025, 4, 1),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_dr_1',
            voucherId: '',
            ledgerId: 'cust_alpha',
            debitAmount: const drift.Value(500.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_cr_1',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(500.0),
          ),
        ],
      );

      // Delete the group
      await groupService.deleteGroup(group.id);

      // Group is deleted
      final gCheck = await groupService.getGroupById(group.id);
      expect(gCheck, isNull);

      // Customers MUST still exist and be intact
      final alpha = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_alpha'))).getSingleOrNull();
      final beta = await (db.select(db.ledgers)..where((t) => t.id.equals('cust_beta'))).getSingleOrNull();
      expect(alpha, isNotNull);
      expect(beta, isNotNull);
      expect(alpha!.customerGroupId, isNull);
      expect(beta!.customerGroupId, isNull);

      // Alpha's balance must remain 100% intact
      final balAlpha = await engine.getLedgerBalance('cust_alpha');
      expect(balAlpha, equals(500.0));
    });

    test('4. Group-wise entries consolidated statement across customers in group', () async {
      final gKey = await groupService.createGroup('Key Accounts');
      await groupService.assignCustomerToGroup('cust_alpha', gKey.id);
      await groupService.assignCustomerToGroup('cust_beta', gKey.id);

      // Transaction 1: Sale to Alpha on April 1 (Rs. 1000)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-GRP-01',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_alpha',
        date: DateTime(2025, 4, 1),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'g_ve_1',
            voucherId: '',
            ledgerId: 'cust_alpha',
            debitAmount: const drift.Value(1000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'g_ve_2',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(1000.0),
          ),
        ],
      );

      // Transaction 2: Sale to Beta on April 2 (Rs. 1500)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-GRP-02',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_beta',
        date: DateTime(2025, 4, 2),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'g_ve_3',
            voucherId: '',
            ledgerId: 'cust_beta',
            debitAmount: const drift.Value(1500.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'g_ve_4',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(1500.0),
          ),
        ],
      );

      // Transaction 3: Receipt from Alpha on April 3 (Rs. 400)
      await engine.createVoucher(
        voucherType: 'Receipt',
        voucherNumber: 'RCT-GRP-01',
        paymentMode: 'Cash',
        partyLedgerId: 'cust_alpha',
        date: DateTime(2025, 4, 3),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'g_ve_5',
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(400.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'g_ve_6',
            voucherId: '',
            ledgerId: 'cust_alpha',
            creditAmount: const drift.Value(400.0),
          ),
        ],
      );

      // Transaction 4: Transaction for Gamma (not in group) on April 4 (Rs. 2000)
      await engine.createVoucher(
        voucherType: 'Sales',
        voucherNumber: 'INV-GAMMA-01',
        paymentMode: 'Credit',
        partyLedgerId: 'cust_gamma',
        date: DateTime(2025, 4, 4),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'g_ve_7',
            voucherId: '',
            ledgerId: 'cust_gamma',
            debitAmount: const drift.Value(2000.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'g_ve_8',
            voucherId: '',
            ledgerId: 'sales',
            creditAmount: const drift.Value(2000.0),
          ),
        ],
      );

      // Query consolidated Group-wise entries
      final summary = await groupService.getGroupTransactionsSummary(gKey.id);

      expect(summary.totalCustomers, equals(2));
      expect(summary.activeCustomersWithTransactions, equals(2));
      expect(summary.rows.length, equals(3)); // Alpha sale, Beta sale, Alpha receipt (Gamma is excluded)

      // Total Debits = 1000 + 1500 = 2500
      expect(summary.totalDebit, equals(2500.0));
      // Total Credits = 400
      expect(summary.totalCredit, equals(400.0));
      // Net Outstanding = 2500 - 400 = 2100
      expect(summary.netOutstanding, equals(2100.0));

      // Verify row order & running balance
      expect(summary.rows[0].customerName, equals('Alpha Traders'));
      expect(summary.rows[0].debitAmount, equals(1000.0));
      expect(summary.rows[0].runningBalance, equals(1000.0));

      expect(summary.rows[1].customerName, equals('Beta Enterprises'));
      expect(summary.rows[1].debitAmount, equals(1500.0));
      expect(summary.rows[1].runningBalance, equals(2500.0));

      expect(summary.rows[2].customerName, equals('Alpha Traders'));
      expect(summary.rows[2].creditAmount, equals(400.0));
      expect(summary.rows[2].runningBalance, equals(2100.0));

      // Test Date Filtering: Only April 2 to April 3
      final filteredSummary = await groupService.getGroupTransactionsSummary(
        gKey.id,
        fromDate: DateTime(2025, 4, 2),
        toDate: DateTime(2025, 4, 3),
      );
      expect(filteredSummary.rows.length, equals(2)); // Beta sale + Alpha receipt
      expect(filteredSummary.totalDebit, equals(1500.0));
      expect(filteredSummary.totalCredit, equals(400.0));
    });
  });
}
