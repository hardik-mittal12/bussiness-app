import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../core/accounting_engine.dart';
import '../core/pdf_export_service.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'theme/app_theme.dart';

class StockSummaryPage extends StatefulWidget {
  const StockSummaryPage({super.key});

  @override
  State<StockSummaryPage> createState() => _StockSummaryPageState();
}

class _StockSummaryPageState extends State<StockSummaryPage> {
  late Future<List<StockStatus>> _stockSummaryFuture;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
  final Uuid uuid = const Uuid();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refresh();
  }

  void _refresh() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    setState(() {
      _stockSummaryFuture = engine.getStockSummary();
    });
  }

  // Dialog to Add a Stock Item
  void _showAddStockDialog(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    String name = '';
    String sku = '';
    String unit = 'PCS';
    double openingQty = 0.0;
    double openingRate = 0.0;
    double purchaseRate = 0.0;
    double salesRate = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Add Stock Item', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Stock Item Name *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter item name' : null,
                      onSaved: (val) => name = val!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'SKU / Part Number'),
                      onSaved: (val) => sku = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: 'PCS',
                      decoration: const InputDecoration(labelText: 'Unit of Measure (PCS, KGS, etc.)'),
                      onSaved: (val) => unit = val?.trim() ?? 'PCS',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Opening Quantity'),
                            onSaved: (val) => openingQty = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Opening Rate (₹)'),
                            onSaved: (val) => openingRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Purchase Rate (₹)'),
                            onSaved: (val) => purchaseRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Sales Rate (₹)'),
                            onSaved: (val) => salesRate = double.tryParse(val ?? '0') ?? 0.0,
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
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Save Item'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();
                  try {
                    await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                          id: uuid.v4(),
                          name: name,
                          sku: drift.Value(sku.isNotEmpty ? sku : null),
                          unitOfMeasure: drift.Value(unit.isNotEmpty ? unit : 'PCS'),
                          openingQuantity: drift.Value(openingQty),
                          openingRate: drift.Value(openingRate),
                          purchaseRate: drift.Value(purchaseRate),
                          salesRate: drift.Value(salesRate),
                        ));
                    if (context.mounted) {
                      Navigator.pop(context);
                      _refresh();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stock item added successfully')),
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
            ),
          ],
        );
      },
    );
  }

  void _showEditStockDialog(BuildContext context, String itemId) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    final formKey = GlobalKey<FormState>();

    final item = await (db.select(db.stockItems)..where((t) => t.id.equals(itemId))).getSingle();

    String name = item.name;
    String sku = item.sku ?? '';
    String unit = item.unitOfMeasure;
    double openingQty = item.openingQuantity;
    double openingRate = item.openingRate;
    double purchaseRate = item.purchaseRate;
    double salesRate = item.salesRate;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Edit Stock Item', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Stock Item Name *'),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter item name' : null,
                      onSaved: (val) => name = val!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: sku,
                      decoration: const InputDecoration(labelText: 'SKU / Part Number'),
                      onSaved: (val) => sku = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: unit,
                      decoration: const InputDecoration(labelText: 'Unit of Measure'),
                      onSaved: (val) => unit = val?.trim() ?? 'PCS',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: openingQty.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Opening Qty'),
                            onSaved: (val) => openingQty = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: openingRate.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Opening Rate (₹)'),
                            onSaved: (val) => openingRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: purchaseRate.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Purchase Rate (₹)'),
                            onSaved: (val) => purchaseRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: salesRate.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Sales Rate (₹)'),
                            onSaved: (val) => salesRate = double.tryParse(val ?? '0') ?? 0.0,
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
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Save Changes'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();

                  await db.update(db.stockItems).replace(StockItem(
                        id: itemId,
                        name: name,
                        sku: sku.isNotEmpty ? sku : null,
                        unitOfMeasure: unit,
                        openingQuantity: openingQty,
                        openingRate: openingRate,
                        purchaseRate: purchaseRate,
                        salesRate: salesRate,
                        updatedAt: DateTime.now(),
                        isSynced: false,
                      ));

                  if (context.mounted) {
                    Navigator.pop(context);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock item "$name" updated successfully.')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteStockItem(BuildContext context, String itemId, String itemName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete Stock Item?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text('Are you sure you want to delete "$itemName"? This action cannot be undone.', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              child: const Text('Delete Permanently'),
              onPressed: () async {
                final db = Provider.of<AppDatabase>(context, listen: false);
                try {
                  await (db.delete(db.stockItems)..where((t) => t.id.equals(itemId))).go();
                  if (context.mounted) {
                    Navigator.pop(context);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock item "$itemName" deleted successfully.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cannot delete item: It has transactions recorded.')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<AppDatabase>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Inventory & Stock Summary', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: AppColors.error, size: 18),
            label: const Text('Export Valuation PDF'),
            onPressed: () async {
              try {
                final pdfService = PdfExportService(db);
                final bytes = await pdfService.exportInventoryReportPdf();
                await Printing.layoutPdf(
                  onLayout: (format) async => bytes,
                  name: 'Inventory_Valuation_Report.pdf',
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
                }
              }
            },
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _refresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<List<StockStatus>>(
        future: _stockSummaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading inventory: ${snapshot.error}', style: const TextStyle(color: AppColors.error)));
          }

          final summary = snapshot.data ?? [];
          double totalValuation = summary.fold(0.0, (sum, item) => sum + item.totalValue);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Valuation Stat Card & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Stock Valuation (Average Cost)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            _currencyFormat.format(totalValuation),
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      icon: const Icon(Icons.add_box_rounded, size: 18),
                      label: const Text('Add Stock Item'),
                      onPressed: () => _showAddStockDialog(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Item Master Catalog',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondary,
                    border: Border.all(color: AppColors.border),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('Item Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('SKU / Code', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Stock Quantity', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Average Cost', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Total Value', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Center(child: Text('Actions', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

                // Table list
                Expanded(
                  child: summary.isEmpty
                      ? Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                          ),
                          alignment: Alignment.center,
                          child: const Text('No inventory items found. Add items to start catalog.', style: TextStyle(color: AppColors.textMuted)),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            border: Border.all(color: AppColors.border),
                            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8)),
                          ),
                          child: ListView.separated(
                            itemCount: summary.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border),
                            itemBuilder: (context, index) {
                              final item = summary[index];
                              final isLow = item.quantity <= 5;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          if (isLow) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: item.quantity <= 0 ? AppColors.errorBg : AppColors.warningBg,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                item.quantity <= 0 ? 'Out of Stock' : 'Low Stock',
                                                style: TextStyle(
                                                  color: item.quantity <= 0 ? AppColors.error : AppColors.warning,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.id.length > 8 ? item.id.substring(0, 8) : item.id,
                                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.quantity.toStringAsFixed(2),
                                        style: TextStyle(
                                          color: isLow ? AppColors.error : AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currencyFormat.format(item.averageRate),
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        _currencyFormat.format(item.totalValue),
                                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                            tooltip: 'Edit Item',
                                            onPressed: () => _showEditStockDialog(context, item.id),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                                            tooltip: 'Delete Item',
                                            onPressed: () => _confirmDeleteStockItem(context, item.id, item.name),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
}
