import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../core/pdf_export_service.dart';
import '../core/customer_group_service.dart';
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
  late Stream<List<CustomerGroup>> _groupsStream;
  String? _selectedFilterGroupId;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
  final Uuid uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final db = Provider.of<AppDatabase>(context, listen: false);
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    
    // Query active, non-deleted ledgers ordered alphabetically A-Z
    _debtorsStream = (db.select(db.ledgers)
      ..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.name.lower())]))
      .watch();
    _creditorsStream = (db.select(db.ledgers)
      ..where((t) => t.groupId.equals('creditors') & t.isDeleted.equals(false))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.name.lower())]))
      .watch();
    _groupsStream = groupService.watchAllGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // Dialog to Add a Ledger Account
  void _showAddLedgerDialog(BuildContext context) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    final groups = await groupService.getAllGroups();
    final formKey = GlobalKey<FormState>();
    
    String name = '';
    String phone = '';
    String address = '';
    String taxNumber = '';
    double openingBalance = 0.0;
    String selectedGroupId = 'debtors';
    String? selectedCustomerGroupId;

    if (!context.mounted) return;

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
                        if (selectedGroupId == 'debtors' && groups.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: selectedCustomerGroupId,
                            decoration: const InputDecoration(labelText: 'Customer Group (Metadata Category)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('None (Ungrouped)')),
                              ...groups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                            ],
                            onChanged: (val) {
                              setDialogState(() => selectedCustomerGroupId = val);
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Account Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Opening Balance (Rs.)'),
                          onSaved: (val) => openingBalance = double.tryParse(val ?? '0') ?? 0.0,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          onSaved: (val) => phone = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Address'),
                          onSaved: (val) => address = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          textInputAction: TextInputAction.done,
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
                              customerGroupId: drift.Value(selectedGroupId == 'debtors' ? selectedCustomerGroupId : null),
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

  // Dialog to Edit/Alter an Account
  void _showEditLedgerDialog(BuildContext context, Ledger ledger) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    final groups = await groupService.getAllGroups();
    final formKey = GlobalKey<FormState>();

    String name = ledger.name;
    String phone = ledger.phone ?? '';
    String address = ledger.address ?? '';
    String taxNumber = ledger.taxNumber ?? '';
    double openingBalance = ledger.openingBalance;
    String selectedGroupId = ledger.groupId;
    String? selectedCustomerGroupId = ledger.customerGroupId;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Edit Account (${ledger.name})',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
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
                        if (selectedGroupId == 'debtors' && groups.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: selectedCustomerGroupId,
                            decoration: const InputDecoration(labelText: 'Customer Group (Metadata Category)'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('None (Ungrouped)')),
                              ...groups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                            ],
                            onChanged: (val) {
                              setDialogState(() => selectedCustomerGroupId = val);
                            },
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          autofocus: true,
                          initialValue: name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Account Name *'),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: openingBalance.toStringAsFixed(2),
                          textInputAction: TextInputAction.next,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Opening Balance (Rs.)'),
                          onSaved: (val) => openingBalance = double.tryParse(val ?? '0') ?? 0.0,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          onSaved: (val) => phone = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: address,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Address'),
                          onSaved: (val) => address = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: taxNumber,
                          textInputAction: TextInputAction.done,
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
                        await (db.update(db.ledgers)..where((t) => t.id.equals(ledger.id))).write(
                          LedgersCompanion(
                            name: drift.Value(name),
                            groupId: drift.Value(selectedGroupId),
                            customerGroupId: drift.Value(selectedGroupId == 'debtors' ? selectedCustomerGroupId : null),
                            openingBalance: drift.Value(openingBalance),
                            phone: drift.Value(phone.isNotEmpty ? phone : null),
                            address: drift.Value(address.isNotEmpty ? address : null),
                            taxNumber: drift.Value(taxNumber.isNotEmpty ? taxNumber : null),
                          ),
                        );
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('Account "$name" updated successfully'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('Failed to update account: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
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
            Tab(text: 'Customer Groups'),
            Tab(text: 'Cash Transactions / Book'),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search accounts by name, phone, GSTIN, or address...',
                  prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDebtorsList(),
                _buildLedgerList(_creditorsStream),
                _buildCustomerGroupsTab(),
                _buildCashTransactionsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtorsList() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return StreamBuilder<List<CustomerGroup>>(
      stream: _groupsStream,
      builder: (context, groupSnapshot) {
        final groups = groupSnapshot.data ?? [];
        final groupNameMap = {for (var g in groups) g.id: g.name};

        return StreamBuilder<List<Ledger>>(
          stream: _debtorsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
            }

            final rawLedgers = snapshot.data ?? [];
            final ledgers = rawLedgers.where((l) {
              // Group filter
              if (_selectedFilterGroupId != null) {
                if (_selectedFilterGroupId == '__ungrouped__') {
                  if (l.customerGroupId != null && l.customerGroupId!.isNotEmpty) return false;
                } else if (l.customerGroupId != _selectedFilterGroupId) {
                  return false;
                }
              }

              // Search query filter
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return l.name.toLowerCase().contains(q) ||
                  (l.phone?.toLowerCase().contains(q) ?? false) ||
                  (l.taxNumber?.toLowerCase().contains(q) ?? false) ||
                  (l.address?.toLowerCase().contains(q) ?? false);
            }).toList();

            ledgers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            return Column(
              children: [
                // Filter bar for Customer Groups
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      const Text('Filter by Group:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _selectedFilterGroupId,
                            isDense: true,
                            hint: const Text('All Customers', style: TextStyle(fontSize: 13)),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('All Customers (All Groups)')),
                              const DropdownMenuItem<String?>(value: '__ungrouped__', child: Text('Ungrouped Customers')),
                              ...groups.map((g) => DropdownMenuItem<String?>(
                                value: g.id,
                                child: Text('Group: ${g.name}'),
                              )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedFilterGroupId = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${ledgers.length} ${ledgers.length == 1 ? "Customer" : "Customers"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ledgers.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isNotEmpty
                                ? 'No accounts match "$_searchQuery"'
                                : 'No customers found in this category / group.',
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          itemCount: ledgers.length,
                          itemBuilder: (context, index) {
                            final ledger = ledgers[index];
                            final groupName = ledger.customerGroupId != null ? groupNameMap[ledger.customerGroupId] : null;

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
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            ledger.name,
                                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (groupName != null) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBackground,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              groupName,
                                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
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
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                                          tooltip: 'Edit / Alter Account',
                                          onPressed: () => _showEditLedgerDialog(context, ledger),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                          tooltip: 'Delete / Deactivate Account',
                                          onPressed: () => _confirmDeleteLedger(context, ledger),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                                      ],
                                    ),
                                    onTap: () => _openLedgerStatement(context, ledger),
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
        );
      },
    );
  }

  Widget _buildCustomerGroupsTab() {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);

    return StreamBuilder<List<CustomerGroup>>(
      stream: _groupsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final groups = snapshot.data ?? [];
        final filteredGroups = groups.where((g) {
          if (_searchQuery.isEmpty) return true;
          return g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (g.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        }).toList();

        return Column(
          children: [
            // Top action bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Row(
                children: [
                  const Text(
                    'Customer Groups',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${groups.length} defined)',
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Customer Group'),
                    onPressed: () => _showCreateGroupDialog(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.folder_shared_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No customer groups match "$_searchQuery"'
                                : 'No customer groups created yet.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create First Customer Group'),
                            onPressed: () => _showCreateGroupDialog(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        final group = filteredGroups[index];

                        return FutureBuilder<List<Ledger>>(
                          future: groupService.getGroupMembers(group.id),
                          builder: (context, membersSnapshot) {
                            final members = membersSnapshot.data ?? [];
                            final memberCount = members.length;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    const CircleAvatar(
                                      radius: 20,
                                      backgroundColor: AppColors.primaryBackground,
                                      child: Icon(Icons.group_rounded, color: AppColors.primary, size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                group.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surface,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: AppColors.border),
                                                ),
                                                child: Text(
                                                  '$memberCount ${memberCount == 1 ? "Customer" : "Customers"}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (group.description != null && group.description!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              group.description!,
                                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.receipt_long_rounded, size: 16),
                                          label: const Text('Group Entries'),
                                          onPressed: () => _showGroupEntriesDialog(context, group),
                                        ),
                                        OutlinedButton.icon(
                                          icon: const Icon(Icons.people_outline_rounded, size: 16),
                                          label: const Text('Manage Members'),
                                          onPressed: () => _showManageGroupMembersDialog(context, group),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                          tooltip: 'Rename / Edit Group',
                                          onPressed: () => _showEditGroupDialog(context, group),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                          tooltip: 'Delete Group (Safe Unlinking)',
                                          onPressed: () => _confirmDeleteGroupDialog(context, group),
                                        ),
                                      ],
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
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String name = '';
    String description = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Create Customer Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Group Name *',
                    hintText: 'e.g. Wholesale - North, VIP, Retail',
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a group name' : null,
                  onSaved: (val) => name = val!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of this customer group',
                  ),
                  onSaved: (val) => description = val?.trim() ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                try {
                  await groupService.createGroup(name, description: description.isNotEmpty ? description : null);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Create Group'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(BuildContext context, CustomerGroup group) {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    final formKey = GlobalKey<FormState>();
    String name = group.name;
    String description = group.description ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Edit Customer Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  initialValue: name,
                  decoration: const InputDecoration(labelText: 'Group Name *'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a group name' : null,
                  onSaved: (val) => name = val!.trim(),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: description,
                  decoration: const InputDecoration(labelText: 'Description (Optional)'),
                  onSaved: (val) => description = val?.trim() ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                formKey.currentState!.save();
                try {
                  await groupService.updateGroup(
                    group.id,
                    name,
                    description: description.isNotEmpty ? description : null,
                  );
                  if (ctx.mounted) Navigator.of(ctx).pop();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroupDialog(BuildContext context, CustomerGroup group) {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            SizedBox(width: 8),
            Text('Delete Customer Group?'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Group: ${group.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              const Text(
                'SAFE UNLINKING:\n\nDeleting this customer group will NEVER delete or corrupt member customers, invoices, or accounting entries.\n\nAll members currently in this group will safely become ungrouped.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await groupService.deleteGroup(group.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group "${group.name}" deleted. Member customers unlinked safely.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );
  }

  void _showManageGroupMembersDialog(BuildContext context, CustomerGroup group) async {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    final allDebtors = await groupService.getCustomersWithGroup();
    final allGroups = await groupService.getAllGroups();
    final groupMap = {for (var g in allGroups) g.id: g.name};

    // Track selected member IDs in this group
    final selectedIds = <String>{
      for (var d in allDebtors)
        if (d.customerGroupId == group.id) d.id
    };

    if (!context.mounted) return;

    String memberSearch = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filtered = allDebtors.where((d) {
            if (memberSearch.isEmpty) return true;
            return d.name.toLowerCase().contains(memberSearch.toLowerCase()) ||
                (d.phone?.toLowerCase().contains(memberSearch.toLowerCase()) ?? false);
          }).toList();

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Members: ${group.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Select customers to include in this group. Moving a customer unlinks them from their previous group.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search customers...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (val) {
                      setDialogState(() => memberSearch = val.trim());
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isSelected = selectedIds.contains(c.id);
                        final currentGroupId = c.customerGroupId;
                        final isOtherGroup = currentGroupId != null && currentGroupId != group.id;
                        final otherGroupName = isOtherGroup ? groupMap[currentGroupId] ?? 'Other Group' : null;

                        return CheckboxListTile(
                          dense: true,
                          value: isSelected,
                          title: Row(
                            children: [
                              Flexible(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                              if (isOtherGroup) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('in $otherGroupName', style: const TextStyle(fontSize: 10, color: Colors.orange)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: c.phone != null ? Text(c.phone!, style: const TextStyle(fontSize: 11)) : null,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedIds.add(c.id);
                              } else {
                                selectedIds.remove(c.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  for (var d in allDebtors) {
                    final shouldBeInGroup = selectedIds.contains(d.id);
                    final wasInGroup = d.customerGroupId == group.id;

                    if (shouldBeInGroup && !wasInGroup) {
                      await groupService.assignCustomerToGroup(d.id, group.id);
                    } else if (!shouldBeInGroup && wasInGroup) {
                      await groupService.removeCustomerFromGroup(d.id);
                    }
                  }

                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated members for "${group.name}".')),
                    );
                  }
                },
                child: const Text('Save Members'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showGroupEntriesDialog(BuildContext context, CustomerGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => _GroupEntriesDialog(group: group),
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

        final rawLedgers = snapshot.data ?? [];
        final ledgers = rawLedgers.where((l) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return l.name.toLowerCase().contains(q) ||
              (l.phone?.toLowerCase().contains(q) ?? false) ||
              (l.taxNumber?.toLowerCase().contains(q) ?? false) ||
              (l.address?.toLowerCase().contains(q) ?? false);
        }).toList();
        ledgers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        if (ledgers.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No accounts match "$_searchQuery"'
                  : 'No active accounts found in this category.',
              style: const TextStyle(color: AppColors.textMuted),
            ),
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
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                          tooltip: 'Edit / Alter Account',
                          onPressed: () => _showEditLedgerDialog(context, ledger),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                          tooltip: 'Delete / Deactivate Account',
                          onPressed: () => _confirmDeleteLedger(context, ledger),
                        ),
                        const SizedBox(width: 4),
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

  Widget _buildCashTransactionsList() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return FutureBuilder<List<CashTransactionRow>>(
      future: engine.getCashTransactions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
        }

        final allTxs = snapshot.data ?? [];
        final filteredTxs = allTxs.where((tx) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return tx.partyName.toLowerCase().contains(q) ||
              tx.voucherNo.toLowerCase().contains(q) ||
              tx.voucherType.toLowerCase().contains(q) ||
              tx.narration.toLowerCase().contains(q);
        }).toList();

        final double totalCashIn = allTxs.where((tx) => tx.isCashIn).fold(0.0, (sum, tx) => sum + tx.amount);
        final double totalCashOut = allTxs.where((tx) => !tx.isCashIn).fold(0.0, (sum, tx) => sum + tx.amount);
        final double netBalance = allTxs.isNotEmpty ? allTxs.last.runningBalance : 0.0;

        return Column(
          children: [
            // Top Summary Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Cash In', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_currencyFormat.format(totalCashIn), style: const TextStyle(color: AppColors.success, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Cash Out', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_currencyFormat.format(totalCashOut), style: const TextStyle(color: AppColors.error, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Net Cash Balance', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_currencyFormat.format(netBalance), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Cash Transactions List
            Expanded(
              child: filteredTxs.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No cash transactions match "$_searchQuery"'
                            : 'No cash transactions recorded yet.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      itemCount: filteredTxs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final tx = filteredTxs[filteredTxs.length - 1 - index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: tx.isCashIn ? AppColors.successBg : AppColors.errorBg,
                              child: Icon(
                                tx.isCashIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: tx.isCashIn ? AppColors.success : AppColors.error,
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          tx.partyName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBackground,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${tx.voucherType} #${tx.voucherNo}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                    DateFormat('dd-MMM-yyyy hh:mm a').format(tx.date),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                  if (tx.narration.isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                                    Expanded(
                                      child: Text(
                                        tx.narration,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${tx.isCashIn ? '+' : '-'} ${_currencyFormat.format(tx.amount)}',
                                  style: TextStyle(
                                    color: tx.isCashIn ? AppColors.success : AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Bal: ${_currencyFormat.format(tx.runningBalance)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            onTap: () {
                              VoucherDetailDialog.show(
                                context,
                                tx.voucherId,
                                onDeleted: () => setState(() {}),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ----------------------------------------------------
// Customer Group Entries Consolidated Statement Dialog
// ----------------------------------------------------
class _GroupEntriesDialog extends StatefulWidget {
  final CustomerGroup group;

  const _GroupEntriesDialog({required this.group});

  @override
  State<_GroupEntriesDialog> createState() => _GroupEntriesDialogState();
}

class _GroupEntriesDialogState extends State<_GroupEntriesDialog> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
  DateTime? _startDate;
  DateTime? _endDate;
  late Future<GroupTransactionsSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  void _loadSummary() {
    final groupService = Provider.of<CustomerGroupService>(context, listen: false);
    setState(() {
      _summaryFuture = groupService.getGroupTransactions(
        widget.group.id,
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSummary();
    }
  }

  void _clearDateRange() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);

    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primaryBackground,
                  child: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Statement: ${widget.group.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (widget.group.description != null && widget.group.description!.isNotEmpty)
                        Text(
                          widget.group.description!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                // Date Range Button
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${_dateFormat.format(_startDate!)} - ${_dateFormat.format(_endDate!)}'
                        : 'Filter Date Range',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: _selectDateRange,
                ),
                if (_startDate != null || _endDate != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                    tooltip: 'Clear Date Filter',
                    onPressed: _clearDateRange,
                  ),
                ],
                const SizedBox(width: 8),
                FutureBuilder<GroupTransactionsSummary>(
                  future: _summaryFuture,
                  builder: (context, snapshot) {
                    final summary = snapshot.data;
                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                      label: const Text('Export PDF'),
                      onPressed: summary == null
                          ? null
                          : () async {
                              try {
                                final pdfService = PdfExportService(db);
                                final bytes = await pdfService.exportGroupTransactionsPdf(
                                  summary,
                                  fromDate: _startDate,
                                  toDate: _endDate,
                                );
                                await Printing.layoutPdf(
                                  onLayout: (format) async => bytes,
                                  name: 'Group_Statement_${widget.group.name.replaceAll(' ', '_')}.pdf',
                                );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to export PDF: $e')),
                                  );
                                }
                              }
                            },
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: FutureBuilder<GroupTransactionsSummary>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
                  }

                  final summary = snapshot.data;
                  if (summary == null) {
                    return const Center(child: Text('No data found'));
                  }

                  return Column(
                    children: [
                      // KPI Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpiCard(
                              'Total Customers',
                              '${summary.totalCustomers} (${summary.activeCustomersWithTransactions} active)',
                              AppColors.primary,
                              Icons.group_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              'Total Debits (Sales/Charges)',
                              _currencyFormat.format(summary.totalDebit),
                              AppColors.primary,
                              Icons.arrow_upward_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              'Total Credits (Receipts/Returns)',
                              _currencyFormat.format(summary.totalCredit),
                              AppColors.success,
                              Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpiCard(
                              'Net Group Outstanding',
                              '${_currencyFormat.format(summary.netOutstanding.abs())} ${summary.netOutstanding >= 0 ? "Dr" : "Cr"}',
                              summary.netOutstanding > 0 ? AppColors.error : AppColors.success,
                              Icons.account_balance_wallet_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Entries Table
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: summary.rows.isEmpty
                              ? const Center(
                                  child: Text('No transactions recorded for this customer group in the selected period.',
                                      style: TextStyle(color: AppColors.textMuted)),
                                )
                              : ListView.separated(
                                  itemCount: summary.rows.length,
                                  separatorBuilder: (context, i) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, i) {
                                    final row = summary.rows[i];
                                    return ListTile(
                                      dense: true,
                                      title: Row(
                                        children: [
                                          SizedBox(
                                            width: 90,
                                            child: Text(
                                              _dateFormat.format(row.date),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryBackground,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '#${row.voucherNumber} (${row.voucherType})',
                                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              row.customerName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                                            ),
                                          ),
                                          if (row.debitAmount > 0)
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                '+ ${_currencyFormat.format(row.debitAmount)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            )
                                          else
                                            const SizedBox(width: 110),
                                          if (row.creditAmount > 0)
                                            SizedBox(
                                              width: 110,
                                              child: Text(
                                                '- ${_currencyFormat.format(row.creditAmount)}',
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            )
                                          else
                                            const SizedBox(width: 110),
                                          const SizedBox(width: 16),
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              'Bal: ${_currencyFormat.format(row.runningBalance)}',
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: (row.narration != null && row.narration!.isNotEmpty)
                                          ? Padding(
                                              padding: const EdgeInsets.only(left: 90, top: 2),
                                              child: Text(
                                                row.narration!,
                                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          : null,
                                      onTap: () {
                                        VoucherDetailDialog.show(
                                          context,
                                          row.voucherId,
                                          onDeleted: _loadSummary,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Ledger Statement Screen
// ----------------------------------------------------
class LedgerStatementPage extends StatefulWidget {
  final Ledger ledger;

  const LedgerStatementPage({super.key, required this.ledger});

  @override
  State<LedgerStatementPage> createState() => _LedgerStatementPageState();
}

class _LedgerStatementPageState extends State<LedgerStatementPage> {
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs. ', decimalDigits: 2);

  @override
  Widget build(BuildContext context) {
    final ledger = widget.ledger;
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
                                    if (row.paymentMode == 'Cash') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.successBg,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CASH (PAID)',
                                          style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: row.narration.isNotEmpty
                                    ? Text(row.narration, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))
                                    : null,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (row.paymentMode == 'Cash')
                                      Text(
                                        'PAID ${_currencyFormat.format(row.debitAmount)}',
                                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13),
                                      )
                                    else ...[
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
                                    ],
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
                                  VoucherDetailDialog.show(
                                    context,
                                    row.voucherId,
                                    onDeleted: () => setState(() {}),
                                  );
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
