import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/accounting_engine.dart';
import '../../core/invoice_printer.dart';
import '../../data/database.dart';
import '../invoice_creation_page.dart';

class VoucherDetailDialog extends StatelessWidget {
  final String voucherId;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  VoucherDetailDialog({super.key, required this.voucherId});

  static void show(BuildContext context, String voucherId) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => VoucherDetailDialog(voucherId: voucherId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return Dialog(
      backgroundColor: const Color(0xFF161928),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 24,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: FutureBuilder<VoucherDetail?>(
        future: engine.getVoucherDetail(voucherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 300,
              width: 500,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.indigoAccent),
            );
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return Container(
              height: 200,
              width: 400,
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Error: ${snapshot.error ?? "Voucher not found"}',
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final detail = snapshot.data!;
          final voucher = detail.voucher;
          final isInvoice = voucher.voucherType == 'Sales' || voucher.voucherType == 'Purchase';

          return Container(
            width: 800,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                _buildHeader(context, voucher),
                const Divider(color: Colors.white12, height: 24),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact Ledger Info Card
                        _buildContactCard(detail.contactLedger, voucher),
                        const SizedBox(height: 20),

                        // Line items (for invoices) or Ledger splits (for payments/receipts)
                        if (isInvoice) ...[
                          const Text(
                            'Inventory Line Items',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          _buildInventoryTable(detail.stockTransactions),
                          const SizedBox(height: 16),
                          _buildSummarySection(detail),
                        ] else ...[
                          const Text(
                            'Double-Entry Postings',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                          _buildLedgerEntriesTable(detail.entries),
                        ],

                        if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'Narration / Notes',
                            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2235),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            child: Text(
                              voucher.narration!,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),

                const Divider(color: Colors.white12, height: 24),

                // Footer actions
                _buildFooterActions(context, detail),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Voucher voucher) {
    Color badgeColor = Colors.blueAccent;
    if (voucher.voucherType == 'Sales') badgeColor = Colors.greenAccent;
    if (voucher.voucherType == 'Purchase') badgeColor = Colors.orangeAccent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  voucher.voucherNumber,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    voucher.voucherType.toUpperCase(),
                    style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('dd-MMM-yyyy  hh:mm a').format(voucher.date)}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        if (voucher.referenceNumber != null && voucher.referenceNumber!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Ref No.', style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text(
                voucher.referenceNumber!,
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildContactCard(Ledger contact, Voucher voucher) {
    final title = voucher.voucherType == 'Sales' ? 'Customer Account' : 'Supplier Account';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: Colors.indigoAccent, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(contact.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                if (contact.phone != null && contact.phone!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Phone: ${contact.phone}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                if (contact.address != null && contact.address!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Address: ${contact.address}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
                if (contact.taxNumber != null && contact.taxNumber!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('GSTIN: ${contact.taxNumber}', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryTable(List<StockTransactionWithItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black12,
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Product Description', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('SKU / Code', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Rate', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('Amount', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Items
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final qty = item.tx.quantity.abs();
              final amount = qty * item.tx.rate;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.02))),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(item.itemName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text(item.sku ?? 'N/A', style: const TextStyle(color: Colors.white54, fontSize: 13))),
                    Expanded(flex: 2, child: Text(qty.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(_currencyFormat.format(item.tx.rate), style: const TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(flex: 3, child: Text(_currencyFormat.format(amount), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(VoucherDetail detail) {
    // Read voucher splits to find sales/purchase, cgst, sgst, grand total
    double subtotal = 0.0;
    double cgst = 0.0;
    double sgst = 0.0;
    double grandTotal = 0.0;

    for (final entry in detail.entries) {
      if (entry.ledgerId == 'sales' || entry.ledgerId == 'purchase') {
        subtotal = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
      } else if (entry.ledgerId == 'cgst') {
        cgst = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
      } else if (entry.ledgerId == 'sgst') {
        sgst = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
      } else if (entry.ledgerId == detail.contactLedger.id) {
        grandTotal = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
      }
    }

    // Fallbacks if entries are custom journals
    if (subtotal == 0) {
      subtotal = detail.stockTransactions.fold(0.0, (sum, st) => sum + (st.tx.quantity.abs() * st.tx.rate));
    }
    if (grandTotal == 0) {
      grandTotal = subtotal + cgst + sgst;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2235),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', subtotal),
            if (cgst > 0) ...[
              const SizedBox(height: 6),
              _buildSummaryRow('CGST (9%)', cgst),
            ],
            if (sgst > 0) ...[
              const SizedBox(height: 6),
              _buildSummaryRow('SGST (9%)', sgst),
            ],
            const Divider(color: Colors.white24, height: 16),
            _buildSummaryRow('Grand Total', grandTotal, isBold: true, valueColor: Colors.greenAccent),
          ],
        ),
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
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerEntriesTable(List<VoucherEntry> entries) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2235),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.black12,
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text('Account Ledger Name', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Debit Amount', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('Credit Amount', style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          // Entries list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.02))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: FutureBuilder<Ledger?>(
                        future: (Provider.of<AppDatabase>(context, listen: false).select(Provider.of<AppDatabase>(context, listen: false).ledgers)..where((t) => t.id.equals(entry.ledgerId))).getSingleOrNull(),
                        builder: (context, snap) {
                          return Text(
                            snap.data?.name ?? entry.ledgerId,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.debitAmount > 0 ? _currencyFormat.format(entry.debitAmount) : '-',
                        style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.creditAmount > 0 ? _currencyFormat.format(entry.creditAmount) : '-',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, VoucherDetail detail) {
    final isInvoice = detail.voucher.voucherType == 'Sales' || detail.voucher.voucherType == 'Purchase';

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Close Button
        TextButton(
          child: const Text('Close', style: TextStyle(color: Colors.white54)),
          onPressed: () => Navigator.pop(context),
        ),
        const SizedBox(width: 12),
        // Alter / Edit Button
        if (isInvoice) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Alter / Edit Bill'),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceCreationPage(existingVoucher: detail.voucher),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          // Reprint Invoice Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Reprint Invoice'),
            onPressed: () async {
              // Extract rows and details for InvoicePrinter
              List<InvoiceRowItem> printRows = [];
              for (final st in detail.stockTransactions) {
                printRows.add(InvoiceRowItem(
                  item: StockItem(
                    id: st.tx.stockItemId,
                    name: st.itemName,
                    sku: st.sku,
                    openingQuantity: 0.0,
                    openingRate: 0.0,
                    salesRate: st.tx.rate,
                    purchaseRate: st.tx.rate,
                    unitOfMeasure: 'pcs',
                    updatedAt: DateTime.now(),
                    isSynced: false,
                  ),
                  quantity: st.tx.quantity.abs(),
                  rate: st.tx.rate,
                ));
              }

              double subtotal = 0.0;
              double cgst = 0.0;
              double sgst = 0.0;
              double grandTotal = 0.0;

              for (final entry in detail.entries) {
                if (entry.ledgerId == 'sales' || entry.ledgerId == 'purchase') {
                  subtotal = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
                } else if (entry.ledgerId == 'cgst') {
                  cgst = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
                } else if (entry.ledgerId == 'sgst') {
                  sgst = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
                } else if (entry.ledgerId == detail.contactLedger.id) {
                  grandTotal = entry.debitAmount > 0 ? entry.debitAmount : entry.creditAmount;
                }
              }

              if (subtotal == 0) {
                subtotal = printRows.fold(0.0, (sum, r) => sum + r.total);
              }
              if (grandTotal == 0) {
                grandTotal = subtotal + cgst + sgst;
              }

              await InvoicePrinter.printInvoice(
                context: context,
                voucherNumber: detail.voucher.voucherNumber,
                voucherType: detail.voucher.voucherType,
                date: detail.voucher.date,
                contact: detail.contactLedger,
                rows: printRows,
                subtotal: subtotal,
                cgst: cgst,
                sgst: sgst,
                grandTotal: grandTotal,
                narration: detail.voucher.narration,
              );
            },
          ),
        ],
      ],
    );
  }
}
