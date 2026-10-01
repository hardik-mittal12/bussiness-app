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
    qtyController = TextEditingController(
      text: quantity > 0 ? quantity.toString() : '',
    );
    rateController = TextEditingController(
      text: isReplacement ? '0.00' : (rate > 0 ? rate.toString() : ''),
    );

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
  final TextEditingController _contactSearchController =
      TextEditingController();
  final FocusNode _contactSearchFocusNode = FocusNode();

  String _invoiceType = 'Sales'; // 'Sales' or 'Purchase'
  String _paymentMode = 'Debt'; // 'Debt' or 'Cash'
  String _invoiceNumber = '';
  DateTime _invoiceDate = DateTime.now();
  String? _selectedLedgerId; // Customer for Sales, Supplier for Purchase
  String _narration = '';
  String _referenceNumber = '';
  double _discountAmount = 0.0;
  final TextEditingController _discountController = TextEditingController(
    text: '0.00',
  );

  List<InvoiceRowItem> _rows = [];
  List<Ledger> _contactLedgers = []; // Customers/Suppliers loaded dynamically
  List<StockItem> _allItems = [];
  List<StockStatus> _allStockStatus = [];

  final double _taxRatePercent = 0.0; // 0% GST (disabled by default)
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'Rs. ',
    decimalDigits: 2,
  );
  final NumberFormat _quantityFormat = NumberFormat('#,##0.##');
  PrinterPaperSize _selectedPaperSize = PrinterPaperSize.a4;
  bool _isSubmitting = false;
  bool _isDataLoaded = false;

  @override
  void dispose() {
    _narrationFocusNode.dispose();
    _contactSearchController.dispose();
    _contactSearchFocusNode.dispose();
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
      if (!mounted) return;
      if (detail != null) {
        _invoiceType = detail.voucher.voucherType;
        _paymentMode = detail.voucher.paymentMode ?? 'Debt';
        _invoiceNumber = detail.voucher.voucherNumber;
        _invoiceDate = detail.voucher.date;
        _narration = detail.voucher.narration ?? '';
        _referenceNumber = detail.voucher.referenceNumber ?? '';
        _selectedLedgerId = detail.contactLedger.id;
        _contactSearchController.text = detail.contactLedger.name;
        _discountAmount = detail.voucher.discountAmount;
        _discountController.text = _discountAmount > 0
            ? _discountAmount.toStringAsFixed(2)
            : '0.00';

        // Load contact ledgers (exclude soft-deleted unless it is the currently selected one)
        final targetGroup = _invoiceType == 'Sales' ? 'debtors' : 'creditors';
        final contactLedgers =
            await (db.select(db.ledgers)..where(
                  (t) =>
                      t.groupId.equals(targetGroup) &
                      (t.isDeleted.equals(false) |
                          t.id.equals(_selectedLedgerId!)),
                ))
                .get();
        contactLedgers.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

        // Load inventory items
        final allItems = await db.select(db.stockItems).get();
        allItems.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        final stockStatus = await engine.getStockSummary();
        if (!mounted) return;

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
          loadedRows.add(
            InvoiceRowItem(
              item: matchingItem,
              quantity: st.tx.quantity.abs(),
              rate: st.tx.rate,
              originalRate: _invoiceType == 'Sales'
                  ? matchingItem.salesRate
                  : matchingItem.purchaseRate,
              isReplacement: st.tx.isReplacement,
            ),
          );
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
    final contactLedgers =
        await (db.select(db.ledgers)..where(
              (t) => t.groupId.equals(targetGroup) & t.isDeleted.equals(false),
            ))
            .get();
    contactLedgers.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    final allItems = await db.select(db.stockItems).get();
    allItems.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    final stockStatus = await engine.getStockSummary();
    if (!mounted) return;

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
        _paymentMode = 'Debt';
        _selectedLedgerId = null;
        _contactSearchController.clear();
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

  double get _totalPairs => _rows.fold(
    0.0,
    (total, row) => total + (row.item == null ? 0.0 : row.quantity),
  );

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

    final validRows = _rows
        .where((r) => r.item != null && r.quantity > 0)
        .toList();
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
      items: validRows
          .map(
            (r) => InvoiceItemRow(
              itemName: r.item!.name,
              quantity: r.quantity,
              rate: r.rate,
              amount: r.total,
              isReplacement: r.isReplacement,
            ),
          )
          .toList(),
      subtotal: _subtotal,
      discount: _discountAmount,
      cgst: _cgst,
      sgst: _sgst,
      grandTotal: _grandTotal,
      narration: _narration,
      paymentMode: _paymentMode,
    );
  }

  Future<void> _previewInvoice() async {
    if (_selectedLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Customer or Supplier ledger.'),
        ),
      );
      return;
    }

    final validRows = _rows
        .where((row) => row.item != null && row.quantity > 0)
        .toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one line item with valid quantity.',
          ),
        ),
      );
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);
    final viewModel = _buildCurrentInvoiceViewModel(
      _invoiceNumber.isNotEmpty ? _invoiceNumber : 'PREVIEW',
    );
    await PrintPreviewDialog.show(context, db: db, invoice: viewModel);
  }

  Future<void> _submitInvoice({bool andPrint = false}) async {
    if (_isSubmitting) return;

    if (_selectedLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a Customer or Supplier ledger.'),
        ),
      );
      return;
    }

    final validRows = _rows
        .where((row) => row.item != null && row.quantity > 0)
        .toList();
    if (validRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add at least one line item with valid quantity.',
          ),
        ),
      );
      return;
    }

    for (final row in validRows) {
      if (!row.isReplacement && row.rate <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enter a valid rate for ${row.item!.name} or mark as Replacement.',
            ),
          ),
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
            title: const Text(
              'Price Overrides Detected',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'You have modified standard prices for ${itemsToUpdate.length} item(s).\n\nDo you want to update their default catalog rates in inventory for future invoices?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Keep Old Rates',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text(
                  'Update Rates',
                  style: TextStyle(color: Colors.white),
                ),
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
            await (db.update(db.stockItems)
                  ..where((t) => t.id.equals(updatedItem.id)))
                .write(StockItemsCompanion(salesRate: drift.Value(row.rate)));
          } else {
            await (db.update(
              db.stockItems,
            )..where((t) => t.id.equals(updatedItem.id))).write(
              StockItemsCompanion(purchaseRate: drift.Value(row.rate)),
            );
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
      if (_paymentMode == 'Cash') {
        // Immediate Cash Sale: Cash is debited immediately (customer does not accumulate debt, no separate receipt needed)
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: drift.Value(grandTotal),
            creditAmount: const drift.Value(0.0),
          ),
        );
      } else {
        // Debt / Credit Sale: Customer ledger is debited (adds up to customer debt; receipt voucher required later)
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: _selectedLedgerId!,
            debitAmount: drift.Value(grandTotal),
            creditAmount: const drift.Value(0.0),
          ),
        );
      }

      entries.add(
        VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'sales',
          debitAmount: const drift.Value(0.0),
          creditAmount: drift.Value(taxable),
        ),
      );

      if (cgst > 0) {
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'cgst',
            debitAmount: const drift.Value(0.0),
            creditAmount: drift.Value(cgst),
          ),
        );
      }

      if (sgst > 0) {
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'sgst',
            debitAmount: const drift.Value(0.0),
            creditAmount: drift.Value(sgst),
          ),
        );
      }
    } else {
      // Purchase Entry
      entries.add(
        VoucherEntriesCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          ledgerId: 'purchase',
          debitAmount: drift.Value(taxable),
          creditAmount: const drift.Value(0.0),
        ),
      );

      if (cgst > 0) {
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'cgst',
            debitAmount: drift.Value(cgst),
            creditAmount: const drift.Value(0.0),
          ),
        );
      }

      if (sgst > 0) {
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'sgst',
            debitAmount: drift.Value(sgst),
            creditAmount: const drift.Value(0.0),
          ),
        );
      }

      if (_paymentMode == 'Cash') {
        // Immediate Cash Purchase: Cash is credited directly
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: 'cash',
            debitAmount: const drift.Value(0.0),
            creditAmount: drift.Value(grandTotal),
          ),
        );
      } else {
        // Debt / Credit Purchase: Supplier ledger is credited (adds to supplier debt, payment voucher required later)
        entries.add(
          VoucherEntriesCompanion.insert(
            id: uuid.v4(),
            voucherId: '',
            ledgerId: _selectedLedgerId!,
            debitAmount: const drift.Value(0.0),
            creditAmount: drift.Value(grandTotal),
          ),
        );
      }
    }

    // Formulate Stock transactions
    List<StockTransactionsCompanion> stockTxs = [];
    for (final row in validRows) {
      stockTxs.add(
        StockTransactionsCompanion.insert(
          id: uuid.v4(),
          voucherId: '',
          stockItemId: row.item!.id,
          quantity: row.quantity,
          rate: row.rate,
          transactionType: _invoiceType == 'Sales' ? 'OUT' : 'IN',
          isReplacement: drift.Value(row.isReplacement),
        ),
      );
    }

    try {
      final savedVoucherNo = await engine.createVoucher(
        voucherNumber: widget.existingVoucher != null ? _invoiceNumber : null,
        voucherType: _invoiceType,
        date: _invoiceDate,
        partyLedgerId: _selectedLedgerId,
        narration: _narration,
        referenceNumber: _referenceNumber,
        paymentMode: _paymentMode,
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
            content: Text(
              '$_invoiceType Invoice $savedVoucherNo saved successfully!',
            ),
          ),
        );
        if (widget.existingVoucher != null) {
          Navigator.pop(context);
        } else {
          setState(() {
            _rows = [InvoiceRowItem()];
            _selectedLedgerId = null;
            _contactSearchController.clear();
            _narration = '';
            _referenceNumber = '';
            _discountAmount = 0.0;
            _discountController.text = '0.00';
            _paymentMode = 'Debt';
          });
          _loadInitialData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to save invoice: $e'),
          ),
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
        title: const Text(
          'Cancel Invoice',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to cancel invoice ${_invoiceNumber}?\n\n'
          'This will mark the bill as CANCELLED, remove its impact from customer balances, and safely restore stock quantities.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Keep Active',
              style: TextStyle(color: AppColors.textMuted),
            ),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text(
              'Cancel Invoice',
              style: TextStyle(color: Colors.white),
            ),
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
          SnackBar(
            backgroundColor: AppColors.warning,
            content: Text('Invoice $_invoiceNumber has been cancelled.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to cancel invoice: $e'),
          ),
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
        title: const Text(
          'Delete Invoice Permanently',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to PERMANENTLY DELETE invoice ${_invoiceNumber}?\n\n'
          'This will completely remove the bill, its ledger entries, and its stock adjustments from the database. This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(
              'Delete Permanently',
              style: TextStyle(color: Colors.white),
            ),
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
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Invoice $_invoiceNumber deleted permanently.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to delete invoice: $e'),
          ),
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
          widget.existingVoucher != null
              ? 'Edit $_invoiceType Bill / Invoice'
              : 'New $_invoiceType Bill / Invoice',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (widget.existingVoucher != null) ...[
            TextButton.icon(
              icon: const Icon(
                Icons.block_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              label: const Text(
                'Cancel Bill',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _cancelBill,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 18,
              ),
              label: const Text(
                'Delete Bill',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

              // Add row button & Create new item button
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryLight),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Add Line Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      setState(() {
                        _rows.add(InvoiceRowItem());
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    key: const ValueKey('invoice-add-new-stock-item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceSecondary,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add_box_rounded, size: 18),
                    label: const Text(
                      '+ Create New Item',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _showQuickCreateItemDialog(context),
                  ),
                ],
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

  // Quick dialog to add new stock item in-between making a bill without losing current bill progress
  void _showQuickCreateItemDialog(BuildContext context, {int? targetRowIndex}) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    String name = '';
    String sku = '';
    String unit = 'pcs';
    double salesRate = 0.0;
    double purchaseRate = 0.0;
    double openingQty = 0.0;
    double openingRate = 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Quick Add New Stock Item',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
                        TextFormField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            labelText: 'Item Name *',
                            hintText: 'e.g. Leather Formal Shoes Size 9',
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Please enter item name'
                              : null,
                          onSaved: (val) => name = val!.trim(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'SKU / Item Code',
                            hintText: 'e.g. SK-001',
                          ),
                          onSaved: (val) => sku = val?.trim() ?? '',
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: unit,
                          decoration: const InputDecoration(
                            labelText: 'Unit of Measure',
                            hintText: 'pcs, kg, box, mtr',
                          ),
                          onSaved: (val) =>
                              unit = val?.trim().isNotEmpty == true
                              ? val!.trim()
                              : 'pcs',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Opening Quantity',
                                ),
                                onSaved: (val) => openingQty =
                                    double.tryParse(val ?? '0') ?? 0.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Opening Rate (Rs.)',
                                ),
                                onSaved: (val) => openingRate =
                                    double.tryParse(val ?? '0') ?? 0.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Purchase Rate (Rs.)',
                                ),
                                onSaved: (val) => purchaseRate =
                                    double.tryParse(val ?? '0') ?? 0.0,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Sales Rate (Rs.)',
                                ),
                                onSaved: (val) => salesRate =
                                    double.tryParse(val ?? '0') ?? 0.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      try {
                        final newItemId = uuid.v4();
                        final finalSku = sku.isNotEmpty
                            ? sku
                            : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}';

                        await db
                            .into(db.stockItems)
                            .insert(
                              StockItemsCompanion.insert(
                                id: newItemId,
                                name: name,
                                sku: drift.Value(finalSku),
                                unitOfMeasure: drift.Value(unit),
                                salesRate: drift.Value(salesRate),
                                purchaseRate: drift.Value(purchaseRate),
                                openingQuantity: drift.Value(openingQty),
                                openingRate: drift.Value(openingRate),
                                updatedAt: drift.Value(DateTime.now()),
                                isSynced: const drift.Value(false),
                              ),
                            );

                        // Reload all items & stock summary without losing current bill entries!
                        final freshItems =
                            await (db.select(db.stockItems)..orderBy([
                                  (t) => drift.OrderingTerm.asc(t.name.lower()),
                                ]))
                                .get();
                        final freshStock = await engine.getStockSummary();

                        final newlyAddedItem = freshItems.firstWhere(
                          (i) => i.id == newItemId,
                        );

                        if (mounted) {
                          setState(() {
                            _allItems = freshItems;
                            _allStockStatus = freshStock;

                            // If target row is provided or the last row is empty, assign it
                            int targetIdx = targetRowIndex ?? -1;
                            if (targetIdx == -1) {
                              targetIdx = _rows.indexWhere(
                                (r) => r.item == null,
                              );
                            }
                            if (targetIdx != -1 && targetIdx < _rows.length) {
                              final row = _rows[targetIdx];
                              row.item = newlyAddedItem;
                              row.rate = _invoiceType == 'Sales'
                                  ? (newlyAddedItem.salesRate > 0
                                        ? newlyAddedItem.salesRate
                                        : 0.0)
                                  : (newlyAddedItem.purchaseRate > 0
                                        ? newlyAddedItem.purchaseRate
                                        : 0.0);
                              row.originalRate = row.rate;
                              if (row.quantity == 0) row.quantity = 1.0;
                              row.qtyController.text = row.quantity.toString();
                              row.rateController.text = row.rate
                                  .toStringAsFixed(2);
                            } else {
                              // Append a new row with this item
                              final newRow = InvoiceRowItem(
                                item: newlyAddedItem,
                                quantity: 1.0,
                                rate: _invoiceType == 'Sales'
                                    ? newlyAddedItem.salesRate
                                    : newlyAddedItem.purchaseRate,
                                originalRate: _invoiceType == 'Sales'
                                    ? newlyAddedItem.salesRate
                                    : newlyAddedItem.purchaseRate,
                              );
                              newRow.qtyController.text = '1';
                              newRow.rateController.text = newRow.rate
                                  .toStringAsFixed(2);
                              _rows.add(newRow);
                            }
                          });

                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text(
                                'Item "$name" created and added to invoice!',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.error,
                              content: Text('Failed to save item: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save & Add to Bill'),
                ),
              ],
            );
          },
        );
      },
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
                  isExpanded: true,
                  value: _invoiceType,
                  dropdownColor: AppColors.surface,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Voucher Type',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Sales',
                      child: Text('Sales Invoice'),
                    ),
                    DropdownMenuItem(
                      value: 'Purchase',
                      child: Text('Purchase Entry'),
                    ),
                  ],
                  onChanged: widget.existingVoucher != null
                      ? null
                      : _onInvoiceTypeChanged,
                ),
              ),
              const SizedBox(width: 16),
              // Invoice Number
              Expanded(
                child: TextFormField(
                  key: ValueKey(_invoiceNumber),
                  initialValue: _invoiceNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Date & Time',
                    suffixIcon: Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    isDense: true,
                  ),
                  controller: TextEditingController(
                    text: DateFormat(
                      'dd-MMM-yyyy hh:mm a',
                    ).format(_invoiceDate),
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
          const SizedBox(height: 12),
          // Payment Mode Selector (Cash vs Debt)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Bill Mode:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ChoiceChip(
                key: const ValueKey('invoice-mode-debt'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.credit_card_rounded,
                  size: 14,
                  color: _paymentMode == 'Debt'
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                label: const Text('Debt / Credit'),
                selected: _paymentMode == 'Debt',
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: _paymentMode == 'Debt'
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _paymentMode = 'Debt');
                },
              ),
              ChoiceChip(
                key: const ValueKey('invoice-mode-cash'),
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  Icons.payments_outlined,
                  size: 14,
                  color: _paymentMode == 'Cash'
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                label: const Text('Cash (Paid)'),
                selected: _paymentMode == 'Cash',
                selectedColor: AppColors.success,
                backgroundColor: AppColors.surfaceSecondary,
                labelStyle: TextStyle(
                  color: _paymentMode == 'Cash'
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _paymentMode = 'Cash');
                },
              ),
              Text(
                _paymentMode == 'Cash'
                    ? '• Cash Bill: Paid immediately; cash debited'
                    : '• Debt Bill: Unpaid credit sale; adds to customer debt',
                style: TextStyle(
                  fontSize: 11,
                  color: _paymentMode == 'Cash'
                      ? AppColors.success
                      : AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Contact Ledger selector (Customers / Suppliers)
              Expanded(
                child: RawAutocomplete<Ledger>(
                  focusNode: _contactSearchFocusNode,
                  textEditingController: _contactSearchController,
                  displayStringForOption: (ledger) => ledger.name,
                  optionsBuilder: (value) {
                    final query = value.text.trim().toLowerCase();
                    final matches = _contactLedgers.where((ledger) {
                      return query.isEmpty ||
                          ledger.name.toLowerCase().contains(query) ||
                          (ledger.phone?.toLowerCase().contains(query) ??
                              false);
                    }).toList();
                    if (query.isNotEmpty) {
                      matches.sort((a, b) {
                        final aStartsWithQuery = a.name
                            .toLowerCase()
                            .startsWith(query);
                        final bStartsWithQuery = b.name
                            .toLowerCase()
                            .startsWith(query);
                        if (aStartsWithQuery != bStartsWithQuery) {
                          return aStartsWithQuery ? -1 : 1;
                        }
                        return a.name.toLowerCase().compareTo(
                          b.name.toLowerCase(),
                        );
                      });
                    }
                    return matches;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return TextField(
                          key: const ValueKey('invoice-contact-search'),
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            labelText: _invoiceType == 'Sales'
                                ? 'Customer / Sundry Debtor'
                                : 'Supplier / Sundry Creditor',
                            hintText: 'Type to search or open the list',
                            suffixIcon: IconButton(
                              key: const ValueKey('invoice-contact-open-list'),
                              tooltip: 'Show all customers and suppliers',
                              icon: const Icon(Icons.arrow_drop_down_rounded),
                              onPressed: () {
                                _selectedLedgerId = null;
                                _contactSearchController.clear();
                                _contactSearchFocusNode.requestFocus();
                              },
                            ),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            if (_selectedLedgerId != null &&
                                !_contactLedgers.any(
                                  (ledger) =>
                                      ledger.id == _selectedLedgerId &&
                                      ledger.name == value,
                                )) {
                              _selectedLedgerId = null;
                            }
                          },
                          onSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 6,
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          constraints: const BoxConstraints(
                            maxWidth: 480,
                            maxHeight: 280,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) => const Divider(
                              color: AppColors.border,
                              height: 1,
                            ),
                            itemBuilder: (context, index) {
                              final ledger = options.elementAt(index);
                              return Material(
                                color: AppColors.surface,
                                child: ListTile(
                                  dense: true,
                                  hoverColor: AppColors.surfaceSecondary,
                                  title: Text(
                                    ledger.name +
                                        (ledger.isDeleted
                                            ? ' (Deactivated)'
                                            : ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: ledger.isDeleted
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  subtitle: ledger.phone?.isNotEmpty == true
                                      ? Text(
                                          ledger.phone!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  onTap: () => onSelected(ledger),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  onSelected: (ledger) =>
                      setState(() => _selectedLedgerId = ledger.id),
                ),
              ),
              const SizedBox(width: 16),
              // Reference Number
              Expanded(
                child: TextFormField(
                  initialValue: _referenceNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 920
            ? 920.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      'Stock Item Description & Stock',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'Type',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Quantity',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Rate (Rs.)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Total (Rs.)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceRow(int index) {
    final row = _rows[index];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth < 920
            ? 920.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: row.isReplacement
                    ? AppColors.warningBg.withOpacity(0.3)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: row.isReplacement
                      ? AppColors.warning.withOpacity(0.5)
                      : AppColors.border,
                ),
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
                              (item.sku != null &&
                                  item.sku!.toLowerCase().contains(query));
                        });
                      },
                      displayStringForOption: (StockItem option) => option.name,
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            if (controller.text.isEmpty && row.item != null) {
                              controller.text = row.item!.name;
                            }
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Type item name or SKU...',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
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
                              constraints: const BoxConstraints(
                                maxWidth: 480,
                                maxHeight: 280,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                      color: AppColors.border,
                                      height: 1,
                                    ),
                                itemBuilder: (BuildContext context, int index) {
                                  final option = options.elementAt(index);
                                  final stockQty = _getStockQuantity(option.id);
                                  final stdRate = _invoiceType == 'Sales'
                                      ? option.salesRate
                                      : option.purchaseRate;

                                  return ListTile(
                                    dense: true,
                                    hoverColor: AppColors.surfaceSecondary,
                                    title: Text(
                                      option.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Std Rate: ${_currencyFormat.format(stdRate)}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: stockQty <= 0
                                            ? AppColors.errorBg
                                            : AppColors.successBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Stock: ${stockQty.toStringAsFixed(0)} ${option.unitOfMeasure}',
                                        style: TextStyle(
                                          color: stockQty <= 0
                                              ? AppColors.error
                                              : AppColors.success,
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
                          row.originalRate = _invoiceType == 'Sales'
                              ? selection.salesRate
                              : selection.purchaseRate;
                          if (row.isReplacement) {
                            row.rate = 0.0;
                            row.rateController.text = '0.00';
                          } else {
                            row.rate = row.originalRate;
                            row.rateController.text = row.rate > 0
                                ? row.rate.toString()
                                : '';
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
                    width: 130,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        setState(() {
                          row.toggleReplacement(!row.isReplacement);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: row.isReplacement
                              ? AppColors.warningBg
                              : AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: row.isReplacement
                                ? AppColors.warning
                                : AppColors.border,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                row.isReplacement
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                size: 14,
                                color: row.isReplacement
                                    ? AppColors.warning
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                row.isReplacement
                                    ? 'Replace (Rs. 0)'
                                    : 'Standard',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: row.isReplacement
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
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
                          if (event.logicalKey ==
                              LogicalKeyboardKey.backspace) {
                            if (!row.isEditingQty) {
                              row.itemFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          } else if (event.logicalKey ==
                                  LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter) {
                            return KeyEventResult.ignored;
                          } else {
                            if (event.character != null &&
                                event.character!.isNotEmpty) {
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
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
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
                          if (event.logicalKey ==
                              LogicalKeyboardKey.backspace) {
                            if (!row.isEditingRate) {
                              row.qtyFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            }
                          } else if (event.logicalKey ==
                                  LogicalKeyboardKey.enter ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.numpadEnter) {
                            return KeyEventResult.ignored;
                          } else {
                            if (event.character != null &&
                                event.character!.isNotEmpty) {
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
                        key: ValueKey(
                          'rate-${index}-${row.item?.id}-${row.isReplacement}',
                        ),
                        controller: row.rateController,
                        focusNode: row.rateFocusNode,
                        readOnly: row.isReplacement,
                        style: TextStyle(
                          color: row.isReplacement
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: row.isReplacement
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          fillColor: row.isReplacement
                              ? AppColors.surfaceSecondary
                              : AppColors.surface,
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
                        color: row.isReplacement
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),

                  // Delete button
                  SizedBox(
                    width: 40,
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
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
            ),
          ),
        );
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final footerWidth = constraints.maxWidth < 840
            ? 840.0
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: footerWidth,
            child: Container(
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Narration / Remarks / Notes',
                            hintText:
                                'Enter any payment terms or notes for the invoice...',
                          ),
                          onChanged: (val) => _narration = val,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Paper Size:',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceSecondary,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<PrinterPaperSize>(
                                    isExpanded: true,
                                    value: _selectedPaperSize,
                                    dropdownColor: AppColors.surface,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: PrinterPaperSize.a4,
                                        child: Text('A4 Standard Print / PDF'),
                                      ),
                                      DropdownMenuItem(
                                        value: PrinterPaperSize.thermal58mm,
                                        child: Text(
                                          '58mm Thermal Receipt (POS)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: PrinterPaperSize.thermal80mm,
                                        child: Text(
                                          '80mm Thermal Receipt (POS)',
                                        ),
                                      ),
                                    ],
                                    onChanged: _isSubmitting
                                        ? null
                                        : (val) {
                                            if (val != null)
                                              setState(
                                                () => _selectedPaperSize = val,
                                              );
                                          },
                                  ),
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
                        _buildSummaryRow(
                          'Total Pcs',
                          _totalPairs,
                          isCurrency: false,
                        ),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Subtotal', _subtotal),
                        const SizedBox(height: 8),

                        // Discount field
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Bill Discount (Rs.):',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 120,
                              height: 32,
                              child: TextFormField(
                                controller: _discountController,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _discountAmount =
                                        double.tryParse(val) ?? 0.0;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),

                        if (_discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _buildSummaryRow(
                            'Taxable Amount',
                            _taxableAmount,
                            valueColor: AppColors.primary,
                          ),
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
                        _buildSummaryRow(
                          'Grand Total',
                          _grandTotal,
                          isBold: true,
                          valueColor: AppColors.success,
                        ),
                        const SizedBox(height: 16),

                        // Action buttons
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.borderStrong,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.preview_rounded, size: 16),
                              label: const Text(
                                'Preview',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isSubmitting ? null : _previewInvoice,
                            ),
                            if (widget.existingVoucher != null) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.delete_forever_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'Delete $_invoiceType',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _deleteBill,
                              ),
                            ],
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.surfaceSecondary,
                                foregroundColor: AppColors.textPrimary,
                                elevation: 0,
                                side: const BorderSide(
                                  color: AppColors.borderStrong,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined, size: 16),
                              label: const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitInvoice(andPrint: false),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.print_rounded, size: 16),
                              label: const Text(
                                'Save & Print',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _submitInvoice(andPrint: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isCurrency = true,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          isCurrency
              ? _currencyFormat.format(amount)
              : _quantityFormat.format(amount),
          style: TextStyle(
            color:
                valueColor ??
                (isBold ? AppColors.textPrimary : AppColors.textSecondary),
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
