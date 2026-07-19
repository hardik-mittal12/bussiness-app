import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/accounting_engine.dart';
import '../data/database.dart';
import 'package:intl/intl.dart';

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
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFF161928), // Sleek body dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Financial Overview Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _refresh,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigoAccent));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading dashboard: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final data = snapshot.data!;
          final BalanceSheetReport bs = data['balanceSheet'];
          final ProfitLossReport pl = data['profitLoss'];
          final List<StockStatus> lowStock = data['lowStock'];
          final List<StockStatus> stock = data['stockSummary'];

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
                            colors: [Color(0xFF3A47D5), Color(0xFF00D2FF)],
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
                            colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
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
                            colors: [Color(0xFFeb307a), Color(0xFFfe7a15)],
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
                            color: const Color(0xFF1E2235),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Performance Summary (This Period)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildRowDetail('Total Sales', pl.salesValue, Colors.greenAccent),
                              const Divider(color: Colors.white10, height: 20),
                              _buildRowDetail('Total Purchase', pl.purchaseValue, Colors.orangeAccent),
                              const Divider(color: Colors.white10, height: 20),
                              _buildRowDetail('Direct & Indirect Expenses', pl.directExpenses + pl.indirectExpenses, Colors.redAccent),
                              const Divider(color: Colors.white10, height: 20),
                              _buildRowDetail('Gross Profit', pl.grossProfit, Colors.tealAccent),
                              const Divider(color: Colors.white10, height: 20),
                              _buildRowDetail(
                                'Net Profit / Loss',
                                pl.netProfit,
                                pl.netProfit >= 0 ? Colors.greenAccent : Colors.redAccent,
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
                                color: const Color(0xFF1E2235),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Quick Actions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildActionButton(
                                    label: 'Create Sale Bill',
                                    icon: Icons.add_shopping_cart_rounded,
                                    color: Colors.indigoAccent,
                                    onPressed: () => widget.onNavigate(3), // Index 3 is Sales & Purchases
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'Receive Payment',
                                    icon: Icons.call_received_rounded,
                                    color: Colors.teal,
                                    onPressed: () => widget.onNavigate(4), // Index 4 is Receipts & Payments
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'Add Purchase Bill',
                                    icon: Icons.add_box_rounded,
                                    color: Colors.deepOrangeAccent,
                                    onPressed: () => widget.onNavigate(3),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildActionButton(
                                    label: 'View Balance Sheet',
                                    icon: Icons.account_balance_wallet_rounded,
                                    color: Colors.purpleAccent,
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
                      color: const Color(0xFF1E2235),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (lowStock.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${lowStock.length} Items Low',
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
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
                              style: TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: lowStock.length > 5 ? 5 : lowStock.length,
                            separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 12),
                            itemBuilder: (context, index) {
                              final item = lowStock[index];
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.name,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Qty Left: ${item.quantity.toStringAsFixed(0)} ${item.averageRate > 0 ? '' : ''}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${item.quantity <= 0 ? "Out of Stock" : "Reorder Soon"})',
                                        style: TextStyle(
                                          color: item.quantity <= 0 ? Colors.redAccent : Colors.orangeAccent,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              color: Colors.white.withOpacity(0.15),
              size: 48,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _currencyFormat.format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
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
            color: highlight ? Colors.white : Colors.white70,
            fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
            fontSize: highlight ? 15 : 14,
          ),
        ),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: highlight ? 16 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.15),
          foregroundColor: color,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: color.withOpacity(0.3), width: 1),
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
