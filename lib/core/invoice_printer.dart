import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';
import 'business_profile_service.dart';
import 'money_precision.dart';

class InvoiceItemRow {
  final String itemName;
  final double quantity;
  final double rate;
  final double amount;
  final bool isReplacement;

  InvoiceItemRow({
    required this.itemName,
    required this.quantity,
    required this.rate,
    required this.amount,
    this.isReplacement = false,
  });
}

class InvoiceViewModel {
  final String voucherNumber;
  final String voucherType;
  final String financialYear;
  final DateTime date;
  final String partyName;
  final String partyAddress;
  final String partyTaxNumber;
  final String? partyPhone;
  final List<InvoiceItemRow> items;
  final double subtotal;
  final double discount;
  final double cgst;
  final double sgst;
  final double grandTotal;
  final String narration;
  final String? paymentMode;

  InvoiceViewModel({
    required this.voucherNumber,
    required this.voucherType,
    required this.financialYear,
    required this.date,
    required this.partyName,
    required this.partyAddress,
    required this.partyTaxNumber,
    this.partyPhone,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.cgst,
    required this.sgst,
    required this.grandTotal,
    required this.narration,
    this.paymentMode,
  });
}

enum PrinterPaperSize {
  a4,
  thermal58mm,
  thermal80mm,
}

class InvoicePrinter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  /// Main entry point for printing an invoice across paper formats (A4, 58mm, 80mm)
  static Future<void> printInvoice({
    required BuildContext context,
    required AppDatabase db,
    required InvoiceViewModel invoice,
    PrinterPaperSize paperSize = PrinterPaperSize.a4,
  }) async {
    final pdfBytes = await generatePdfBytes(db: db, invoice: invoice, paperSize: paperSize);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: '${invoice.voucherType}_${invoice.voucherNumber}.pdf',
    );
  }

  /// Generates the raw PDF bytes for an invoice
  static Future<Uint8List> generatePdfBytes({
    required AppDatabase db,
    required InvoiceViewModel invoice,
    PrinterPaperSize paperSize = PrinterPaperSize.a4,
  }) async {
    final profileService = BusinessProfileService(db);
    final profile = await profileService.getProfile();

    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await profileService.getLogoBytes();
      if (logoBytes != null && logoBytes.isNotEmpty) {
        logoImage = pw.MemoryImage(logoBytes);
      }
    } catch (_) {}

    final pdf = pw.Document();

    switch (paperSize) {
      case PrinterPaperSize.a4:
        _buildA4Pdf(pdf, invoice, profile, logoImage);
        break;
      case PrinterPaperSize.thermal58mm:
        _buildThermalPdf(pdf, invoice, profile, logoImage, paperWidthMm: 58);
        break;
      case PrinterPaperSize.thermal80mm:
        _buildThermalPdf(pdf, invoice, profile, logoImage, paperWidthMm: 80);
        break;
    }

    return pdf.save();
  }

  /// Builds A4 standard invoice PDF layout
  static void _buildA4Pdf(
    pw.Document pdf,
    InvoiceViewModel invoice,
    BusinessProfile profile,
    pw.MemoryImage? logoImage,
  ) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Center(
                child: pw.Text(
                  invoice.voucherType == 'Sales' ? 'TAX INVOICE' : 'PURCHASE VOUCHER',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    decoration: pw.TextDecoration.underline,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // Business Header with optional Logo & Invoice Metadata
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            height: 60,
                            width: 60,
                            margin: const pw.EdgeInsets.only(right: 12),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(profile.companyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                              if (profile.address != null && profile.address!.isNotEmpty)
                                pw.Text(profile.address!, style: const pw.TextStyle(fontSize: 10)),
                              if (profile.phone != null && profile.phone!.isNotEmpty)
                                pw.Text('Phone: ${profile.phone}', style: const pw.TextStyle(fontSize: 10)),
                              if (profile.email != null && profile.email!.isNotEmpty)
                                pw.Text('Email: ${profile.email}', style: const pw.TextStyle(fontSize: 10)),
                              if (profile.taxNumber != null && profile.taxNumber!.isNotEmpty)
                                pw.Text('GSTIN/Tax ID: ${profile.taxNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice No: ${invoice.voucherNumber}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.Text('FY: ${invoice.financialYear}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Date: ${DateFormat('dd-MMM-yyyy hh:mm a').format(invoice.date)}', style: const pw.TextStyle(fontSize: 10)),
                      if (invoice.paymentMode != null && invoice.paymentMode!.isNotEmpty)
                        pw.Text('Mode: ${invoice.paymentMode}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1, height: 20),

              // Customer / Party Details
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Billed To:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.grey700)),
                  pw.Text(invoice.partyName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                  if (invoice.partyAddress.isNotEmpty) pw.Text(invoice.partyAddress, style: const pw.TextStyle(fontSize: 10)),
                  if (invoice.partyPhone != null && invoice.partyPhone!.isNotEmpty)
                    pw.Text('Phone: ${invoice.partyPhone}', style: const pw.TextStyle(fontSize: 10)),
                  if (invoice.partyTaxNumber.isNotEmpty) pw.Text('GSTIN: ${invoice.partyTaxNumber}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Items Table
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Item Description', 'Qty', 'Rate', 'Amount'],
                data: List<List<String>>.generate(
                  invoice.items.length,
                  (index) {
                    final item = invoice.items[index];
                    final desc = item.isReplacement ? '${item.itemName}  [REPLACEMENT]' : item.itemName;
                    final rateStr = item.isReplacement ? '₹ 0.00' : _currencyFormat.format(item.rate);
                    final amtStr = item.isReplacement ? '₹ 0.00' : _currencyFormat.format(item.amount);
                    return [
                      '${index + 1}',
                      desc,
                      item.quantity.toStringAsFixed(2),
                      rateStr,
                      amtStr,
                    ];
                  },
                ),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                  4: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 16),

              // Totals Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 220,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal', _currencyFormat.format(invoice.subtotal)),
                        if (invoice.discount > 0)
                          _buildTotalRow('Discount', '- ${_currencyFormat.format(invoice.discount)}', isBold: true),
                        if (invoice.cgst > 0) _buildTotalRow('CGST', _currencyFormat.format(invoice.cgst)),
                        if (invoice.sgst > 0) _buildTotalRow('SGST', _currencyFormat.format(invoice.sgst)),
                        pw.Divider(),
                        _buildTotalRow('Grand Total', _currencyFormat.format(invoice.grandTotal), isBold: true),
                      ],
                    ),
                  ),
                ],
              ),

              if (invoice.narration.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                pw.Text('Narration: ${invoice.narration}', style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9)),
              ],

              if (profile.bankDetails != null && profile.bankDetails!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('Bank Details: ${profile.bankDetails}', style: const pw.TextStyle(fontSize: 8)),
              ],

              if (profile.termsAndConditions != null && profile.termsAndConditions!.isNotEmpty) ...[
                pw.Spacer(),
                pw.Divider(thickness: 0.5),
                pw.Text('Terms & Conditions:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                pw.Text(profile.termsAndConditions!, style: const pw.TextStyle(fontSize: 8)),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Builds Thermal 58mm / 80mm continuous receipt PDF layout
  static void _buildThermalPdf(
    pw.Document pdf,
    InvoiceViewModel invoice,
    BusinessProfile profile,
    pw.MemoryImage? logoImage, {
    required double paperWidthMm,
  }) {
    final format = PdfPageFormat(
      paperWidthMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: paperWidthMm == 58 ? 2 * PdfPageFormat.mm : 4 * PdfPageFormat.mm,
    );

    final double fontSize = paperWidthMm == 58 ? 7.0 : 8.5;
    final double headerFontSize = paperWidthMm == 58 ? 9.0 : 11.0;

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        build: (pw.Context pdfContext) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    height: paperWidthMm == 58 ? 32 : 44,
                    width: paperWidthMm == 58 ? 32 : 44,
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                  ),
                ),
              // Header Shop Name
              pw.Center(
                child: pw.Text(
                  profile.companyName,
                  style: pw.TextStyle(fontSize: headerFontSize, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (profile.address != null && profile.address!.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    profile.address!,
                    style: pw.TextStyle(fontSize: fontSize - 1),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (profile.phone != null && profile.phone!.isNotEmpty)
                pw.Center(
                  child: pw.Text('Ph: ${profile.phone}', style: pw.TextStyle(fontSize: fontSize - 1)),
                ),
              if (profile.taxNumber != null && profile.taxNumber!.isNotEmpty)
                pw.Center(
                  child: pw.Text('GSTIN: ${profile.taxNumber}', style: pw.TextStyle(fontSize: fontSize - 1, fontWeight: pw.FontWeight.bold)),
                ),
              pw.SizedBox(height: 4),
              pw.Text('-' * (paperWidthMm == 58 ? 32 : 45), style: pw.TextStyle(fontSize: fontSize)),

              // Invoice Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Inv: ${invoice.voucherNumber}', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yy').format(invoice.date), style: pw.TextStyle(fontSize: fontSize)),
                ],
              ),
              pw.Text('Party: ${invoice.partyName}', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              pw.Text('-' * (paperWidthMm == 58 ? 32 : 45), style: pw.TextStyle(fontSize: fontSize)),

              // Items Header
              pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Item', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Qty', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.Expanded(flex: 3, child: pw.Text('Amt', style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                ],
              ),
              pw.Text('-' * (paperWidthMm == 58 ? 32 : 45), style: pw.TextStyle(fontSize: fontSize)),

              // Items
              ...invoice.items.map((item) {
                final itemName = item.isReplacement ? '${item.itemName} [REP]' : item.itemName;
                final amtStr = item.isReplacement ? '0.00' : MoneyPrecision.format(item.amount);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.0),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(itemName, style: pw.TextStyle(fontSize: fontSize))),
                      pw.Expanded(flex: 2, child: pw.Text(item.quantity.toStringAsFixed(1), style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 3, child: pw.Text(amtStr, style: pw.TextStyle(fontSize: fontSize), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                );
              }),
              pw.Text('-' * (paperWidthMm == 58 ? 32 : 45), style: pw.TextStyle(fontSize: fontSize)),

              // Discount
              if (invoice.discount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: pw.TextStyle(fontSize: fontSize)),
                    pw.Text('-₹${MoneyPrecision.format(invoice.discount)}', style: pw.TextStyle(fontSize: fontSize)),
                  ],
                ),
                pw.Text('-' * (paperWidthMm == 58 ? 32 : 45), style: pw.TextStyle(fontSize: fontSize)),
              ],

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: headerFontSize - 1, fontWeight: pw.FontWeight.bold)),
                  pw.Text('₹${MoneyPrecision.format(invoice.grandTotal)}', style: pw.TextStyle(fontSize: headerFontSize - 1, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text('Thank You! Visit Again.', style: pw.TextStyle(fontSize: fontSize - 1, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    final style = pw.TextStyle(
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      fontSize: isBold ? 11 : 10,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
