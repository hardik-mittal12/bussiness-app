import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import 'package:printing/printing.dart';
import '../core/accounting_engine.dart';
import '../core/pdf_export_service.dart';
import '../data/database.dart';
import 'theme/app_theme.dart';

class PaymentReceiptPage extends StatefulWidget {
  const PaymentReceiptPage({super.key});

  @override
  State<PaymentReceiptPage> createState() => _PaymentReceiptPageState();
}

class _PaymentReceiptPageState extends State<PaymentReceiptPage> with SingleTickerProviderStateMixin {
  final Uuid uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  String _voucherType = 'Receipt'; // 'Receipt' (from Customer) or 'Payment' (to Supplier)
  String _voucherNumber = '';
  DateTime _voucherDate = DateTime.now();
  
  String? _selectedContactLedgerId; // Customer for Receipt, Supplier for Payment
  String? _selectedCashBankLedgerId; // Bank/Cash account
  double _amount = 0.0;
  final TextEditingController _amountController = TextEditingController();
  String _narration = '';
  final TextEditingController _narrationController = TextEditingController();
  String _referenceNumber = '';
  final TextEditingController _refController = TextEditingController();

  String? _editingVoucherId; // If non-null, we are updating an existing voucher

  List<Ledger> _contactLedgers = [];
  List<Ledger> _cashBankLedgers = [];
  List<VoucherDetail> _recentVouchers = [];
  bool _isLoadingRecent = true;

  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
  final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _narrationController.dispose();
    _refController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    // Load active Contact Ledgers (Receipt = Customer, Payment = Supplier)
    final contactGroup = _voucherType == 'Receipt' ? 'debtors' : 'creditors';
    final contactLedgers = await (db.select(db.ledgers)
      ..where((t) => t.groupId.equals(contactGroup) & (t.isDeleted.equals(false) | t.id.equals(_selectedContactLedgerId ?? ''))))
      .get();

    // Load Cash and Bank Ledgers
    final cashBankLedgers = await (db.select(db.ledgers)
      ..where((t) => t.groupId.equals('cash_in_hand') | t.groupId.equals('bank_accounts')))
      .get();

    // Generate Voucher number if not editing
    if (_editingVoucherId == null) {
      final vouchersList = await db.select(db.vouchers).get();
      final count = vouchersList.where((v) => v.voucherType == _voucherType).length + 1;
      final prefix = _voucherType == 'Receipt' ? 'RCT' : 'PAY';
      _voucherNumber = '$prefix-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';
    }

    setState(() {
      _contactLedgers = contactLedgers;
      _cashBankLedgers = cashBankLedgers;
      
      // Auto select default cash ledger if not set
      if (_cashBankLedgers.isNotEmpty && _selectedCashBankLedgerId == null) {
        final cashMatch = _cashBankLedgers.where((l) => l.id == 'cash');
        _selectedCashBankLedgerId = cashMatch.isNotEmpty ? cashMatch.first.id : _cashBankLedgers.first.id;
      }
    });

    await _loadRecentVouchers();
  }

  Future<void> _loadRecentVouchers() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    final vouchers = await (db.select(db.vouchers)
      ..where((t) => t.voucherType.isIn(['Receipt', 'Payment']))
      ..orderBy([(t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc)])
      ..limit(30))
      .get();

    List<VoucherDetail> details = [];
    for (final v in vouchers) {
      final d = await engine.getVoucherDetail(v.id);
      if (d != null) details.add(d);
    }

    if (mounted) {
      setState(() {
        _recentVouchers = details;
        _isLoadingRecent = false;
      });
    }
  }

  void _onVoucherTypeChanged(String? type) {
    if (type != null && type != _voucherType) {
      setState(() {
        _voucherType = type;
        _selectedContactLedgerId = null;
        _amount = 0.0;
        _amountController.text = '';
        _editingVoucherId = null;
      });
      _loadInitialData();
    }
  }

  void _editVoucher(VoucherDetail detail) {
    setState(() {
      _editingVoucherId = detail.voucher.id;
      _voucherType = detail.voucher.voucherType;
      _voucherNumber = detail.voucher.voucherNumber;
      _voucherDate = detail.voucher.date;
      _selectedContactLedgerId = detail.contactLedger.id;
      _narration = detail.voucher.narration ?? '';
      _narrationController.text = _narration;
      _referenceNumber = detail.voucher.referenceNumber ?? '';
      _refController.text = _referenceNumber;

      // Extract amount and cash/bank ledger
      double amt = 0.0;
      for (final e in detail.entries) {
        if (e.ledgerId != detail.contactLedger.id) {
          _selectedCashBankLedgerId = e.ledgerId;
        }
        if (e.debitAmount > 0) amt = e.debitAmount;
        if (e.creditAmount > 0 && amt == 0) amt = e.creditAmount;
      }
      _amount = amt;
      _amountController.text = amt > 0 ? amt.toStringAsFixed(2) : '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingVoucherId = null;
      _selectedContactLedgerId = null;
      _amount = 0.0;
      _amountController.text = '';
      _narration = '';
      _narrationController.text = '';
      _referenceNumber = '';
      _refController.text = '';
    });
    _loadInitialData();
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
      // Credit: Customer Ledger (reduces debtor balance)
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
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
      // Debit: Supplier Ledger (reduces creditor balance)
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
        existingVoucherId: _editingVoucherId,
      );

      if (mounted) {
        final isEdit = _editingVoucherId != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('$_voucherType voucher $_voucherNumber ${isEdit ? "updated" : "saved"} successfully!'),
          ),
        );
        _cancelEdit();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to save voucher: $e')),
        );
      }
    }
  }

  Future<void> _cancelVoucher(VoucherDetail detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Cancel ${detail.voucher.voucherType}', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to cancel ${detail.voucher.voucherType} ${detail.voucher.voucherNumber}?\n\n'
          'This will reverse the financial posting and update the customer/supplier balance without deleting audit history.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Back', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Cancel Voucher', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final engine = Provider.of<AccountingEngine>(context, listen: false);
      await engine.cancelVoucher(detail.voucher.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.warning, content: Text('${detail.voucher.voucherNumber} cancelled.')),
        );
        _loadRecentVouchers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to cancel: $e')),
        );
      }
    }
  }

  Future<void> _deleteVoucher(VoucherDetail detail) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete ${detail.voucher.voucherType} Permanently', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to PERMANENTLY DELETE ${detail.voucher.voucherType} ${detail.voucher.voucherNumber}?\n\n'
          'This will completely remove the entry and its ledger postings from the database.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final engine = Provider.of<AccountingEngine>(context, listen: false);
      await engine.deleteVoucher(detail.voucher.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('${detail.voucher.voucherNumber} deleted permanently.')),
        );
        if (_editingVoucherId == detail.voucher.id) {
          _cancelEdit();
        } else {
          _loadRecentVouchers();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _printReceiptPdf(VoucherDetail detail) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final pdfService = PdfExportService(db);

    double amt = 0.0;
    String mode = 'Cash';
    for (final e in detail.entries) {
      if (e.ledgerId != detail.contactLedger.id) {
        final cashBank = _cashBankLedgers.where((l) => l.id == e.ledgerId).firstOrNull;
        if (cashBank != null && cashBank.groupId == 'bank_accounts') {
          mode = 'Bank Transfer / Online';
        }
      }
      if (e.debitAmount > 0) amt = e.debitAmount;
    }

    final bytes = await pdfService.exportReceiptPdf(
      voucher: detail.voucher,
      partyLedger: detail.contactLedger,
      amount: amt,
      paymentMode: mode,
      narration: detail.voucher.narration,
    );

    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _editingVoucherId != null ? 'Edit $_voucherType Voucher' : 'Record $_voucherType / Payment',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_editingVoucherId != null)
            TextButton.icon(
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
              label: const Text('Cancel Edit', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
              onPressed: _cancelEdit,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Entry Form
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _editingVoucherId != null ? 'Editing Voucher: $_voucherNumber' : 'New Transaction',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          if (_editingVoucherId != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(4)),
                              child: const Text('Editing', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Voucher Type Selector
                      DropdownButtonFormField<String>(
                        value: _voucherType,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(labelText: 'Transaction Mode', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Receipt', child: Text('Receipt (Money Received from Customer)')),
                          DropdownMenuItem(value: 'Payment', child: Text('Payment (Money Paid to Supplier)')),
                        ],
                        onChanged: _editingVoucherId != null ? null : _onVoucherTypeChanged,
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          // Voucher Number
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(_voucherNumber),
                              initialValue: _voucherNumber,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(labelText: 'Voucher Number', isDense: true),
                              onChanged: (val) => _voucherNumber = val,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Date picker
                          Expanded(
                            child: TextFormField(
                              readOnly: true,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                              decoration: const InputDecoration(
                                labelText: 'Posting Date',
                                suffixIcon: Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                                isDense: true,
                              ),
                              controller: TextEditingController(
                                text: DateFormat('dd-MMM-yyyy hh:mm a').format(_voucherDate),
                              ),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _voucherDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
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
                      const SizedBox(height: 14),

                      // Cash/Bank account to use
                      DropdownButtonFormField<String>(
                        value: _selectedCashBankLedgerId,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(labelText: 'Deposit to / Pay from Account', isDense: true),
                        items: _cashBankLedgers.map((l) {
                          return DropdownMenuItem(value: l.id, child: Text(l.name));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCashBankLedgerId = val),
                      ),
                      const SizedBox(height: 14),

                      // Customer / Supplier selector
                      DropdownButtonFormField<String>(
                        value: _selectedContactLedgerId,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: _voucherType == 'Receipt' ? 'Customer (Sundry Debtor)' : 'Supplier (Sundry Creditor)',
                          isDense: true,
                        ),
                        items: _contactLedgers.map((l) {
                          return DropdownMenuItem(
                            value: l.id,
                            child: Text(
                              l.name + (l.isDeleted ? ' (Deactivated)' : ''),
                              style: TextStyle(color: l.isDeleted ? AppColors.textMuted : AppColors.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedContactLedgerId = val),
                      ),
                      const SizedBox(height: 14),

                      // Amount
                      TextFormField(
                        controller: _amountController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          hintText: '0.00',
                          isDense: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0) return 'Please enter a positive amount';
                          return null;
                        },
                        onChanged: (val) => _amount = double.tryParse(val) ?? 0.0,
                        onSaved: (val) => _amount = double.tryParse(val ?? '') ?? 0.0,
                      ),
                      const SizedBox(height: 14),

                      // Reference Number
                      TextFormField(
                        controller: _refController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Cheque / Ref No. / Transaction ID',
                          hintText: 'e.g. UTR123456 / CHQ 00456',
                          isDense: true,
                        ),
                        onChanged: (val) => _referenceNumber = val,
                      ),
                      const SizedBox(height: 14),

                      // Narration / Remarks
                      TextFormField(
                        controller: _narrationController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Narration / Remarks',
                          hintText: 'Enter payment notes...',
                          isDense: true,
                        ),
                        onChanged: (val) => _narration = val,
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text(
                            _editingVoucherId != null ? 'Update $_voucherType Entry' : 'Post $_voucherType Entry',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

          // Right Side: Recent Payments & Receipts List with Edit/Cancel/Delete/Print
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 20, bottom: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Payments & Receipts',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                            tooltip: 'Refresh',
                            onPressed: _loadRecentVouchers,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                    Expanded(
                      child: _isLoadingRecent
                          ? const Center(child: CircularProgressIndicator())
                          : _recentVouchers.isEmpty
                              ? const Center(
                                  child: Text('No payment or receipt vouchers found.', style: TextStyle(color: AppColors.textMuted)),
                                )
                              : ListView.separated(
                                  itemCount: _recentVouchers.length,
                                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                                  itemBuilder: (context, index) {
                                    final d = _recentVouchers[index];
                                    final isReceipt = d.voucher.voucherType == 'Receipt';
                                    final isCancelled = d.voucher.status == 'CANCELLED';

                                    double amt = 0.0;
                                    for (final e in d.entries) {
                                      if (e.debitAmount > 0) amt = e.debitAmount;
                                    }

                                    return ListTile(
                                      dense: true,
                                      leading: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isCancelled
                                              ? AppColors.surfaceSecondary
                                              : (isReceipt ? AppColors.successBg : AppColors.infoBg),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isCancelled ? 'CANCELLED' : d.voucher.voucherType.toUpperCase(),
                                          style: TextStyle(
                                            color: isCancelled
                                                ? AppColors.textMuted
                                                : (isReceipt ? AppColors.success : AppColors.info),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        children: [
                                          Text(d.contactLedger.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(width: 8),
                                          Text('(${d.voucher.voucherNumber})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                        ],
                                      ),
                                      subtitle: Text(
                                        '${_dateFormat.format(d.voucher.date)} • ${_currencyFormat.format(amt)}${d.voucher.referenceNumber != null && d.voucher.referenceNumber!.isNotEmpty ? " • Ref: ${d.voucher.referenceNumber}" : ""}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.primary),
                                            tooltip: 'Print / Export PDF',
                                            onPressed: () => _printReceiptPdf(d),
                                          ),
                                          if (!isCancelled) ...[
                                            IconButton(
                                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                                              tooltip: 'Edit Voucher',
                                              onPressed: () => _editVoucher(d),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.block_rounded, size: 18, color: AppColors.warning),
                                              tooltip: 'Cancel Voucher',
                                              onPressed: () => _cancelVoucher(d),
                                            ),
                                          ],
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                                            tooltip: 'Delete Voucher',
                                            onPressed: () => _deleteVoucher(d),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
