import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../core/financial_year_service.dart';
import '../core/invoice_printer.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'theme/app_theme.dart';
import 'widgets/print_preview_dialog.dart';

class InvoiceRowItem {
  StockItem? item;
  double quantity;
  double rate;
  double originalRate; // To detect price overrides
  bool isReplacement;

  late final TextEditingController itemController;
  late final TextEditingController qtyController;
  late final TextEditingController rateController;

  final FocusNode itemFocusNode = FocusNode();
  final FocusNode qtyFocusNode = FocusNode();
  final FocusNode rateFocusNode = FocusNode();

  bool isEditingQty = false;
  bool isEditingRate = false;

  InvoiceRowItem({
    this.item,
    this.quantity = 0.0,
    this.rate = 0.0,
    this.originalRate = 0.0,
    this.isReplacement = false,
  }) {
    itemController = TextEditingController(text: item?.name ?? '');
    qtyController = TextEditingController(text: quantity > 0 ? quantity.toString() : '');
    rateController = TextEditingController(text: isReplacement ? '0.00' : (rate > 0 ? rate.toString() : ''));

    qtyFocusNode.addListener(() {
      if (qtyFocusNode.hasFocus) {
        isEditingQty = false;
      }
    });

    rateFocusNode.addListener(() {
      if (rateFocusNode.hasFocus) {
        isEditingRate = false;
      }
    });
  }

  double get total => isReplacement ? 0.0 : (quantity * rate);

  void toggleReplacement(bool value) {
    isReplacement = value;
    if (isReplacement) {
      rate = 0.0;
      rateController.text = '0.00';
    } else {
      rate = originalRate;
      rateController.text = rate > 0 ? rate.toString() : '';
    }
  }

  void dispose() {
    itemController.dispose();
    qtyController.dispose();
    rateController.dispose();
    itemFocusNode.dispose();
    qtyFocusNode.dispose();
    rateFocusNode.dispose();
  }
}

class InvoiceCreationPage extends StatefulWidget {
  final Voucher? existingVoucher;
  const InvoiceCreationPage({super.key, this.existingVoucher});

  @override
  State<InvoiceCreationPage> createState() => _InvoiceCreationPageState();
}

class _InvoiceCreationPageState extends State<InvoiceCreationPage> {
  final Uuid uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _narrationFocusNode = FocusNode();
  
  String _invoiceType = 'Sales'; // 'Sales' or 'Purchase'
  String _invoiceNumber = '';
  DateTime _invoiceDate = DateTime.now();
  String? _selectedLedgerId; // Customer for Sales, Supplier for Purchase
  String _narration = '';
  String _referenceNumber = '';
  double _discountAmount = 0.0;
  final TextEditingController _discountController = TextEditingController(text: '0.00');

  List<InvoiceRowItem> _rows = [];
  List<Ledger> _contactLedgers = []; // Customers/Suppliers loaded dynamically
  List<StockItem> _allItems = [];
  List<StockStatus> _allStockStatus = [];

  final double _taxRatePercent = 0.0; // 0% GST (disabled by default)
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
  PrinterPaperSize _selectedPaperSize = PrinterPaperSize.a4;
  bool _isSubmitting = false;
  bool _isDataLoaded = false;

  @override
  void dispose() {
    _narrationFocusNode.dispose();
    _discountController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataLoaded) {
      _isDataLoaded = true;
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    
    if (widget.existingVoucher != null) {
      final detail = await engine.getVoucherDetail(widget.existingVoucher!.id);
      if (detail != null) {
        _invoiceType = detail.voucher.voucherType;
        _invoiceNumber = detail.voucher.voucherNumber;
        _invoiceDate = detail.voucher.date;
        _narration = detail.voucher.narration ?? '';
        _referenceNumber = detail.voucher.referenceNumber ?? '';
        _selectedLedgerId = detail.contactLedger.id;
        _discountAmount = detail.voucher.discountAmount;
        _discountController.text = _discountAmount > 0 ? _discountAmount.toStringAsFixed(2) : '0.00';

        // Load contact ledgers (exclude soft-deleted unless it is the currently selected one)
        final targetGroup = _invoiceType == 'Sales' ? 'debtors' : 'creditors';
        final contactLedgers = await (db.select(db.ledgers)
          ..where((t) => t.groupId.equals(targetGroup) & (t.isDeleted.equals(false) | t.id.equals(_selectedLedgerId!))))
          .get();
        
        // Load inventory items
        final allItems = await db.select(db.stockItems).get();
        final stockStatus = await engine.getStockSummary();

        // Convert stock transactions back to rows
        List<InvoiceRowItem> loadedRows = [];
        for (final st in detail.stockTransactions) {
          final matchingItem = allItems.firstWhere(
            (i) => i.id == st.tx.stockItemId,
            orElse: () => StockItem(
              id: 'unknown',
              name: 'Unknown',
              sku: 'N/A',
              openingQuantity: 0.0,
              openingRate: 0.0,
              salesRate: 0.0,
              purchaseRate: 0.0,
              unitOfMeasure: 'pcs',
              updatedAt: DateTime.now(),
              isSynced: false,
            ),
          );
          loadedRows.add(InvoiceRowItem(
            item: matchingItem,
            quantity: st.tx.quantity.abs(),
            rate: st.tx.rate,
            originalRate: _invoiceType == 'Sales' ? matchingItem.salesRate : matchingItem.purchaseRate,
            isReplacement: st.tx.isReplacement,
          ));
        }

        if (loadedRows.isEmpty) {
          loadedRows = [InvoiceRowItem()];
        }

        setState(() {
          _contactLedgers = contactLedgers;
          _allItems = allItems;
          _allStockStatus = stockStatus;
          _rows = loadedRows;
        });
        return;
      }
    }

    // Default creation path
    final targetGroup = _invoiceType == 'Sales' ? 'debtors' : 'creditors';
    final contactLedgers = await (db.select(db.ledgers)
      ..where((t) => t.groupId.equals(targetGroup) & t.isDeleted.equals(false)))
      .get();
    
    final allItems = await db.select(db.stockItems).get();
    final stockStatus = await engine.getStockSummary();

    final prefix = _invoiceType == 'Sales' ? 'INV' : 'PUR';
    final invNo = '$prefix-${DateTime.now().year}-Auto';

    setState(() {
      _contactLedgers = contactLedgers;
      _allItems = allItems;
      _allStockStatus = stockStatus;
      _invoiceNumber = invNo;
      if (_rows.isEmpty) {
        _rows = [InvoiceRowItem()];
      }
    });
  }

  void _onInvoiceTypeChanged(String? type) {
    if (type != null && type != _invoiceType) {
      setState(() {
        _invoiceType = type;
        _selectedLedgerId = null;
        _rows = [InvoiceRowItem()];
      });
      _loadInitialData();
    }
  }

  double get _subtotal {
    return _rows.fold(0.0, (sum, row) => sum + row.total);
  }

  double get _taxableAmount {
    final sub = _subtotal;
    if (_discountAmount >= sub) return 0.0;
    return sub - _discountAmount;
  }

  double get _cgst {
    return _taxableAmount * (_taxRatePercent / 2) / 100;
  }

  double get _sgst {
    return _taxableAmount * (_taxRatePercent / 2) / 100;
  }

  double get _grandTotal {
    return _taxableAmount + _cgst + _sgst;
  }

  double _getStockQuantity(String itemId) {
    final match = _allStockStatus.where((status) => status.id == itemId);
    if (match.isNotEmpty) {
      return match.first.quantity;
    }
    return 0.0;
  }

  InvoiceViewModel _buildCurrentInvoiceViewModel(String voucherNo) {
    final contact = _contactLedgers.firstWhere(
      (l) => l.id == _selectedLedgerId,
      orElse: () => Ledger(
        id: _selectedLedgerId ?? '',
        name: 'Walk-in Party',
        groupId: _invoiceType == 'Sales' ? 'debtors' : 'creditors',
        openingBalance: 0.0,
        updatedAt: DateTime.now(),
        isSynced: false,
        isDeleted: false,
      ),
    );

    final validRows = _rows.where((r) => r.item != null && r.quantity > 0).toList();
    final fy = FinancialYearService.getFinancialYear(_invoiceDate);

    return InvoiceViewModel(
      voucherNumber: voucherNo,
      voucherType: _invoiceType,
      financialYear: fy,
      date: _invoiceDate,
      partyName: contact.name,
      partyAddress: contact.address ?? '',
      partyTaxNumber: contact.taxNumber ?? '',
      partyPhone: contact.phone,
      items: validRows.map((r) => InvoiceItemRow(
        itemName: r.item!.name,
        quantity: r.quantity,
        rate: r.rate,
        amount: r.total,
        isReplacement: r.isReplacement,
      )).toList(),
      subtotal: _subtotal,
      discount: _discountAmount,
      cgst: _cgst,
      sgst: _sgst,
      grandTotal: _grandTotal,
      narration: _narration,
    );
  }

  Future<void> _previewInvoice() async {
    if (_selectedLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Customer or Supplier ledger.')),
      );
      return;
    }

    final validRows = _rows.where((row) => row.item != null && row.quantity > 0).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with valid quantity.')),
      );
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);
    final viewModel = _buildCurrentInvoiceViewModel(_invoiceNumber.isNotEmpty ? _invoiceNumber : 'PREVIEW');
    await PrintPreviewDialog.show(context, db: db, invoice: viewModel);
  }

  Future<void> _submitInvoice({bool andPrint = false}) async {
    if (_isSubmitting) return;

    if (_selectedLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Customer or Supplier ledger.')),
      );
      return;
    }

    final validRows = _rows.where((row) => row.item != null && row.quantity > 0).toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item with valid quantity.')),
      );
      return;
    }

    for (final row in validRows) {
      if (!row.isReplacement && row.rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid rate for ${row.item!.name} or mark as Replacement.')),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    // Check price overrides for non-replacement items
    List<StockItem> itemsToUpdate = [];
    for (final row in validRows) {
      if (!row.isReplacement && row.rate != row.originalRate) {
        itemsToUpdate.add(row.item!);
      }
    }

    bool confirmedPriceUpdates = false;
    if (itemsToUpdate.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Price Overrides Detected', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            content: Text(
              'You have modified standard prices for ${itemsToUpdate.length} item(s).\n\nDo you want to update their default catalog rates in inventory for future invoices?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                child: const Text('Keep Old Rates', style: TextStyle(color: AppColors.textMuted)),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: const Text('Update Rates', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        },
      );
      confirmedPriceUpdates = confirm ?? false;
    }

    if (confirmedPriceUpdates) {
      for (final row in validRows) {
        if (!row.isReplacement && row.rate != row.originalRate) {
          final updatedItem = row.item!;
          if (_invoiceType == 'Sales') {
            await (db.update(db.stockItems)..where((t) => t.id.equals(updatedItem.id)))
                .write(StockItemsCompanion(salesRate: drift.Value(row.rate)));
          } else {
            await (db.update(db.stockItems)..where((t) => t.id.equals(updatedItem.id)))
                .write(StockItemsCompanion(purchaseRate: drift.Value(row.rate)));
          }
        }
      }
    }

    // Formulate Double-Entry ledger postings
    final taxable = _taxableAmount;
    final cgst = _cgst;
    final sgst = _sgst;
    final grandTotal = _grandTotal;

    List<VoucherEntriesCompanion> entries = [];
    
    if (_invoiceType == 'Sales') {
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: _selectedLedgerId!,
        debitAmount: drift.Value(grandTotal),
        creditAmount: const drift.Value(0.0),
      ));
      
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'sales',
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(taxable),
      ));

      if (cgst > 0) {
        entries.add(VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'cgst',
          debitAmount: const drift.Value(0.0),
          creditAmount: drift.Value(cgst),
        ));
      }

      if (sgst > 0) {
        entries.add(VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'sgst',
          debitAmount: const drift.Value(0.0),
          creditAmount: drift.Value(sgst),
        ));
      }
    } else {
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'purchase',
        debitAmount: drift.Value(taxable),
        creditAmount: const drift.Value(0.0),
      ));

      if (cgst > 0) {
        entries.add(VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'cgst',
          debitAmount: drift.Value(cgst),
          creditAmount: const drift.Value(0.0),
        ));
      }

      if (sgst > 0) {
        entries.add(VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'sgst',
          debitAmount: drift.Value(sgst),
          creditAmount: const drift.Value(0.0),
        ));
      }

      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: _selectedLedgerId!,
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(grandTotal),
      ));
    }

    // Formulate Stock transactions
    List<StockTransactionsCompanion> stockTxs = [];
    for (final row in validRows) {
      stockTxs.add(StockTransactionsCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        stockItemId: row.item!.id,
        quantity: row.quantity,
        rate: row.rate,
        transactionType: _invoiceType == 'Sales' ? 'OUT' : 'IN',
        isReplacement: drift.Value(row.isReplacement),
      ));
    }

    try {
      final savedVoucherNo = await engine.createVoucher(
        voucherNumber: widget.existingVoucher != null ? _invoiceNumber : null,
        voucherType: _invoiceType,
        date: _invoiceDate,
        narration: _narration,
        referenceNumber: _referenceNumber,
        discountAmount: _discountAmount,
        entries: entries,
        stockTransactions: stockTxs,
        existingVoucherId: widget.existingVoucher?.id,
      );

      if (mounted) {
        if (andPrint) {
          final viewModel = _buildCurrentInvoiceViewModel(savedVoucherNo);
          await InvoicePrinter.printInvoice(
            context: context,
            db: db,
            invoice: viewModel,
            paperSize: _selectedPaperSize,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('$_invoiceType Invoice $savedVoucherNo saved successfully!'),
          ),
        );
        if (widget.existingVoucher != null) {
          Navigator.pop(context);
        } else {
          setState(() {
            _rows = [InvoiceRowItem()];
            _selectedLedgerId = null;
            _narration = '';
            _referenceNumber = '';
            _discountAmount = 0.0;
            _discountController.text = '0.00';
          });
          _loadInitialData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to save invoice: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _cancelBill() async {
    if (widget.existingVoucher == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Invoice', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to cancel invoice ${_invoiceNumber}?\n\n'
          'This will mark the bill as CANCELLED, remove its impact from customer balances, and safely restore stock quantities.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text('Keep Active', style: TextStyle(color: AppColors.textMuted)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Cancel Invoice', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final engine = Provider.of<AccountingEngine>(context, listen: false);
      await engine.cancelVoucher(widget.existingVoucher!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.warning, content: Text('Invoice $_invoiceNumber has been cancelled.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to cancel invoice: $e')),
        );
      }
    }
  }

  Future<void> _deleteBill() async {
    if (widget.existingVoucher == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Invoice Permanently', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to PERMANENTLY DELETE invoice ${_invoiceNumber}?\n\n'
          'This will completely remove the bill, its ledger entries, and its stock adjustments from the database. This action cannot be undone.',
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
      await engine.deleteVoucher(widget.existingVoucher!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Invoice $_invoiceNumber deleted permanently.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Failed to delete invoice: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.existingVoucher != null ? 'Edit $_invoiceType Bill / Invoice' : 'New $_invoiceType Bill / Invoice',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (widget.existingVoucher != null) ...[
            TextButton.icon(
              icon: const Icon(Icons.block_rounded, color: AppColors.warning, size: 18),
              label: const Text('Cancel Bill', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
              onPressed: _cancelBill,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 18),
              label: const Text('Delete Bill', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              onPressed: _deleteBill,
            ),
            const SizedBox(width: 16),
          ],
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Details Card
              _buildHeaderCard(),
              const SizedBox(height: 16),

              // Invoice Rows Header
              _buildRowsHeader(),
              const SizedBox(height: 6),

              // Invoice Rows List
              Expanded(
                child: ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) => _buildInvoiceRow(index),
                ),
              ),

              const SizedBox(height: 10),

              // Add row button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primaryLight),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Line Item', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  setState(() {
                    _rows.add(InvoiceRowItem());
                  });
                },
              ),

              const SizedBox(height: 16),

              // Footer Card
              _buildFooterCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Invoice Type Selection
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _invoiceType,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Voucher Type',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sales', child: Text('Sales Invoice')),
                    DropdownMenuItem(value: 'Purchase', child: Text('Purchase Entry')),
                  ],
                  onChanged: widget.existingVoucher != null ? null : _onInvoiceTypeChanged,
                ),
              ),
              const SizedBox(width: 16),
              // Invoice Number
              Expanded(
                child: TextFormField(
                  key: ValueKey(_invoiceNumber),
                  initialValue: _invoiceNumber,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Voucher / Invoice No.',
                    isDense: true,
                  ),
                  onChanged: (val) => _invoiceNumber = val,
                ),
              ),
              const SizedBox(width: 16),
              // Date picker field
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Date & Time',
                    suffixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                    isDense: true,
                  ),
                  controller: TextEditingController(
                    text: DateFormat('dd-MMM-yyyy hh:mm a').format(_invoiceDate),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      final now = DateTime.now();
                      setState(() {
                        _invoiceDate = DateTime(
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
          Row(
            children: [
              // Contact Ledger selector (Customers / Suppliers)
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedLedgerId,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: _invoiceType == 'Sales' ? 'Customer / Sundry Debtor' : 'Supplier / Sundry Creditor',
                    isDense: true,
                  ),
                  items: _contactLedgers.map((l) {
                    return DropdownMenuItem(
                      value: l.id,
                      child: Text(
                        l.name + (l.isDeleted ? ' (Deactivated)' : ''),
                        style: TextStyle(
                          color: l.isDeleted ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLedgerId = val),
                ),
              ),
              const SizedBox(width: 16),
              // Reference Number
              Expanded(
                child: TextFormField(
                  initialValue: _referenceNumber,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    labelText: 'Reference / Purchase Order / LPO No.',
                    isDense: true,
                  ),
                  onChanged: (val) => _referenceNumber = val,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowsHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('Stock Item Description & Stock', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
          SizedBox(width: 12),
          SizedBox(width: 110, child: Text('Type', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text('Quantity', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text('Rate (₹)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text('Total (₹)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(int index) {
    final row = _rows[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: row.isReplacement ? AppColors.warningBg.withOpacity(0.3) : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: row.isReplacement ? AppColors.warning.withOpacity(0.5) : AppColors.border),
      ),
      child: Row(
        children: [
          // 1. Fuzzy Autocomplete Search Field
          Expanded(
            flex: 5,
            child: RawAutocomplete<StockItem>(
              focusNode: row.itemFocusNode,
              textEditingController: row.itemController,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _allItems;
                }
                final query = textEditingValue.text.toLowerCase();
                return _allItems.where((item) {
                  return item.name.toLowerCase().contains(query) ||
                      (item.sku != null && item.sku!.toLowerCase().contains(query));
                });
              },
              displayStringForOption: (StockItem option) => option.name,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text.isEmpty && row.item != null) {
                  controller.text = row.item!.name;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Type item name or SKU...',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onSubmitted: (val) {
                    if (row.item != null) {
                      row.qtyFocusNode.requestFocus();
                    } else if (val.trim().isEmpty) {
                      _narrationFocusNode.requestFocus();
                    } else {
                      onFieldSubmitted();
                    }
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6.0,
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 480, maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          final stockQty = _getStockQuantity(option.id);
                          final stdRate = _invoiceType == 'Sales' ? option.salesRate : option.purchaseRate;

                          return ListTile(
                            dense: true,
                            hoverColor: AppColors.surfaceSecondary,
                            title: Text(option.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text('Std Rate: ${_currencyFormat.format(stdRate)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stockQty <= 0 ? AppColors.errorBg : AppColors.successBg,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Stock: ${stockQty.toStringAsFixed(0)} ${option.unitOfMeasure}',
                                style: TextStyle(
                                  color: stockQty <= 0 ? AppColors.error : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            onTap: () {
                              onSelected(option);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: (StockItem selection) {
                setState(() {
                  row.item = selection;
                  row.itemController.text = selection.name;
                  row.originalRate = _invoiceType == 'Sales' ? selection.salesRate : selection.purchaseRate;
                  if (row.isReplacement) {
                    row.rate = 0.0;
                    row.rateController.text = '0.00';
                  } else {
                    row.rate = row.originalRate;
                    row.rateController.text = row.rate > 0 ? row.rate.toString() : '';
                  }
                  row.quantity = 0.0;
                  row.qtyController.text = '';
                });
                row.qtyFocusNode.requestFocus();
              },
            ),
          ),
          
          const SizedBox(width: 12),

          // Replacement Toggle Button
          SizedBox(
            width: 110,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() {
                  row.toggleReplacement(!row.isReplacement);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: row.isReplacement ? AppColors.warningBg : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: row.isReplacement ? AppColors.warning : AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      row.isReplacement ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 14,
                      color: row.isReplacement ? AppColors.warning : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      row.isReplacement ? 'Replace (₹0)' : 'Standard',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: row.isReplacement ? AppColors.warning : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 2. Quantity field
          Expanded(
            flex: 2,
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.backspace) {
                    if (!row.isEditingQty) {
                      row.itemFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    return KeyEventResult.ignored;
                  } else {
                    if (event.character != null && event.character!.isNotEmpty) {
                      if (!row.isEditingQty) {
                        row.isEditingQty = true;
                        row.qtyController.text = '';
                        row.quantity = 0.0;
                      }
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                controller: row.qtyController,
                focusNode: row.qtyFocusNode,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '0.00',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                onChanged: (val) {
                  setState(() {
                    row.quantity = double.tryParse(val) ?? 0.0;
                  });
                },
                onFieldSubmitted: (val) {
                  if (row.isReplacement) {
                    // For replacement, rate is locked to 0, advance to next row or add row
                    _advanceRow(index);
                  } else {
                    row.rateFocusNode.requestFocus();
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 3. Rate field
          Expanded(
            flex: 2,
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (row.isReplacement) return KeyEventResult.ignored;
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.backspace) {
                    if (!row.isEditingRate) {
                      row.qtyFocusNode.requestFocus();
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    return KeyEventResult.ignored;
                  } else {
                    if (event.character != null && event.character!.isNotEmpty) {
                      if (!row.isEditingRate) {
                        row.isEditingRate = true;
                        row.rateController.text = '';
                        row.rate = 0.0;
                      }
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextFormField(
                key: ValueKey('rate-${index}-${row.item?.id}-${row.isReplacement}'),
                controller: row.rateController,
                focusNode: row.rateFocusNode,
                readOnly: row.isReplacement,
                style: TextStyle(
                  color: row.isReplacement ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: row.isReplacement ? FontWeight.bold : FontWeight.normal,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: '0.00',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  fillColor: row.isReplacement ? AppColors.surfaceSecondary : AppColors.surface,
                ),
                onChanged: (val) {
                  if (!row.isReplacement) {
                    setState(() {
                      row.rate = double.tryParse(val) ?? 0.0;
                    });
                  }
                },
                onFieldSubmitted: (val) {
                  _advanceRow(index);
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 4. Total Display
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(row.total),
              style: TextStyle(
                color: row.isReplacement ? AppColors.warning : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),

          // Delete button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              tooltip: 'Remove Row',
              onPressed: () {
                setState(() {
                  final removedRow = _rows.removeAt(index);
                  removedRow.dispose();
                  if (_rows.isEmpty) {
                    _rows = [InvoiceRowItem()];
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _advanceRow(int index) {
    if (index == _rows.length - 1) {
      setState(() {
        _rows.add(InvoiceRowItem());
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _rows.last.itemFocusNode.requestFocus();
      });
    } else {
      _rows[index + 1].itemFocusNode.requestFocus();
    }
  }

  Widget _buildFooterCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Narration
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  focusNode: _narrationFocusNode,
                  initialValue: _narration,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Narration / Remarks / Notes',
                    hintText: 'Enter any payment terms or notes for the invoice...',
                  ),
                  onChanged: (val) => _narration = val,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Paper Size:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PrinterPaperSize>(
                          value: _selectedPaperSize,
                          dropdownColor: AppColors.surface,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 18),
                          items: const [
                            DropdownMenuItem(value: PrinterPaperSize.a4, child: Text('A4 Standard Print / PDF')),
                            DropdownMenuItem(value: PrinterPaperSize.thermal58mm, child: Text('58mm Thermal Receipt (POS)')),
                            DropdownMenuItem(value: PrinterPaperSize.thermal80mm, child: Text('80mm Thermal Receipt (POS)')),
                          ],
                          onChanged: _isSubmitting ? null : (val) {
                            if (val != null) setState(() => _selectedPaperSize = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 32),

          // Right column: Calculations summary
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', _subtotal),
                const SizedBox(height: 8),

                // Discount field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bill Discount (₹):',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    SizedBox(
                      width: 120,
                      height: 32,
                      child: TextFormField(
                        controller: _discountController,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _discountAmount = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),

                if (_discountAmount > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('Taxable Amount', _taxableAmount, valueColor: AppColors.primary),
                ],

                if (_cgst > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('CGST (9%)', _cgst),
                ],
                if (_sgst > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('SGST (9%)', _sgst),
                ],
                const Divider(color: AppColors.border, height: 16),
                _buildSummaryRow('Grand Total', _grandTotal, isBold: true, valueColor: AppColors.success),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.preview_rounded, size: 16),
                      label: const Text('Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isSubmitting ? null : _previewInvoice,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceSecondary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.borderStrong),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSubmitting 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isSubmitting ? null : () => _submitInvoice(andPrint: false),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSubmitting 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.print_rounded, size: 16),
                      label: const Text('Save & Print', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isSubmitting ? null : () => _submitInvoice(andPrint: true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: valueColor ?? (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
