import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/database.dart';
import 'core/accounting_engine.dart';
import 'core/audit_log_service.dart';
import 'core/backup_service.dart';
import 'core/database_diagnostic_service.dart';
import 'core/business_profile_service.dart';
import 'core/data_exchange_service.dart';
import 'core/pdf_export_service.dart';
import 'ui/theme/app_theme.dart';
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
  final auditLog = AuditLogService(database);
  final backupService = BackupService(database, auditLogService: auditLog);
  final diagnosticService = DatabaseDiagnosticService(database, backupService);
  final profileService = BusinessProfileService(database);
  final pdfService = PdfExportService(database);
  final exchangeService = DataExchangeService(database);

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        Provider<AccountingEngine>.value(value: engine),
        Provider<AuditLogService>.value(value: auditLog),
        Provider<BackupService>.value(value: backupService),
        Provider<DatabaseDiagnosticService>.value(value: diagnosticService),
        ChangeNotifierProvider<BusinessProfileService>.value(value: profileService),
        Provider<PdfExportService>.value(value: pdfService),
        Provider<DataExchangeService>.value(value: exchangeService),
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
      theme: AppTheme.lightTheme,
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
          Sidebar(
            currentIndex: _currentIndex,
            onTap: _onNavigate,
          ),
          Expanded(
            child: activePage,
          ),
        ],
      ),
    );
  }
}
