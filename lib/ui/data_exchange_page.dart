import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/database.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';

class DataExchangePage extends StatefulWidget {
  const DataExchangePage({super.key});

  @override
  State<DataExchangePage> createState() => _DataExchangePageState();
}

class _DataExchangePageState extends State<DataExchangePage> {
  final Uuid uuid = const Uuid();
  final TextEditingController _importPathController = TextEditingController();
  String _importType = 'Ledgers'; // 'Ledgers' or 'Stock Items'
  String _statusMessage = '';
  Color _statusColor = Colors.white;

  Future<void> _exportData(String type) async {
    final db = Provider.of<AppDatabase>(context, listen: false);
    
    try {
      Directory targetDir;
      if (kIsWeb) {
        final homeDir = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
        targetDir = Directory('$homeDir/Downloads');
      } else {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        targetDir = Directory('$exeDir/exports');
      }
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      String csvData = '';
      String filePath = '';

      if (type == 'Ledgers') {
        final ledgers = await db.select(db.ledgers).get();
        List<List<dynamic>> rows = [
          ['ID', 'Name', 'GroupID', 'OpeningBalance', 'Phone', 'Address', 'TaxNumber']
        ];
        for (final l in ledgers) {
          rows.add([
            l.id,
            l.name,
            l.groupId,
            l.openingBalance,
            l.phone ?? '',
            l.address ?? '',
            l.taxNumber ?? ''
          ]);
        }
        csvData = const ListToCsvConverter().convert(rows);
        filePath = '${targetDir.path}/ledgers_export.csv';
      } else {
        final stock = await db.select(db.stockItems).get();
        List<List<dynamic>> rows = [
          ['ID', 'Name', 'SKU', 'UnitOfMeasure', 'OpeningQuantity', 'OpeningRate', 'PurchaseRate', 'SalesRate']
        ];
        for (final s in stock) {
          rows.add([
            s.id,
            s.name,
            s.sku ?? '',
            s.unitOfMeasure,
            s.openingQuantity,
            s.openingRate,
            s.purchaseRate,
            s.salesRate
          ]);
        }
        csvData = const ListToCsvConverter().convert(rows);
        filePath = '${targetDir.path}/stock_export.csv';
      }

      final file = File(filePath);
      await file.writeAsString(csvData);

      setState(() {
        _statusMessage = 'Exported successfully to: $filePath';
        _statusColor = Colors.greenAccent;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Export failed: $e';
        _statusColor = Colors.redAccent;
      });
    }
  }

  Future<void> _importData() async {
    final path = _importPathController.text.trim();
    if (path.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a valid file path.';
        _statusColor = Colors.orangeAccent;
      });
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      setState(() {
        _statusMessage = 'File does not exist at specified path: $path';
        _statusColor = Colors.redAccent;
      });
      return;
    }

    final db = Provider.of<AppDatabase>(context, listen: false);

    try {
      final input = await file.readAsString();
      final fields = const CsvToListConverter().convert(input);

      if (fields.length <= 1) {
        throw Exception('File is empty or contains only headers.');
      }

      int importCount = 0;
      await db.transaction(() async {
        if (_importType == 'Ledgers') {
          // Headers: ID, Name, GroupID, OpeningBalance, Phone, Address, TaxNumber
          for (int i = 1; i < fields.length; i++) {
            final row = fields[i];
            if (row.length < 3) continue;

            final String name = row[1].toString().trim();
            final String group = row[2].toString().trim();
            
            // Validate name is not empty
            if (name.isEmpty || group.isEmpty) continue;

            final double opBal = row.length > 3 ? (double.tryParse(row[3].toString()) ?? 0.0) : 0.0;
            final String phone = row.length > 4 ? row[4].toString().trim() : '';
            final String addr = row.length > 5 ? row[5].toString().trim() : '';
            final String tax = row.length > 6 ? row[6].toString().trim() : '';

            // Check if ledger already exists by name
            final existing = await (db.select(db.ledgers)..where((t) => t.name.equals(name))).get();
            if (existing.isNotEmpty) continue;

            await db.into(db.ledgers).insert(LedgersCompanion.insert(
              id: uuid.v4(),
              name: name,
              groupId: group,
              openingBalance: drift.Value(opBal),
              phone: drift.Value(phone.isNotEmpty ? phone : null),
              address: drift.Value(addr.isNotEmpty ? addr : null),
              taxNumber: drift.Value(tax.isNotEmpty ? tax : null),
            ));
            importCount++;
          }
        } else {
          // Headers: ID, Name, SKU, UnitOfMeasure, OpeningQuantity, OpeningRate, PurchaseRate, SalesRate
          for (int i = 1; i < fields.length; i++) {
            final row = fields[i];
            if (row.length < 2) continue;

            final String name = row[1].toString().trim();
            if (name.isEmpty) continue;

            final String sku = row.length > 2 ? row[2].toString().trim() : '';
            final String unit = row.length > 3 ? row[3].toString().trim() : 'PCS';
            final double opQty = row.length > 4 ? (double.tryParse(row[4].toString()) ?? 0.0) : 0.0;
            final double opRate = row.length > 5 ? (double.tryParse(row[5].toString()) ?? 0.0) : 0.0;
            final double purRate = row.length > 6 ? (double.tryParse(row[6].toString()) ?? 0.0) : 0.0;
            final double salRate = row.length > 7 ? (double.tryParse(row[7].toString()) ?? 0.0) : 0.0;

            final existing = await (db.select(db.stockItems)..where((t) => t.name.equals(name))).get();
            if (existing.isNotEmpty) continue;

            await db.into(db.stockItems).insert(StockItemsCompanion.insert(
              id: uuid.v4(),
              name: name,
              sku: drift.Value(sku.isNotEmpty ? sku : null),
              unitOfMeasure: drift.Value(unit.isNotEmpty ? unit : 'PCS'),
              openingQuantity: drift.Value(opQty),
              openingRate: drift.Value(opRate),
              purchaseRate: drift.Value(purRate),
              salesRate: drift.Value(salRate),
            ));
            importCount++;
          }
        }
      });

      setState(() {
        _statusMessage = 'Imported $importCount record(s) successfully.';
        _statusColor = Colors.greenAccent;
        _importPathController.clear();
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Import failed: $e';
        _statusColor = Colors.redAccent;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161928),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Data Import & Export Utilities', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary explanation
              const Text(
                'Import and export your chart of accounts (ledgers) and stock items using standard CSV formatting. CSV files are exported directly to your local Downloads folder.',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),

              if (_statusMessage.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _statusColor == Colors.redAccent ? Icons.error_outline : Icons.check_circle_outline,
                        color: _statusColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: _statusColor, fontWeight: FontWeight.w500, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card 1: Export Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.unarchive_rounded, color: Colors.indigoAccent),
                              SizedBox(width: 8),
                              Text('Export Data (CSV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Save database tables as CSV files in your local Downloads folder. You can open these in Excel or edit them manually.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          
                          // Export Ledger Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent.withOpacity(0.15),
                                foregroundColor: Colors.indigoAccent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Colors.indigoAccent, width: 1),
                                ),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Export Ledgers to CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _exportData('Ledgers'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Export Stock Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purpleAccent.withOpacity(0.15),
                                foregroundColor: Colors.purpleAccent,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: const BorderSide(color: Colors.purpleAccent, width: 1),
                                ),
                              ),
                              icon: const Icon(Icons.download_rounded, size: 18),
                              label: const Text('Export Stock Items to CSV', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () => _exportData('Stock'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Card 2: Import Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2235),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.archive_rounded, color: Colors.greenAccent),
                              SizedBox(width: 8),
                              Text('Import Data (CSV)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Import data from a CSV file. The file columns must match the headers exactly. Duplicate accounts/items are ignored.',
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 24),

                          // Import Type dropdown
                          DropdownButtonFormField<String>(
                            value: _importType,
                            dropdownColor: const Color(0xFF1E2235),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Data Type to Import',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Ledgers', child: Text('Ledger Accounts (Customers / Suppliers)')),
                              DropdownMenuItem(value: 'Stock Items', child: Text('Inventory Catalog (Stock Items)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _importType = val);
                            },
                          ),
                          const SizedBox(height: 16),

                          // Absolute Path Input
                          TextFormField(
                            controller: _importPathController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: const InputDecoration(
                              labelText: 'Absolute CSV File Path',
                              hintText: '/Users/username/Downloads/data.csv',
                              hintStyle: TextStyle(color: Colors.white30),
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.greenAccent)),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Trigger Import Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Execute CSV Import', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: _importData,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
