import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/accounting_engine.dart';
import '../../core/financial_year_service.dart';
import '../../core/invoice_printer.dart';
import '../../data/database.dart';
import '../invoice_creation_page.dart';
import '../theme/app_theme.dart';
import 'print_preview_dialog.dart';

class VoucherDetailDialog extends StatelessWidget {
  final String voucherId;
  final VoidCallback? onDeleted;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  VoucherDetailDialog({super.key, required this.voucherId, this.onDeleted});

  static void show(BuildContext context, String voucherId, {VoidCallback? onDeleted}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => VoucherDetailDialog(voucherId: voucherId, onDeleted: onDeleted),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = Provider.of<AccountingEngine>(context, listen: false);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 12,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: FutureBuilder<VoucherDetail?>(
        future: engine.getVoucherDetail(voucherId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 300,
              width: 500,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
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
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Error: ${snapshot.error ?? "Voucher not found"}',
                    style: const TextStyle(color: AppColors.textSecondary),
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
            constraints: const BoxConstraints(maxHeight: 720),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                _buildHeader(context, voucher),
                const Divider(color: AppColors.border, height: 24),

                // Content Area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Contact Ledger Info Card
                        _buildContactCard(detail.contactLedger, voucher),
                        const SizedBox(height: 16),

                        // Line items (for invoices) or Ledger splits (for payments/receipts)
                        if (isInvoice) ...[
                          const Text(
                            'Inventory Line Items',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildInventoryTable(detail.stockTransactions),
                          const SizedBox(height: 14),
                          _buildSummarySection(detail),
                        ] else ...[
                          const Text(
                            'Double-Entry Postings',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _buildLedgerEntriesTable(detail.entries),
                        ],

                        if (voucher.narration != null && voucher.narration!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Narration / Remarks',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              voucher.narration!,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),

                const Divider(color: AppColors.border, height: 24),

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
    Color badgeColor = AppColors.primary;
    Color badgeBg = AppColors.primaryBackground;
    if (voucher.voucherType == 'Sales') {
      badgeColor = AppColors.success;
      badgeBg = AppColors.successBg;
    } else if (voucher.voucherType == 'Purchase') {
      badgeColor = AppColors.warning;
      badgeBg = AppColors.warningBg;
    }

    final isCancelled = voucher.status == 'CANCELLED';

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
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCancelled ? AppColors.surfaceSecondary : badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isCancelled ? AppColors.borderStrong : badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    isCancelled ? 'CANCELLED' : voucher.voucherType.toUpperCase(),
                    style: TextStyle(
                      color: isCancelled ? AppColors.textMuted : badgeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Date: ${DateFormat('dd-MMM-yyyy  hh:mm a').format(voucher.date)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        if (voucher.referenceNumber != null && voucher.referenceNumber!.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Reference / Ref No.', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(
                voucher.referenceNumber!,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
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
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(contact.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                if (contact.phone != null && contact.phone!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Phone: ${contact.phone}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
                if (contact.address != null && contact.address!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Address: ${contact.address}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
                if (contact.taxNumber != null && contact.taxNumber!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('GSTIN: ${contact.taxNumber}', style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.bold)),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceSecondary,
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Product Description', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('SKU / Code', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Qty', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Rate', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
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
              final isRep = item.tx.isReplacement;
              final amount = isRep ? 0.0 : (qty * item.tx.rate);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isRep ? AppColors.warningBg.withOpacity(0.3) : AppColors.surface,
                  border: const Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.itemName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                          if (isRep)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(4)),
                              child: const Text('REPLACEMENT', style: TextStyle(color: AppColors.warning, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(item.sku ?? 'N/A', style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
                    Expanded(flex: 2, child: Text(qty.toStringAsFixed(0), style: const TextStyle(color: AppColors.textPrimary, fontSize: 13), textAlign: TextAlign.right)),
                    Expanded(
                      flex: 2,
                      child: Text(
                        isRep ? '₹ 0.00' : _currencyFormat.format(item.tx.rate),
                        style: TextStyle(color: isRep ? AppColors.warning : AppColors.textPrimary, fontSize: 13),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        isRep ? '₹ 0.00' : _currencyFormat.format(amount),
                        style: TextStyle(color: isRep ? AppColors.warning : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
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

  Widget _buildSummarySection(VoucherDetail detail) {
    double subtotal = 0.0;
    double cgst = 0.0;
    double sgst = 0.0;
    double grandTotal = 0.0;
    final discount = detail.voucher.discountAmount;

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
      subtotal = detail.stockTransactions.fold(0.0, (sum, st) => sum + (st.tx.isReplacement ? 0.0 : (st.tx.quantity.abs() * st.tx.rate)));
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
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', subtotal),
            if (discount > 0) ...[
              const SizedBox(height: 6),
              _buildSummaryRow('Discount', discount, valueColor: AppColors.error),
            ],
            if (cgst > 0) ...[
              const SizedBox(height: 6),
              _buildSummaryRow('CGST (9%)', cgst),
            ],
            if (sgst > 0) ...[
              const SizedBox(height: 6),
              _buildSummaryRow('SGST (9%)', sgst),
            ],
            const Divider(color: AppColors.borderStrong, height: 16),
            _buildSummaryRow('Grand Total', grandTotal, isBold: true, valueColor: AppColors.success),
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
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: valueColor ?? (isBold ? AppColors.textPrimary : AppColors.textSecondary),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surfaceSecondary,
            child: const Row(
              children: [
                Expanded(flex: 5, child: Text('Account Ledger Name', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Debit Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                Expanded(flex: 3, child: Text('Credit Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
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
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.debitAmount > 0 ? _currencyFormat.format(entry.debitAmount) : '-',
                        style: const TextStyle(color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.creditAmount > 0 ? _currencyFormat.format(entry.creditAmount) : '-',
                        style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: Delete Permanently Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          icon: const Icon(Icons.delete_forever_rounded, size: 16),
          label: Text(
            isInvoice ? 'Delete Invoice' : 'Delete ${detail.voucher.voucherType}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.surface,
                title: Text(
                  'Permanently Delete ${detail.voucher.voucherType}?',
                  style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                ),
                content: Text(
                  'Are you sure you want to permanently delete ${detail.voucher.voucherType} #${detail.voucher.voucherNumber}?\n\n'
                  '• This voucher will be completely removed from the database.\n'
                  '• Stock quantities and inventory history will be restored.\n'
                  '• Customer and ledger balances will be reversed.\n\n'
                  'This action cannot be undone.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Delete Permanently', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(ctx, true),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              if (!context.mounted) return;
              try {
                final engine = Provider.of<AccountingEngine>(context, listen: false);
                await engine.deleteVoucher(detail.voucher.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  onDeleted?.call();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.error,
                      content: Text('${detail.voucher.voucherType} #${detail.voucher.voucherNumber} permanently deleted.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.error, content: Text('Failed to delete voucher: $e')),
                  );
                }
              }
            }
          },
        ),

        // Right Actions
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              child: const Text('Close', style: TextStyle(color: AppColors.textMuted)),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 12),
            if (isInvoice) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.preview_rounded, size: 16),
                label: const Text('Print Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final db = Provider.of<AppDatabase>(context, listen: false);
                  final fy = FinancialYearService.getFinancialYear(detail.voucher.date);
                  
                  double subtotal = 0.0;
                  for (final st in detail.stockTransactions) {
                    if (!st.tx.isReplacement) subtotal += (st.tx.quantity.abs() * st.tx.rate);
                  }
                  double grandTotal = 0.0;
                  for (final e in detail.entries) {
                    if (e.ledgerId == detail.contactLedger.id) {
                      grandTotal = e.debitAmount > 0 ? e.debitAmount : e.creditAmount;
                    }
                  }

                  final viewModel = InvoiceViewModel(
                    voucherNumber: detail.voucher.voucherNumber,
                    voucherType: detail.voucher.voucherType,
                    financialYear: fy,
                    date: detail.voucher.date,
                    partyName: detail.contactLedger.name,
                    partyAddress: detail.contactLedger.address ?? '',
                    partyTaxNumber: detail.contactLedger.taxNumber ?? '',
                    partyPhone: detail.contactLedger.phone,
                    items: detail.stockTransactions.map((st) => InvoiceItemRow(
                      itemName: st.itemName,
                      quantity: st.tx.quantity.abs(),
                      rate: st.tx.rate,
                      amount: st.tx.isReplacement ? 0.0 : (st.tx.quantity.abs() * st.tx.rate),
                      isReplacement: st.tx.isReplacement,
                    )).toList(),
                    subtotal: subtotal,
                    discount: detail.voucher.discountAmount,
                    cgst: 0.0,
                    sgst: 0.0,
                    grandTotal: grandTotal,
                    narration: detail.voucher.narration ?? '',
                  );

                  await PrintPreviewDialog.show(context, db: db, invoice: viewModel);
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceSecondary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  side: const BorderSide(color: AppColors.borderStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Alter / Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCreationPage(existingVoucher: detail.voucher),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                icon: const Icon(Icons.print_rounded, size: 16),
                label: const Text('Reprint', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  final db = Provider.of<AppDatabase>(context, listen: false);
                  final fy = FinancialYearService.getFinancialYear(detail.voucher.date);

                  double subtotal = 0.0;
                  for (final st in detail.stockTransactions) {
                    if (!st.tx.isReplacement) subtotal += (st.tx.quantity.abs() * st.tx.rate);
                  }
                  double grandTotal = 0.0;
                  for (final e in detail.entries) {
                    if (e.ledgerId == detail.contactLedger.id) {
                      grandTotal = e.debitAmount > 0 ? e.debitAmount : e.creditAmount;
                    }
                  }

                  final viewModel = InvoiceViewModel(
                    voucherNumber: detail.voucher.voucherNumber,
                    voucherType: detail.voucher.voucherType,
                    financialYear: fy,
                    date: detail.voucher.date,
                    partyName: detail.contactLedger.name,
                    partyAddress: detail.contactLedger.address ?? '',
                    partyTaxNumber: detail.contactLedger.taxNumber ?? '',
                    partyPhone: detail.contactLedger.phone,
                    items: detail.stockTransactions.map((st) => InvoiceItemRow(
                      itemName: st.itemName,
                      quantity: st.tx.quantity.abs(),
                      rate: st.tx.rate,
                      amount: st.tx.isReplacement ? 0.0 : (st.tx.quantity.abs() * st.tx.rate),
                      isReplacement: st.tx.isReplacement,
                    )).toList(),
                    subtotal: subtotal,
                    discount: detail.voucher.discountAmount,
                    cgst: 0.0,
                    sgst: 0.0,
                    grandTotal: grandTotal,
                    narration: detail.voucher.narration ?? '',
                  );

                  await InvoicePrinter.printInvoice(
                    context: context,
                    db: db,
                    invoice: viewModel,
                  );
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}
