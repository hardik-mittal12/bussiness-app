import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../core/data_exchange_service.dart';
import '../data/database.dart';
import 'theme/app_theme.dart';

class DataExchangePage extends StatefulWidget {
  const DataExchangePage({super.key});

  @override
  State<DataExchangePage> createState() => _DataExchangePageState();
}

class _DataExchangePageState extends State<DataExchangePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Export states
  String _exportFormat = 'csv'; // 'csv', 'tsv', 'xlsx', 'xml', 'tallybak'
  String _exportTarget = 'bills'; // 'bills', 'payments', 'customers', 'stock', 'all'
  ExportDateRange _selectedDateRange = ExportDateRange.allTime;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  bool _isExporting = false;
  String? _exportSuccessPath;

  // Import states
  String _importType = 'csv'; // 'csv' or 'xml'
  String? _selectedImportFilePath;
  CsvImportPreview? _csvPreview;
  String _csvTargetType = 'customers'; // 'customers' or 'stock'
  DuplicateHandling _duplicateHandling = DuplicateHandling.skip;
  bool _isImporting = false;
  ImportResult? _importResult;
  String? _importErrorMessage;

  final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleExport() async {
    setState(() {
      _isExporting = true;
      _exportSuccessPath = null;
    });

    final db = Provider.of<AppDatabase>(context, listen: false);
    final service = DataExchangeService(db);

    try {
      final nowStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String fileName = 'export_$nowStr';
      Uint8List? fileBytes;
      String? fileContent;

      if (_exportFormat == 'csv' || _exportFormat == 'tsv') {
        final delimiter = _exportFormat == 'tsv' ? '\t' : ',';
        final ext = _exportFormat == 'tsv' ? 'tsv' : 'csv';

        if (_exportTarget == 'customers') {
          fileContent = await service.exportCustomersCsv(delimiter: delimiter);
          fileName = 'customers_$nowStr.$ext';
        } else if (_exportTarget == 'stock') {
          fileContent = await service.exportProductsCsv(delimiter: delimiter);
          fileName = 'stock_items_$nowStr.$ext';
        } else if (_exportTarget == 'payments') {
          fileContent = await service.exportPaymentsReceiptsCsv(
            range: _selectedDateRange,
            customStart: _customStartDate,
            customEnd: _customEndDate,
            delimiter: delimiter,
          );
          fileName = 'payments_receipts_$nowStr.$ext';
        } else {
          fileContent = await service.exportBillsCsv(
            range: _selectedDateRange,
            customStart: _customStartDate,
            customEnd: _customEndDate,
            delimiter: delimiter,
          );
          fileName = 'bills_invoices_$nowStr.$ext';
        }
      } else if (_exportFormat == 'xlsx') {
        fileBytes = await service.exportExcelWorkbook(
          range: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        );
        fileName = 'business_report_$nowStr.xlsx';
      } else if (_exportFormat == 'xml') {
        fileContent = await service.exportTallyXml(
          range: _selectedDateRange,
          customStart: _customStartDate,
          customEnd: _customEndDate,
        );
        fileName = 'tally_export_$nowStr.xml';
      } else if (_exportFormat == 'tallybak') {
        fileBytes = await service.createFullApplicationBackup();
        fileName = 'tally_full_backup_$nowStr.tallybak';
      }

      // Save file
      final bytesToSave = fileBytes ?? Uint8List.fromList(utf8.encode(fileContent!));
      String? savePath;
      try {
        final uri = await FilePicker.saveFile(
          dialogTitle: 'Save Export File',
          fileName: fileName,
          bytes: bytesToSave,
        );
        savePath = uri?.toFilePath();
      } catch (_) {}

      if (savePath == null) {
        // Fallback to exports folder
        final exportDir = Directory('${Directory.current.path}/exports');
        if (!await exportDir.exists()) await exportDir.create(recursive: true);
        savePath = '${exportDir.path}/$fileName';
        final file = File(savePath);
        await file.writeAsBytes(bytesToSave);
      }

      if (mounted) {
        setState(() {
          _exportSuccessPath = savePath;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.success, content: Text('Exported successfully to: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Export error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _pickImportFile() async {
    try {
      final allowed = _importType == 'xml'
          ? ['xml']
          : (_importType == 'tallybak' ? ['tallybak'] : ['csv', 'tsv', 'txt']);

      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowed,
      );

      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
        setState(() {
          _selectedImportFilePath = path;
          _csvPreview = null;
          _importResult = null;
          _importErrorMessage = null;
        });

        if (_importType == 'csv') {
          final db = Provider.of<AppDatabase>(context, listen: false);
          final service = DataExchangeService(db);
          final preview = await service.previewCsvImport(filePath: path);
          setState(() {
            _csvPreview = preview;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('File selection error: $e')),
        );
      }
    }
  }

  Future<void> _executeImport() async {
    if (_selectedImportFilePath == null) return;

    setState(() {
      _isImporting = true;
      _importResult = null;
      _importErrorMessage = null;
    });

    final db = Provider.of<AppDatabase>(context, listen: false);
    final service = DataExchangeService(db);

    try {
      if (_importType == 'xml') {
        final content = await File(_selectedImportFilePath!).readAsString();
        final res = await service.importTallyXml(content);
        setState(() => _importResult = res);
      } else if (_importType == 'tallybak') {
        final bytes = await File(_selectedImportFilePath!).readAsBytes();
        final success = await service.restoreFullApplicationBackup(bytes);
        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(backgroundColor: AppColors.success, content: Text('Full database backup restored successfully!')),
            );
          }
        }
      } else {
        // CSV Import
        Map<String, String> colMap = {};
        if (_csvPreview != null) {
          for (final h in _csvPreview!.headers) {
            colMap[h.toLowerCase().trim()] = h;
          }
        }

        final res = await service.executeCsvImport(
          filePath: _selectedImportFilePath!,
          targetType: _csvTargetType,
          columnMapping: colMap,
          duplicateHandling: _duplicateHandling,
          delimiter: _csvPreview?.delimiter ?? ',',
        );
        setState(() => _importResult = res);
      }

      if (mounted && _importResult != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text('Import finished: ${_importResult!.createdCount} created, ${_importResult!.updatedCount} updated, ${_importResult!.skippedCount} skipped.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _importErrorMessage = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Data Import & Export Center', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.file_download_outlined), text: 'Export Data'),
            Tab(icon: Icon(Icons.file_upload_outlined), text: 'Import CSV / Tally XML'),
            Tab(icon: Icon(Icons.settings_backup_restore_rounded), text: 'Full Backup & Restore'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(),
          _buildImportTab(),
          _buildBackupRestoreTab(),
        ],
      ),
    );
  }

  Widget _buildExportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Export Financial & Inventory Data', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Export your transactions, ledgers, and inventory in various standard formats.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Format Selection
              const Text('1. Select File Format:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _formatChoiceChip('csv', 'Comma-Separated (CSV)', Icons.table_chart_outlined),
                  _formatChoiceChip('tsv', 'ASCII Tab-Delimited (TSV)', Icons.text_snippet_outlined),
                  _formatChoiceChip('xlsx', 'Microsoft Excel (.xlsx)', Icons.grid_on_outlined),
                  _formatChoiceChip('xml', 'Tally XML (<ENVELOPE>)', Icons.code_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Data Target Selection
              const Text('2. Select Dataset to Export:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _exportTarget,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 'bills', child: Text('Bills & Invoices (Sales & Purchases)')),
                  DropdownMenuItem(value: 'payments', child: Text('Payments & Receipts')),
                  DropdownMenuItem(value: 'customers', child: Text('Customer Masters (Ledgers & Balances)')),
                  DropdownMenuItem(value: 'stock', child: Text('Stock Items & Inventory Valuation')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _exportTarget = val);
                },
              ),
              const SizedBox(height: 20),

              // Date Range Filter
              const Text('3. Date Range Filter:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<ExportDateRange>(
                      value: _selectedDateRange,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      decoration: const InputDecoration(isDense: true),
                      items: const [
                        DropdownMenuItem(value: ExportDateRange.allTime, child: Text('All Time (Entire History)')),
                        DropdownMenuItem(value: ExportDateRange.today, child: Text('Today')),
                        DropdownMenuItem(value: ExportDateRange.thisWeek, child: Text('This Week')),
                        DropdownMenuItem(value: ExportDateRange.thisMonth, child: Text('This Month')),
                        DropdownMenuItem(value: ExportDateRange.thisYear, child: Text('Current Financial Year')),
                        DropdownMenuItem(value: ExportDateRange.custom, child: Text('Custom Date Range...')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedDateRange = val);
                      },
                    ),
                  ),
                  if (_selectedDateRange == ExportDateRange.custom) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surfaceSecondary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.borderStrong),
                      ),
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text(
                        _customStartDate != null && _customEndDate != null
                            ? '${_dateFormat.format(_customStartDate!)} - ${_dateFormat.format(_customEndDate!)}'
                            : 'Pick Range',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () async {
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                          initialDateRange: _customStartDate != null && _customEndDate != null
                              ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
                              : null,
                        );
                        if (range != null) {
                          setState(() {
                            _customStartDate = range.start;
                            _customEndDate = range.end;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 28),

              // Export Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isExporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_download_rounded, size: 18),
                  label: Text(_isExporting ? 'Exporting Data...' : 'Export & Save File', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: _isExporting ? null : _handleExport,
                ),
              ),

              if (_exportSuccessPath != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('File saved to: $_exportSuccessPath', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _formatChoiceChip(String key, String label, IconData icon) {
    final isSelected = _exportFormat == key;
    return ChoiceChip(
      selected: isSelected,
      selectedColor: AppColors.primaryBackground,
      backgroundColor: AppColors.surfaceSecondary,
      side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
      avatar: Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
      label: Text(label, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textSecondary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 12)),
      onSelected: (val) {
        if (val) setState(() => _exportFormat = key);
      },
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Import Masters & Records', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Safely import customers, stock items, or Tally XML data with duplicate protection.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),

              // Import Type Selection
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('CSV / TSV Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: 'csv',
                      groupValue: _importType,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() {
                        _importType = val!;
                        _selectedImportFilePath = null;
                        _csvPreview = null;
                      }),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Tally XML Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      value: 'xml',
                      groupValue: _importType,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setState(() {
                        _importType = val!;
                        _selectedImportFilePath = null;
                        _csvPreview = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_importType == 'csv') ...[
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _csvTargetType,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Import Target', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'customers', child: Text('Customer Masters (Ledgers)')),
                          DropdownMenuItem(value: 'stock', child: Text('Inventory Items (Products)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _csvTargetType = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<DuplicateHandling>(
                        value: _duplicateHandling,
                        dropdownColor: AppColors.surface,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: const InputDecoration(labelText: 'Duplicate Handling', isDense: true),
                        items: const [
                          DropdownMenuItem(value: DuplicateHandling.skip, child: Text('Skip Existing Records')),
                          DropdownMenuItem(value: DuplicateHandling.update, child: Text('Update / Overwrite Existing')),
                          DropdownMenuItem(value: DuplicateHandling.createWithSuffix, child: Text('Append Suffix (e.g. -1)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _duplicateHandling = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Pick File
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _selectedImportFilePath ?? 'No file selected. Click Choose File to proceed.',
                        style: TextStyle(
                          color: _selectedImportFilePath != null ? AppColors.textPrimary : AppColors.textMuted,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceSecondary,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.borderStrong),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('Choose File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: _pickImportFile,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // CSV Preview Table
              if (_csvPreview != null) ...[
                Text('File Preview (${_csvPreview!.totalRows} rows found):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 28,
                        dataRowMaxHeight: 32,
                        columns: _csvPreview!.headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)))).toList(),
                        rows: _csvPreview!.previewRows.map((r) => DataRow(
                          cells: r.map((c) => DataCell(Text(c.toString(), style: const TextStyle(fontSize: 11)))).toList(),
                        )).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Execute Import Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isImporting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.file_upload_rounded, size: 18),
                  label: Text(_isImporting ? 'Importing Data...' : 'Execute Import', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  onPressed: (_isImporting || _selectedImportFilePath == null) ? null : _executeImport,
                ),
              ),

              if (_importResult != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Import Summary:', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('• Created: ${_importResult!.createdCount} records', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                      Text('• Updated: ${_importResult!.updatedCount} records', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                      Text('• Skipped: ${_importResult!.skippedCount} records', style: const TextStyle(color: AppColors.success, fontSize: 12)),
                      if (_importResult!.failedCount > 0)
                        Text('• Failed: ${_importResult!.failedCount} records', style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],

              if (_importErrorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Text('Error: $_importErrorMessage', style: const TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupRestoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Full Application Backup & Disaster Recovery', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Package the full database, transaction log, configuration, and company branding into a single portable .tallybak archive.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 24),

              // Full Backup Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined, color: AppColors.primary, size: 36),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Full Standalone Backup (.tallybak)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Generates a compressed, tamper-verified archive containing your entire accounting database, company settings, and logo.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export .tallybak', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        setState(() {
                          _exportFormat = 'tallybak';
                        });
                        _handleExport();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Full Restore Section
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.unarchive_outlined, color: AppColors.warning, size: 36),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Restore from Backup Archive (.tallybak)', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 4),
                          Text('Restores database tables, journal logs, and company profile from a previously exported .tallybak file.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: const Text('Restore Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        setState(() {
                          _importType = 'tallybak';
                        });
                        _pickImportFile();
                      },
                    ),
                  ],
                ),
              ),

              if (_selectedImportFilePath != null && _importType == 'tallybak') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Selected Backup File: $_selectedImportFilePath\nClick below to overwrite current database with this backup.', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                        onPressed: _isImporting ? null : _executeImport,
                        child: const Text('Confirm Restore', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
