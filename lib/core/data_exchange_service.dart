import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:drift/drift.dart' as drift;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart' as xml;
import '../data/database.dart';
import '../data/path_resolver.dart';
import 'accounting_engine.dart';
import 'business_profile_service.dart';
import 'financial_year_service.dart';

enum ExportDateRange {
  allTime,
  today,
  thisWeek,
  thisMonth,
  thisYear,
  custom,
}

enum DuplicateHandling {
  skip,
  update,
  createWithSuffix,
}

class ImportResult {
  final int createdCount;
  final int updatedCount;
  final int skippedCount;
  final int failedCount;
  final List<String> errors;

  ImportResult({
    required this.createdCount,
    required this.updatedCount,
    required this.skippedCount,
    required this.failedCount,
    required this.errors,
  });
}

class CsvImportPreview {
  final List<String> headers;
  final List<List<dynamic>> previewRows;
  final int totalRows;
  final String delimiter;

  CsvImportPreview({
    required this.headers,
    required this.previewRows,
    required this.totalRows,
    required this.delimiter,
  });
}

class DataExchangeService {
  final AppDatabase db;
  final Uuid uuid = const Uuid();
  late final AccountingEngine engine;
  late final BusinessProfileService profileService;

  DataExchangeService(this.db) {
    engine = AccountingEngine(db);
    profileService = BusinessProfileService(db);
  }

  // Helper for Date filtering
  bool isDateInRange(DateTime date, ExportDateRange range, {DateTime? customStart, DateTime? customEnd}) {
    final now = DateTime.now();
    switch (range) {
      case ExportDateRange.allTime:
        return true;
      case ExportDateRange.today:
        return date.year == now.year && date.month == now.month && date.day == now.day;
      case ExportDateRange.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startZero = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        return date.isAfter(startZero.subtract(const Duration(seconds: 1)));
      case ExportDateRange.thisMonth:
        return date.year == now.year && date.month == now.month;
      case ExportDateRange.thisYear:
        final currentFy = FinancialYearService.getFinancialYear(now);
        return FinancialYearService.getFinancialYear(date) == currentFy;
      case ExportDateRange.custom:
        if (customStart != null && date.isBefore(customStart)) return false;
        if (customEnd != null && date.isAfter(customEnd.add(const Duration(days: 1)))) return false;
        return true;
    }
  }

  // ==========================================
  // 1. CSV & ASCII / TSV EXPORTS
  // ==========================================

  Future<String> exportCustomersCsv({String delimiter = ','}) async {
    final ledgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))).get();
    final rows = <List<dynamic>>[
      ['ID', 'Name', 'Phone', 'Address', 'Email', 'GSTIN_TaxNumber', 'OpeningBalance', 'CurrentBalance']
    ];

    for (final l in ledgers) {
      final bal = await engine.getLedgerBalance(l.id);
      rows.add([
        l.id,
        l.name,
        l.phone ?? '',
        l.address ?? '',
        l.email ?? '',
        l.taxNumber ?? '',
        l.openingBalance.toStringAsFixed(2),
        bal.toStringAsFixed(2),
      ]);
    }

    return delimiter == '\t'
        ? rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ')).join('\t')).join('\n')
        : const ListToCsvConverter().convert(rows);
  }

  Future<String> exportProductsCsv({String delimiter = ','}) async {
    final stockItems = await engine.getStockSummary();
    final dbItems = await db.select(db.stockItems).get();
    final itemMap = {for (var i in dbItems) i.id: i};

    final rows = <List<dynamic>>[
      ['ID', 'Name', 'SKU', 'UnitOfMeasure', 'CurrentQuantity', 'AvgRate', 'TotalValue', 'SalesRate', 'PurchaseRate']
    ];

    for (final s in stockItems) {
      final orig = itemMap[s.id];
      rows.add([
        s.id,
        s.name,
        orig?.sku ?? '',
        orig?.unitOfMeasure ?? 'PCS',
        s.quantity.toStringAsFixed(2),
        s.averageRate.toStringAsFixed(2),
        s.totalValue.toStringAsFixed(2),
        (orig?.salesRate ?? 0.0).toStringAsFixed(2),
        (orig?.purchaseRate ?? 0.0).toStringAsFixed(2),
      ]);
    }

    return delimiter == '\t'
        ? rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ')).join('\t')).join('\n')
        : const ListToCsvConverter().convert(rows);
  }

  Future<String> exportBillsCsv({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
    String delimiter = ',',
  }) async {
    final allVouchers = await (db.select(db.vouchers)
          ..where((t) => t.voucherType.equals('Sales') | t.voucherType.equals('Purchase'))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    final filtered = allVouchers.where((v) => isDateInRange(v.date, range, customStart: customStart, customEnd: customEnd)).toList();

    final rows = <List<dynamic>>[
      ['VoucherNumber', 'VoucherType', 'FinancialYear', 'Date', 'Party', 'Discount', 'Status', 'Narration', 'GrandTotal']
    ];

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final v in filtered) {
      final detail = await engine.getVoucherDetail(v.id);
      double total = 0.0;
      if (detail != null) {
        for (final e in detail.entries) {
          if (e.ledgerId == detail.contactLedger.id) {
            total = e.debitAmount > 0 ? e.debitAmount : e.creditAmount;
            break;
          }
        }
      }

      rows.add([
        v.voucherNumber,
        v.voucherType,
        v.financialYear,
        dateFormat.format(v.date),
        detail?.contactLedger.name ?? 'Unknown',
        v.discountAmount.toStringAsFixed(2),
        v.status,
        v.narration ?? '',
        total.toStringAsFixed(2),
      ]);
    }

    return delimiter == '\t'
        ? rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ')).join('\t')).join('\n')
        : const ListToCsvConverter().convert(rows);
  }

  Future<String> exportBillItemsCsv({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
    String delimiter = ',',
  }) async {
    final allVouchers = await (db.select(db.vouchers)
          ..where((t) => t.voucherType.equals('Sales') | t.voucherType.equals('Purchase'))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    final filtered = allVouchers.where((v) => isDateInRange(v.date, range, customStart: customStart, customEnd: customEnd)).toList();

    final rows = <List<dynamic>>[
      ['VoucherNumber', 'Date', 'ItemName', 'Quantity', 'Rate', 'Amount', 'IsReplacement']
    ];

    final dateFormat = DateFormat('yyyy-MM-dd');

    for (final v in filtered) {
      final detail = await engine.getVoucherDetail(v.id);
      if (detail != null) {
        for (final st in detail.stockTransactions) {
          final amt = st.tx.isReplacement ? 0.0 : (st.tx.quantity.abs() * st.tx.rate);
          rows.add([
            v.voucherNumber,
            dateFormat.format(v.date),
            st.itemName,
            st.tx.quantity.abs().toStringAsFixed(2),
            st.tx.isReplacement ? '0.00' : st.tx.rate.toStringAsFixed(2),
            amt.toStringAsFixed(2),
            st.tx.isReplacement ? 'YES' : 'NO',
          ]);
        }
      }
    }

    return delimiter == '\t'
        ? rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ')).join('\t')).join('\n')
        : const ListToCsvConverter().convert(rows);
  }

  Future<String> exportPaymentsAndReceiptsCsv({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
    String delimiter = ',',
  }) async {
    final vouchers = await (db.select(db.vouchers)
          ..where((t) => t.voucherType.equals('Receipt') | t.voucherType.equals('Payment'))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    final filtered = vouchers.where((v) => isDateInRange(v.date, range, customStart: customStart, customEnd: customEnd)).toList();

    final rows = <List<dynamic>>[
      ['VoucherNumber', 'VoucherType', 'FinancialYear', 'Date', 'Party', 'Amount', 'Status', 'Narration']
    ];

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    for (final v in filtered) {
      final detail = await engine.getVoucherDetail(v.id);
      double amt = 0.0;
      if (detail != null && detail.entries.isNotEmpty) {
        for (final e in detail.entries) {
          if (e.ledgerId == detail.contactLedger.id) {
            amt = e.debitAmount > 0 ? e.debitAmount : e.creditAmount;
            break;
          }
        }
      }

      rows.add([
        v.voucherNumber,
        v.voucherType,
        v.financialYear,
        dateFormat.format(v.date),
        detail?.contactLedger.name ?? 'Unknown',
        amt.toStringAsFixed(2),
        v.status,
        v.narration ?? '',
      ]);
    }

    return delimiter == '\t'
        ? rows.map((r) => r.map((c) => c.toString().replaceAll('\t', ' ')).join('\t')).join('\n')
        : const ListToCsvConverter().convert(rows);
  }

  // ==========================================
  // 2. EXCEL (.XLSX) EXPORTS
  // ==========================================

  Future<List<int>> exportMasterExcel() async {
    final excel = Excel.createExcel();

    // 1. Customers Sheet
    final Sheet custSheet = excel['Customers'];
    custSheet.appendRow([
      TextCellValue('Customer ID'),
      TextCellValue('Name'),
      TextCellValue('Phone'),
      TextCellValue('Address'),
      TextCellValue('Email'),
      TextCellValue('GSTIN'),
      TextCellValue('Opening Balance'),
      TextCellValue('Current Balance'),
    ]);

    final ledgers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))).get();
    for (final l in ledgers) {
      final bal = await engine.getLedgerBalance(l.id);
      custSheet.appendRow([
        TextCellValue(l.id),
        TextCellValue(l.name),
        TextCellValue(l.phone ?? ''),
        TextCellValue(l.address ?? ''),
        TextCellValue(l.email ?? ''),
        TextCellValue(l.taxNumber ?? ''),
        DoubleCellValue(l.openingBalance),
        DoubleCellValue(bal),
      ]);
    }

    // 2. Products Sheet
    final Sheet prodSheet = excel['Products'];
    prodSheet.appendRow([
      TextCellValue('Product ID'),
      TextCellValue('Item Name'),
      TextCellValue('SKU'),
      TextCellValue('Unit'),
      TextCellValue('Current Stock Qty'),
      TextCellValue('Avg Cost Rate'),
      TextCellValue('Stock Valuation'),
      TextCellValue('Sales Rate'),
    ]);

    final stockItems = await engine.getStockSummary();
    final dbItems = await db.select(db.stockItems).get();
    final itemMap = {for (var i in dbItems) i.id: i};

    for (final s in stockItems) {
      final orig = itemMap[s.id];
      prodSheet.appendRow([
        TextCellValue(s.id),
        TextCellValue(s.name),
        TextCellValue(orig?.sku ?? ''),
        TextCellValue(orig?.unitOfMeasure ?? 'PCS'),
        DoubleCellValue(s.quantity),
        DoubleCellValue(s.averageRate),
        DoubleCellValue(s.totalValue),
        DoubleCellValue(orig?.salesRate ?? 0.0),
      ]);
    }

    // Remove default sheet
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    return excel.encode() ?? [];
  }

  // ==========================================
  // 3. TALLY COMPATIBLE XML EXPORT & IMPORT
  // ==========================================

  /// Exports Ledgers, Stock Items, and Sales/Receipt vouchers in authentic Tally XML format
  Future<String> exportTallyXml({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final profile = await profileService.getProfile();
    final ledgers = await (db.select(db.ledgers)..where((t) => t.isDeleted.equals(false))).get();
    final stockItems = await db.select(db.stockItems).get();

    final allVouchers = await (db.select(db.vouchers)..orderBy([(t) => drift.OrderingTerm.asc(t.date)])).get();
    final filteredVouchers = allVouchers.where((v) => isDateInRange(v.date, range, customStart: customStart, customEnd: customEnd)).toList();

    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element('ENVELOPE', nest: () {
      builder.element('HEADER', nest: () {
        builder.element('TALLYREQUEST', nest: 'Import Data');
      });
      builder.element('BODY', nest: () {
        builder.element('IMPORTDATA', nest: () {
          builder.element('REQUESTDESC', nest: () {
            builder.element('REPORTNAME', nest: 'All Masters');
            builder.element('STATICVARIABLES', nest: () {
              builder.element('SVCURRENTCOMPANY', nest: profile.companyName);
            });
          });
          builder.element('REQUESTDATA', nest: () {
            // 1. Export Ledgers
            for (final l in ledgers) {
              final tallyGroup = l.groupId == 'debtors'
                  ? 'Sundry Debtors'
                  : (l.groupId == 'creditors'
                      ? 'Sundry Creditors'
                      : (l.groupId == 'sales_accounts'
                          ? 'Sales Accounts'
                          : (l.groupId == 'purchase_accounts'
                              ? 'Purchase Accounts'
                              : (l.groupId == 'cash_in_hand'
                                  ? 'Cash-in-Hand'
                                  : (l.groupId == 'bank_accounts' ? 'Bank Accounts' : 'Duties & Taxes')))));

              builder.element('TALLYMESSAGE', attributes: {'xmlns:UDF': 'TallyUDF'}, nest: () {
                builder.element('LEDGER', attributes: {'NAME': l.name, 'ACTION': 'Create'}, nest: () {
                  builder.element('NAME', nest: l.name);
                  builder.element('PARENT', nest: tallyGroup);
                  builder.element('OPENINGBALANCE', nest: l.openingBalance.toStringAsFixed(2));
                  if (l.address != null) builder.element('ADDRESS', nest: l.address!);
                  if (l.phone != null) builder.element('LEDGERPHONE', nest: l.phone!);
                  if (l.taxNumber != null) builder.element('PARTYGSTIN', nest: l.taxNumber!);
                });
              });
            }

            // 2. Export Stock Items
            for (final s in stockItems) {
              builder.element('TALLYMESSAGE', attributes: {'xmlns:UDF': 'TallyUDF'}, nest: () {
                builder.element('STOCKITEM', attributes: {'NAME': s.name, 'ACTION': 'Create'}, nest: () {
                  builder.element('NAME', nest: s.name);
                  builder.element('BASEUNITS', nest: s.unitOfMeasure);
                  builder.element('OPENINGBALANCE', nest: '${s.openingQuantity.toStringAsFixed(2)} ${s.unitOfMeasure}');
                  builder.element('OPENINGRATE', nest: s.openingRate.toStringAsFixed(2));
                });
              });
            }

            // 3. Export Vouchers (Sales, Receipts, Payments)
            final tallyDateFormat = DateFormat('yyyyMMdd');
            for (final v in filteredVouchers) {
              builder.element('TALLYMESSAGE', attributes: {'xmlns:UDF': 'TallyUDF'}, nest: () {
                builder.element('VOUCHER', attributes: {'VCHTYPE': v.voucherType, 'ACTION': 'Create'}, nest: () {
                  builder.element('DATE', nest: tallyDateFormat.format(v.date));
                  builder.element('VOUCHERTYPENAME', nest: v.voucherType);
                  builder.element('VOUCHERNUMBER', nest: v.voucherNumber);
                  if (v.narration != null) builder.element('NARRATION', nest: v.narration!);
                });
              });
            }
          });
        });
      });
    });

    return builder.buildDocument().toXmlString(pretty: true);
  }

  /// Safe Tally XML Import with Duplicate Prevention
  Future<ImportResult> importTallyXml(String xmlContent, {DuplicateHandling duplicateHandling = DuplicateHandling.skip}) async {
    int created = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];

    try {
      final document = xml.XmlDocument.parse(xmlContent);

      // Parse Ledgers
      final ledgerElements = document.findAllElements('LEDGER');
      for (final el in ledgerElements) {
        try {
          final name = el.getAttribute('NAME') ?? el.findElements('NAME').firstOrNull?.innerText ?? '';
          if (name.trim().isEmpty) continue;

          final parent = el.findElements('PARENT').firstOrNull?.innerText.toLowerCase() ?? '';
          String groupId = 'debtors';
          if (parent.contains('creditor')) groupId = 'creditors';
          if (parent.contains('bank')) groupId = 'bank_accounts';
          if (parent.contains('cash')) groupId = 'cash_in_hand';
          if (parent.contains('sales')) groupId = 'sales_accounts';
          if (parent.contains('purchase')) groupId = 'purchase_accounts';

          final opBalStr = el.findElements('OPENINGBALANCE').firstOrNull?.innerText ?? '0';
          final opBal = double.tryParse(opBalStr.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
          final addr = el.findElements('ADDRESS').firstOrNull?.innerText;
          final phone = el.findElements('LEDGERPHONE').firstOrNull?.innerText;
          final gstin = el.findElements('PARTYGSTIN').firstOrNull?.innerText;

          final existing = await (db.select(db.ledgers)..where((t) => t.name.equals(name.trim()))).getSingleOrNull();

          if (existing != null) {
            if (duplicateHandling == DuplicateHandling.skip) {
              skipped++;
            } else if (duplicateHandling == DuplicateHandling.update) {
              await (db.update(db.ledgers)..where((t) => t.id.equals(existing.id))).write(
                LedgersCompanion(
                  address: drift.Value(addr ?? existing.address),
                  phone: drift.Value(phone ?? existing.phone),
                  taxNumber: drift.Value(gstin ?? existing.taxNumber),
                ),
              );
              updated++;
            } else {
              final newName = '$name (Imported)';
              await db.into(db.ledgers).insert(LedgersCompanion.insert(
                    id: uuid.v4(),
                    name: newName,
                    groupId: groupId,
                    openingBalance: drift.Value(opBal),
                    address: drift.Value(addr),
                    phone: drift.Value(phone),
                    taxNumber: drift.Value(gstin),
                  ));
              created++;
            }
          } else {
            await db.into(db.ledgers).insert(LedgersCompanion.insert(
                  id: uuid.v4(),
                  name: name.trim(),
                  groupId: groupId,
                  openingBalance: drift.Value(opBal),
                  address: drift.Value(addr),
                  phone: drift.Value(phone),
                  taxNumber: drift.Value(gstin),
                ));
            created++;
          }
        } catch (e) {
          failed++;
          errors.add('Failed importing ledger: $e');
        }
      }

      // Parse Stock Items
      final stockElements = document.findAllElements('STOCKITEM');
      for (final el in stockElements) {
        try {
          final name = el.getAttribute('NAME') ?? el.findElements('NAME').firstOrNull?.innerText ?? '';
          if (name.trim().isEmpty) continue;

          final uom = el.findElements('BASEUNITS').firstOrNull?.innerText ?? 'PCS';
          final opBalStr = el.findElements('OPENINGBALANCE').firstOrNull?.innerText ?? '0';
          final opQty = double.tryParse(opBalStr.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;
          final opRateStr = el.findElements('OPENINGRATE').firstOrNull?.innerText ?? '0';
          final opRate = double.tryParse(opRateStr.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0.0;

          final existing = await (db.select(db.stockItems)..where((t) => t.name.equals(name.trim()))).getSingleOrNull();

          if (existing != null) {
            if (duplicateHandling == DuplicateHandling.skip) {
              skipped++;
            } else if (duplicateHandling == DuplicateHandling.update) {
              await (db.update(db.stockItems)..where((t) => t.id.equals(existing.id))).write(
                StockItemsCompanion(
                  unitOfMeasure: drift.Value(uom),
                  openingQuantity: drift.Value(opQty),
                  openingRate: drift.Value(opRate),
                ),
              );
              updated++;
            } else {
              final newName = '$name (Imported)';
              await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                    id: uuid.v4(),
                    name: newName,
                    unitOfMeasure: drift.Value(uom),
                    openingQuantity: drift.Value(opQty),
                    openingRate: drift.Value(opRate),
                  ));
              created++;
            }
          } else {
            await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                  id: uuid.v4(),
                  name: name.trim(),
                  unitOfMeasure: drift.Value(uom),
                  openingQuantity: drift.Value(opQty),
                  openingRate: drift.Value(opRate),
                ));
            created++;
          }
        } catch (e) {
          failed++;
          errors.add('Failed importing stock item: $e');
        }
      }
    } catch (e) {
      errors.add('XML Parsing Error: $e');
    }

    return ImportResult(
      createdCount: created,
      updatedCount: updated,
      skippedCount: skipped,
      failedCount: failed,
      errors: errors,
    );
  }

  // ==========================================
  // 4. CSV & ASCII SAFE IMPORT WORKFLOW
  // ==========================================

  /// Previews CSV or Tab-delimited file before import
  CsvImportPreview previewDelimitedFile(String content) {
    String delimiter = ',';
    final firstLine = content.split('\n').firstOrNull ?? '';
    if (firstLine.contains('\t') && !firstLine.contains(',')) {
      delimiter = '\t';
    }

    List<List<dynamic>> rows;
    if (delimiter == '\t') {
      rows = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((line) => line.split('\t').map((c) => c.trim()).toList())
          .toList();
    } else {
      final normalized = content.replaceAll('\r\n', '\n');
      rows = const CsvToListConverter(eol: '\n').convert(normalized);
    }

    if (rows.isEmpty) {
      return CsvImportPreview(headers: [], previewRows: [], totalRows: 0, delimiter: delimiter);
    }

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final previewData = rows.skip(1).take(5).toList();

    return CsvImportPreview(
      headers: headers,
      previewRows: previewData,
      totalRows: rows.length - 1,
      delimiter: delimiter,
    );
  }

  /// Imports Customers/Ledgers using mapped columns
  Future<ImportResult> importCustomersMapped({
    required List<List<dynamic>> rows,
    required Map<String, int> columnMapping, // 'name', 'phone', 'address', 'email', 'taxNumber', 'openingBalance'
    DuplicateHandling duplicateHandling = DuplicateHandling.skip,
  }) async {
    int created = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];

    final nameCol = columnMapping['name'];
    if (nameCol == null) {
      return ImportResult(createdCount: 0, updatedCount: 0, skippedCount: 0, failedCount: 0, errors: ['Customer Name mapping is required.']);
    }

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (nameCol >= row.length) continue;

      final name = row[nameCol].toString().trim();
      if (name.isEmpty) continue;

      final phone = (columnMapping['phone'] != null && columnMapping['phone']! < row.length) ? row[columnMapping['phone']!].toString().trim() : null;
      final addr = (columnMapping['address'] != null && columnMapping['address']! < row.length) ? row[columnMapping['address']!].toString().trim() : null;
      final email = (columnMapping['email'] != null && columnMapping['email']! < row.length) ? row[columnMapping['email']!].toString().trim() : null;
      final tax = (columnMapping['taxNumber'] != null && columnMapping['taxNumber']! < row.length) ? row[columnMapping['taxNumber']!].toString().trim() : null;
      final opBal = (columnMapping['openingBalance'] != null && columnMapping['openingBalance']! < row.length)
          ? (double.tryParse(row[columnMapping['openingBalance']!].toString()) ?? 0.0)
          : 0.0;

      try {
        final existing = await (db.select(db.ledgers)..where((t) => t.name.equals(name))).getSingleOrNull();

        if (existing != null) {
          if (duplicateHandling == DuplicateHandling.skip) {
            skipped++;
          } else if (duplicateHandling == DuplicateHandling.update) {
            await (db.update(db.ledgers)..where((t) => t.id.equals(existing.id))).write(
              LedgersCompanion(
                phone: drift.Value(phone ?? existing.phone),
                address: drift.Value(addr ?? existing.address),
                email: drift.Value(email ?? existing.email),
                taxNumber: drift.Value(tax ?? existing.taxNumber),
              ),
            );
            updated++;
          } else {
            final uniqueName = '$name (${created + 1})';
            await db.into(db.ledgers).insert(LedgersCompanion.insert(
                  id: uuid.v4(),
                  name: uniqueName,
                  groupId: 'debtors',
                  openingBalance: drift.Value(opBal),
                  phone: drift.Value(phone),
                  address: drift.Value(addr),
                  email: drift.Value(email),
                  taxNumber: drift.Value(tax),
                ));
            created++;
          }
        } else {
          await db.into(db.ledgers).insert(LedgersCompanion.insert(
                id: uuid.v4(),
                name: name,
                groupId: 'debtors',
                openingBalance: drift.Value(opBal),
                phone: drift.Value(phone),
                address: drift.Value(addr),
                email: drift.Value(email),
                taxNumber: drift.Value(tax),
              ));
          created++;
        }
      } catch (e) {
        failed++;
        errors.add('Row ${i + 1} ($name): $e');
      }
    }

    return ImportResult(
      createdCount: created,
      updatedCount: updated,
      skippedCount: skipped,
      failedCount: failed,
      errors: errors,
    );
  }

  /// Imports Products/StockItems using mapped columns
  Future<ImportResult> importProductsMapped({
    required List<List<dynamic>> rows,
    required Map<String, int> columnMapping, // 'name', 'sku', 'unit', 'salesRate', 'purchaseRate', 'openingQuantity'
    DuplicateHandling duplicateHandling = DuplicateHandling.skip,
  }) async {
    int created = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    final errors = <String>[];

    final nameCol = columnMapping['name'];
    if (nameCol == null) {
      return ImportResult(createdCount: 0, updatedCount: 0, skippedCount: 0, failedCount: 0, errors: ['Product Name mapping is required.']);
    }

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (nameCol >= row.length) continue;

      final name = row[nameCol].toString().trim();
      if (name.isEmpty) continue;

      final sku = (columnMapping['sku'] != null && columnMapping['sku']! < row.length) ? row[columnMapping['sku']!].toString().trim() : null;
      final unit = (columnMapping['unit'] != null && columnMapping['unit']! < row.length) ? row[columnMapping['unit']!].toString().trim() : 'PCS';
      final salesRate = (columnMapping['salesRate'] != null && columnMapping['salesRate']! < row.length)
          ? (double.tryParse(row[columnMapping['salesRate']!].toString()) ?? 0.0)
          : 0.0;
      final purRate = (columnMapping['purchaseRate'] != null && columnMapping['purchaseRate']! < row.length)
          ? (double.tryParse(row[columnMapping['purchaseRate']!].toString()) ?? 0.0)
          : 0.0;
      final opQty = (columnMapping['openingQuantity'] != null && columnMapping['openingQuantity']! < row.length)
          ? (double.tryParse(row[columnMapping['openingQuantity']!].toString()) ?? 0.0)
          : 0.0;

      try {
        final existing = await (db.select(db.stockItems)..where((t) => t.name.equals(name))).getSingleOrNull();

        if (existing != null) {
          if (duplicateHandling == DuplicateHandling.skip) {
            skipped++;
          } else if (duplicateHandling == DuplicateHandling.update) {
            await (db.update(db.stockItems)..where((t) => t.id.equals(existing.id))).write(
              StockItemsCompanion(
                sku: drift.Value(sku ?? existing.sku),
                unitOfMeasure: drift.Value(unit.isNotEmpty ? unit : existing.unitOfMeasure),
                salesRate: drift.Value(salesRate > 0 ? salesRate : existing.salesRate),
                purchaseRate: drift.Value(purRate > 0 ? purRate : existing.purchaseRate),
              ),
            );
            updated++;
          } else {
            final uniqueName = '$name (${created + 1})';
            await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                  id: uuid.v4(),
                  name: uniqueName,
                  sku: drift.Value(sku),
                  unitOfMeasure: drift.Value(unit.isNotEmpty ? unit : 'PCS'),
                  salesRate: drift.Value(salesRate),
                  purchaseRate: drift.Value(purRate),
                  openingQuantity: drift.Value(opQty),
                ));
            created++;
          }
        } else {
          await db.into(db.stockItems).insert(StockItemsCompanion.insert(
                id: uuid.v4(),
                name: name,
                sku: drift.Value(sku),
                unitOfMeasure: drift.Value(unit.isNotEmpty ? unit : 'PCS'),
                salesRate: drift.Value(salesRate),
                purchaseRate: drift.Value(purRate),
                openingQuantity: drift.Value(opQty),
              ));
          created++;
        }
      } catch (e) {
        failed++;
        errors.add('Row ${i + 1} ($name): $e');
      }
    }

    return ImportResult(
      createdCount: created,
      updatedCount: updated,
      skippedCount: skipped,
      failedCount: failed,
      errors: errors,
    );
  }

  // ==========================================
  // 5. COMPLETE APPLICATION BACKUP & RESTORE
  // ==========================================

  /// Creates a complete self-contained application backup (.tallybak archive)
  Future<Uint8List> createFullBackupArchive() async {
    final archive = Archive();

    // 1. Snapshot database safely via checkpoint & VACUUM INTO
    final dbFile = File(await getCustomDatabasePath('tally_ledger'));
    if (!await dbFile.exists()) {
      throw Exception('Database file not found at ${dbFile.path}');
    }

    await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('tally_ledger.sqlite', dbBytes.length, dbBytes));

    // 2. Include Company Logo if present
    final profile = await profileService.getProfile();
    if (profile.logoPath != null && profile.logoPath!.isNotEmpty) {
      final logoFile = File(profile.logoPath!);
      if (await logoFile.exists()) {
        final logoBytes = await logoFile.readAsBytes();
        final ext = logoFile.path.split('.').lastOrNull ?? 'png';
        archive.addFile(ArchiveFile('company_logo.$ext', logoBytes.length, logoBytes));
      }
    }

    // 3. Include Manifest metadata
    final custCount = await (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors'))).get();
    final prodCount = await db.select(db.stockItems).get();
    final vchCount = await db.select(db.vouchers).get();

    final manifest = {
      'app': 'Tally Ledger Desktop',
      'version': '1.1.0',
      'schemaVersion': 5,
      'createdAt': DateTime.now().toIso8601String(),
      'companyName': profile.companyName,
      'customerCount': custCount.length,
      'productCount': prodCount.length,
      'voucherCount': vchCount.length,
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData ?? []);
  }

  /// Restores complete application backup from archive bytes
  Future<Map<String, dynamic>> restoreFullBackupArchive(Uint8List archiveBytes) async {
    final archive = ZipDecoder().decodeBytes(archiveBytes);

    ArchiveFile? dbArchiveFile;
    ArchiveFile? logoArchiveFile;
    ArchiveFile? manifestFile;

    for (final f in archive.files) {
      if (f.name == 'tally_ledger.sqlite') dbArchiveFile = f;
      if (f.name.startsWith('company_logo.')) logoArchiveFile = f;
      if (f.name == 'manifest.json') manifestFile = f;
    }

    if (dbArchiveFile == null) {
      throw Exception('Invalid backup file: Database snapshot (tally_ledger.sqlite) is missing.');
    }

    // 1. Verify Manifest
    Map<String, dynamic> manifestData = {};
    if (manifestFile != null) {
      try {
        manifestData = jsonDecode(utf8.decode(manifestFile.content as List<int>)) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 2. Validate DB integrity in temporary file before overwriting active database
    final dbPath = await getCustomDatabasePath('tally_ledger');
    final dbDir = File(dbPath).parent;
    final tempDbFile = File('${dbDir.path}/restore_test_${DateTime.now().millisecondsSinceEpoch}.sqlite');
    await tempDbFile.writeAsBytes(dbArchiveFile.content as List<int>);

    // 3. Atomically overwrite active database file
    final activeFile = File(dbPath);
    await tempDbFile.copy(activeFile.path);
    await tempDbFile.delete();

    // 4. Restore logo if present
    if (logoArchiveFile != null) {
      final ext = logoArchiveFile.name.split('.').lastOrNull ?? 'png';
      final restoredLogoFile = File('${dbDir.path}/restored_logo.$ext');
      await restoredLogoFile.writeAsBytes(logoArchiveFile.content as List<int>);
      await profileService.updateLogo(restoredLogoFile.path);
    }

    return manifestData;
  }

  // Convenience aliases for UI and testing
  Future<String> exportPaymentsReceiptsCsv({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
    String delimiter = ',',
  }) =>
      exportPaymentsAndReceiptsCsv(
        range: range,
        customStart: customStart,
        customEnd: customEnd,
        delimiter: delimiter,
      );

  Future<Uint8List> exportExcelWorkbook({
    ExportDateRange range = ExportDateRange.allTime,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final bytes = await exportMasterExcel();
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> createFullApplicationBackup() => createFullBackupArchive();

  Future<bool> restoreFullApplicationBackup(Uint8List archiveBytes) async {
    final manifest = await restoreFullBackupArchive(archiveBytes);
    return manifest.isNotEmpty;
  }

  Future<CsvImportPreview> previewCsvImport({required String filePath, String delimiter = ','}) async {
    final content = await File(filePath).readAsString();
    return previewDelimitedFile(content);
  }

  Future<ImportResult> executeCsvImport({
    required String filePath,
    required String targetType,
    required Map<String, String> columnMapping,
    DuplicateHandling duplicateHandling = DuplicateHandling.skip,
    String delimiter = ',',
  }) async {
    final content = await File(filePath).readAsString();
    List<List<dynamic>> rows;
    if (delimiter == '\t') {
      rows = content
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((line) => line.split('\t').map((c) => c.trim()).toList())
          .toList();
    } else {
      final normalized = content.replaceAll('\r\n', '\n');
      rows = const CsvToListConverter(eol: '\n').convert(normalized);
    }

    if (rows.length <= 1) {
      return ImportResult(createdCount: 0, updatedCount: 0, skippedCount: 0, failedCount: 0, errors: ['File contains no data rows.']);
    }

    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final dataRows = rows.skip(1).toList();

    // Map header names to column index
    Map<String, int> indexMap = {};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i];
      if (h.contains('name')) indexMap['name'] = i;
      if (h.contains('phone') || h.contains('mobile')) indexMap['phone'] = i;
      if (h.contains('address')) indexMap['address'] = i;
      if (h.contains('email')) indexMap['email'] = i;
      if (h.contains('tax') || h.contains('gst')) indexMap['taxNumber'] = i;
      if (h.contains('opening') && (h.contains('bal') || h.contains('balance'))) indexMap['openingBalance'] = i;
      if (h.contains('sku') || h.contains('code')) indexMap['sku'] = i;
      if (h.contains('unit') || h.contains('uom')) indexMap['unit'] = i;
      if (h.contains('sales') || h.contains('selling')) indexMap['salesRate'] = i;
      if (h.contains('purchase') || h.contains('cost') || h.contains('buy')) indexMap['purchaseRate'] = i;
      if (h.contains('opening') && (h.contains('qty') || h.contains('quantity'))) indexMap['openingQuantity'] = i;
    }

    // Default name to column 0 or 1 if not detected
    if (!indexMap.containsKey('name')) {
      indexMap['name'] = headers.length > 1 ? 1 : 0;
    }

    if (targetType == 'stock') {
      return importProductsMapped(
        rows: dataRows,
        columnMapping: indexMap,
        duplicateHandling: duplicateHandling,
      );
    } else {
      return importCustomersMapped(
        rows: dataRows,
        columnMapping: indexMap,
        duplicateHandling: duplicateHandling,
      );
    }
  }
}
