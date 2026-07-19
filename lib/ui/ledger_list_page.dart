import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
    
    // Create query streams
    _debtorsStream = (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors'))).watch();
    _creditorsStream = (db.select(db.ledgers)..where((t) => t.groupId.equals('creditors'))).watch();
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
    String selectedGroupId = 'debtors'; // default customer

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2235),
              title: const Text('Create Ledger Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Account Group Selection
                        DropdownButtonFormField<String>(
                          value: selectedGroupId,
                          dropdownColor: const Color(0xFF1E2235),
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Ledger Category / Group',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'debtors', child: Text('Customer (Sundry Debtors)')),
                            DropdownMenuItem(value: 'creditors', child: Text('Supplier (Sundry Creditors)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                selectedGroupId = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // Ledger Name
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Account Name',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a name' : null,
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 12),

                        // Opening Balance
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Opening Balance (Dr for Customer, Cr for Supplier)',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onSaved: (val) => openingBalance = double.tryParse(val ?? '0') ?? 0.0,
                        ),
                        const SizedBox(height: 12),

                        // Phone
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onSaved: (val) => phone = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),

                        // Address
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Billing Address',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onSaved: (val) => address = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),

                        // GSTIN / Tax Number
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Tax Registration No (GSTIN / VAT)',
                            labelStyle: TextStyle(color: Colors.white70),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          ),
                          onSaved: (val) => taxNumber = val?.trim() ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  child: const Text('Save Ledger', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      
                      // For double entry ledger creation, we save it with opening balance.
                      // Note: In strict double entry, an opening balance is offset by an 'Opening Balance Difference' ledger.
                      // Here we just save the ledger.
                      await db.into(db.ledgers).insert(LedgersCompanion.insert(
                            id: uuid.v4(),
                            name: name,
                            groupId: selectedGroupId,
                            openingBalance: drift.Value(openingBalance),
                            phone: drift.Value(phone.isNotEmpty ? phone : null),
                            address: drift.Value(address.isNotEmpty ? address : null),
                            email: const drift.Value(null),
                            taxNumber: drift.Value(taxNumber.isNotEmpty ? taxNumber : null),
                            updatedAt: drift.Value(DateTime.now()),
                            isSynced: const drift.Value(false),
                          ));

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ledger "$name" created successfully.')),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Opens Ledger detail / Statement page
  void _openLedgerStatement(BuildContext context, Ledger ledger) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LedgerStatementPage(ledger: ledger),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ledgers & Accounts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.indigoAccent,
          tabs: const [
            Tab(text: 'Customers (Sundry Debtors)'),
            Tab(text: 'Suppliers (Sundry Creditors)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLedgerList(_debtorsStream),
          _buildLedgerList(_creditorsStream),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Ledger Account', style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddLedgerDialog(context),
      ),
    );
  }

  Widget _buildLedgerList(Stream<List<Ledger>> stream) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return StreamBuilder<List<Ledger>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final ledgers = snapshot.data ?? [];
        if (ledgers.isEmpty) {
          return const Center(
            child: Text(
              'No ledger accounts found. Click "Add Ledger Account" to create one.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ledgers.length,
          itemBuilder: (context, index) {
            final ledger = ledgers[index];

            return FutureBuilder<double>(
              future: engine.getLedgerBalance(ledger.id),
              builder: (context, balanceSnapshot) {
                final balance = balanceSnapshot.data ?? ledger.openingBalance;
                
                // Represent Dr or Cr balance
                String balanceStr = '';
                if (balance > 0) {
                  balanceStr = '${_currencyFormat.format(balance)} Dr';
                } else if (balance < 0) {
                  balanceStr = '${_currencyFormat.format(balance.abs())} Cr';
                } else {
                  balanceStr = _currencyFormat.format(0.0);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Card(
                    color: const Color(0xFF1E2235),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.04), width: 1),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: Text(
                        ledger.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            if (ledger.phone != null) ...[
                              const Icon(Icons.phone_rounded, color: Colors.white30, size: 14),
                              const SizedBox(width: 4),
                              Text(ledger.phone!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              const SizedBox(width: 16),
                            ],
                            if (ledger.taxNumber != null) ...[
                              const Icon(Icons.description_rounded, color: Colors.white30, size: 14),
                              const SizedBox(width: 4),
                              Text('Tax No: ${ledger.taxNumber}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
                              const Text('Outstanding Balance', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                balanceStr,
                                style: TextStyle(
                                  color: balance > 0
                                      ? Colors.greenAccent
                                      : balance < 0
                                          ? Colors.redAccent
                                          : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white30),
                        ],
                      ),
                      onTap: () => _openLedgerStatement(context, ledger),
                    ),
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

    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ledger.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(
              ledger.groupId == 'debtors' ? 'Customer Account Statement' : 'Supplier Account Statement',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<LedgerStatementRow>>(
        future: engine.getLedgerStatement(ledger.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          final statement = snapshot.data ?? [];

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ledger Header Info Cards
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2235),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Account Contact Info', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.phone_rounded, 'Phone', ledger.phone ?? 'N/A'),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.location_on_rounded, 'Address', ledger.address ?? 'N/A'),
                            const SizedBox(height: 8),
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
                        height: 125,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Colors.indigoAccent, Color(0xFF5D51E5)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Opening Balance', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              '${_currencyFormat.format(ledger.openingBalance.abs())} ${ledger.openingBalance >= 0 ? "Dr" : "Cr"}',
                              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Transaction Postings Ledger',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2235),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Voucher No', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Voucher Type', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Debit', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Credit', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text('Running Balance', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),

                // Statement List
                Expanded(
                  child: statement.isEmpty
                      ? Container(
                          width: double.infinity,
                          color: const Color(0xFF1E2235).withOpacity(0.5),
                          alignment: Alignment.center,
                          child: const Text('No transactions posted for this account.', style: TextStyle(color: Colors.white38)),
                        )
                      : ListView.builder(
                          itemCount: statement.length,
                          itemBuilder: (context, index) {
                            final row = statement[index];
                            final isDr = row.runningBalance >= 0;
                            final runningBalStr = '${_currencyFormat.format(row.runningBalance.abs())} ${isDr ? "Dr" : "Cr"}';

                            return InkWell(
                              onTap: () => VoucherDetailDialog.show(context, row.voucherId),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: index % 2 == 0 ? const Color(0xFF1E2235).withOpacity(0.3) : const Color(0xFF1E2235).withOpacity(0.1),
                                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        DateFormat('dd-MMM-yyyy hh:mm a').format(row.date),
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        row.voucherNo,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        row.voucherType,
                                        style: TextStyle(
                                          color: row.voucherType == 'Sales'
                                              ? Colors.greenAccent
                                              : row.voucherType == 'Purchase'
                                                  ? Colors.orangeAccent
                                                  : Colors.blueAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        row.debit > 0 ? _currencyFormat.format(row.debit) : '-',
                                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        row.credit > 0 ? _currencyFormat.format(row.credit) : '-',
                                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        runningBalStr,
                                        style: TextStyle(
                                          color: isDr ? Colors.greenAccent : Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 13)),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
