import 'package:drift/drift.dart';
import 'connection/connection.dart';
import 'path_resolver.dart';
import '../core/financial_year_service.dart';

part 'database.g.dart';

// 1. Account Groups table
class AccountGroups extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get primaryGroup => text()(); // e.g. 'Assets', 'Liabilities', 'Equity', 'Revenue', 'Expense'
  
  @override
  Set<Column> get primaryKey => {id};
}

// 2. Ledgers table (accounts like customers, suppliers, capital, bank, cash)
class Ledgers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get groupId => text().references(AccountGroups, #id)();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get taxNumber => text().nullable()(); // GSTIN, VAT, etc.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 3. Stock Items table (Inventory)
class StockItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get sku => text().nullable()();
  TextColumn get unitOfMeasure => text().withDefault(const Constant('PCS'))();
  RealColumn get openingQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get openingRate => real().withDefault(const Constant(0.0))();
  RealColumn get purchaseRate => real().withDefault(const Constant(0.0))();
  RealColumn get salesRate => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 4. Vouchers table (Transactions journal header)
class Vouchers extends Table {
  TextColumn get id => text()();
  TextColumn get voucherNumber => text()();
  TextColumn get voucherType => text()(); // 'Sales', 'Purchase', 'Receipt', 'Payment', 'Journal', 'Contra'
  TextColumn get financialYear => text().withDefault(const Constant('2025-26'))(); // e.g. '2025-26'
  DateTimeColumn get date => dateTime()();
  TextColumn get narration => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('POSTED'))(); // 'POSTED', 'CANCELLED', 'REVERSED', 'DRAFT'
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 5. Voucher Entries table (Double-Entry splits: posting debit/credit to ledgers)
class VoucherEntries extends Table {
  TextColumn get id => text()();
  TextColumn get voucherId => text().references(Vouchers, #id, onDelete: KeyAction.cascade)();
  TextColumn get ledgerId => text().references(Ledgers, #id)();
  RealColumn get debitAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditAmount => real().withDefault(const Constant(0.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// 6. Stock Transactions table (Inventory movements)
class StockTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get voucherId => text().references(Vouchers, #id, onDelete: KeyAction.cascade)();
  TextColumn get stockItemId => text().references(StockItems, #id)();
  RealColumn get quantity => real()(); // Positive for IN (Purchase), Negative for OUT (Sale)
  RealColumn get rate => real()();
  TextColumn get transactionType => text()(); // 'IN' / 'OUT'
  BoolColumn get isReplacement => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// 7. Sync Metadata table (tracks timestamps and key-value configuration)
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// 8. Invoice Sequences table (for atomic sequence generation)
class InvoiceSequences extends Table {
  TextColumn get id => text()(); // e.g. '2025-26:Sales'
  TextColumn get financialYear => text()(); // e.g. '2025-26'
  TextColumn get voucherType => text()(); // 'Sales', 'Purchase', etc.
  IntColumn get nextNumber => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {id};
}

// 9. Audit Logs table (for compliance & tracking changes)
class AuditLogs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get userDevice => text().withDefault(const Constant('Desktop'))();
  TextColumn get action => text()(); // 'CREATE', 'UPDATE', 'CANCEL', 'DELETE', 'BACKUP', 'RESTORE'
  TextColumn get entityType => text()(); // 'Voucher', 'StockItem', 'Ledger', etc.
  TextColumn get entityId => text()();
  TextColumn get oldValue => text().nullable()();
  TextColumn get newValue => text().nullable()();
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// 10. Business Profiles table (for company setup, address, GST, contact)
class BusinessProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get companyName => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get taxNumber => text().nullable()(); // GSTIN
  TextColumn get bankDetails => text().nullable()();
  TextColumn get termsAndConditions => text().nullable()();
  TextColumn get logoPath => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  AccountGroups,
  Ledgers,
  StockItems,
  Vouchers,
  VoucherEntries,
  StockTransactions,
  SyncMetadata,
  InvoiceSequences,
  AuditLogs,
  BusinessProfiles,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 5;

  static QueryExecutor _openConnection() => openConnection();

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Configure SQLite PRAGMAs for production reliability
          try {
            await customStatement('PRAGMA journal_mode = WAL;');
            await customStatement('PRAGMA synchronous = FULL;');
            await customStatement('PRAGMA foreign_keys = ON;');
            await customStatement('PRAGMA busy_timeout = 5000;');
          } catch (_) {}

          // Ensure critical performance indexes exist
          await customStatement('CREATE INDEX IF NOT EXISTS idx_vouchers_date ON vouchers (date DESC);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_vouchers_type_date ON vouchers (voucher_type, date);');
          await customStatement('DROP INDEX IF EXISTS idx_vouchers_no_type_fy;');
          await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS idx_vouchers_fy_type_no ON vouchers (financial_year, voucher_type, voucher_number);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ve_voucher ON voucher_entries (voucher_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ve_ledger ON voucher_entries (ledger_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_st_voucher ON stock_transactions (voucher_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_st_item ON stock_transactions (stock_item_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ledgers_group ON ledgers (group_id);');
          await customStatement('CREATE INDEX IF NOT EXISTS idx_ledgers_deleted ON ledgers (is_deleted);');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(syncMetadata);
          }
          if (from < 3) {
            await m.createTable(invoiceSequences);
            await m.createTable(auditLogs);
            await m.addColumn(vouchers, vouchers.status);
          }
          if (from < 4) {
            await m.addColumn(vouchers, vouchers.financialYear);
            await m.createTable(businessProfiles);

            // Safely calculate each voucher's financial year from date and check for uniqueness conflicts
            final allVouchers = await select(vouchers).get();
            final seen = <String>{};
            for (final v in allVouchers) {
              final fy = FinancialYearService.getFinancialYear(v.date);
              final key = '$fy:${v.voucherType}:${v.voucherNumber}';
              if (seen.contains(key)) {
                throw StateError('Duplicate (financialYear, voucherType, voucherNumber) combination found during migration: $key. Migration stopped safely.');
              }
              seen.add(key);
              await (update(vouchers)..where((t) => t.id.equals(v.id))).write(
                VouchersCompanion(financialYear: Value(fy)),
              );
            }
          }
          if (from < 5) {
            await m.addColumn(ledgers, ledgers.isDeleted);
            await m.addColumn(vouchers, vouchers.discountAmount);
            await m.addColumn(stockTransactions, stockTransactions.isReplacement);
            await m.addColumn(businessProfiles, businessProfiles.logoPath);
          }
        },
        onCreate: (m) async {
          await m.createAll();
          
          // Seed standard Account Groups
          final groups = [
            AccountGroupsCompanion.insert(id: 'equity', name: 'Capital Account', primaryGroup: 'Equity'),
            AccountGroupsCompanion.insert(id: 'current_assets', name: 'Current Assets', primaryGroup: 'Assets'),
            AccountGroupsCompanion.insert(id: 'cash_in_hand', name: 'Cash-in-hand', primaryGroup: 'Assets'),
            AccountGroupsCompanion.insert(id: 'bank_accounts', name: 'Bank Accounts', primaryGroup: 'Assets'),
            AccountGroupsCompanion.insert(id: 'debtors', name: 'Sundry Debtors (Customers)', primaryGroup: 'Assets'),
            AccountGroupsCompanion.insert(id: 'current_liabilities', name: 'Current Liabilities', primaryGroup: 'Liabilities'),
            AccountGroupsCompanion.insert(id: 'creditors', name: 'Sundry Creditors (Suppliers)', primaryGroup: 'Liabilities'),
            AccountGroupsCompanion.insert(id: 'duties_taxes', name: 'Duties & Taxes', primaryGroup: 'Liabilities'),
            AccountGroupsCompanion.insert(id: 'sales_accounts', name: 'Sales Accounts', primaryGroup: 'Revenue'),
            AccountGroupsCompanion.insert(id: 'direct_income', name: 'Direct Incomes', primaryGroup: 'Revenue'),
            AccountGroupsCompanion.insert(id: 'purchase_accounts', name: 'Purchase Accounts', primaryGroup: 'Expense'),
            AccountGroupsCompanion.insert(id: 'direct_expenses', name: 'Direct Expenses', primaryGroup: 'Expense'),
            AccountGroupsCompanion.insert(id: 'indirect_expenses', name: 'Indirect Expenses', primaryGroup: 'Expense'),
          ];

          for (final g in groups) {
            await into(accountGroups).insert(g);
          }

          // Seed standard Ledgers
          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'cash',
            name: 'Cash Ledger',
            groupId: 'cash_in_hand',
            openingBalance: const Value(0.0),
          ));

          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'profit_loss',
            name: 'Profit & Loss A/c',
            groupId: 'equity',
            openingBalance: const Value(0.0),
          ));

          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'sales',
            name: 'Sales Ledger',
            groupId: 'sales_accounts',
            openingBalance: const Value(0.0),
          ));

          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'purchase',
            name: 'Purchase Ledger',
            groupId: 'purchase_accounts',
            openingBalance: const Value(0.0),
          ));

          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'cgst',
            name: 'CGST Ledger',
            groupId: 'duties_taxes',
            openingBalance: const Value(0.0),
          ));

          await into(ledgers).insert(LedgersCompanion.insert(
            id: 'sgst',
            name: 'SGST Ledger',
            groupId: 'duties_taxes',
            openingBalance: const Value(0.0),
          ));

          // Seed default Business Profile
          await into(businessProfiles).insert(BusinessProfilesCompanion.insert(
            id: 'default',
            companyName: 'My Business Enterprise',
            address: const Value('123 Commercial Complex, Main Road'),
            phone: const Value('+91 9876543210'),
            email: const Value('info@mybusiness.com'),
            taxNumber: const Value('27AAAAA0000A1Z5'),
            bankDetails: const Value('HDFC Bank, A/C: 50200012345678, IFSC: HDFC0001234'),
            termsAndConditions: const Value('Goods once sold will not be taken back. Subject to local jurisdiction.'),
            isActive: const Value(true),
          ));
        },
      );
}
