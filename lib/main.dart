import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'core/accounting_engine.dart';
import 'ui/widgets/sidebar.dart';
import 'ui/dashboard_page.dart';
import 'ui/ledger_list_page.dart';
import 'ui/stock_summary_page.dart';
import 'ui/invoice_creation_page.dart';
import 'ui/payment_receipt_page.dart';
import 'ui/report_viewer_page.dart';
import 'ui/data_exchange_page.dart';
import 'ui/settings_page.dart';
import 'ui/security_lock_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  final engine = AccountingEngine(database);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<AccountingEngine>.value(value: engine),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally Ledger Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.indigoAccent,
        colorScheme: ColorScheme.dark(
          primary: Colors.indigoAccent,
          secondary: Colors.purpleAccent,
          surface: const Color(0xFF1E2235),
          error: Colors.redAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF161928),
        useMaterial3: true,
        fontFamily: 'Segoe UI', // Clean, professional sans-serif on Windows/macOS
      ),
      home: const SecurityLockPage(),
    );
  }
}

class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({super.key});

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  int _currentIndex = 0;

  void _onNavigate(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget activePage;
    
    switch (_currentIndex) {
      case 0:
        activePage = DashboardPage(onNavigate: _onNavigate);
        break;
      case 1:
        activePage = const LedgerListPage();
        break;
      case 2:
        activePage = const StockSummaryPage();
        break;
      case 3:
        activePage = const InvoiceCreationPage();
        break;
      case 4:
        activePage = const PaymentReceiptPage();
        break;
      case 5:
        activePage = const ReportViewerPage();
        break;
      case 6:
        activePage = const DataExchangePage();
        break;
      case 7:
        activePage = const SettingsPage();
        break;
      default:
        activePage = DashboardPage(onNavigate: _onNavigate);
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar Left
          Sidebar(
            currentIndex: _currentIndex,
            onTap: _onNavigate,
          ),
          // Active screen right
          Expanded(
            child: activePage,
          ),
        ],
      ),
    );
  }
}
