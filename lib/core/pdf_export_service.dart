import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import '../data/database.dart';
import 'accounting_engine.dart';
import 'business_profile_service.dart';
import 'invoice_printer.dart';

class PdfExportService {
  final AppDatabase db;
  late final AccountingEngine engine;
  late final BusinessProfileService profileService;

  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);
  static final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MMM-yyyy hh:mm a');

  PdfExportService(this.db) {
    engine = AccountingEngine(db);
    profileService = BusinessProfileService(db);
  }

  Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final bytes = await profileService.getLogoBytes();
      if (bytes != null && bytes.isNotEmpty) {
        return pw.MemoryImage(bytes);
      }
    } catch (_) {}
    return null;
  }

  pw.Widget _buildHeader(BusinessProfile profile, pw.MemoryImage? logo, String title, {String? subtitle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    height: 50,
                    width: 50,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logo, fit: pw.BoxFit.contain),
                  ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(profile.companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    if (profile.address != null && profile.address!.isNotEmpty)
                      pw.Text(profile.address!, style: const pw.TextStyle(fontSize: 9)),
                    if (profile.phone != null && profile.phone!.isNotEmpty)
                      pw.Text('Phone: ${profile.phone}', style: const pw.TextStyle(fontSize: 9)),
                    if (profile.taxNumber != null && profile.taxNumber!.isNotEmpty)
                      pw.Text('GSTIN: ${profile.taxNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.blue900)),
                if (subtitle != null) pw.Text(subtitle, style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Generated: ${_dateTimeFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 1, height: 16),
      ],
    );
  }

  /// Exports an individual bill/invoice to PDF
  Future<Uint8List> exportInvoicePdf(InvoiceViewModel invoice, {PrinterPaperSize paperSize = PrinterPaperSize.a4}) async {
    return InvoicePrinter.generatePdfBytes(db: db, invoice: invoice, paperSize: paperSize);
  }

  /// Exports multiple bills in a combined PDF document
  Future<Uint8List> exportMultipleInvoicesPdf(List<InvoiceViewModel> invoices) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    for (final invoice in invoices) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(profile, logo, invoice.voucherType == 'Sales' ? 'TAX INVOICE' : 'PURCHASE VOUCHER', subtitle: 'No: ${invoice.voucherNumber}'),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed To: ${invoice.partyName}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        if (invoice.partyAddress.isNotEmpty) pw.Text(invoice.partyAddress, style: const pw.TextStyle(fontSize: 9)),
                        if (invoice.partyTaxNumber.isNotEmpty) pw.Text('GSTIN: ${invoice.partyTaxNumber}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Date: ${_dateFormat.format(invoice.date)}', style: const pw.TextStyle(fontSize: 9)),
                        pw.Text('FY: ${invoice.financialYear}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.TableHelper.fromTextArray(
                  headers: ['#', 'Item', 'Qty', 'Rate', 'Amount'],
                  data: List.generate(invoice.items.length, (i) {
                    final it = invoice.items[i];
                    return [
                      '${i + 1}',
                      it.isReplacement ? '${it.itemName} [REP]' : it.itemName,
                      it.quantity.toStringAsFixed(2),
                      it.isReplacement ? '₹ 0.00' : _currencyFormat.format(it.rate),
                      it.isReplacement ? '₹ 0.00' : _currencyFormat.format(it.amount),
                    ];
                  }),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                  cellStyle: const pw.TextStyle(fontSize: 8.5),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      child: pw.Column(
                        children: [
                          if (invoice.discount > 0)
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('Discount:', style: const pw.TextStyle(fontSize: 9)),
                                pw.Text('- ${_currencyFormat.format(invoice.discount)}', style: const pw.TextStyle(fontSize: 9)),
                              ],
                            ),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Grand Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                              pw.Text(_currencyFormat.format(invoice.grandTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Exports Payment or Receipt Voucher to PDF
  Future<Uint8List> exportReceiptPdf({
    required Voucher voucher,
    required Ledger partyLedger,
    required double amount,
    required String paymentMode,
    String? narration,
  }) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    final isReceipt = voucher.voucherType == 'Receipt';
    final docTitle = isReceipt ? 'PAYMENT RECEIPT' : 'PAYMENT VOUCHER';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(profile, logo, docTitle, subtitle: 'Ref: ${voucher.voucherNumber}'),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Voucher No: ${voucher.voucherNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${_dateFormat.format(voucher.date)}'),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(isReceipt ? 'Received With Thanks From:' : 'Paid To:', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text(partyLedger.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    if (partyLedger.address != null && partyLedger.address!.isNotEmpty)
                      pw.Text(partyLedger.address!, style: const pw.TextStyle(fontSize: 10)),
                    if (partyLedger.phone != null && partyLedger.phone!.isNotEmpty)
                      pw.Text('Phone: ${partyLedger.phone!}', style: const pw.TextStyle(fontSize: 10)),
                    pw.Divider(height: 20),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Amount:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
                        pw.Text(_currencyFormat.format(amount), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: PdfColors.blue800)),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Payment Mode: $paymentMode', style: const pw.TextStyle(fontSize: 10)),
                    if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                      pw.SizedBox(height: 6),
                      pw.Text('Narration: ${voucher.narration}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                    ],
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 20),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Customer Statement / Account Ledger History
  Future<Uint8List> exportCustomerStatementPdf(String ledgerId) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final ledger = await (db.select(db.ledgers)..where((t) => t.id.equals(ledgerId))).getSingle();
    final statementRows = await engine.getLedgerStatement(ledgerId);
    final currentBalance = await engine.getLedgerBalance(ledgerId);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(profile, logo, 'CUSTOMER STATEMENT', subtitle: ledger.name),
        build: (ctx) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Party: ${ledger.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    if (ledger.address != null) pw.Text('Address: ${ledger.address}', style: const pw.TextStyle(fontSize: 9)),
                    if (ledger.phone != null) pw.Text('Phone: ${ledger.phone}', style: const pw.TextStyle(fontSize: 9)),
                    if (ledger.taxNumber != null) pw.Text('GSTIN: ${ledger.taxNumber}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Opening Balance: ${_currencyFormat.format(ledger.openingBalance)}', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text(
                      'Closing Balance: ${_currencyFormat.format(currentBalance)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: currentBalance >= 0 ? PdfColors.blue800 : PdfColors.red800),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Voucher Type', 'Voucher #', 'Debit', 'Credit', 'Running Balance'],
              data: statementRows.map((r) => [
                _dateFormat.format(r.date),
                r.voucherType,
                r.voucherNumber,
                r.debitAmount > 0 ? _currencyFormat.format(r.debitAmount) : '-',
                r.creditAmount > 0 ? _currencyFormat.format(r.creditAmount) : '-',
                _currencyFormat.format(r.runningBalance),
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Inventory Stock Report
  Future<Uint8List> exportInventoryReportPdf() async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final stockItems = await engine.getStockSummary();

    final pdf = pw.Document();

    double totalStockVal = 0.0;
    for (final s in stockItems) {
      totalStockVal += s.totalValue;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(profile, logo, 'INVENTORY VALUATION REPORT'),
        build: (ctx) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Item Name', 'Quantity', 'Avg Cost', 'Total Value'],
              data: List.generate(stockItems.length, (i) {
                final s = stockItems[i];
                return [
                  '${i + 1}',
                  s.name,
                  s.quantity.toStringAsFixed(2),
                  _currencyFormat.format(s.averageRate),
                  _currencyFormat.format(s.totalValue),
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Inventory Valuation: ${_currencyFormat.format(totalStockVal)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Customer Outstanding Balances Report
  Future<Uint8List> exportOutstandingReportPdf() async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final customers = await (db.select(db.ledgers)..where((t) => t.groupId.equals('debtors') & t.isDeleted.equals(false))).get();

    final pdf = pw.Document();

    final outstandingList = <Map<String, dynamic>>[];
    double grandTotalOutstanding = 0.0;

    for (final c in customers) {
      final bal = await engine.getLedgerBalance(c.id);
      if (bal.abs() > 0.001) {
        outstandingList.add({
          'name': c.name,
          'phone': c.phone ?? '-',
          'balance': bal,
        });
        grandTotalOutstanding += bal;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(profile, logo, 'CUSTOMER OUTSTANDING REPORT'),
        build: (ctx) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Customer Name', 'Phone', 'Outstanding Balance'],
              data: List.generate(outstandingList.length, (i) {
                final row = outstandingList[i];
                return [
                  '${i + 1}',
                  row['name'].toString(),
                  row['phone'].toString(),
                  _currencyFormat.format(row['balance']),
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Outstanding: ${_currencyFormat.format(grandTotalOutstanding)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Day Book report to PDF
  Future<Uint8List> exportDayBookPdf(DateTime date, List<DayBookRow> rows) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    double totalAmount = 0.0;
    for (final r in rows) {
      totalAmount += r.totalAmount;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(profile, logo, 'DAY BOOK REPORT', subtitle: 'Date: ${_dateFormat.format(date)}'),
        build: (ctx) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Voucher #', 'Type', 'Time', 'Narration', 'Amount'],
              data: List.generate(rows.length, (i) {
                final r = rows[i];
                return [
                  '${i + 1}',
                  r.voucherNumber,
                  r.voucherType,
                  DateFormat('hh:mm a').format(r.date),
                  r.narration,
                  _currencyFormat.format(r.totalAmount),
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text('Total Turnover: ${_currencyFormat.format(totalAmount)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Trial Balance report to PDF
  Future<Uint8List> exportTrialBalancePdf(List<TrialBalanceRow> rows) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    double totalDebit = 0.0;
    double totalCredit = 0.0;
    for (final r in rows) {
      totalDebit += r.debitBalance;
      totalCredit += r.creditBalance;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _buildHeader(profile, logo, 'TRIAL BALANCE REPORT'),
        build: (ctx) {
          return [
            pw.TableHelper.fromTextArray(
              headers: ['#', 'Account Ledger', 'Group', 'Debit Balance', 'Credit Balance'],
              data: List.generate(rows.length, (i) {
                final r = rows[i];
                return [
                  '${i + 1}',
                  r.ledgerName,
                  r.groupName,
                  r.debitBalance > 0 ? _currencyFormat.format(r.debitBalance) : '-',
                  r.creditBalance > 0 ? _currencyFormat.format(r.creditBalance) : '-',
                ];
              }),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                pw.Row(
                  children: [
                    pw.Text('Debit: ${_currencyFormat.format(totalDebit)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(width: 24),
                    pw.Text('Credit: ${_currencyFormat.format(totalCredit)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Profit & Loss report to PDF
  Future<Uint8List> exportProfitLossPdf(ProfitLossReport report) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(profile, logo, 'PROFIT & LOSS STATEMENT'),
              pw.SizedBox(height: 16),
              pw.Text('Trading Account', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Particulars (Debits)', 'Amount', 'Particulars (Credits)', 'Amount'],
                data: [
                  ['Opening Stock', _currencyFormat.format(report.openingStockValue), 'Sales Account', _currencyFormat.format(report.salesValue)],
                  ['Purchase Account', _currencyFormat.format(report.purchaseValue), 'Closing Stock', _currencyFormat.format(report.closingStockValue)],
                  ['Direct Expenses', _currencyFormat.format(report.directExpenses), '', ''],
                  ['Gross Profit c/d', _currencyFormat.format(report.grossProfit), '', ''],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              pw.SizedBox(height: 24),
              pw.Text('Income Statement / P&L', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Particulars (Expenses)', 'Amount', 'Particulars (Income)', 'Amount'],
                data: [
                  ['Indirect Expenses', _currencyFormat.format(report.indirectExpenses), 'Gross Profit b/d', _currencyFormat.format(report.grossProfit)],
                  ['Net Profit', _currencyFormat.format(report.netProfit), '', ''],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Net Profit / Surplus for the Period:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text(_currencyFormat.format(report.netProfit), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: report.netProfit >= 0 ? PdfColors.blue900 : PdfColors.red900)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Exports Balance Sheet report to PDF
  Future<Uint8List> exportBalanceSheetPdf(BalanceSheetReport report) async {
    final profile = await profileService.getProfile();
    final logo = await _loadLogoImage();
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(profile, logo, 'BALANCE SHEET AS ON DATE'),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['Liabilities & Capital', 'Amount', 'Assets & Resources', 'Amount'],
                data: [
                  ['Capital Account', _currencyFormat.format(report.capitalBalance), 'Closing Stock', _currencyFormat.format(report.closingStock)],
                  ['Profit & Loss Surplus', _currencyFormat.format(report.netProfitSurplus), 'Sundry Debtors', _currencyFormat.format(report.sundryDebtors)],
                  ['Sundry Creditors', _currencyFormat.format(report.sundryCreditors), 'Bank Accounts', _currencyFormat.format(report.bankBalance)],
                  ['Other Liabilities', '-', 'Cash-in-Hand', _currencyFormat.format(report.cashBalance)],
                  ['Total Liabilities', _currencyFormat.format(report.totalLiabilities), 'Total Assets', _currencyFormat.format(report.totalAssets)],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Liabilities: ${_currencyFormat.format(report.totalLiabilities)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('Total Assets: ${_currencyFormat.format(report.totalAssets)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
