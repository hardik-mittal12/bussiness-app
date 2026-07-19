import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class PaymentReceiptPage extends StatefulWidget {
  const PaymentReceiptPage({super.key});

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> {
  final Uuid uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  String _voucherType = 'Receipt'; // 'Receipt' (Received from Customer) or 'Payment' (Paid to Supplier)
  String _voucherNumber = '';
  DateTime _voucherDate = DateTime.now();
  
  String? _selectedContactLedgerId; // Customer for Receipt, Supplier for Payment
  String? _selectedCashBankLedgerId; // Bank/Cash account to debit/credit
  double _amount = 0.0;
  String _narration = '';
  String _referenceNumber = '';

  List<Ledger> _contactLedgers = [];
  List<Ledger> _cashBankLedgers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    // Load Contact Ledgers (Receipt = Customer, Payment = Supplier)
    final contactGroup = _voucherType == 'Receipt' ? 'debtors' : 'creditors';
    final contactLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals(contactGroup))).get();

    // Load Cash and Bank Ledgers
    // Get all ledgers in cash_in_hand or bank_accounts groups
    final cashBankLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('cash_in_hand') | t.groupId.equals('bank_accounts'))).get();

    // Generate Voucher number
    final vouchersList = await db.select(db.vouchers).get();
    final count = vouchersList.where((v) => v.voucherType == _voucherType).length + 1;
    final prefix = _voucherType == 'Receipt' ? 'RCT' : 'PAY';
    final vNo = '$prefix-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';

    setState(() {
      _contactLedgers = contactLedgers;
      _cashBankLedgers = cashBankLedgers;
      _voucherNumber = vNo;
      
      // Auto select default cash ledger if available
      if (_cashBankLedgers.isNotEmpty && _selectedCashBankLedgerId == null) {
        final cashMatch = _cashBankLedgers.where((l) => l.id == 'cash');
        _selectedCashBankLedgerId = cashMatch.isNotEmpty ? cashMatch.first.id : _cashBankLedgers.first.id;
      }
    });
  }

  void _onVoucherTypeChanged(String? type) {
    if (type != null && type != _voucherType) {
      setState(() {
        _voucherType = type;
        _selectedContactLedgerId = null;
        _amount = 0.0;
      });
      _loadInitialData();
    }
  }

  Future<void> _submitVoucher() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedContactLedgerId == null || _selectedCashBankLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both the contact and cash/bank accounts.')),
      );
      return;
    }

    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than zero.')),
      );
      return;
    }

    final engine = Provider.of<AccountingEngine>(context, listen: false);
    List<VoucherEntriesCompanion> entries = [];

    if (_voucherType == 'Receipt') {
      // Money Received from Customer:
      // Debit: Cash/Bank Account (increases asset)
      // Credit: Customer Ledger (reduces debtor asset balance)
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '', // Set by transaction
        ledgerId: _selectedCashBankLedgerId!,
        debitAmount: drift.Value(_amount),
        creditAmount: const drift.Value(0.0),
      ));
      
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: _selectedContactLedgerId!,
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(_amount),
      ));
    } else {
      // Money Paid to Supplier:
      // Debit: Supplier Ledger (reduces creditor liability balance)
      // Credit: Cash/Bank Account (reduces asset)
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: _selectedContactLedgerId!,
        debitAmount: drift.Value(_amount),
        creditAmount: const drift.Value(0.0),
      ));

      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: _selectedCashBankLedgerId!,
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(_amount),
      ));
    }

    try {
      await engine.createVoucher(
        voucherNumber: _voucherNumber,
        voucherType: _voucherType,
        date: _voucherDate,
        narration: _narration,
        referenceNumber: _referenceNumber,
        entries: entries,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_voucherType voucher $_voucherNumber saved successfully!')),
        );
        setState(() {
          _selectedContactLedgerId = null;
          _amount = 0.0;
          _narration = '';
          _referenceNumber = '';
        });
        _loadInitialData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save voucher: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Record $_voucherType Voucher',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2235),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment & Receipt Details',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    // Voucher Type Selector
                    DropdownButtonFormField<String>(
                      value: _voucherType,
                      dropdownColor: const Color(0xFF1E2235),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Transaction Mode',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Receipt', child: Text('Receipt (Money Received from Customer)')),
                        DropdownMenuItem(value: 'Payment', child: Text('Payment (Money Paid to Supplier)')),
                      ],
                      onChanged: _onVoucherTypeChanged,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        // Voucher Number
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(_voucherNumber),
                            initialValue: _voucherNumber,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Voucher Number',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onChanged: (val) => _voucherNumber = val,
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Date picker
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Posting Date',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            controller: TextEditingController(
                              text: DateFormat('dd-MMM-yyyy hh:mm a').format(_voucherDate),
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _voucherDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final now = DateTime.now();
                                setState(() {
                                  _voucherDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    now.hour,
                                    now.minute,
                                    now.second,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Cash/Bank account to use
                    DropdownButtonFormField<String>(
                      value: _selectedCashBankLedgerId,
                      dropdownColor: const Color(0xFF1E2235),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Cash / Bank Ledger Account',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: _cashBankLedgers.map((l) {
                        return DropdownMenuItem(value: l.id, child: Text(l.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedCashBankLedgerId = val),
                    ),
                    const SizedBox(height: 16),

                    // Customer / Supplier selector
                    DropdownButtonFormField<String>(
                      value: _selectedContactLedgerId,
                      dropdownColor: const Color(0xFF1E2235),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: _voucherType == 'Receipt' ? 'Received From Customer' : 'Paid To Supplier',
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: _contactLedgers.map((l) {
                        return DropdownMenuItem(value: l.id, child: Text(l.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedContactLedgerId = val),
                    ),
                    const SizedBox(height: 16),

                    // Amount
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Transaction Amount (INR)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                        final numVal = double.tryParse(val);
                        if (numVal == null || numVal <= 0) return 'Please enter a positive number';
                        return null;
                      },
                      onSaved: (val) => _amount = double.parse(val!),
                    ),
                    const SizedBox(height: 16),

                    // Reference Number
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Cheque No. / Transaction ID / Ref No.',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onChanged: (val) => _referenceNumber = val,
                    ),
                    const SizedBox(height: 16),

                    // Narration / Remarks
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Narration / Remarks',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onChanged: (val) => _narration = val,
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(
                          'Post $_voucherType Entry',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: _submitVoucher,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
