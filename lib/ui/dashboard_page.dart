import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import 'package:intl/intl.dart';
import 'theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<int> onNavigate;

  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Future<Map<String, dynamic>> _dashboardDataFuture;
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '₹ ', decimalDigits: 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    _dashboardDataFuture = _loadDashboardData(engine);
  }

  Future<Map<String, dynamic>> _loadDashboardData(AccountingEngine engine) async {
    final bs = await engine.getBalanceSheetReport();
    final pl = await engine.getProfitLossReport();
    final stock = await engine.getStockSummary();

    // Find items with low stock (quantity <= 5)
    final lowStockItems = stock.where((item) => item.quantity <= 5).toList();

    return {
      'balanceSheet': bs,
      'profitLoss': pl,
      'lowStock': lowStockItems,
      'stockSummary': stock,
    };
  }

  void _refresh() {
    final engine = Provider.of<AccountingEngine>(context, listen: false);
    setState(() {
      _dashboardDataFuture = _loadDashboardData(engine);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Financial Overview Dashboard',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _refresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading dashboard: ${snapshot.error}',
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final data = snapshot.data!;
          final BalanceSheetReport bs = data['balanceSheet'];
          final ProfitLossReport pl = data['profitLoss'];
          final List<StockStatus> lowStock = data['lowStock'];

          final double netCashBank = bs.cashBalance + bs.bankBalance;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Core Stat Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          title: 'Cash & Bank Balance',
                          amount: netCashBank,
                          icon: Icons.account_balance_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Receivables (Customers)',
                          amount: bs.sundryDebtors,
                          icon: Icons.trending_up_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF065F46), Color(0xFF059669)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          title: 'Payables (Suppliers)',
                          amount: bs.sundryCreditors,
                          icon: Icons.trending_down_rounded,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF991B1B), Color(0xFFDC2626)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  // Row 2: Performance metrics and quick actions
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Financial Summary
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Performance Summary (This Period)',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildRowDetail('Total Sales', pl.salesValue, AppColors.success),
                              const Divider(color: AppColors.border, height: 20),
                              _buildRowDetail('Total Purchase', pl.purchaseValue, AppColors.warning),
                              const Divider(color: AppColors.border, height: 20),
                              _buildRowDetail('Direct & Indirect Expenses', pl.directExpenses + pl.indirectExpenses, AppColors.error),
                              const Divider(color: AppColors.border, height: 20),
                              _buildRowDetail('Gross Profit', pl.grossProfit, const Color(0xFF0D9488)),
                              const Divider(color: AppColors.border, height: 20),
                              _buildRowDetail(
                                'Net Profit / Loss',
                                pl.netProfit,
                                pl.netProfit >= 0 ? AppColors.success : AppColors.error,
                                highlight: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),

                      // Quick Actions
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActionButton(
                                    label: 'Create Sale Bill',
                                    icon: Icons.add_shopping_cart_rounded,
                                    color: const Color(0xFF2563EB),
                                    bgColor: const Color(0xFFEFF6FF),
                                    onPressed: () => widget.onNavigate(3), // Index 3 is Sales & Purchases
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'Receive Payment',
                                    icon: Icons.call_received_rounded,
                                    color: const Color(0xFF059669),
                                    bgColor: const Color(0xFFECFDF5),
                                    onPressed: () => widget.onNavigate(4), // Index 4 is Receipts & Payments
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'Add Purchase Bill',
                                    icon: Icons.add_box_rounded,
                                    color: const Color(0xFFD97706),
                                    bgColor: const Color(0xFFFFFBEB),
                                    onPressed: () => widget.onNavigate(3),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'View Balance Sheet',
                                    icon: Icons.account_balance_wallet_rounded,
                                    color: const Color(0xFF7C3AED),
                                    bgColor: const Color(0xFFF5F3FF),
                                    onPressed: () => widget.onNavigate(5), // Index 5 is Financial Reports
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Row 3: Inventory Alerts
                  Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Low Stock Alerts',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (lowStock.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.errorBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${lowStock.length} Items Low',
                                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (lowStock.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'All stock items are at healthy levels.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lowStock.length > 5 ? 5 : lowStock.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.border, height: 12),
                            itemBuilder: (context, index) {
                              final item = lowStock[index];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Qty Left: ${item.quantity.toStringAsFixed(0)}',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${item.quantity <= 0 ? "Out of Stock" : "Reorder Soon"})',
                                        style: TextStyle(
                                          color: item.quantity <= 0 ? AppColors.error : AppColors.warning,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required double amount,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 0,
            child: Icon(
              icon,
              color: Colors.white.withValues(alpha: 0.18),
              size: 44,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _currencyFormat.format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRowDetail(String title, double amount, Color color, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            fontSize: highlight ? 14.5 : 13.5,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 15.5 : 13.5,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: color.withValues(alpha: 0.25), width: 1),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
