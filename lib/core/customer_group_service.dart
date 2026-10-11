import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';

class GroupTransactionRow {
  final String voucherId;
  final String voucherNumber;
  final String voucherType;
  final DateTime date;
  final String customerId;
  final String customerName;
  final double debitAmount;
  final double creditAmount;
  final double runningBalance;
  final String? narration;

  GroupTransactionRow({
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherType,
    required this.date,
    required this.customerId,
    required this.customerName,
    required this.debitAmount,
    required this.creditAmount,
    required this.runningBalance,
    this.narration,
  });
}

class GroupTransactionsSummary {
  final CustomerGroup group;
  final List<GroupTransactionRow> rows;
  final double openingBalance;
  final double totalDebit;
  final double totalCredit;
  final double netOutstanding;
  final int totalCustomers;
  final int activeCustomersWithTransactions;

  GroupTransactionsSummary({
    required this.group,
    required this.rows,
    this.openingBalance = 0.0,
    required this.totalDebit,
    required this.totalCredit,
    required this.netOutstanding,
    required this.totalCustomers,
    required this.activeCustomersWithTransactions,
  });
}

class CustomerGroupService {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  CustomerGroupService(this.db);

  /// 1. Create a new Customer Group
  Future<CustomerGroup> createGroup(String name, {String? description}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    // Check case-insensitive duplicate
    final existing = await (db.select(db.customerGroups)
          ..where((t) => t.name.lower().equals(trimmedName.toLowerCase())))
        .getSingleOrNull();

    if (existing != null) {
      throw ArgumentError('A customer group named "$trimmedName" already exists');
    }

    final id = _uuid.v4();
    final now = DateTime.now();
    final companion = CustomerGroupsCompanion.insert(
      id: id,
      name: trimmedName,
      description: Value(description?.trim()),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    await db.into(db.customerGroups).insert(companion);
    return (await (db.select(db.customerGroups)..where((t) => t.id.equals(id))).getSingle());
  }

  /// 2. Rename / update Customer Group
  Future<void> updateGroup(String id, String newName, {String? description}) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Group name cannot be empty');
    }

    final duplicate = await (db.select(db.customerGroups)
          ..where((t) => t.name.lower().equals(trimmedName.toLowerCase()) & t.id.equals(id).not()))
        .getSingleOrNull();

    if (duplicate != null) {
      throw ArgumentError('A customer group named "$trimmedName" already exists');
    }

    await (db.update(db.customerGroups)..where((t) => t.id.equals(id))).write(
      CustomerGroupsCompanion(
        name: Value(trimmedName),
        description: Value(description?.trim()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 3. Safely delete Customer Group without deleting or corrupting member customers
  Future<void> deleteGroup(String id) async {
    return db.transaction(() async {
      // Unlink all member customers safely (they become ungrouped)
      await (db.update(db.ledgers)..where((t) => t.customerGroupId.equals(id))).write(
        const LedgersCompanion(
          customerGroupId: Value(null),
        ),
      );

      // Delete the group definition
      await (db.delete(db.customerGroups)..where((t) => t.id.equals(id))).go();
    });
  }

  /// 4. Watch all customer groups ordered alphabetically
  Stream<List<CustomerGroup>> watchAllGroups() {
    return (db.select(db.customerGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]))
        .watch();
  }

  /// 5. Get all customer groups
  Future<List<CustomerGroup>> getAllGroups() {
    return (db.select(db.customerGroups)
          ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]))
        .get();
  }

  /// 6. Get a group by ID
  Future<CustomerGroup?> getGroupById(String id) {
    return (db.select(db.customerGroups)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// 7. Assign customer to a group (or ungroup if groupId is null)
  Future<void> assignCustomerToGroup(String customerId, String? groupId) async {
    if (groupId != null) {
      final group = await getGroupById(groupId);
      if (group == null) {
        throw ArgumentError('Target customer group does not exist');
      }
    }

    await (db.update(db.ledgers)..where((t) => t.id.equals(customerId))).write(
      LedgersCompanion(
        customerGroupId: Value(groupId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// 8. Bulk assign customers to a group
  Future<void> assignMultipleCustomersToGroup(List<String> customerIds, String? groupId) async {
    if (customerIds.isEmpty) return;
    return db.transaction(() async {
      for (final cid in customerIds) {
        await assignCustomerToGroup(cid, groupId);
      }
    });
  }

  /// 9. Get all customers belonging to a group
  Future<List<Ledger>> getCustomersInGroup(String groupId) {
    return (db.select(db.ledgers)
          ..where((t) =>
              t.customerGroupId.equals(groupId) &
              t.groupId.equals('debtors') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]))
        .get();
  }

  /// Alias for getCustomersInGroup
  Future<List<Ledger>> getGroupMembers(String groupId) => getCustomersInGroup(groupId);

  /// Remove customer from their group
  Future<void> removeCustomerFromGroup(String customerId) => assignCustomerToGroup(customerId, null);

  /// Get all customers (debtors) with their group assignments
  Future<List<Ledger>> getCustomersWithGroup() {
    return (db.select(db.ledgers)
          ..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]))
        .get();
  }

  /// 10. Get all ungrouped customers
  Future<List<Ledger>> getUngroupedCustomers() {
    return (db.select(db.ledgers)
          ..where((t) =>
              t.customerGroupId.isNull() &
              t.groupId.equals('debtors') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name.lower())]))
        .get();
  }

  /// Get consolidated transactions for a group (alias for getGroupTransactionsSummary)
  Future<GroupTransactionsSummary> getGroupTransactions(
    String groupId, {
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      getGroupTransactionsSummary(groupId, fromDate: startDate, toDate: endDate);

  /// 11. Count customers per group
  Future<Map<String, int>> getCustomerCountPerGroup() async {
    final query = await db.customSelect('''
      SELECT customer_group_id, COUNT(*) as cnt
      FROM ledgers
      WHERE group_id = 'debtors' AND is_deleted = 0 AND customer_group_id IS NOT NULL
      GROUP BY customer_group_id;
    ''').get();

    final counts = <String, int>{};
    for (final row in query) {
      final gid = row.data['customer_group_id'] as String;
      final cnt = (row.data['cnt'] as num).toInt();
      counts[gid] = cnt;
    }
    return counts;
  }

  /// 12. Group-wise Entries: Consolidated transaction view across all customers in group
  Future<GroupTransactionsSummary> getGroupTransactionsSummary(
    String groupId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final group = await getGroupById(groupId);
    if (group == null) {
      throw ArgumentError('Customer group not found: $groupId');
    }

    final customers = await getCustomersInGroup(groupId);
    final customerMap = {for (final c in customers) c.id: c.name};

    if (customers.isEmpty) {
      return GroupTransactionsSummary(
        group: group,
        rows: [],
        totalDebit: 0.0,
        totalCredit: 0.0,
        netOutstanding: 0.0,
        totalCustomers: 0,
        activeCustomersWithTransactions: 0,
      );
    }

    final customerIds = customers.map((c) => c.id).toList();
    final placeholders = List.filled(customerIds.length, '?').join(',');

    // 1. Calculate base opening balance from customer ledgers
    final baseOpening = customers.fold<double>(0.0, (sum, c) => sum + c.openingBalance);

    // 2. If filtering by fromDate, calculate prior period transactions
    double priorPeriodMovement = 0.0;
    if (fromDate != null) {
      final priorParams = <Variable>[];
      for (final cid in customerIds) {
        priorParams.add(Variable.withString(cid));
      }
      priorParams.add(Variable.withDateTime(fromDate));

      final priorSql = '''
        SELECT 
          COALESCE(SUM(ve.debit_amount), 0.0) AS prior_debit,
          COALESCE(SUM(ve.credit_amount), 0.0) AS prior_credit
        FROM voucher_entries ve
        JOIN vouchers v ON ve.voucher_id = v.id
        WHERE ve.ledger_id IN ($placeholders)
          AND (v.status IS NULL OR v.status = 'POSTED')
          AND v.date < ?;
      ''';
      final priorRes = await db.customSelect(priorSql, variables: priorParams).getSingleOrNull();
      if (priorRes != null) {
        final pDr = (priorRes.data['prior_debit'] as num?)?.toDouble() ?? 0.0;
        final pCr = (priorRes.data['prior_credit'] as num?)?.toDouble() ?? 0.0;
        priorPeriodMovement = pDr - pCr;
      }
    }

    final totalOpeningBalance = baseOpening + priorPeriodMovement;

    String dateClause = '';
    final params = <Variable>[];
    for (final cid in customerIds) {
      params.add(Variable.withString(cid));
    }

    if (fromDate != null) {
      dateClause += ' AND v.date >= ?';
      params.add(Variable.withDateTime(fromDate));
    }
    if (toDate != null) {
      // Include whole day
      final endOfDay = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999);
      dateClause += ' AND v.date <= ?';
      params.add(Variable.withDateTime(endOfDay));
    }

    final sql = '''
      SELECT 
        v.id AS voucher_id,
        v.voucher_number,
        v.voucher_type,
        v.date,
        v.narration,
        ve.ledger_id,
        ve.debit_amount,
        ve.credit_amount
      FROM voucher_entries ve
      JOIN vouchers v ON ve.voucher_id = v.id
      WHERE ve.ledger_id IN ($placeholders)
        AND (v.status IS NULL OR v.status = 'POSTED')
        $dateClause
      ORDER BY v.date ASC, v.rowid ASC, ve.rowid ASC;
    ''';

    final result = await db.customSelect(sql, variables: params).get();

    final rows = <GroupTransactionRow>[];
    double runningBalance = totalOpeningBalance;
    double totalDebit = 0.0;
    double totalCredit = 0.0;
    final activeCustomerIds = <String>{};

    for (final r in result) {
      final rawDebit = (r.data['debit_amount'] as num?)?.toDouble() ?? 0.0;
      final rawCredit = (r.data['credit_amount'] as num?)?.toDouble() ?? 0.0;

      // In double-entry for Sundry Debtors: Debit increases debt (Sale), Credit decreases debt (Receipt/Return)
      final debit = rawDebit;
      final credit = rawCredit;

      totalDebit += debit;
      totalCredit += credit;
      runningBalance += (debit - credit);

      final cid = r.data['ledger_id'] as String;
      activeCustomerIds.add(cid);

      final dateEpoch = r.data['date'];
      DateTime dt;
      if (dateEpoch is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(dateEpoch);
      } else if (dateEpoch is String) {
        dt = DateTime.parse(dateEpoch);
      } else {
        dt = DateTime.now();
      }

      rows.add(GroupTransactionRow(
        voucherId: r.data['voucher_id'] as String,
        voucherNumber: r.data['voucher_number'] as String,
        voucherType: r.data['voucher_type'] as String,
        date: dt,
        customerId: cid,
        customerName: customerMap[cid] ?? 'Unknown Customer',
        debitAmount: debit,
        creditAmount: credit,
        runningBalance: runningBalance,
        narration: r.data['narration'] as String?,
      ));
    }

    return GroupTransactionsSummary(
      group: group,
      rows: rows,
      openingBalance: totalOpeningBalance,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
      netOutstanding: runningBalance,
      totalCustomers: customers.length,
      activeCustomersWithTransactions: activeCustomerIds.length,
    );
  }
}
