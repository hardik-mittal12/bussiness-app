import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/database.dart';
import '../ui/invoice_creation_page.dart';
import 'package:intl/intl.dart';

class InvoicePrinter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);

  static Future<void> printInvoice({
    required BuildContext context,
    required String voucherNumber,
    required String voucherType,
    required DateTime date,
    required Ledger contact,
    required List<InvoiceRowItem> rows,
    required double subtotal,
    required double cgst,
    required double sgst,
    required double grandTotal,
    String? narration,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Tax Invoice Title
              pw.Center(
                child: pw.Text(
                  voucherType == 'Sales' ? 'TAX INVOICE' : 'PURCHASE VOUCHER',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),

              // 2. Company Details & Invoice Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Seller Info (Company)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DEMO COMPANY PVT LTD',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
                      ),
                      pw.Text('123, Business Center, Sector 5'),
                      pw.Text('Mumbai, Maharashtra - 400001'),
                      pw.Text('GSTIN: 27AAAAA1111A1Z1', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  // Invoice Meta Info
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Row(
                        children: [
                          pw.Text('Invoice No: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(voucherNumber),
                        ],
                      ),
                      pw.Row(
                        children: [
                          pw.Text('Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(DateFormat('dd-MMM-yyyy hh:mm a').format(date)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, height: 24),

              // 3. Billing Info (Customer/Supplier)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        voucherType == 'Sales' ? 'Bill To (Customer):' : 'Bill From (Supplier):',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(contact.name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      if (contact.address != null) pw.Text(contact.address!),
                      if (contact.phone != null) pw.Text('Phone: ${contact.phone!}'),
                      if (contact.taxNumber != null)
                        pw.Text('GSTIN/Tax No: ${contact.taxNumber!}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // 4. Line Items Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),  // Sl No
                  1: const pw.FlexColumnWidth(4),     // Description
                  2: const pw.FlexColumnWidth(1.5),   // Qty
                  3: const pw.FlexColumnWidth(2),     // Rate
                  4: const pw.FlexColumnWidth(2),     // Total
                },
                children: [
                  // Table Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.center,
                        child: pw.Text('Sl', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Item Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        alignment: pw.Alignment.centerRight,
                        child: pw.Text('Amount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                    ],
                  ),
                  
                  // Table Rows
                  ...List.generate(rows.length, (idx) {
                    final row = rows[idx];
                    return pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.center,
                          child: pw.Text('${idx + 1}', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(row.item?.name ?? 'Unknown Item', style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            '${row.quantity.toStringAsFixed(0)} ${row.item?.unitOfMeasure ?? 'PCS'}',
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(_currencyFormat.format(row.rate), style: const pw.TextStyle(fontSize: 9)),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(_currencyFormat.format(row.total), style: const pw.TextStyle(fontSize: 9)),
                        ),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),

              // 5. Summary calculations
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left side: Narration/Notes
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (narration != null && narration.isNotEmpty) ...[
                          pw.Text('Narration/Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.SizedBox(height: 4),
                          pw.Text(narration, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 32),
                  // Right side: Sum calculations
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      children: [
                        _buildPdfSummaryRow('Subtotal', subtotal),
                        if (cgst > 0) ...[
                          pw.SizedBox(height: 4),
                          _buildPdfSummaryRow('CGST (9%)', cgst),
                        ],
                        if (sgst > 0) ...[
                          pw.SizedBox(height: 4),
                          _buildPdfSummaryRow('SGST (9%)', sgst),
                        ],
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        _buildPdfSummaryRow('Grand Total', grandTotal, isBold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // 6. Signatures and Declaration
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Declaration:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.Text('We declare that this invoice shows the actual price of the goods', style: const pw.TextStyle(fontSize: 8)),
                      pw.Text('described and that all particulars are true and correct.', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('For DEMO COMPANY PVT LTD', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                      pw.SizedBox(height: 30),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Save and print/preview using printing library
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '$voucherType-$voucherNumber.pdf',
    );
  }

  static pw.Widget _buildPdfSummaryRow(String label, double amount, {bool isBold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          _currencyFormat.format(amount),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
