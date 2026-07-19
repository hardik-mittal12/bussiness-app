import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'path_resolver.dart';

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
  DateTimeColumn get date => dateTime()();
  TextColumn get narration => text().nullable()();
  TextColumn get referenceNumber => text().nullable()();
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

  @override
  Set<Column> get primaryKey => {id};
}

// 7. Sync Metadata table (tracks timestamps)
class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [
  AccountGroups,
  Ledgers,
  StockItems,
  Vouchers,
  VoucherEntries,
  StockTransactions,
  SyncMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'tally_ledger',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
      native: DriftNativeOptions(
        databasePath: () => getCustomDatabasePath('tally_ledger'),
      ),
    );
  }

  // Define database creation callbacks to seed default data
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(syncMetadata);
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
        },
      );
}
