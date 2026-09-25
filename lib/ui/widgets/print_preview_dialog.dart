import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../core/business_profile_service.dart';
import '../../core/invoice_printer.dart';
import '../../core/money_precision.dart';
import '../../core/pdf_export_service.dart';
import '../../data/database.dart';

class PrintPreviewDialog extends StatefulWidget {
  final AppDatabase db;
  final InvoiceViewModel invoice;

  const PrintPreviewDialog({
    super.key,
    required this.db,
    required this.invoice,
  });

  static Future<void> show(BuildContext context, {required AppDatabase db, required InvoiceViewModel invoice}) {
    return showDialog(
      context: context,
      builder: (ctx) => PrintPreviewDialog(db: db, invoice: invoice),
    );
  }

  @override
  State<PrintPreviewDialog> createState() => _PrintPreviewDialogState();
}

class _PrintPreviewDialogState extends State<PrintPreviewDialog> {
  PrinterPaperSize _selectedPaperSize = PrinterPaperSize.a4;
  BusinessProfile? _profile;
  bool _isLoading = true;
  static final _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final service = BusinessProfileService(widget.db);
    final p = await service.getProfile();
    if (mounted) {
      setState(() {
        _profile = p;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.85).clamp(400.0, 840.0);
    final dialogHeight = (screenSize.height * 0.9).clamp(500.0, 800.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Bar
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.preview_outlined, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Print Preview — ${widget.invoice.voucherType} #${widget.invoice.voucherNumber}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<PrinterPaperSize>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment(value: PrinterPaperSize.a4, label: Text('A4')),
                    ButtonSegment(value: PrinterPaperSize.thermal80mm, label: Text('80mm')),
                    ButtonSegment(value: PrinterPaperSize.thermal58mm, label: Text('58mm')),
                  ],
                  selected: {_selectedPaperSize},
                  onSelectionChanged: (set) {
                    setState(() => _selectedPaperSize = set.first);
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // Preview Scrollable Container
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _selectedPaperSize == PrinterPaperSize.a4
                            ? _buildA4Document()
                            : _buildThermalDocument(_selectedPaperSize == PrinterPaperSize.thermal58mm ? 300 : 380),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Bottom Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFFDC2626)),
                  label: const Text('Export PDF'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final pdfService = PdfExportService(widget.db);
                      final bytes = await pdfService.exportInvoicePdf(widget.invoice, paperSize: _selectedPaperSize);
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'invoice_${widget.invoice.voucherNumber}.pdf',
                      );
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
                      }
                    }
                  },
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.print),
                  label: const Text('Print Now'),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await InvoicePrinter.printInvoice(
                        context: context,
                        db: widget.db,
                        invoice: widget.invoice,
                        paperSize: _selectedPaperSize,
                      );
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFDC2626),
                            content: Text('Print failed: $e'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildA4Document() {
    final p = _profile!;
    final inv = widget.invoice;
    final file = (p.logoPath != null && p.logoPath!.isNotEmpty) ? File(p.logoPath!) : null;
    final hasLogo = file != null && file.existsSync();

    return Container(
      width: 600,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              inv.voucherType == 'Sales' ? 'TAX INVOICE' : 'PURCHASE VOUCHER',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
            ),
          ),
          const SizedBox(height: 16),
          // Company details & Invoice details
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasLogo)
                      Container(
                        height: 52,
                        width: 52,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(file, fit: BoxFit.contain),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          if (p.address != null && p.address!.isNotEmpty)
                            Text(p.address!, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          if (p.phone != null && p.phone!.isNotEmpty)
                            Text('Phone: ${p.phone}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
                          if (p.taxNumber != null && p.taxNumber!.isNotEmpty)
                            Text('GSTIN: ${p.taxNumber}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Invoice No: ${inv.voucherNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('FY: ${inv.financialYear}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text('Date: ${DateFormat('dd-MMM-yyyy').format(inv.date)}', style: const TextStyle(fontSize: 11)),
                  if (inv.paymentMode != null)
                    Text('Payment: ${inv.paymentMode}', style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const Divider(height: 24),

          // Customer details
          Text('Billed To:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          Text(inv.partyName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          if (inv.partyAddress.isNotEmpty)
            Text(inv.partyAddress, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          if (inv.partyPhone != null && inv.partyPhone!.isNotEmpty)
            Text('Phone: ${inv.partyPhone}', style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          if (inv.partyTaxNumber.isNotEmpty)
            Text('GSTIN: ${inv.partyTaxNumber}', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 16),

          // Items table
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            columnWidths: const {
              0: FixedColumnWidth(36),
              1: FlexColumnWidth(4),
              2: FlexColumnWidth(1.5),
              3: FlexColumnWidth(2),
              4: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade100),
                children: const [
                  Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Item Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  Padding(padding: EdgeInsets.all(6), child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                ],
              ),
              ...List.generate(inv.items.length, (idx) {
                final item = inv.items[idx];
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text('${idx + 1}', style: const TextStyle(fontSize: 11))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 11))),
                          if (item.isReplacement)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(3)),
                              child: const Text('REPLACEMENT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309))),
                            ),
                        ],
                      ),
                    ),
                    Padding(padding: const EdgeInsets.all(6), child: Text(item.quantity.toStringAsFixed(2), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(item.isReplacement ? '₹ 0.00' : _currencyFormat.format(item.rate), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text(item.isReplacement ? '₹ 0.00' : _currencyFormat.format(item.amount), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Totals
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 240,
                child: Column(
                  children: [
                    _previewTotalRow('Subtotal', _currencyFormat.format(inv.subtotal)),
                    if (inv.discount > 0)
                      _previewTotalRow('Discount', '- ${_currencyFormat.format(inv.discount)}', isHighlight: true),
                    if (inv.cgst > 0) _previewTotalRow('CGST', _currencyFormat.format(inv.cgst)),
                    if (inv.sgst > 0) _previewTotalRow('SGST', _currencyFormat.format(inv.sgst)),
                    const Divider(),
                    _previewTotalRow('Grand Total', _currencyFormat.format(inv.grandTotal), isBold: true),
                  ],
                ),
              ),
            ],
          ),
          if (inv.narration.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Narration: ${inv.narration}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B))),
          ],
          if (p.termsAndConditions != null && p.termsAndConditions!.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const Text('Terms & Conditions:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
            Text(p.termsAndConditions!, style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
          ],
        ],
      ),
    );
  }

  Widget _buildThermalDocument(double width) {
    final p = _profile!;
    final inv = widget.invoice;
    final file = (p.logoPath != null && p.logoPath!.isNotEmpty) ? File(p.logoPath!) : null;
    final hasLogo = file != null && file.existsSync();

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (hasLogo) ...[
            Image.file(file, height: 40, fit: BoxFit.contain),
            const SizedBox(height: 6),
          ],
          Text(p.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
          if (p.address != null) Text(p.address!, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
          if (p.phone != null) Text('Ph: ${p.phone}', style: const TextStyle(fontSize: 10)),
          if (p.taxNumber != null) Text('GSTIN: ${p.taxNumber}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const Text('------------------------------------------', maxLines: 1, overflow: TextOverflow.clip),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Inv: ${inv.voucherNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              Text(DateFormat('dd/MM/yy').format(inv.date), style: const TextStyle(fontSize: 10)),
            ],
          ),
          Align(alignment: Alignment.centerLeft, child: Text('Party: ${inv.partyName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
          const Text('------------------------------------------', maxLines: 1, overflow: TextOverflow.clip),

          // Items
          ...inv.items.map((it) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      it.isReplacement ? '${it.itemName} [REP]' : it.itemName,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(it.quantity.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(fontSize: 10)),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      it.isReplacement ? '0.00' : MoneyPrecision.format(it.amount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Text('------------------------------------------', maxLines: 1, overflow: TextOverflow.clip),

          if (inv.discount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Discount:', style: TextStyle(fontSize: 10)),
                Text('-₹${MoneyPrecision.format(inv.discount)}', style: const TextStyle(fontSize: 10)),
              ],
            ),
            const Text('------------------------------------------', maxLines: 1, overflow: TextOverflow.clip),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('₹${MoneyPrecision.format(inv.grandTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Thank You! Visit Again.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _previewTotalRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHighlight ? const Color(0xFFDC2626) : null)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isHighlight ? const Color(0xFFDC2626) : null)),
        ],
      ),
    );
  }
}
