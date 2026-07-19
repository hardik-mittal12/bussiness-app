import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../core/invoice_printer.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class InvoiceRowItem {
  StockItem? item;
  double quantity;
  double rate;
  double originalRate; // To detect price overrides

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
  }) {
    qtyController = TextEditingController(text: quantity > 0 ? quantity.toString() : '');
    rateController = TextEditingController(text: rate > 0 ? rate.toString() : '');

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

  double get total => quantity * rate;

  void dispose() {
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

  List<InvoiceRowItem> _rows = [];
  List<Ledger> _contactLedgers = []; // Customers/Suppliers loaded dynamically
  List<StockItem> _allItems = [];
  List<StockStatus> _allStockStatus = [];

  final double _taxRatePercent = 0.0; // 0% GST (disabled)
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  bool _isDataLoaded = false;

  @override
  void dispose() {
    _narrationFocusNode.dispose();
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

        // Load contact ledgers
        final targetGroup = _invoiceType == 'Sales' ? 'debtors' : 'creditors';
        final contactLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals(targetGroup))).get();
        
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
            quantity: st.tx.quantity.abs(), // positive for quantity field display
            rate: st.tx.rate,
            originalRate: _invoiceType == 'Sales' ? matchingItem.salesRate : matchingItem.purchaseRate,
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
    final contactLedgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals(targetGroup))).get();
    
    final allItems = await db.select(db.stockItems).get();
    final stockStatus = await engine.getStockSummary();

    // Auto-generate invoice number
    final vouchersList = await db.select(db.vouchers).get();
    final count = vouchersList.where((v) => v.voucherType == _invoiceType).length + 1;
    final prefix = _invoiceType == 'Sales' ? 'INV' : 'PUR';
    final invNo = '$prefix-${DateTime.now().year}-${count.toString().padLeft(4, '0')}';

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

  double get _cgst {
    return _subtotal * (_taxRatePercent / 2) / 100;
  }

  double get _sgst {
    return _subtotal * (_taxRatePercent / 2) / 100;
  }

  double get _grandTotal {
    return _subtotal + _cgst + _sgst;
  }

  // Find stock quantity left for an item
  double _getStockQuantity(String itemId) {
    final match = _allStockStatus.where((status) => status.id == itemId);
    if (match.isNotEmpty) {
      return match.first.quantity;
    }
    return 0.0;
  }

  // Handle saving the voucher
  Future<void> _submitInvoice({bool andPrint = false}) async {
    if (_selectedLedgerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Customer or Supplier ledger.')),
      );
      return;
    }

    if (_rows.any((row) => row.item == null || row.quantity <= 0 || row.rate <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all item rows with valid items, quantities, and rates.')),
      );
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    // 1. Detect if any rate is overridden (Sales price change logic)
    List<StockItem> itemsToUpdate = [];
    for (final row in _rows) {
      if (row.rate != row.originalRate) {
        itemsToUpdate.add(row.item!);
      }
    }

    // 2. If price changed, prompt user for confirmation to update default catalog price
    bool confirmedPriceUpdates = false;
    if (itemsToUpdate.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E2235),
            title: const Text('Price Overrides Detected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text(
              'You have modified standard prices for ${itemsToUpdate.length} item(s).\n\nDo you want to update their default catalog rates in inventory for future invoices?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                child: const Text('Keep Old Rates', style: TextStyle(color: Colors.white54)),
                onPressed: () => Navigator.pop(context, false),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                child: const Text('Update Rates', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        },
      );
      confirmedPriceUpdates = confirm ?? false;
    }

    // 3. Process database updates for overridden rates
    if (confirmedPriceUpdates) {
      for (final row in _rows) {
        if (row.rate != row.originalRate) {
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

    // 4. Formulate Double-Entry ledger postings
    final subtotal = _subtotal;
    final cgst = _cgst;
    final sgst = _sgst;
    final grandTotal = _grandTotal;

    List<VoucherEntriesCompanion> entries = [];
    
    if (_invoiceType == 'Sales') {
      // Sales Double Entry:
      // Debit: Customer Ledger (Grand Total)
      // Credit: Sales Ledger (Subtotal)
      // Credit: CGST Ledger (CGST)
      // Credit: SGST Ledger (SGST)
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '', // Set by engine transaction
        ledgerId: _selectedLedgerId!,
        debitAmount: drift.Value(grandTotal),
        creditAmount: const drift.Value(0.0),
      ));
      
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'sales',
        debitAmount: const drift.Value(0.0),
        creditAmount: drift.Value(subtotal),
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
      // Purchase Double Entry:
      // Debit: Purchase Ledger (Subtotal)
      // Debit: CGST Ledger (CGST)
      // Debit: SGST Ledger (SGST)
      // Credit: Supplier Ledger (Grand Total)
      entries.add(VoucherEntriesCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        ledgerId: 'purchase',
        debitAmount: drift.Value(subtotal),
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

    // 5. Formulate Stock transactions (Inventory adjustments)
    List<StockTransactionsCompanion> stockTxs = [];
    for (final row in _rows) {
      stockTxs.add(StockTransactionsCompanion.insert(
        id: uuid.v4(),
        voucherId: '',
        stockItemId: row.item!.id,
        quantity: row.quantity, // quantity is positive
        rate: row.rate,
        transactionType: _invoiceType == 'Sales' ? 'OUT' : 'IN',
      ));
    }

    try {
      // Create voucher using engine
      await engine.createVoucher(
        voucherNumber: _invoiceNumber,
        voucherType: _invoiceType,
        date: _invoiceDate,
        narration: _narration,
        referenceNumber: _referenceNumber,
        entries: entries,
        stockTransactions: stockTxs,
        existingVoucherId: widget.existingVoucher?.id,
      );

      if (mounted) {
        if (andPrint) {
          final contact = _contactLedgers.firstWhere((l) => l.id == _selectedLedgerId);
          final oldInvoiceNumber = _invoiceNumber;
          final oldInvoiceType = _invoiceType;
          final oldInvoiceDate = _invoiceDate;
          final oldRows = List<InvoiceRowItem>.from(_rows);
          final oldSubtotal = subtotal;
          final oldCgst = cgst;
          final oldSgst = sgst;
          final oldGrandTotal = grandTotal;
          final oldNarration = _narration;
          
          await InvoicePrinter.printInvoice(
            context: context,
            voucherNumber: oldInvoiceNumber,
            voucherType: oldInvoiceType,
            date: oldInvoiceDate,
            contact: contact,
            rows: oldRows,
            subtotal: oldSubtotal,
            cgst: oldCgst,
            sgst: oldSgst,
            grandTotal: oldGrandTotal,
            narration: oldNarration,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$_invoiceType Invoice $_invoiceNumber saved successfully!')),
        );
        if (widget.existingVoucher != null) {
          Navigator.pop(context);
        } else {
          setState(() {
            _rows = [InvoiceRowItem()];
            _selectedLedgerId = null;
            _narration = '';
            _referenceNumber = '';
          });
          _loadInitialData();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save invoice: $e')),
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
          'New $_invoiceType Bill / Invoice',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Details Card
              _buildHeaderCard(),
              const SizedBox(height: 20),

              // Invoice Rows Header
              _buildRowsHeader(),
              const SizedBox(height: 8),

              // Invoice Rows List
              Expanded(
                child: ListView.builder(
                  itemCount: _rows.length,
                  itemBuilder: (context, index) => _buildInvoiceRow(index),
                ),
              ),

              const SizedBox(height: 12),

              // Add row button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.05),
                  foregroundColor: Colors.indigoAccent,
                  elevation: 0,
                  side: const BorderSide(color: Colors.indigoAccent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Line Item'),
                onPressed: () {
                  setState(() {
                    _rows.add(InvoiceRowItem());
                  });
                },
              ),

              const SizedBox(height: 20),

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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Invoice Type Selection
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _invoiceType,
                  dropdownColor: const Color(0xFF1E2235),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Voucher Type',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Sales', child: Text('Sales Invoice')),
                    DropdownMenuItem(value: 'Purchase', child: Text('Purchase Entry')),
                  ],
                  onChanged: widget.existingVoucher != null ? null : _onInvoiceTypeChanged,
                ),
              ),
              const SizedBox(width: 24),
              // Invoice Number
              Expanded(
                child: TextFormField(
                  key: ValueKey(_invoiceNumber),
                  initialValue: _invoiceNumber,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Voucher / Invoice No.',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  onChanged: (val) => _invoiceNumber = val,
                ),
              ),
              const SizedBox(width: 24),
              // Date picker field
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  controller: TextEditingController(
                    text: DateFormat('dd-MMM-yyyy hh:mm a').format(_invoiceDate),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _invoiceDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
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
          const SizedBox(height: 16),
          Row(
            children: [
              // Contact Ledger selector (Customers / Suppliers)
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedLedgerId,
                  dropdownColor: const Color(0xFF1E2235),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: _invoiceType == 'Sales' ? 'Customer / Sundry Debtor' : 'Supplier / Sundry Creditor',
                    labelStyle: const TextStyle(color: Colors.white70),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  ),
                  items: _contactLedgers.map((l) {
                    return DropdownMenuItem(
                      value: l.id,
                      child: Text(l.name),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLedgerId = val),
                ),
              ),
              const SizedBox(width: 24),
              // Reference Number
              Expanded(
                child: TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Reference Number / LPO No.',
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
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
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(flex: 5, child: Text('Stock Item Description (Matches Name & Shows Qty)', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Quantity', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Rate', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Total Amount', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(int index) {
    final row = _rows[index];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235).withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.02)),
      ),
      child: Row(
        children: [
          // 1. Fuzzy Autocomplete Search Field
          Expanded(
            flex: 5,
            child: RawAutocomplete<StockItem>(
              focusNode: row.itemFocusNode,
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _allItems;
                }
                // Spell matching / Substring search
                return _allItems.where((item) {
                  return item.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                      (item.sku != null && item.sku!.toLowerCase().contains(textEditingValue.text.toLowerCase()));
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Type item name...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
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
                    elevation: 4.0,
                    color: const Color(0xFF1E2235),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450, maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final option = options.elementAt(index);
                          final stockQty = _getStockQuantity(option.id);
                          final stdRate = _invoiceType == 'Sales' ? option.salesRate : option.purchaseRate;

                          return ListTile(
                            dense: true,
                            hoverColor: Colors.white.withOpacity(0.05),
                            title: Text(option.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('Std Rate: ${_currencyFormat.format(stdRate)}', style: const TextStyle(color: Colors.white54)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: stockQty <= 0 ? Colors.redAccent.withOpacity(0.1) : Colors.greenAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Stock: ${stockQty.toStringAsFixed(0)} ${option.unitOfMeasure}',
                                style: TextStyle(
                                  color: stockQty <= 0 ? Colors.redAccent : Colors.greenAccent,
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
                  row.rate = _invoiceType == 'Sales' ? selection.salesRate : selection.purchaseRate;
                  row.originalRate = row.rate;
                  row.rateController.text = row.rate > 0 ? row.rate.toString() : '';
                  row.quantity = 0.0;
                  row.qtyController.text = '';
                });
                row.qtyFocusNode.requestFocus();
              },
            ),
          ),
          
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
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
                onChanged: (val) {
                  setState(() {
                    row.quantity = double.tryParse(val) ?? 0.0;
                  });
                },
                onFieldSubmitted: (val) {
                  row.rateFocusNode.requestFocus();
                },
              ),
            ),
          ),

          // 3. Rate field
          Expanded(
            flex: 2,
            child: Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
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
                key: ValueKey('rate-${index}-${row.item?.id}'),
                controller: row.rateController,
                focusNode: row.rateFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(border: InputBorder.none, hintText: '0.00'),
                onChanged: (val) {
                  setState(() {
                    row.rate = double.tryParse(val) ?? 0.0;
                  });
                },
                onFieldSubmitted: (val) {
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
                },
              ),
            ),
          ),

          // 4. Total Display
          Expanded(
            flex: 2,
            child: Text(
              _currencyFormat.format(row.total),
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // Delete button
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
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

  Widget _buildFooterCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: Narration
          Expanded(
            flex: 3,
            child: TextFormField(
              focusNode: _narrationFocusNode,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Narration / Remarks',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.indigoAccent)),
              ),
              onChanged: (val) => _narration = val,
            ),
          ),
          
          const SizedBox(width: 32),

          // Right column: Calculations summary
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _buildSummaryRow('Subtotal', _subtotal),
                if (_cgst > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('CGST (9%)', _cgst),
                ],
                if (_sgst > 0) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow('SGST (9%)', _sgst),
                ],
                const Divider(color: Colors.white10, height: 16),
                _buildSummaryRow('Grand Total', _grandTotal, isBold: true, valueColor: Colors.greenAccent),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save Bill', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _submitInvoice(andPrint: false),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Save & Print Invoice', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _submitInvoice(andPrint: true),
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
            color: isBold ? Colors.white : Colors.white70,
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: valueColor ?? (isBold ? Colors.white : Colors.white70),
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
