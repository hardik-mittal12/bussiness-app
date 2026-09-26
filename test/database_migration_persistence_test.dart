import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/business_profile_service.dart';
import 'package:tally_ledger_desktop/data/database.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tally_migration_test_');
    dbFile = File('${tempDir.path}/test_migration.sqlite');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Database persists across app restarts and retains all data', () async {
    // 1. First Launch: Open and seed data
    {
      final db = AppDatabase(NativeDatabase(dbFile));
      final engine = AccountingEngine(db);
      final profileService = BusinessProfileService(db);

      // Create a customer
      await db.into(db.ledgers).insert(LedgersCompanion.insert(
        id: 'cust_persist_1',
        name: 'Persistent Customer Ltd',
        groupId: 'debtors',
        phone: const drift.Value('+91 9988776655'),
        address: const drift.Value('100 Industrial Area'),
      ));

      // Create a stock item
      await db.into(db.stockItems).insert(StockItemsCompanion.insert(
        id: 'item_persist_1',
        name: 'Heavy Duty Cable',
        openingQuantity: const drift.Value(50.0),
        openingRate: const drift.Value(120.0),
        salesRate: const drift.Value(180.0),
        purchaseRate: const drift.Value(120.0),
        unitOfMeasure: const drift.Value('MTR'),
      ));

      // Post a sales invoice
      await engine.createVoucher(
        voucherNumber: 'INV-2026-PERSIST-1',
        voucherType: 'Sales',
        date: DateTime(2026, 4, 15),
        entries: [
          VoucherEntriesCompanion.insert(
            id: 'e_p1',
            voucherId: '',
            ledgerId: 'cust_persist_1',
            debitAmount: const drift.Value(3600.0),
            creditAmount: const drift.Value(0.0),
          ),
          VoucherEntriesCompanion.insert(
            id: 'e_p2',
            voucherId: '',
            ledgerId: 'sales',
            debitAmount: const drift.Value(0.0),
            creditAmount: const drift.Value(3600.0),
          ),
        ],
        stockTransactions: [
          StockTransactionsCompanion.insert(
            id: 'st_p1',
            voucherId: '',
            stockItemId: 'item_persist_1',
            quantity: 20.0,
            rate: 180.0,
            transactionType: 'OUT',
          ),
        ],
      );

      // Update business profile
      await profileService.updateProfile(
        companyName: 'Persistent Enterprises Inc',
        address: '42 Silicon Avenue, Sector 5',
        phone: '+91 1122334455',
        email: 'billing@persistent.com',
        taxNumber: '07AAAAA1234A1Z5',
        bankDetails: 'State Bank, A/C: 1234567890, IFSC: SBIN0001234',
        termsAndConditions: 'Payment due in 15 days.',
      );

      await db.close();
    }

    // Verify database file was written to disk and has content
    expect(dbFile.existsSync(), isTrue);
    expect(dbFile.lengthSync(), greaterThan(0));

    // 2. Second Launch: Reopen the same database file (simulating app restart)
    {
      final db2 = AppDatabase(NativeDatabase(dbFile));
      final engine2 = AccountingEngine(db2);
      final profileService2 = BusinessProfileService(db2);

      // Verify schema version is intact
      expect(db2.schemaVersion, equals(5));

      // Verify customer exists with intact data
      final cust = await (db2.select(db2.ledgers)..where((t) => t.id.equals('cust_persist_1'))).getSingleOrNull();
      expect(cust, isNotNull);
      expect(cust!.name, equals('Persistent Customer Ltd'));
      expect(cust.phone, equals('+91 9988776655'));
      expect(cust.address, equals('100 Industrial Area'));

      // Verify stock item exists and quantity reflects previous sales
      final stockSummary = await engine2.getStockSummaryForItem('item_persist_1');
      expect(stockSummary.quantity, equals(30.0)); // 50 - 20 = 30

      // Verify customer ledger balance reflects the invoice
      final balance = await engine2.getLedgerBalance('cust_persist_1');
      expect(balance, equals(3600.0));

      // Verify business profile survived restart
      final profile = await profileService2.getProfile();
      expect(profile.companyName, equals('Persistent Enterprises Inc'));
      expect(profile.address, equals('42 Silicon Avenue, Sector 5'));
      expect(profile.phone, equals('+91 1122334455'));
      expect(profile.email, equals('billing@persistent.com'));
      expect(profile.taxNumber, equals('07AAAAA1234A1Z5'));

      await db2.close();
    }
  });

  test('Database correctly runs v4 -> v5 migration and preserves existing records', () async {
    // 1. Create a simulated v4 database directly via sqlite3
    {
      final rawDb = sqlite3.open(dbFile.path);

      // Create v4 schema tables
      rawDb.execute('CREATE TABLE account_groups (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL UNIQUE, primary_group TEXT NOT NULL);');
      rawDb.execute('CREATE TABLE ledgers (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL UNIQUE, group_id TEXT NOT NULL, opening_balance REAL NOT NULL DEFAULT 0.0, phone TEXT, address TEXT, email TEXT, tax_number TEXT, updated_at INTEGER NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0);');
      rawDb.execute('CREATE TABLE stock_items (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL UNIQUE, sku TEXT, unit_of_measure TEXT NOT NULL DEFAULT \'PCS\', opening_quantity REAL NOT NULL DEFAULT 0.0, opening_rate REAL NOT NULL DEFAULT 0.0, purchase_rate REAL NOT NULL DEFAULT 0.0, sales_rate REAL NOT NULL DEFAULT 0.0, updated_at INTEGER NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0);');
      rawDb.execute('CREATE TABLE vouchers (id TEXT NOT NULL PRIMARY KEY, voucher_number TEXT NOT NULL, voucher_type TEXT NOT NULL, financial_year TEXT NOT NULL, date INTEGER NOT NULL, narration TEXT, reference_number TEXT, status TEXT DEFAULT \'POSTED\', updated_at INTEGER NOT NULL, is_synced INTEGER NOT NULL DEFAULT 0);');
      rawDb.execute('CREATE TABLE voucher_entries (id TEXT NOT NULL PRIMARY KEY, voucher_id TEXT NOT NULL, ledger_id TEXT NOT NULL, debit_amount REAL NOT NULL DEFAULT 0.0, credit_amount REAL NOT NULL DEFAULT 0.0);');
      rawDb.execute('CREATE TABLE stock_transactions (id TEXT NOT NULL PRIMARY KEY, voucher_id TEXT NOT NULL, stock_item_id TEXT NOT NULL, quantity REAL NOT NULL, rate REAL NOT NULL, transaction_type TEXT NOT NULL);');
      rawDb.execute('CREATE TABLE business_profiles (id TEXT NOT NULL PRIMARY KEY, company_name TEXT NOT NULL, address TEXT, phone TEXT, email TEXT, tax_number TEXT, bank_details TEXT, terms_and_conditions TEXT, is_active INTEGER NOT NULL DEFAULT 1, updated_at INTEGER NOT NULL);');
      rawDb.execute('CREATE TABLE sync_metadata (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL, updated_at INTEGER NOT NULL);');
      rawDb.execute('CREATE TABLE invoice_sequences (id TEXT NOT NULL PRIMARY KEY, current_sequence INTEGER NOT NULL DEFAULT 0, updated_at INTEGER NOT NULL);');
      rawDb.execute('CREATE TABLE audit_logs (id TEXT NOT NULL PRIMARY KEY, action TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL, details TEXT, timestamp INTEGER NOT NULL);');

      // Set user_version to 4
      rawDb.execute('PRAGMA user_version = 4;');

      // Insert pre-migration records
      rawDb.execute('INSERT INTO account_groups VALUES (\'debtors\', \'Sundry Debtors\', \'Assets\');');
      rawDb.execute('INSERT INTO account_groups VALUES (\'sales_accounts\', \'Sales Accounts\', \'Revenue\');');
      rawDb.execute('INSERT INTO ledgers VALUES (\'cust_v4\', \'Old Customer v4\', \'debtors\', 0.0, \'9876543210\', \'Old Address\', \'old@v4.com\', \'27ABCDE1234F1Z5\', 1700000000, 0);');
      rawDb.execute('INSERT INTO stock_items VALUES (\'item_v4\', \'Old Product v4\', \'SKU-001\', \'PCS\', 100.0, 10.0, 10.0, 15.0, 1700000000, 0);');
      rawDb.execute('INSERT INTO business_profiles VALUES (\'default\', \'Existing Business v4\', \'v4 Street\', \'123456\', \'biz@v4.com\', \'TAX-v4\', \'Bank-v4\', \'Terms-v4\', 1, 1700000000);');

      rawDb.dispose();
    }

    // 2. Open with v5 AppDatabase — trigger migration
    {
      final appDb = AppDatabase(NativeDatabase(dbFile));

      // Verify migration completed to schemaVersion 5
      expect(appDb.schemaVersion, equals(5));

      // Verify v4 customer survived and new v5 column is_deleted defaulted to false
      final cust = await (appDb.select(appDb.ledgers)..where((t) => t.id.equals('cust_v4'))).getSingle();
      expect(cust.name, equals('Old Customer v4'));
      expect(cust.isDeleted, isFalse);

      // Verify v4 stock item survived
      final item = await (appDb.select(appDb.stockItems)..where((t) => t.id.equals('item_v4'))).getSingle();
      expect(item.name, equals('Old Product v4'));
      expect(item.openingQuantity, equals(100.0));

      // Verify business profile survived and new v5 logo_path column exists and is null
      final profile = await (appDb.select(appDb.businessProfiles)..where((t) => t.id.equals('default'))).getSingle();
      expect(profile.companyName, equals('Existing Business v4'));
      expect(profile.logoPath, isNull);

      await appDb.close();
    }
  });
}
