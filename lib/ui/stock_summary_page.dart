import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../data/database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
          backgroundColor: const Color(0xFF1E2235),
          title: const Text('Add Stock Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Item Name
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Stock Item Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter item name' : null,
                      onSaved: (val) => name = val!.trim(),
                    ),
                    const SizedBox(height: 12),

                    // SKU
                    TextFormField(
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'SKU / Part Number',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onSaved: (val) => sku = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),

                    // Unit of Measure
                    TextFormField(
                      initialValue: 'PCS',
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure (e.g. PCS, KGS, LTRS, BOX)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onSaved: (val) => unit = val?.trim() ?? 'PCS',
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Opening Quantity
                        Expanded(
                          child: TextFormField(
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Qty',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => openingQty = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Opening Rate
                        Expanded(
                          child: TextFormField(
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => openingRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        // Standard Purchase Rate
                        Expanded(
                          child: TextFormField(
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => purchaseRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Standard Sales Rate
                        Expanded(
                          child: TextFormField(
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sales Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              child: const Text('Save Item', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  formKey.currentState!.save();

                  await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                        id: uuid.v4(),
                        name: name,
                        sku: drift.Value(sku.isNotEmpty ? sku : null),
                        unitOfMeasure: drift.Value(unit),
                        openingQuantity: drift.Value(openingQty),
                        openingRate: drift.Value(openingRate),
                        purchaseRate: drift.Value(purchaseRate),
                        salesRate: drift.Value(salesRate),
                        updatedAt: drift.Value(DateTime.now()),
                        isSynced: const drift.Value(false),
                      ));

                  if (context.mounted) {
                    Navigator.pop(context);
                    _refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Stock item "$name" added successfully.')),
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
          backgroundColor: const Color(0xFF1E2235),
          title: const Text('Edit Stock Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: name,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Stock Item Name',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter item name' : null,
                      onSaved: (val) => name = val!.trim(),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: sku,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'SKU / Part Number',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onSaved: (val) => sku = val?.trim() ?? '',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: unit,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Unit of Measure',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      onSaved: (val) => unit = val?.trim() ?? 'PCS',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: openingQty.toString(),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Qty',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => openingQty = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: openingRate.toString(),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Opening Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
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
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Purchase Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            onSaved: (val) => purchaseRate = double.tryParse(val ?? '0') ?? 0.0,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: salesRate.toString(),
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sales Rate',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
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
          backgroundColor: const Color(0xFF1E2235),
          title: const Text('Delete Stock Item?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text('Are you sure you want to delete "$itemName"? This action cannot be undone.', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
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
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Inventory & Stock Summary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _refresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<List<StockStatus>>(
        future: _stockSummaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading inventory: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
          }

          final summary = snapshot.data ?? [];
          double totalValuation = summary.fold(0.0, (sum, item) => sum + item.totalValue);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Valuation Stat Card
                Container(
                  width: 350,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.purpleAccent, Color(0xFF8A2387)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Stock Valuation (Average Cost)', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        _currencyFormat.format(totalValuation),
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  'Item Master Catalog',
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
                      Expanded(flex: 3, child: Text('Item Name', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('SKU / Code', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Stock Quantity', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Average Cost', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text('Total Value', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))),
                      Expanded(flex: 1, child: Center(child: Text('Actions', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)))),
                    ],
                  ),
                ),

                // Table list
                Expanded(
                  child: summary.isEmpty
                      ? Container(
                          width: double.infinity,
                          color: const Color(0xFF1E2235).withOpacity(0.5),
                          alignment: Alignment.center,
                          child: const Text('No inventory items found. Add items to start catalog.', style: TextStyle(color: Colors.white38)),
                        )
                      : ListView.builder(
                          itemCount: summary.length,
                          itemBuilder: (context, index) {
                            final item = summary[index];
                            final isLow = item.quantity <= 5;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? const Color(0xFF1E2235).withOpacity(0.3) : const Color(0xFF1E2235).withOpacity(0.1),
                                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.03))),
                              ),
                              child: Row(
                                children: [
                                  // Name
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  // SKU
                                  Expanded(
                                    flex: 2,
                                    child: FutureBuilder<StockItem>(
                                      future: (Provider.of<AppDatabase>(context, listen: false).select(Provider.of<AppDatabase>(context, listen: false).stockItems)..where((t) => t.id.equals(item.id))).getSingle(),
                                      builder: (context, subSnap) {
                                        final skuCode = subSnap.data?.sku ?? '-';
                                        return Text(
                                          skuCode,
                                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                                        );
                                      }
                                    ),
                                  ),
                                  // Stock Qty
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Text(
                                          item.quantity.toStringAsFixed(2),
                                          style: TextStyle(
                                            color: isLow ? Colors.redAccent : Colors.white70,
                                            fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (isLow) ...[
                                          const SizedBox(width: 6),
                                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                                        ]
                                      ],
                                    ),
                                  ),
                                  // Average Rate
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currencyFormat.format(item.averageRate),
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ),
                                  // Total Value
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _currencyFormat.format(item.totalValue),
                                      style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  // Actions Column
                                  Expanded(
                                    flex: 1,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, color: Colors.blueAccent, size: 16),
                                          onPressed: () => _showEditStockDialog(context, item.id),
                                          tooltip: 'Edit Item',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 16),
                                          onPressed: () => _confirmDeleteStockItem(context, item.id, item.name),
                                          tooltip: 'Delete Item',
                                          constraints: const BoxConstraints(),
                                          padding: EdgeInsets.zero,
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
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigoAccent,
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text('Add Stock Item', style: TextStyle(color: Colors.white)),
        onPressed: () => _showAddStockDialog(context),
      ),
    );
  }
}
