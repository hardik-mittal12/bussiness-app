import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:printing/printing.dart';
import '../core/accounting_engine.dart';
import '../core/pdf_export_service.dart';
import '../data/database.dart';
import 'theme/app_theme.dart';
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

  Future<void> _exportCurrentTabPdf() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    final pdfService = PdfExportService(db);

    try {
      final tabIndex = _tabController.index;
      Uint8List? bytes;

      if (tabIndex == 0) {
        // Day Book
        final startDate = _enableDaybookDateFilter ? DateTime(_selectedDaybookDate.year, _selectedDaybookDate.month, _selectedDaybookDate.day) : null;
        final endDate = _enableDaybookDateFilter ? DateTime(_selectedDaybookDate.year, _selectedDaybookDate.month, _selectedDaybookDate.day, 23, 59, 59) : null;
        final dayRows = await engine.getDayBook(
          startDate: startDate,
          endDate: endDate,
          limit: 1000,
        );
        bytes = await pdfService.exportDayBookPdf(_selectedDaybookDate, dayRows);
      } else if (tabIndex == 1) {
        // Trial Balance
        final tbRows = await engine.getTrialBalance();
        bytes = await pdfService.exportTrialBalancePdf(tbRows);
      } else if (tabIndex == 2) {
        // Profit & Loss
        final plReport = await engine.getProfitLossReport();
        bytes = await pdfService.exportProfitLossPdf(plReport);
      } else if (tabIndex == 3) {
        // Balance Sheet
        final bsReport = await engine.getBalanceSheetReport();
        bytes = await pdfService.exportBalanceSheetPdf(bsReport);
      }

      if (bytes != null) {
        await Printing.layoutPdf(onLayout: (_) => bytes!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Financial Reports & Statements', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
            label: const Text('Export PDF / Print', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: _exportCurrentTabPdf,
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
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
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text('Filter by Date', style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Switch(
                    value: _enableDaybookDateFilter,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _enableDaybookDateFilter = val),
                  ),
                ],
              ),
              if (_enableDaybookDateFilter)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.borderStrong),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
                  label: Text(DateFormat('dd-MMM-yyyy').format(_selectedDaybookDate)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDaybookDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setState(() => _selectedDaybookDate = picked);
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
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
              }

              final vouchers = snapshot.data ?? [];
              if (vouchers.isEmpty) {
                return const Center(child: Text('No vouchers posted on this date.', style: TextStyle(color: AppColors.textMuted)));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: vouchers.length,
                itemBuilder: (context, index) {
                  final voucher = vouchers[index];
                  
                  return FutureBuilder<List<VoucherEntry>>(
                    future: (db.select(db.voucherEntries)..where((t) => t.voucherId.equals(voucher.id))).get(),
                    builder: (context, entrySnap) {
                      final entries = entrySnap.data ?? [];
                      double voucherTotal = entries.fold(0.0, (sum, ent) => sum + ent.debitAmount);
                      final isCancelled = voucher.status == 'CANCELLED';

                      return Card(
                        color: AppColors.surface,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ExpansionTile(
                          iconColor: AppColors.textSecondary,
                          collapsedIconColor: AppColors.textMuted,
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(voucher.voucherNumber, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isCancelled
                                      ? AppColors.surfaceSecondary
                                      : (voucher.voucherType == 'Sales'
                                          ? AppColors.successBg
                                          : (voucher.voucherType == 'Purchase' ? AppColors.warningBg : AppColors.infoBg)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isCancelled ? 'CANCELLED' : voucher.voucherType.toUpperCase(),
                                  style: TextStyle(
                                    color: isCancelled
                                        ? AppColors.textMuted
                                        : (voucher.voucherType == 'Sales'
                                            ? AppColors.success
                                            : (voucher.voucherType == 'Purchase' ? AppColors.warning : AppColors.info)),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('dd-MMM-yyyy hh:mm a').format(voucher.date), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(_currencyFormat.format(voucherTotal), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              color: AppColors.surfaceSecondary.withOpacity(0.5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                                    Text('Narration: ${voucher.narration}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic)),
                                    const SizedBox(height: 8),
                                  ],
                                  const Divider(color: AppColors.border, height: 1),
                                  const SizedBox(height: 8),
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
                                                  color: isDr ? AppColors.textPrimary : AppColors.textSecondary,
                                                  fontWeight: isDr ? FontWeight.w600 : FontWeight.normal,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                '${_currencyFormat.format(amt)} ${isDr ? "Dr" : "Cr"}',
                                                style: TextStyle(
                                                  color: isDr ? AppColors.success : AppColors.error,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                  const SizedBox(height: 10),
                                  const Divider(color: AppColors.border, height: 1),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                        label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor: AppColors.surface,
                                              title: Text('Delete ${voucher.voucherType} Permanently?', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                                              content: Text(
                                                'Permanently delete ${voucher.voucherType} #${voucher.voucherNumber}?\n\n'
                                                'This will reverse all inventory movements and ledger balances.',
                                                style: const TextStyle(color: AppColors.textSecondary),
                                              ),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                  child: const Text('Delete Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            try {
                                              final engine = Provider.of<AccountingEngine>(context, listen: false);
                                              await engine.deleteVoucher(voucher.id);
                                              if (context.mounted) {
                                                setState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: AppColors.error,
                                                    content: Text('${voucher.voucherType} #${voucher.voucherNumber} deleted.'),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(backgroundColor: AppColors.error, content: Text('Delete failed: $e')),
                                                );
                                              }
                                            }
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                        icon: const Icon(Icons.zoom_in_rounded, size: 16),
                                        label: const Text('View Bill / Alter Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        onPressed: () => VoucherDetailDialog.show(context, voucher.id, onDeleted: () => setState(() {})),
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final rows = snapshot.data ?? [];
        double totalDebit = rows.fold(0.0, (sum, row) => sum + row.debitBalance);
        double totalCredit = rows.fold(0.0, (sum, row) => sum + row.creditBalance);

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildReportHeader(['Account Ledger', 'Group', 'Debit Balance', 'Credit Balance']),
                const SizedBox(height: 8),

                Expanded(
                  child: rows.isEmpty
                      ? const Center(child: Text('No ledger accounts with non-zero balances.', style: TextStyle(color: AppColors.textMuted)))
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

                const Divider(color: AppColors.border, thickness: 1, height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Sum', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          Text(_currencyFormat.format(totalDebit), style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(width: 80),
                          Text(_currencyFormat.format(totalCredit), style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final report = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.all(20.0),
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DEBITS (Trading & Expenses)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Opening Stock Value', report.openingStockValue),
                        _buildPLRow('Add: Purchases', report.purchaseValue, onTap: () => _showGroupScheduleDialog('purchase_accounts', 'Purchase Accounts')),
                        _buildPLRow('Direct Expenses', report.directExpenses, onTap: () => _showGroupScheduleDialog('direct_expenses', 'Direct Expenses')),
                        const Divider(color: AppColors.border),
                        _buildPLRow('Gross Profit (Transferred)', report.grossProfit, highlight: true, valueColor: AppColors.primary),
                        const Divider(color: AppColors.border, height: 24),
                        _buildPLRow('Indirect Expenses', report.indirectExpenses, onTap: () => _showGroupScheduleDialog('indirect_expenses', 'Indirect Expenses')),
                        const Divider(color: AppColors.border),
                        _buildPLRow(
                          report.netProfit >= 0 ? 'Net Profit' : 'Net Loss',
                          report.netProfit.abs(),
                          highlight: true,
                          valueColor: report.netProfit >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 20 : 0),
                // Right Box: Credit items (Sales, Closing Stock)
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CREDITS (Trading & Revenue)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Sales Accounts Revenue', report.salesValue, onTap: () => _showGroupScheduleDialog('sales_accounts', 'Sales Accounts')),
                        _buildPLRow('Closing Stock Value', report.closingStockValue),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 52),
                        const Divider(color: AppColors.border, height: 24),
                        _buildPLRow('Gross Profit b/f', report.grossProfit, highlight: true, valueColor: AppColors.primary),
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
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final bs = snapshot.data!;
        final double totalLiabilitiesBox = bs.capitalBalance + bs.netProfitSurplus + bs.sundryCreditors + bs.totalLiabilities;
        final double totalAssetsBox = bs.totalAssets;

        return Padding(
          padding: const EdgeInsets.all(20.0),
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
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LIABILITIES & CAPITAL', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Capital Account Balance', bs.capitalBalance, onTap: () => _showGroupScheduleDialog('equity', 'Capital Account')),
                        _buildPLRow('Profit & Loss Surplus (Net Profit)', bs.netProfitSurplus, valueColor: bs.netProfitSurplus >= 0 ? AppColors.success : AppColors.error),
                        _buildPLRow('Sundry Creditors (Suppliers)', bs.sundryCreditors, onTap: () => _showGroupScheduleDialog('sundry_creditors', 'Sundry Creditors')),
                        _buildPLRow('Duties & Taxes (Liabilities)', bs.totalLiabilities, onTap: () => _showGroupScheduleDialog('duties_taxes', 'Duties & Taxes')),
                        const SizedBox(height: 40),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Total Capital & Liabilities', totalLiabilitiesBox, highlight: true),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: isNarrow ? 0 : 20, height: isNarrow ? 20 : 0),
                // Assets Column
                Expanded(
                  flex: isNarrow ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ASSETS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Cash-in-hand Balance', bs.cashBalance, onTap: () => _showGroupScheduleDialog('cash_in_hand', 'Cash-in-Hand')),
                        _buildPLRow('Bank Accounts Balance', bs.bankBalance, onTap: () => _showGroupScheduleDialog('bank_accounts', 'Bank Accounts')),
                        _buildPLRow('Sundry Debtors (Customers)', bs.sundryDebtors, onTap: () => _showGroupScheduleDialog('sundry_debtors', 'Sundry Debtors')),
                        _buildPLRow('Closing Stock Valuation', bs.closingStock),
                        const SizedBox(height: 40),
                        const Divider(color: AppColors.border, height: 20),
                        _buildPLRow('Total Assets Valuation', totalAssetsBox, highlight: true, valueColor: AppColors.success),
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

  Widget _buildReportHeader(List<String> headers) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: headers.map((h) {
          return Expanded(
            child: Text(h, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportRow(List<String> values, bool alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: alt ? AppColors.surfaceSecondary.withOpacity(0.3) : AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: values.map((v) {
          return Expanded(
            child: Text(v, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
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
          backgroundColor: AppColors.surface,
          title: Text('$ledgerName - Statement', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 800,
            height: 500,
            child: FutureBuilder<List<LedgerStatementRow>>(
              future: engine.getLedgerStatement(ledgerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
                }

                final rows = snapshot.data ?? [];

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Date', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Vch Type', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Vch No.', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Debit', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('Credit', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 3, child: Text('Running Balance', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: rows.isEmpty
                          ? const Center(child: Text('No transactions recorded in this ledger.', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.builder(
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final isAlt = index % 2 == 0;

                                return InkWell(
                                  onTap: () {
                                    VoucherDetailDialog.show(
                                      context,
                                      row.voucherId,
                                      onDeleted: () => setState(() {}),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isAlt ? AppColors.surfaceSecondary.withOpacity(0.3) : AppColors.surface,
                                      border: const Border(bottom: BorderSide(color: AppColors.border)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(DateFormat('dd-MMM-yyyy hh:mm a').format(row.date), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.voucherType, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.voucherNo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.debit > 0 ? _currencyFormat.format(row.debit) : '-', style: const TextStyle(color: AppColors.success, fontSize: 12))),
                                        Expanded(flex: 2, child: Text(row.credit > 0 ? _currencyFormat.format(row.credit) : '-', style: const TextStyle(color: AppColors.error, fontSize: 12))),
                                        Expanded(flex: 3, child: Text(_currencyFormat.format(row.runningBalance), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
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
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
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
          backgroundColor: AppColors.surface,
          title: Text('$groupName Schedule', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: FutureBuilder<List<Ledger>>(
              future: (db.select(db.ledgers)..where((t) => t.groupId.equals(groupId))).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
                }

                final ledgers = snapshot.data ?? [];

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ledger Name', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('Closing Balance', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    Expanded(
                      child: ledgers.isEmpty
                          ? const Center(child: Text('No accounts found in this group.', style: TextStyle(color: AppColors.textMuted)))
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
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: isAlt ? AppColors.surfaceSecondary.withOpacity(0.3) : AppColors.surface,
                                          border: const Border(bottom: BorderSide(color: AppColors.border)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(l.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                                            Text(
                                              _currencyFormat.format(bal.abs()),
                                              style: TextStyle(
                                                color: bal >= 0 ? AppColors.success : AppColors.error,
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
              child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
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
                color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                fontSize: highlight ? 14 : 13,
              ),
            ),
            Row(
              children: [
                Text(
                  _currencyFormat.format(amount),
                  style: TextStyle(
                    color: valueColor ?? (highlight ? AppColors.textPrimary : AppColors.textSecondary),
                    fontWeight: FontWeight.bold,
                    fontSize: highlight ? 14 : 13,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 16),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
