import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../core/pdf_export_service.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import 'theme/app_theme.dart';
import 'widgets/voucher_detail_dialog.dart';

class LedgerListPage extends StatefulWidget {
  const LedgerListPage({super.key});

  @override
  State<LedgerListPage> createState() => _LedgerListPageState();
}

class _LedgerListPageState extends State<LedgerListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<List<Ledger>> _debtorsStream;
  late Stream<List<Ledger>> _creditorsStream;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
  final Uuid uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    // Only query active, non-deleted ledgers
    _debtorsStream = (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))).watch();
    _creditorsStream = (db.select(db.ledgers)..where((t) => t.groupId.equals('creditors') & t.isDeleted.equals(false))).watch();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Dialog to Add a Ledger Account
  void _showAddLedgerDialog(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    
    String name = '';
    String phone = '';
    String address = '';
    String taxNumber = '';
    double openingBalance = 0.0;
    String selectedGroupId = 'debtors';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Create Ledger Account', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedGroupId,
                          decoration: const InputDecoration(labelText: 'Account Category / Group'),
                          items: const [
                            DropdownMenuItem(value: 'debtors', child: Text('Customer (Sundry Debtors)')),
                            DropdownMenuItem(value: 'creditors', child: Text('Supplier (Sundry Creditors)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedGroupId = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Account Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Opening Balance (₹)'),
                          onSaved: (val) => openingBalance = double.tryParse(val ?? '0') ?? 0.0,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          onSaved: (val) => phone = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'Address'),
                          onSaved: (val) => address = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(labelText: 'GSTIN / Tax Number'),
                          onSaved: (val) => taxNumber = val?.trim() ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      try {
                        await db.into(db.ledgers).insert(LedgersCompanion.insert(
                              id: uuid.v4(),
                              name: name,
                              groupId: selectedGroupId,
                              openingBalance: drift.Value(openingBalance),
                              phone: drift.Value(phone.isNotEmpty ? phone : null),
                              address: drift.Value(address.isNotEmpty ? address : null),
                              taxNumber: drift.Value(taxNumber.isNotEmpty ? taxNumber : null),
                              isDeleted: const drift.Value(false),
                            ));
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account created successfully')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: Name must be unique ($e)')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Confirm and perform safe customer/account deletion
  Future<void> _confirmDeleteLedger(BuildContext context, Ledger ledger) async {
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    final hasTx = await engine.hasCustomerTransactions(ledger.id);

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              hasTx ? Icons.warning_amber_rounded : Icons.delete_outline_rounded,
              color: hasTx ? AppColors.warning : AppColors.error,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(hasTx ? 'Deactivate Account?' : 'Delete Account?'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account: ${ledger.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              if (hasTx)
                const Text(
                  'This account has prior transaction history (bills, receipts, or payments).\n\nTo preserve historical invoices and reporting integrity, this account will be safely deactivated and hidden from future bill creation without corrupting historical data.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                )
              else
                const Text(
                  'This account has no transaction history. It will be permanently removed from your database.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasTx ? AppColors.warning : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(hasTx ? 'Deactivate Account' : 'Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final wasHardDeleted = await engine.deleteCustomer(ledger.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasHardDeleted
                ? 'Account "${ledger.name}" permanently deleted.'
                : 'Account "${ledger.name}" safely deactivated. Transaction history preserved.'),
          ),
        );
      }
    }
  }

  void _openLedgerStatement(BuildContext context, Ledger ledger) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LedgerStatementPage(ledger: ledger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Accounts & Ledgers',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Customers (Sundry Debtors)'),
            Tab(text: 'Suppliers (Sundry Creditors)'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Account'),
              onPressed: () => _showAddLedgerDialog(context),
            ),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLedgerList(_debtorsStream),
          _buildLedgerList(_creditorsStream),
        ],
      ),
    );
  }

  Widget _buildLedgerList(Stream<List<Ledger>> stream) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return StreamBuilder<List<Ledger>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final ledgers = snapshot.data ?? [];
        if (ledgers.isEmpty) {
          return const Center(
            child: Text('No active accounts found in this category.', style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24.0),
          itemCount: ledgers.length,
          itemBuilder: (context, index) {
            final ledger = ledgers[index];

            return FutureBuilder<double>(
              future: engine.getLedgerBalance(ledger.id),
              builder: (context, balSnapshot) {
                final balance = balSnapshot.data ?? 0.0;
                final balanceStr = '${_currencyFormat.format(balance.abs())} ${balance >= 0 ? "Dr" : "Cr"}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    title: Text(
                      ledger.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Row(
                        children: [
                          if (ledger.phone != null) ...[
                            const Icon(Icons.phone_rounded, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 4),
                            Text(ledger.phone!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            const SizedBox(width: 16),
                          ],
                          if (ledger.taxNumber != null) ...[
                            const Icon(Icons.description_rounded, color: AppColors.textMuted, size: 14),
                            const SizedBox(width: 4),
                            Text('Tax No: ${ledger.taxNumber}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Outstanding Balance', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              balanceStr,
                              style: TextStyle(
                                color: balance > 0
                                    ? AppColors.primary
                                    : balance < 0
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          tooltip: 'Delete / Deactivate Account',
                          onPressed: () => _confirmDeleteLedger(context, ledger),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      ],
                    ),
                    onTap: () => _openLedgerStatement(context, ledger),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------
// Ledger Statement Screen
// ----------------------------------------------------
class LedgerStatementPage extends StatelessWidget {
  final Ledger ledger;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  LedgerStatementPage({super.key, required this.ledger});

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    final db = Provider.of<AppDatabase>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ledger.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            Text(
              ledger.groupId == 'debtors' ? 'Customer Account Statement' : 'Supplier Account Statement',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 18),
              label: const Text('Export Statement PDF'),
              onPressed: () async {
                try {
                  final pdfService = PdfExportService(db);
                  final bytes = await pdfService.exportCustomerStatementPdf(ledger.id);
                  await Printing.layoutPdf(
                    onLayout: (format) async => bytes,
                    name: 'Statement_${ledger.name}.pdf',
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<LedgerStatementRow>>(
        future: engine.getLedgerStatement(ledger.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
          }

          final statement = snapshot.data ?? [];

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Cards
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Account Contact Info', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _buildInfoRow(Icons.phone_rounded, 'Phone', ledger.phone ?? 'N/A'),
                            const SizedBox(height: 6),
                            _buildInfoRow(Icons.location_on_rounded, 'Address', ledger.address ?? 'N/A'),
                            const SizedBox(height: 6),
                            _buildInfoRow(Icons.description_rounded, 'GSTIN / Tax No', ledger.taxNumber ?? 'N/A'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Opening Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              _currencyFormat.format(ledger.openingBalance),
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Transactions Table
                const Text('Transaction Activity', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: statement.isEmpty
                        ? const Center(child: Text('No transactions recorded for this account.', style: TextStyle(color: AppColors.textMuted)))
                        : ListView.separated(
                            itemCount: statement.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border),
                            itemBuilder: (context, index) {
                              final row = statement[index];
                              return ListTile(
                                dense: true,
                                title: Row(
                                  children: [
                                    Text(
                                      DateFormat('dd-MMM-yyyy').format(row.date),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryBackground,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        row.voucherType,
                                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '#${row.voucherNumber}',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                                subtitle: row.narration.isNotEmpty
                                    ? Text(row.narration, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (row.debitAmount > 0)
                                      Text(
                                        '+ ${_currencyFormat.format(row.debitAmount)}',
                                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    if (row.creditAmount > 0)
                                      Text(
                                        '- ${_currencyFormat.format(row.creditAmount)}',
                                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    const SizedBox(width: 16),
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        _currencyFormat.format(row.runningBalance),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  VoucherDetailDialog.show(context, row.voucherId);
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 14),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
