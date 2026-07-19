import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../data/database.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'widgets/voucher_detail_dialog.dart';

class ReportViewerPage extends StatefulWidget {
  const ReportViewerPage({super.key});

  @override
  State<ReportViewerPage> createState() => _ReportViewerPageState();
}

class _ReportViewerPageState extends State<ReportViewerPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  DateTime _selectedDaybookDate = DateTime.now();
  bool _enableDaybookDateFilter = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Financial Reports', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.indigoAccent,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Day Book'),
            Tab(text: 'Trial Balance'),
            Tab(text: 'Profit & Loss A/c'),
            Tab(text: 'Balance Sheet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDaybookTab(),
          _buildTrialBalanceTab(),
          _buildProfitLossTab(),
          _buildBalanceSheetTab(),
        ],
      ),
    );
  }

  // 1. Daybook View
  Widget _buildDaybookTab() {
    final db = Provider.of<AppDatabase>(context);

    // Watch vouchers with optional date filtering
    final query = db.select(db.vouchers)..orderBy([(t) => drift.OrderingTerm.desc(t.date)]);
    if (_enableDaybookDateFilter) {
      final startOfDay = DateTime(_selectedDaybookDate.year, _selectedDaybookDate.month, _selectedDaybookDate.day);
      final endOfDay = DateTime(_selectedDaybookDate.year, _selectedDaybookDate.month, _selectedDaybookDate.day, 23, 59, 59);
      query.where((t) => t.date.isBiggerOrEqual(drift.Variable(startOfDay)) & t.date.isSmallerOrEqual(drift.Variable(endOfDay)));
    }
    final stream = query.watch();

    return Column(
      children: [
        // Date Filter Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2235),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded, color: Colors.indigoAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filter by Date',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _enableDaybookDateFilter,
                    activeColor: Colors.indigoAccent,
                    onChanged: (val) {
                      setState(() {
                        _enableDaybookDateFilter = val;
                      });
                    },
                  ),
                ],
              ),
              if (_enableDaybookDateFilter)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.indigoAccent),
                  label: Text(DateFormat('dd-MMM-yyyy').format(_selectedDaybookDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDaybookDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Colors.indigoAccent,
                              onPrimary: Colors.white,
                              surface: Color(0xFF1E2235),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDaybookDate = picked;
                      });
                    }
                  },
                ),
            ],
          ),
        ),
        // Daybook entries list
        Expanded(
          child: StreamBuilder<List<Voucher>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
              }

              final vouchers = snapshot.data ?? [];
              if (vouchers.isEmpty) {
                return const Center(child: Text('No vouchers posted on this date.', style: TextStyle(color: Colors.white54)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
            final voucher = vouchers[index];
            
            // Query entries inside voucher
            return FutureBuilder<List<VoucherEntry>>(
              future: (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucher.id))).get(),
              builder: (context, entrySnap) {
                final entries = entrySnap.data ?? [];
                
                // Calculate voucher total (sum of debits)
                double voucherTotal = entries.fold(0.0, (sum, ent) => sum + ent.debitAmount);

                return Card(
                  color: const Color(0xFF1E2235),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: ExpansionTile(
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white70,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          voucher.voucherNumber,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          voucher.voucherType.toUpperCase(),
                          style: TextStyle(
                            color: voucher.voucherType == 'Sales'
                                ? Colors.greenAccent
                                : voucher.voucherType == 'Purchase'
                                    ? Colors.orangeAccent
                                    : Colors.blueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('dd-MMM-yyyy hh:mm a').format(voucher.date),
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        Text(
                          _currencyFormat.format(voucherTotal),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFF161928).withOpacity(0.5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                              Text('Narration: ${voucher.narration}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
                              const SizedBox(height: 12),
                            ],
                            const Divider(color: Colors.white10),
                            // List double-entry rows
                            ...entries.map((ent) {
                              return FutureBuilder<Ledger>(
                                future: (db.select(db.ledgers)..where((t) => t.id.equals(ent.ledgerId))).getSingle(),
                                builder: (context, ledgerSnap) {
                                  final ledgerName = ledgerSnap.data?.name ?? 'Loading...';
                                  final double amt = ent.debitAmount > 0 ? ent.debitAmount : ent.creditAmount;
                                  final isDr = ent.debitAmount > 0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isDr ? ledgerName : '   To $ledgerName',
                                          style: TextStyle(
                                            color: isDr ? Colors.white : Colors.white70,
                                            fontWeight: isDr ? FontWeight.w500 : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          '${_currencyFormat.format(amt)} ${isDr ? "Dr" : "Cr"}',
                                          style: TextStyle(
                                            color: isDr ? Colors.greenAccent : Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }),
                            const SizedBox(height: 12),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.indigoAccent,
                                  ),
                                  icon: const Icon(Icons.zoom_in_rounded, size: 16),
                                  label: const Text(
                                    'View Bill / Alter Details',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () => VoucherDetailDialog.show(context, voucher.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ),
  ),
],
);
}

  // 2. Trial Balance View
  Widget _buildTrialBalanceTab() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return FutureBuilder<List<TrialBalanceRow>>(
      future: engine.getTrialBalance(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }

        final rows = snapshot.data ?? [];
        double totalDebit = rows.fold(0.0, (sum, row) => sum + row.debitBalance);
        double totalCredit = rows.fold(0.0, (sum, row) => sum + row.creditBalance);

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              _buildReportHeader(['Account Ledger', 'Group', 'Debit Balance', 'Credit Balance']),
              const SizedBox(height: 8),

              // Rows list
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('No ledger accounts with non-zero balances.', style: TextStyle(color: Colors.white38)))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          return InkWell(
                            onTap: () => _showLedgerStatementDialog(row.ledgerId, row.ledgerName),
                            child: _buildReportRow([
                              row.ledgerName,
                              row.groupName,
                              row.debitBalance > 0 ? _currencyFormat.format(row.debitBalance) : '-',
                              row.creditBalance > 0 ? _currencyFormat.format(row.creditBalance) : '-',
                            ], index % 2 == 0),
                          );
                        },
                      ),
              ),

              const Divider(color: Colors.white24, thickness: 1, height: 24),
              // Total Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Sum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Row(
                      children: [
                        Text(_currencyFormat.format(totalDebit), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 80),
                        Text(_currencyFormat.format(totalCredit), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 3. Profit & Loss View
  Widget _buildProfitLossTab() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return FutureBuilder<ProfitLossReport>(
      future: engine.getProfitLossReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }

        final report = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final plContent = [
                // Left Box: Debit items (Expenses, Opening Stock)
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DEBITS (Trading & Expenses)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white12, height: 20),
                        _buildPLRow('Opening Stock Value', report.openingStockValue),
                        _buildPLRow('Add: Purchases', report.purchaseValue, onTap: () => _showGroupScheduleDialog('purchase_accounts', 'Purchase Accounts')),
                        _buildPLRow('Direct Expenses', report.directExpenses, onTap: () => _showGroupScheduleDialog('direct_expenses', 'Direct Expenses')),
                        const Divider(color: Colors.white10),
                        _buildPLRow('Gross Profit (Transferred)', report.grossProfit, highlight: true, valueColor: Colors.tealAccent),
                        const Divider(color: Colors.white24, height: 24),
                        _buildPLRow('Indirect Expenses', report.indirectExpenses, onTap: () => _showGroupScheduleDialog('indirect_expenses', 'Indirect Expenses')),
                        const Divider(color: Colors.white10),
                        _buildPLRow(
                          report.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                          report.netProfit.abs(),
                          highlight: true,
                          valueColor: report.netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isNarrow ? 0 : 24, height: isNarrow ? 24 : 0),
                // Right Box: Credit items (Sales, Closing Stock)
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CREDITS (Trading & Revenue)', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white12, height: 20),
                        _buildPLRow('Sales Accounts Revenue', report.salesValue, onTap: () => _showGroupScheduleDialog('sales_accounts', 'Sales Accounts')),
                        _buildPLRow('Closing Stock Value', report.closingStockValue),
                        const Divider(color: Colors.white10),
                        // Align with Gross Profit spacer
                        const SizedBox(height: 52),
                        const Divider(color: Colors.white24, height: 24),
                        _buildPLRow('Gross Profit b/f', report.grossProfit, highlight: true, valueColor: Colors.tealAccent),
                      ],
                    ),
                  ),
                ),
              ];

              return isNarrow 
                  ? SingleChildScrollView(child: Column(children: plContent))
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: plContent);
            },
          ),
        );
      },
    );
  }

  // 4. Balance Sheet View
  Widget _buildBalanceSheetTab() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return FutureBuilder<BalanceSheetReport>(
      future: engine.getBalanceSheetReport(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }

        final bs = snapshot.data!;
        final double totalLiabilitiesBox = bs.capitalBalance + bs.netProfitSurplus + bs.sundryCreditors + bs.totalLiabilities;
        final double totalAssetsBox = bs.totalAssets; // including cash, bank, debtors, stock

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 900;
              final bsContent = [
                // Liabilities Column
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LIABILITIES & CAPITAL', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white12, height: 20),
                        _buildPLRow('Capital Account Balance', bs.capitalBalance, onTap: () => _showGroupScheduleDialog('equity', 'Capital Account')),
                        _buildPLRow('Profit & Loss Surplus (Net Profit)', bs.netProfitSurplus, valueColor: bs.netProfitSurplus >= 0 ? Colors.greenAccent : Colors.redAccent),
                        _buildPLRow('Sundry Creditors (Suppliers)', bs.sundryCreditors, onTap: () => _showGroupScheduleDialog('sundry_creditors', 'Sundry Creditors')),
                        _buildPLRow('Duties & Taxes (Liabilities)', bs.totalLiabilities, onTap: () => _showGroupScheduleDialog('duties_taxes', 'Duties & Taxes')),
                        const SizedBox(height: 40),
                        const Divider(color: Colors.white24, height: 20),
                        _buildPLRow('Total Capital & Liabilities', totalLiabilitiesBox, highlight: true),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isNarrow ? 0 : 24, height: isNarrow ? 24 : 0),
                // Assets Column
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ASSETS', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                        const Divider(color: Colors.white12, height: 20),
                        _buildPLRow('Cash-in-hand Balance', bs.cashBalance, onTap: () => _showGroupScheduleDialog('cash_in_hand', 'Cash-in-Hand')),
                        _buildPLRow('Bank Accounts Balance', bs.bankBalance, onTap: () => _showGroupScheduleDialog('bank_accounts', 'Bank Accounts')),
                        _buildPLRow('Sundry Debtors (Customers)', bs.sundryDebtors, onTap: () => _showGroupScheduleDialog('sundry_debtors', 'Sundry Debtors')),
                        _buildPLRow('Closing Stock Valuation', bs.closingStock),
                        const SizedBox(height: 40),
                        const Divider(color: Colors.white24, height: 20),
                        _buildPLRow('Total Assets Valuation', totalAssetsBox, highlight: true, valueColor: Colors.greenAccent),
                      ],
                    ),
                  ),
                ),
              ];

              return isNarrow
                  ? SingleChildScrollView(child: Column(children: bsContent))
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: bsContent);
            },
          ),
        );
      },
    );
  }

  // Common UI Layout helpers for tables
  Widget _buildReportHeader(List<String> headers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: headers.map((h) {
          return Expanded(
            child: Text(
              h,
              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportRow(List<String> values, bool alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: alt ? const Color(0xFF1E2235).withOpacity(0.3) : const Color(0xFF1E2235).withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.02))),
      ),
      child: Row(
        children: values.map((v) {
          return Expanded(
            child: Text(
              v,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showLedgerStatementDialog(String ledgerId, String ledgerName) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          title: Text('$ledgerName - Ledger Book Statement', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 800,
            height: 500,
            child: FutureBuilder<List<LedgerStatementRow>>(
              future: engine.getLedgerStatement(ledgerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }

                final rows = snapshot.data ?? [];

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Vch Type', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Vch No.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Debit', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Credit', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text('Running Balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('No transactions recorded in this ledger.', style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final isAlt = index % 2 == 0;

                                return InkWell(
                                  onTap: () async {
                                    final db = Provider.of<AppDatabase>(context, listen: false);
                                    final voucher = await (db.select(db.vouchers)..where((t) => t.id.equals(row.voucherId))).getSingle();
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => VoucherDetailDialog(voucherId: voucher.id),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isAlt ? Colors.white.withOpacity(0.02) : Colors.transparent,
                                      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.01))),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(DateFormat('dd-MMM-yyyy hh:mm a').format(row.date), style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.voucherType, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.voucherNo, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.debit > 0 ? _currencyFormat.format(row.debit) : '-', style: const TextStyle(color: Colors.greenAccent, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.credit > 0 ? _currencyFormat.format(row.credit) : '-', style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                                        Expanded(flex: 3, child: Text(_currencyFormat.format(row.runningBalance), style: const TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 12))),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  void _showGroupScheduleDialog(String groupId, String groupName) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2235),
          title: Text('$groupName Schedule', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: FutureBuilder<List<Ledger>>(
              future: (db.select(db.ledgers)..where((t) => t.groupId.equals(groupId))).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                }

                final ledgers = snapshot.data ?? [];

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ledger Name', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Closing Balance', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ledgers.isEmpty
                          ? const Center(child: Text('No accounts found in this group.', style: TextStyle(color: Colors.white38)))
                          : ListView.builder(
                              itemCount: ledgers.length,
                              itemBuilder: (context, index) {
                                final l = ledgers[index];
                                final isAlt = index % 2 == 0;

                                return FutureBuilder<double>(
                                  future: engine.getLedgerBalance(l.id),
                                  builder: (context, balSnap) {
                                    final bal = balSnap.data ?? 0.0;

                                    return InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                        _showLedgerStatementDialog(l.id, l.name);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: isAlt ? Colors.white.withOpacity(0.02) : Colors.transparent,
                                          border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.01))),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(l.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                            Text(
                                              _currencyFormat.format(bal.abs()),
                                              style: TextStyle(
                                                color: bal >= 0 ? Colors.greenAccent : Colors.redAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPLRow(String title, double amount, {bool highlight = false, Color? valueColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: highlight ? Colors.white : Colors.white70,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 14 : 13,
              ),
            ),
            Row(
              children: [
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    color: valueColor ?? (highlight ? Colors.white : Colors.white70),
                    fontWeight: FontWeight.bold,
                    fontSize: highlight ? 14 : 13,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
