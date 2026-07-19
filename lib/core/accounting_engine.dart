import 'package:drift/drift.dart';
import '../data/database.dart';
import 'package:uuid/uuid.dart';

class LedgerStatementRow {
  final String voucherId;
  final DateTime date;
  final String voucherNo;
  final String voucherType;
  final String narration;
  final double debit;
  final double credit;
  final double runningBalance;

  LedgerStatementRow({
    required this.voucherId,
    required this.date,
    required this.voucherNo,
    required this.voucherType,
    required this.narration,
    required this.debit,
    required this.credit,
    required this.runningBalance,
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

class AccountingEngine {
  final AppDatabase db;
  final Uuid uuid = const Uuid();

  AccountingEngine(this.db);

  // 1. Create a double-entry voucher
  Future<void> createVoucher({
    required String voucherNumber,
    required String voucherType, // 'Sales', 'Purchase', 'Receipt', 'Payment', 'Journal', 'Contra'
    required DateTime date,
    String? narration,
    String? referenceNumber,
    required List<VoucherEntriesCompanion> entries,
    List<StockTransactionsCompanion>? stockTransactions,
    String? existingVoucherId,
  }) async {
    // Validate double entry (Total Debits == Total Credits)
    double totalDebit = 0;
    double totalCredit = 0;
    for (final entry in entries) {
      totalDebit += entry.debitAmount.value;
      totalCredit += entry.creditAmount.value;
    }

    // Rounding safety check (e.g. within 0.01 margin)
    if ((totalDebit - totalCredit).abs() > 0.01) {
      throw Exception('Double-entry validation failed: Total Debits (\$$totalDebit) must equal Total Credits (\$$totalCredit)');
    }

    await db.transaction(() async {
      final voucherId = existingVoucherId ?? uuid.v4();
      
      if (existingVoucherId != null) {
        // Update existing voucher
        await (db.update(db.vouchers)..where((t) => t.id.equals(existingVoucherId))).write(
          VouchersCompanion(
            voucherNumber: Value(voucherNumber),
            voucherType: Value(voucherType),
            date: Value(date),
            narration: Value(narration),
            referenceNumber: Value(referenceNumber),
            updatedAt: Value(DateTime.now()),
            isSynced: const Value(false),
          ),
        );
        // Wipe old splits and stock transactions
        await (db.delete(db.voucherEntries)..where((t) => t.voucherId.equals(existingVoucherId))).go();
        await (db.delete(db.stockTransactions)..where((t) => t.voucherId.equals(existingVoucherId))).go();
      } else {
        // Insert new voucher header
        await db.into(db.vouchers).insert(VouchersCompanion.insert(
              id: voucherId,
              voucherNumber: voucherNumber,
              voucherType: voucherType,
              date: date,
              narration: Value(narration),
              referenceNumber: Value(referenceNumber),
              updatedAt: Value(DateTime.now()),
              isSynced: const Value(false),
            ));
      }

      // Insert Entries
      for (final entry in entries) {
        final entryWithVoucher = entry.copyWith(
          id: Value(uuid.v4()),
          voucherId: Value(voucherId),
        );
        await db.into(db.voucherEntries).insert(entryWithVoucher);
      }

      // Insert Stock Transactions (if any)
      if (stockTransactions != null) {
        for (final st in stockTransactions) {
          final stWithVoucher = st.copyWith(
            id: Value(uuid.v4()),
            voucherId: Value(voucherId),
          );
          await db.into(db.stockTransactions).insert(stWithVoucher);
        }
      }
    });
  }

  // 2. Compute Ledger Balance dynamically
  Future<double> getLedgerBalance(String ledgerId) async {
    final ledger = await (db.select(db.ledgers)..where((t) => t.id.equals(ledgerId))).getSingle();
    
    final query = db.select(db.voucherEntries)..where((t) => t.ledgerId.equals(ledgerId));
    final entries = await query.get();

    double totalDebit = 0;
    double totalCredit = 0;
    for (final entry in entries) {
      totalDebit += entry.debitAmount;
      totalCredit += entry.creditAmount;
    }

    // Check account type via group to determine if debit or credit heavy
    // For simplicity, Net Debit = OpeningBalance + Debits - Credits
    return ledger.openingBalance + totalDebit - totalCredit;
  }

  // 3. Get Ledger Statement
  Future<List<LedgerStatementRow>> getLedgerStatement(String ledgerId) async {
    final ledger = await (db.select(db.ledgers)..where((t) => t.id.equals(ledgerId))).getSingle();

    final query = db.select(db.voucherEntries).join([
      innerJoin(db.vouchers, db.vouchers.id.equalsExp(db.voucherEntries.voucherId)),
    ])..where(db.voucherEntries.ledgerId.equals(ledgerId));
    
    query.orderBy([OrderingTerm.asc(db.vouchers.date)]);
    
    final results = await query.get();

    double currentBalance = ledger.openingBalance;
    List<LedgerStatementRow> statement = [];

    for (final row in results) {
      final entry = row.readTable(db.voucherEntries);
      final voucher = row.readTable(db.vouchers);

      currentBalance += entry.debitAmount - entry.creditAmount;

      statement.add(LedgerStatementRow(
        voucherId: voucher.id,
        date: voucher.date,
        voucherNo: voucher.voucherNumber,
        voucherType: voucher.voucherType,
        narration: voucher.narration ?? '',
        debit: entry.debitAmount,
        credit: entry.creditAmount,
        runningBalance: currentBalance,
      ));
    }

    return statement;
  }

  // 4. Calculate Inventory Stock Levels and Average Cost Valuations
  Future<List<StockStatus>> getStockSummary() async {
    final items = await db.select(db.stockItems).get();
    List<StockStatus> summary = [];

    for (final item in items) {
      final query = db.select(db.stockTransactions).join([
        innerJoin(db.vouchers, db.vouchers.id.equalsExp(db.stockTransactions.voucherId)),
      ])..where(db.stockTransactions.stockItemId.equals(item.id));
      query.orderBy([OrderingTerm.asc(db.vouchers.date)]);
      final txs = await query.get();

      double currentQty = item.openingQuantity;
      double avgCost = item.openingRate;
      double totalValue = currentQty * avgCost;

      for (final row in txs) {
        final tx = row.readTable(db.stockTransactions);
        
        if (tx.transactionType == 'IN') {
          // Purchase increases stock quantity and updates average cost
          final double newQty = currentQty + tx.quantity;
          if (newQty > 0) {
            avgCost = (totalValue + (tx.quantity * tx.rate)) / newQty;
          } else {
            avgCost = tx.rate;
          }
          currentQty = newQty;
          totalValue = currentQty * avgCost;
        } else {
          // Sale decreases stock quantity, average cost remains the same
          currentQty = currentQty - tx.quantity; // tx.quantity is positive amount sold
          totalValue = currentQty * avgCost;
        }
      }

      summary.add(StockStatus(
        id: item.id,
        name: item.name,
        quantity: currentQty,
        averageRate: avgCost,
        totalValue: totalValue,
      ));
    }

    return summary;
  }

  // 5. Generate Trial Balance
  Future<List<TrialBalanceRow>> getTrialBalance() async {
    final ledgersList = await db.select(db.ledgers).join([
      innerJoin(db.accountGroups, db.accountGroups.id.equalsExp(db.ledgers.groupId))
    ]).get();

    List<TrialBalanceRow> tb = [];

    for (final row in ledgersList) {
      final ledger = row.readTable(db.ledgers);
      final group = row.readTable(db.accountGroups);

      final balance = await getLedgerBalance(ledger.id);

      if (balance == 0.0) continue;

      if (balance > 0) {
        tb.add(TrialBalanceRow(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          groupName: group.name,
          debitBalance: balance,
          creditBalance: 0.0,
        ));
      } else {
        tb.add(TrialBalanceRow(
          ledgerId: ledger.id,
          ledgerName: ledger.name,
          groupName: group.name,
          debitBalance: 0.0,
          creditBalance: balance.abs(),
        ));
      }
    }

    return tb;
  }

  // 6. Generate Profit & Loss Report
  Future<ProfitLossReport> getProfitLossReport() async {
    // 6.1 Total Sales (Revenue Accounts group)
    // Find all ledgers in sales_accounts group
    final salesLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('sales_accounts'))).get();
    double salesVal = 0.0;
    for (final l in salesLedgers) {
      // Sales has credit balance, getLedgerBalance returns Debit-Credit (which is negative for credit). Sum absolute credit.
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) salesVal += bal.abs();
    }

    // 6.2 Total Purchase (Purchase Accounts group)
    final purchaseLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('purchase_accounts'))).get();
    double purchaseVal = 0.0;
    for (final l in purchaseLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) purchaseVal += bal;
    }

    // 6.3 Expenses
    final directExpLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('direct_expenses'))).get();
    double directExp = 0.0;
    for (final l in directExpLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) directExp += bal;
    }

    final indirectExpLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('indirect_expenses'))).get();
    double indirectExp = 0.0;
    for (final l in indirectExpLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) indirectExp += bal;
    }

    // 6.4 Opening Stock Value
    final stockItemsList = await db.select(db.stockItems).get();
    double openingStockVal = 0.0;
    for (final item in stockItemsList) {
      openingStockVal += item.openingQuantity * item.openingRate;
    }

    // 6.5 Closing Stock Value
    final stockStatusList = await getStockSummary();
    double closingStockVal = 0.0;
    for (final status in stockStatusList) {
      closingStockVal += status.totalValue;
    }

    // Cost of Goods Sold (COGS) = Opening Stock + Purchase + Direct Expenses - Closing Stock
    final cogs = openingStockVal + purchaseVal + directExp - closingStockVal;
    
    // Gross Profit = Sales - COGS
    final grossProfit = salesVal - cogs;

    // Net Profit = Gross Profit - Indirect Expenses
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

  // 7. Generate Balance Sheet Report
  Future<BalanceSheetReport> getBalanceSheetReport() async {
    // 7.1 Capital / Equity balances
    final capitalLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('equity'))).get();
    double capitalBal = 0.0;
    for (final l in capitalLedgers) {
      final bal = await getLedgerBalance(l.id);
      // Capital is credit balance, get Ledger balance (Credit - Debit). Since balance is Debit - Credit, negate it.
      if (l.id != 'profit_loss') {
        capitalBal += -bal;
      }
    }

    // 7.2 Sundry Creditors (Suppliers)
    final creditorLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('creditors'))).get();
    double creditorsBal = 0.0;
    for (final l in creditorLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) creditorsBal += bal.abs();
    }

    // 7.3 Duties and Taxes (Liabilities)
    final taxLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('duties_taxes'))).get();
    double taxesBal = 0.0;
    for (final l in taxLedgers) {
      final bal = await getLedgerBalance(l.id);
      if (bal < 0) taxesBal += bal.abs();
    }
    double totalLiabilities = taxesBal; // other liability groups can be added

    // 7.4 Net Profit Surplus from P&L
    final plReport = await getProfitLossReport();
    final netProfitSurplus = plReport.netProfit;

    // 7.5 Assets
    // Cash in hand
    final cashLedgersList = await (db.select(db.ledgers)..where((t) => t.groupId.equals('cash_in_hand'))).get();
    double cashBal = 0.0;
    for (final l in cashLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) cashBal += bal;
    }

    // Bank Accounts
    final bankLedgersList = await (db.select(db.ledgers)..where((t) => t.groupId.equals('bank_accounts'))).get();
    double bankBal = 0.0;
    for (final l in bankLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) bankBal += bal;
    }

    // Sundry Debtors (Customers)
    final debtorLedgersList = await (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors'))).get();
    double debtorsBal = 0.0;
    for (final l in debtorLedgersList) {
      final bal = await getLedgerBalance(l.id);
      if (bal > 0) debtorsBal += bal;
    }

    // Closing Stock
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

  // 12. Fetch complete details for a specific voucher (including items and contact details)
  Future<VoucherDetail?> getVoucherDetail(String voucherId) async {
    final voucher = await (db.select(db.vouchers)..where((t) => t.id.equals(voucherId))).getSingleOrNull();
    if (voucher == null) return null;

    final entries = await (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucherId))).get();
    
    // Find the customer or supplier contact ledger
    Ledger? contactLedger;
    for (final entry in entries) {
      final ledger = await (db.select(db.ledgers)..where((t) => t.id.equals(entry.ledgerId))).getSingleOrNull();
      if (ledger != null && (ledger.groupId == 'debtors' || ledger.groupId == 'creditors')) {
        contactLedger = ledger;
        break;
      }
    }
    
    // Fallback to first ledger if none found
    if (contactLedger == null && entries.isNotEmpty) {
      contactLedger = await (db.select(db.ledgers)..where((t) => t.id.equals(entries.first.ledgerId))).getSingleOrNull();
    }

    final finalContactLedger = contactLedger ?? Ledger(
      id: 'unknown',
      name: 'Unknown Account',
      groupId: 'debtors',
      openingBalance: 0.0,
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    // Load stock transactions and join with stock items to show names
    final query = db.select(db.stockTransactions).join([
      innerJoin(db.stockItems, db.stockItems.id.equalsExp(db.stockTransactions.stockItemId)),
    ])..where(db.stockTransactions.voucherId.equals(voucherId));
    
    final results = await query.get();
    final stockTransactions = results.map((row) {
      final tx = row.readTable(db.stockTransactions);
      final item = row.readTable(db.stockItems);
      return StockTransactionWithItem(tx: tx, itemName: item.name, sku: item.sku);
    }).toList();

    return VoucherDetail(
      voucher: voucher,
      contactLedger: finalContactLedger,
      entries: entries,
      stockTransactions: stockTransactions,
    );
  }
}

// Helper Class definitions for Voucher Drill-downs
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
}
