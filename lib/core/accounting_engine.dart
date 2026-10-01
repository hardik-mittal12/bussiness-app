import 'package:drift/drift.dart';
import '../data/database.dart';
import 'package:uuid/uuid.dart';
import 'financial_year_service.dart';
import 'money_precision.dart';

class LedgerStatementRow {
  final String voucherId;
  final DateTime date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final double debit;
  final double credit;
  final double runningBalance;
  final String? paymentMode;

  double get debitAmount => debit;
  double get creditAmount => credit;
  String get voucherNumber => voucherNo;

  LedgerStatementRow({
    required this.voucherId,
    required this.date,
    required this.voucherNo,
    required this.voucherType,
    required this.narration,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.paymentMode,
  });
}

class CashTransactionRow {
  final String voucherId;
  final DateTime date;
  final String voucherNo;
  final String voucherType;
  final String partyName;
  final String narration;
  final double amount;
  final bool isCashIn;
  final double runningBalance;

  CashTransactionRow({
    required this.voucherId,
    required this.date,
    required this.voucherNo,
    required this.voucherType,
    required this.partyName,
    required this.narration,
    required this.amount,
    required this.isCashIn,
    required this.runningBalance,
  });
}

class _StatementItem {
  final String voucherId;
  final DateTime date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final double debit;
  final double credit;
  final String? paymentMode;

  _StatementItem({
    required this.voucherId,
    required this.date,
    required this.voucherNo,
    required this.voucherType,
    required this.narration,
    required this.debit,
    required this.credit,
    this.paymentMode,
  });
}

class TrialBalanceRow {
  final String ledgerId;
  final String ledgerName;
  final String groupName;
  final double debitBalance;
  final double creditBalance;

  TrialBalanceRow({
    required this.ledgerId,
    required this.ledgerName,
    required this.groupName,
    required this.debitBalance,
    required this.creditBalance,
  });
}

class StockStatus {
  final String id;
  final String name;
  final double quantity;
  final double averageRate;
  final double totalValue;

  StockStatus({
    required this.id,
    required this.name,
    required this.quantity,
    required this.averageRate,
    required this.totalValue,
  });
}

class ProfitLossReport {
  final double openingStockValue;
  final double purchaseValue;
  final double directExpenses;
  final double grossProfit;
  final double closingStockValue;
  final double salesValue;
  final double indirectExpenses;
  final double netProfit;

  ProfitLossReport({
    required this.openingStockValue,
    required this.purchaseValue,
    required this.directExpenses,
    required this.grossProfit,
    required this.closingStockValue,
    required this.salesValue,
    required this.indirectExpenses,
    required this.netProfit,
  });
}

class BalanceSheetReport {
  final double capitalBalance;
  final double netProfitSurplus;
  final double totalLiabilities;
  final double sundryCreditors;

  final double closingStock;
  final double cashBalance;
  final double bankBalance;
  final double sundryDebtors;
  final double totalAssets;

  BalanceSheetReport({
    required this.capitalBalance,
    required this.netProfitSurplus,
    required this.totalLiabilities,
    required this.sundryCreditors,
    required this.closingStock,
    required this.cashBalance,
    required this.bankBalance,
    required this.sundryDebtors,
    required this.totalAssets,
  });
}

class DayBookRow {
  final String voucherId;
  final String voucherNumber;
  final String voucherType;
  final DateTime date;
  final String narration;
  final double totalAmount;
  final double totalDebit;
  final double totalCredit;
  final String? partyLedgerId;
  final String? partyName;
  final String? referenceNumber;
  final String? paymentMode;
  final double discountAmount;

  DayBookRow({
    required this.voucherId,
    required this.voucherNumber,
    required this.voucherType,
    required this.date,
    required this.narration,
    required this.totalAmount,
    required this.totalDebit,
    required this.totalCredit,
    required this.partyLedgerId,
    required this.partyName,
    required this.referenceNumber,
    required this.paymentMode,
    required this.discountAmount,
  });
}

class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);
  @override
  String toString() => message;
}

class AccountingEngine {
  final AppDatabase db;
  final Uuid uuid = const Uuid();
  bool _isSubmitting = false;

  AccountingEngine(this.db);

  /// Check if a voucher submission is currently in progress
  bool get isSubmitting => _isSubmitting;

  // 1. Transactional Sequence Reservation inside SQLite Transaction
  Future<String> reserveNextInvoiceNumberInTx(
    String voucherType,
    DateTime date,
  ) async {
    final financialYear = FinancialYearService.getFinancialYear(date);
    final seqId = FinancialYearService.getSequenceId(
      financialYear,
      voucherType,
    );
    final prefix = voucherType == 'Sales'
        ? 'INV'
        : (voucherType == 'Purchase'
              ? 'PUR'
              : voucherType.substring(0, 3).toUpperCase());

    final existingSeq = await (db.select(
      db.invoiceSequences,
    )..where((t) => t.id.equals(seqId))).getSingleOrNull();

    int currentNext = 1;
    if (existingSeq != null) {
      currentNext = existingSeq.nextNumber;
    }

    // Advance sequence until a non-conflicting number is found (protects against imports & concurrency)
    while (true) {
      final candidateNo =
          '$prefix-$financialYear-${currentNext.toString().padLeft(4, '0')}';
      final existingVoucher =
          await (db.select(db.vouchers)..where(
                (t) =>
                    t.financialYear.equals(financialYear) &
                    t.voucherType.equals(voucherType) &
                    t.voucherNumber.equals(candidateNo),
              ))
              .getSingleOrNull();
      if (existingVoucher == null) {
        break;
      }
      currentNext++;
    }

    if (existingSeq != null) {
      await (db.update(db.invoiceSequences)..where((t) => t.id.equals(seqId)))
          .write(InvoiceSequencesCompanion(nextNumber: Value(currentNext + 1)));
    } else {
      await db
          .into(db.invoiceSequences)
          .insert(
            InvoiceSequencesCompanion.insert(
              id: seqId,
              financialYear: financialYear,
              voucherType: voucherType,
              nextNumber: Value(currentNext + 1),
            ),
          );
    }

    return '$prefix-$financialYear-${currentNext.toString().padLeft(4, '0')}';
  }

  // 2. Create or Update a Double-Entry Voucher (100% Atomic Transaction)
  Future<String> createVoucher({
    String? voucherNumber,
    required String
    voucherType, // 'Sales', 'Purchase', 'Receipt', 'Payment', 'Journal', 'Contra'
    required DateTime date,
    String? partyLedgerId,
    String? narration,
    String? referenceNumber,
    String? paymentMode,
    double? discountAmount,
    required List<VoucherEntriesCompanion> entries,
    List<StockTransactionsCompanion>? stockTransactions,
    String? existingVoucherId,
    bool allowNegativeStock = false,
  }) async {
    if (_isSubmitting) {
      throw Exception(
        'Voucher submission is already in progress. Please wait.',
      );
    }
    _isSubmitting = true;

    try {
      // Validate double entry (Total Debits == Total Credits using exact minor units)
      int totalDebitPaise = 0;
      int totalCreditPaise = 0;
      for (final entry in entries) {
        final d = entry.debitAmount.present ? entry.debitAmount.value : 0.0;
        final c = entry.creditAmount.present ? entry.creditAmount.value : 0.0;
        totalDebitPaise += MoneyPrecision.toPaise(d);
        totalCreditPaise += MoneyPrecision.toPaise(c);
      }

      if (totalDebitPaise != totalCreditPaise) {
        throw Exception(
          'Double-entry validation failed: Total Debits (${MoneyPrecision.toRupees(totalDebitPaise)}) must equal Total Credits (${MoneyPrecision.toRupees(totalCreditPaise)})',
        );
      }

      final financialYear = FinancialYearService.getFinancialYear(date);
      String finalVoucherNumber = voucherNumber ?? '';

      await db.transaction(() async {
        final voucherId = existingVoucherId ?? uuid.v4();

        // If new voucher and no voucherNumber provided, reserve transactionally
        if (existingVoucherId == null && finalVoucherNumber.isEmpty) {
          finalVoucherNumber = await reserveNextInvoiceNumberInTx(
            voucherType,
            date,
          );
        }

        if (existingVoucherId != null) {
          // Wipe old splits and stock transactions first so stock check reflects current state
          await (db.delete(
            db.voucherEntries,
          )..where((t) => t.voucherId.equals(existingVoucherId))).go();
          await (db.delete(
            db.stockTransactions,
          )..where((t) => t.voucherId.equals(existingVoucherId))).go();

          // Update existing voucher
          final voucherUpdate = VouchersCompanion(
            voucherNumber: Value(finalVoucherNumber),
            voucherType: Value(voucherType),
            financialYear: Value(financialYear),
            date: Value(date),
            narration: Value(narration),
            referenceNumber: Value(referenceNumber),
            paymentMode: Value(paymentMode),
            discountAmount: Value(discountAmount ?? 0.0),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          );
          final updateWithParty = partyLedgerId == null
              ? voucherUpdate
              : voucherUpdate.copyWith(partyLedgerId: Value(partyLedgerId));
          await (db.update(db.vouchers)
                ..where((t) => t.id.equals(existingVoucherId)))
              .write(updateWithParty);
        } else {
          // Insert new voucher header
          await db
              .into(db.vouchers)
              .insert(
                VouchersCompanion.insert(
                  id: voucherId,
                  voucherNumber: finalVoucherNumber,
                  voucherType: voucherType,
                  partyLedgerId: Value(partyLedgerId),
                  financialYear: Value(financialYear),
                  date: date,
                  narration: Value(narration),
                  referenceNumber: Value(referenceNumber),
                  paymentMode: Value(paymentMode),
                  discountAmount: Value(discountAmount ?? 0.0),
                  status: const Value('POSTED'),
                  updatedAt: Value(DateTime.now()),
                  isSynced: const Value(false),
                ),
              );
        }

        // Stock Level Validation inside Transaction (Atomic)
        if (stockTransactions != null && !allowNegativeStock) {
          for (final st in stockTransactions) {
            final type = st.transactionType.present
                ? st.transactionType.value
                : 'OUT';
            if (type == 'OUT') {
              final itemId = st.stockItemId.present ? st.stockItemId.value : '';
              final reqQty = st.quantity.present ? st.quantity.value : 0.0;
              if (itemId.isNotEmpty && reqQty > 0) {
                final stockSummary = await getStockSummaryForItem(itemId);
                if (stockSummary.quantity < reqQty) {
                  throw InsufficientStockException(
                    'Insufficient stock for "${stockSummary.name}": Available ${stockSummary.quantity}, Required $reqQty',
                  );
                }
              }
            }
          }
        }

        // Insert Entries (inside transaction)
        for (final entry in entries) {
          final entryWithVoucher = entry.copyWith(
            id: Value(uuid.v4()),
            voucherId: Value(voucherId),
          );
          await db.into(db.voucherEntries).insert(entryWithVoucher);
        }

        // Insert Stock Transactions (if any, inside transaction)
        if (stockTransactions != null) {
          for (final st in stockTransactions) {
            final stWithVoucher = st.copyWith(
              id: Value(uuid.v4()),
              voucherId: Value(voucherId),
            );
            await db.into(db.stockTransactions).insert(stWithVoucher);
          }
        }
      }); // end db.transaction

      return finalVoucherNumber;
    } finally {
      _isSubmitting = false;
    }
  }

  // 3. Cancel Voucher (Preserves accounting history, stock safely restored)
  Future<void> cancelVoucher(String voucherId) async {
    await db.transaction(() async {
      final v = await (db.select(db.vouchers)..where((t) => t.id.equals(voucherId))).getSingleOrNull();
      if (v == null) return;

      await (db.update(
        db.vouchers,
      )..where((t) => t.id.equals(voucherId))).write(
        VouchersCompanion(
          status: const Value('CANCELLED'),
          updatedAt: Value(DateTime.now()),
        ),
      );

      await db.into(db.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: uuid.v4(),
          action: 'CANCEL',
          entityType: 'Voucher',
          entityId: voucherId,
          oldValue: const Value('POSTED'),
          newValue: const Value('CANCELLED'),
          metadata: Value('${v.voucherType} ${v.voucherNumber} cancelled'),
        ),
      );
    });
  }

  // 3b. Delete Voucher (Permanently wipes voucher, entries, and stock)
  Future<void> deleteVoucher(String voucherIdOrNumber) async {
    await db.transaction(() async {
      final v =
          await (db.select(db.vouchers)..where(
                (t) =>
                    t.id.equals(voucherIdOrNumber) |
                    t.voucherNumber.equals(voucherIdOrNumber),
              ))
              .getSingleOrNull();
      if (v == null) return;
      final vid = v.id;

      await db.into(db.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: uuid.v4(),
          action: 'DELETE',
          entityType: 'Voucher',
          entityId: vid,
          oldValue: Value('${v.voucherType} ${v.voucherNumber}'),
          metadata: Value('PaymentMode: ${v.paymentMode ?? "N/A"}, Party: ${v.partyLedgerId ?? "N/A"}'),
        ),
      );

      await (db.delete(
        db.stockTransactions,
      )..where((t) => t.voucherId.equals(vid))).go();
      await (db.delete(
        db.voucherEntries,
      )..where((t) => t.voucherId.equals(vid))).go();
      await (db.delete(db.vouchers)..where((t) => t.id.equals(vid))).go();
    });
  }

  // Payment & Receipt management shortcuts
  Future<void> cancelPayment(String voucherId) => cancelVoucher(voucherId);
  Future<void> deletePayment(String voucherId) => deleteVoucher(voucherId);
  Future<void> cancelReceipt(String voucherId) => cancelVoucher(voucherId);
  Future<void> deleteReceipt(String voucherId) => deleteVoucher(voucherId);

  // Customer / Ledger deletion with transaction preservation
  Future<bool> hasCustomerTransactions(String ledgerId) async {
    final count = await (db.select(
      db.voucherEntries,
    )..where((t) => t.ledgerId.equals(ledgerId))).get();
    return count.isNotEmpty;
  }

  Future<bool> deleteCustomer(String ledgerId) async {
    return await db.transaction(() async {
      final hasTx = await hasCustomerTransactions(ledgerId);
      if (hasTx) {
        // Soft-delete / deactivate customer to safely preserve transaction history
        await (db.update(db.ledgers)..where((t) => t.id.equals(ledgerId)))
            .write(const LedgersCompanion(isDeleted: Value(true)));
        return false; // Soft-deleted / deactivated
      } else {
        // Safe to hard-delete
        await (db.delete(db.ledgers)..where((t) => t.id.equals(ledgerId))).go();
        return true; // Permanently deleted
      }
    });
  }

  // Data Reset: Reset business transactions while preserving company profile & logo
  Future<void> resetBusinessData({bool keepMasters = true}) async {
    await db.transaction(() async {
      await db.delete(db.stockTransactions).go();
      await db.delete(db.voucherEntries).go();
      await db.delete(db.vouchers).go();
      await db.delete(db.invoiceSequences).go();
      await db.delete(db.auditLogs).go();

      if (!keepMasters) {
        await db.delete(db.stockItems).go();
        const standardLedgerIds = {
          'cash',
          'profit_loss',
          'sales',
          'purchase',
          'cgst',
          'sgst',
        };
        await (db.delete(
          db.ledgers,
        )..where((t) => t.id.isNotIn(standardLedgerIds))).go();
      }
      // Business profiles and syncMetadata remain 100% intact!
    });
  }

  // 4. Compute Ledger Balance via direct SQL aggregation
  Future<double> getLedgerBalance(String ledgerId) async {
    final res = await db
        .customSelect(
          'SELECT l.opening_balance + '
          'COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN ve.debit_amount ELSE 0.0 END), 0.0) - '
          'COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN ve.credit_amount ELSE 0.0 END), 0.0) AS net_balance '
          'FROM ledgers l '
          'LEFT JOIN voucher_entries ve ON ve.ledger_id = l.id '
          'LEFT JOIN vouchers v ON ve.voucher_id = v.id AND (v.status IS NULL OR v.status = \'POSTED\') '
          'WHERE l.id = ? '
          'GROUP BY l.id;',
          variables: [Variable.withString(ledgerId)],
        )
        .getSingleOrNull();

    if (res == null) return 0.0;
    return (res.data['net_balance'] as num).toDouble();
  }

  // 5. Get Ledger Statement (Includes both direct postings and settled cash transactions)
  Future<List<LedgerStatementRow>> getLedgerStatement(String ledgerId) async {
    final ledger = await (db.select(
      db.ledgers,
    )..where((t) => t.id.equals(ledgerId))).getSingle();

    // 1. Direct double-entry splits posted to this ledger
    final directQuery =
        db.select(db.voucherEntries).join([
          innerJoin(
            db.vouchers,
            db.vouchers.id.equalsExp(db.voucherEntries.voucherId),
          ),
        ])..where(
          db.voucherEntries.ledgerId.equals(ledgerId) &
              (db.vouchers.status.isNull() |
                  db.vouchers.status.equals('POSTED')),
        );

    final directResults = await directQuery.get();
    final directVoucherIds = directResults
        .map((r) => r.readTable(db.voucherEntries).voucherId)
        .toSet();

    // 2. Direct Cash transactions where this party is the named party on the voucher header
    // (e.g. Cash Sale or Cash Purchase where cash is debited/credited directly without customer debt)
    final cashVouchersQuery = db.select(db.vouchers)..where(
      (v) =>
          v.partyLedgerId.equals(ledgerId) &
          (v.paymentMode.equals('Cash') | v.paymentMode.equals('CASH')) &
          (v.status.isNull() | v.status.equals('POSTED')),
    );
    final cashVouchers = await cashVouchersQuery.get();

    final List<_StatementItem> items = [];

    for (final row in directResults) {
      final entry = row.readTable(db.voucherEntries);
      final voucher = row.readTable(db.vouchers);
      items.add(
        _StatementItem(
          voucherId: voucher.id,
          date: voucher.date,
          voucherNo: voucher.voucherNumber,
          voucherType: voucher.voucherType,
          narration: voucher.narration ?? '',
          debit: entry.debitAmount,
          credit: entry.creditAmount,
          paymentMode: voucher.paymentMode,
        ),
      );
    }

    for (final voucher in cashVouchers) {
      if (directVoucherIds.contains(voucher.id)) continue;

      // Calculate total amount from voucher entries (sum of debits)
      final vEntries = await (db.select(db.voucherEntries)
            ..where((t) => t.voucherId.equals(voucher.id)))
          .get();
      final totalAmount = vEntries.fold<double>(
        0.0,
        (sum, e) => sum + e.debitAmount,
      );

      items.add(
        _StatementItem(
          voucherId: voucher.id,
          date: voucher.date,
          voucherNo: voucher.voucherNumber,
          voucherType: voucher.voucherType,
          narration: voucher.narration ??
              (voucher.voucherType == 'Sales'
                  ? 'Cash Sale (Paid)'
                  : 'Cash Purchase (Paid)'),
          debit: totalAmount,
          credit: totalAmount,
          paymentMode: 'Cash',
        ),
      );
    }

    // Sort chronologically by date and voucher number
    items.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      return a.voucherNo.compareTo(b.voucherNo);
    });

    double currentBalance = ledger.openingBalance;
    List<LedgerStatementRow> statement = [];

    for (final item in items) {
      currentBalance += item.debit - item.credit;
      statement.add(
        LedgerStatementRow(
          voucherId: item.voucherId,
          date: item.date,
          voucherNo: item.voucherNo,
          voucherType: item.voucherType,
          narration: item.narration,
          debit: item.debit,
          credit: item.credit,
          runningBalance: currentBalance,
          paymentMode: item.paymentMode,
        ),
      );
    }

    return statement;
  }

  /// 5b. Fetch all Cash transactions with associated Customer / Supplier Party Name
  Future<List<CashTransactionRow>> getCashTransactions() async {
    final cashLedger = await (db.select(db.ledgers)..where((t) => t.id.equals('cash'))).getSingleOrNull();
    double currentBalance = cashLedger?.openingBalance ?? 0.0;

    final query = db.select(db.voucherEntries).join([
      innerJoin(db.vouchers, db.vouchers.id.equalsExp(db.voucherEntries.voucherId)),
    ])..where(
      db.voucherEntries.ledgerId.equals('cash') &
      (db.vouchers.status.isNull() | db.vouchers.status.equals('POSTED'))
    );
    query.orderBy([OrderingTerm.asc(db.vouchers.date), OrderingTerm.asc(db.vouchers.voucherNumber)]);
    final results = await query.get();

    final List<CashTransactionRow> list = [];
    for (final row in results) {
      final entry = row.readTable(db.voucherEntries);
      final voucher = row.readTable(db.vouchers);

      final isCashIn = entry.debitAmount > 0;
      final amount = isCashIn ? entry.debitAmount : entry.creditAmount;
      currentBalance += entry.debitAmount - entry.creditAmount;

      String partyName = 'Cash Counter / Walk-in';
      if (voucher.partyLedgerId != null) {
        final party = await (db.select(db.ledgers)..where((t) => t.id.equals(voucher.partyLedgerId!))).getSingleOrNull();
        if (party != null) {
          partyName = party.name;
        }
      } else {
        final otherEntries = await (db.select(db.voucherEntries).join([
          innerJoin(db.ledgers, db.ledgers.id.equalsExp(db.voucherEntries.ledgerId)),
        ])..where(
          db.voucherEntries.voucherId.equals(voucher.id) &
          db.voucherEntries.ledgerId.isNotIn(['cash', 'sales', 'purchase', 'cgst', 'sgst'])
        )).get();
        if (otherEntries.isNotEmpty) {
          partyName = otherEntries.first.readTable(db.ledgers).name;
        }
      }

      list.add(CashTransactionRow(
        voucherId: voucher.id,
        date: voucher.date,
        voucherNo: voucher.voucherNumber,
        voucherType: voucher.voucherType,
        partyName: partyName,
        narration: voucher.narration ?? '',
        amount: amount,
        isCashIn: isCashIn,
        runningBalance: currentBalance,
      ));
    }

    return list;
  }

  // 6. Calculate Stock Level for single item
  Future<StockStatus> getStockSummaryForItem(String stockItemId) async {
    final item = await (db.select(
      db.stockItems,
    )..where((t) => t.id.equals(stockItemId))).getSingle();
    final query =
        db.select(db.stockTransactions).join([
          innerJoin(
            db.vouchers,
            db.vouchers.id.equalsExp(db.stockTransactions.voucherId),
          ),
        ])..where(
          db.stockTransactions.stockItemId.equals(stockItemId) &
              (db.vouchers.status.isNull() |
                  db.vouchers.status.equals('POSTED')),
        );
    query.orderBy([OrderingTerm.asc(db.vouchers.date)]);
    final txs = await query.get();

    double currentQty = item.openingQuantity;
    double avgCost = item.openingRate;
    double totalValue = currentQty * avgCost;

    for (final row in txs) {
      final tx = row.readTable(db.stockTransactions);
      if (tx.transactionType == 'IN') {
        final double newQty = currentQty + tx.quantity;
        if (newQty > 0) {
          avgCost = (totalValue + (tx.quantity * tx.rate)) / newQty;
        } else {
          avgCost = tx.rate;
        }
        currentQty = newQty;
        totalValue = currentQty * avgCost;
      } else {
        currentQty = currentQty - tx.quantity;
        totalValue = currentQty * avgCost;
      }
    }

    return StockStatus(
      id: item.id,
      name: item.name,
      quantity: currentQty,
      averageRate: avgCost,
      totalValue: totalValue,
    );
  }

  // 7. Calculate Inventory Stock Levels across catalog
  Future<List<StockStatus>> getStockSummary() async {
    final items = await db.select(db.stockItems).get();
    List<StockStatus> summary = [];

    for (final item in items) {
      final status = await getStockSummaryForItem(item.id);
      summary.add(status);
    }

    summary.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return summary;
  }

  // 8. Generate Trial Balance using direct SQL aggregation
  Future<List<TrialBalanceRow>> getTrialBalance() async {
    final rows = await db
        .customSelect(
          'SELECT l.id AS ledger_id, l.name AS ledger_name, g.name AS group_name, '
          'l.opening_balance + '
          'COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN ve.debit_amount ELSE 0.0 END), 0.0) - '
          'COALESCE(SUM(CASE WHEN v.id IS NOT NULL THEN ve.credit_amount ELSE 0.0 END), 0.0) AS net_balance '
          'FROM ledgers l '
          'JOIN account_groups g ON l.group_id = g.id '
          'LEFT JOIN voucher_entries ve ON ve.ledger_id = l.id '
          'LEFT JOIN vouchers v ON ve.voucher_id = v.id AND (v.status IS NULL OR v.status = \'POSTED\') '
          'GROUP BY l.id, l.name, g.name '
          'HAVING net_balance != 0.0 '
          'ORDER BY LOWER(l.name) ASC;',
        )
        .get();

    final result = rows.map((r) {
      final netBal = (r.data['net_balance'] as num).toDouble();
      return TrialBalanceRow(
        ledgerId: r.data['ledger_id'] as String,
        ledgerName: r.data['ledger_name'] as String,
        groupName: r.data['group_name'] as String,
        debitBalance: netBal > 0 ? netBal : 0.0,
        creditBalance: netBal < 0 ? netBal.abs() : 0.0,
      );
    }).toList();

    result.sort(
      (a, b) =>
          a.ledgerName.toLowerCase().compareTo(b.ledgerName.toLowerCase()),
    );
    return result;
  }

  // 9. Day Book with SQL Join and Keyset/Limit Pagination
  Future<List<DayBookRow>> getDayBook({
    int limit = 50,
    int offset = 0,
    DateTime? startDate,
    DateTime? endDate,
    String? voucherType,
  }) async {
    String whereClause = "WHERE (v.status IS NULL OR v.status = 'POSTED')";
    List<Variable> vars = [];

    if (startDate != null) {
      whereClause += " AND v.date >= ?";
      vars.add(Variable.withDateTime(startDate));
    }
    if (endDate != null) {
      whereClause += " AND v.date <= ?";
      vars.add(Variable.withDateTime(endDate));
    }
    if (voucherType != null && voucherType.isNotEmpty && voucherType != 'All') {
      whereClause += " AND v.voucher_type = ?";
      vars.add(Variable.withString(voucherType));
    }

    vars.add(Variable.withInt(limit));
    vars.add(Variable.withInt(offset));

    final queryStr =
        '''
      WITH paged_vouchers AS (
        SELECT v.id, v.voucher_number, v.voucher_type, v.date, v.narration,
               v.party_ledger_id, v.reference_number, v.payment_mode, v.discount_amount
        FROM vouchers v
        $whereClause
        ORDER BY v.date DESC, v.voucher_number DESC, v.id DESC
        LIMIT ? OFFSET ?
      )
      SELECT pv.id AS voucher_id, pv.voucher_number, pv.voucher_type, pv.date, pv.narration,
             pv.party_ledger_id, pv.reference_number, pv.payment_mode, pv.discount_amount,
             party.name AS party_name,
             COALESCE(SUM(CASE
               WHEN ve.ledger_id = pv.party_ledger_id
                 AND ve.debit_amount = ve.credit_amount THEN 0.0
               ELSE ve.debit_amount
             END), 0.0) AS total_debit,
             COALESCE(SUM(CASE
               WHEN ve.ledger_id = pv.party_ledger_id
                 AND ve.debit_amount = ve.credit_amount THEN 0.0
               ELSE ve.credit_amount
             END), 0.0) AS total_credit
      FROM paged_vouchers pv
      LEFT JOIN voucher_entries ve ON ve.voucher_id = pv.id
      LEFT JOIN ledgers party ON party.id = pv.party_ledger_id
      GROUP BY pv.id, pv.voucher_number, pv.voucher_type, pv.date, pv.narration,
               pv.party_ledger_id, pv.reference_number, pv.payment_mode, pv.discount_amount, party.name
      ORDER BY pv.date DESC, pv.voucher_number DESC, pv.id DESC;
    ''';

    final rows = await db.customSelect(queryStr, variables: vars).get();
    return rows
        .map(
          (r) => DayBookRow(
            voucherId: r.data['voucher_id'] as String,
            voucherNumber: r.data['voucher_number'] as String,
            voucherType: r.data['voucher_type'] as String,
            date: r.read<DateTime>('date'),
            narration: r.data['narration'] as String? ?? '',
            totalAmount: (r.data['total_debit'] as num).toDouble(),
            totalDebit: (r.data['total_debit'] as num).toDouble(),
            totalCredit: (r.data['total_credit'] as num).toDouble(),
            partyLedgerId: r.data['party_ledger_id'] as String?,
            partyName: r.data['party_name'] as String?,
            referenceNumber: r.data['reference_number'] as String?,
            paymentMode: r.data['payment_mode'] as String?,
            discountAmount: (r.data['discount_amount'] as num).toDouble(),
          ),
        )
        .toList();
  }

  // 10. Generate Profit & Loss Report
  Future<ProfitLossReport> getProfitLossReport() async {
    final salesLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('sales_accounts'))).get();
    double salesVal = 0.0;
    for (final l in salesLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) salesVal += bal.abs();
    }

    final purchaseLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('purchase_accounts'))).get();
    double purchaseVal = 0.0;
    for (final l in purchaseLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) purchaseVal += bal;
    }

    final directExpLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('direct_expenses'))).get();
    double directExp = 0.0;
    for (final l in directExpLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) directExp += bal;
    }

    final indirectExpLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('indirect_expenses'))).get();
    double indirectExp = 0.0;
    for (final l in indirectExpLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) indirectExp += bal;
    }

    final stockItemsList = await db.select(db.stockItems).get();
    double openingStockVal = 0.0;
    for (final item in stockItemsList) {
      openingStockVal += item.openingQuantity * item.openingRate;
    }

    final stockStatusList = await getStockSummary();
    double closingStockVal = 0.0;
    for (final status in stockStatusList) {
      closingStockVal += status.totalValue;
    }

    final cogs = openingStockVal + purchaseVal + directExp - closingStockVal;
    final grossProfit = salesVal - cogs;
    final netProfit = grossProfit - indirectExp;

    return ProfitLossReport(
      openingStockValue: openingStockVal,
      purchaseValue: purchaseVal,
      directExpenses: directExp,
      grossProfit: grossProfit,
      closingStockValue: closingStockVal,
      salesValue: salesVal,
      indirectExpenses: indirectExp,
      netProfit: netProfit,
    );
  }

  // 11. Generate Balance Sheet Report
  Future<BalanceSheetReport> getBalanceSheetReport() async {
    final capitalLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('equity'))).get();
    double capitalBal = 0.0;
    for (final l in capitalLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (l.id != 'profit_loss') {
        capitalBal += -bal;
      }
    }

    final creditorLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('creditors'))).get();
    double creditorsBal = 0.0;
    for (final l in creditorLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) creditorsBal += bal.abs();
    }

    final taxLedgers = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('duties_taxes'))).get();
    double taxesBal = 0.0;
    for (final l in taxLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) taxesBal += bal.abs();
    }
    double totalLiabilities = taxesBal;

    final plReport = await getProfitLossReport();
    final netProfitSurplus = plReport.netProfit;

    final cashLedgersList = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('cash_in_hand'))).get();
    double cashBal = 0.0;
    for (final l in cashLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) cashBal += bal;
    }

    final bankLedgersList = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('bank_accounts'))).get();
    double bankBal = 0.0;
    for (final l in bankLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) bankBal += bal;
    }

    final debtorLedgersList = await (db.select(
      db.ledgers,
    )..where((t) => t.groupId.equals('debtors'))).get();
    double debtorsBal = 0.0;
    for (final l in debtorLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) debtorsBal += bal;
    }

    final closingStockVal = plReport.closingStockValue;
    final totalAssets = cashBal + bankBal + debtorsBal + closingStockVal;

    return BalanceSheetReport(
      capitalBalance: capitalBal,
      netProfitSurplus: netProfitSurplus,
      totalLiabilities: totalLiabilities,
      sundryCreditors: creditorsBal,
      closingStock: closingStockVal,
      cashBalance: cashBal,
      bankBalance: bankBal,
      sundryDebtors: debtorsBal,
      totalAssets: totalAssets,
    );
  }

  // 12. Fetch complete details for a specific voucher
  Future<VoucherDetail?> getVoucherDetail(String voucherId) async {
    final voucher = await (db.select(
      db.vouchers,
    )..where((t) => t.id.equals(voucherId))).getSingleOrNull();
    if (voucher == null) return null;

    final entries = await (db.select(
      db.voucherEntries,
    )..where((t) => t.voucherId.equals(voucherId))).get();

    Ledger? contactLedger;
    if (voucher.partyLedgerId != null) {
      contactLedger = await (db.select(
        db.ledgers,
      )..where((t) => t.id.equals(voucher.partyLedgerId!))).getSingleOrNull();
    }
    if (contactLedger == null) {
      for (final entry in entries) {
        final ledger = await (db.select(
          db.ledgers,
        )..where((t) => t.id.equals(entry.ledgerId))).getSingleOrNull();
        if (ledger != null &&
            (ledger.groupId == 'debtors' || ledger.groupId == 'creditors')) {
          contactLedger = ledger;
          break;
        }
      }
    }

    if (contactLedger == null && entries.isNotEmpty) {
      contactLedger = await (db.select(
        db.ledgers,
      )..where((t) => t.id.equals(entries.first.ledgerId))).getSingleOrNull();
    }

    final finalContactLedger =
        contactLedger ??
        Ledger(
          id: 'unknown',
          name: 'Unknown Account',
          groupId: 'debtors',
          openingBalance: 0.0,
          updatedAt: DateTime.now(),
          isSynced: false,
          isDeleted: false,
        );

    final query = db.select(db.stockTransactions).join([
      innerJoin(
        db.stockItems,
        db.stockItems.id.equalsExp(db.stockTransactions.stockItemId),
      ),
    ])..where(db.stockTransactions.voucherId.equals(voucherId));

    final results = await query.get();
    final stockTransactions = results.map((row) {
      final tx = row.readTable(db.stockTransactions);
      final item = row.readTable(db.stockItems);
      return StockTransactionWithItem(
        tx: tx,
        itemName: item.name,
        sku: item.sku,
      );
    }).toList();

    return VoucherDetail(
      voucher: voucher,
      contactLedger: finalContactLedger,
      entries: entries,
      stockTransactions: stockTransactions,
    );
  }
}

class StockTransactionWithItem {
  final StockTransaction tx;
  final String itemName;
  final String? sku;

  StockTransactionWithItem({
    required this.tx,
    required this.itemName,
    required this.sku,
  });
}

class VoucherDetail {
  final Voucher voucher;
  final Ledger contactLedger;
  final List<VoucherEntry> entries;
  final List<StockTransactionWithItem> stockTransactions;

  VoucherDetail({
    required this.voucher,
    required this.contactLedger,
    required this.entries,
    required this.stockTransactions,
  });

  double get transactionAmount => entries.fold(
    0.0,
    (total, entry) => entry.debitAmount == entry.creditAmount
        ? total
        : total + entry.debitAmount,
  );
}
