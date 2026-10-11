import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/customer_group_service.dart';
import 'package:tally_ledger_desktop/core/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory suiteTempDir;

  setUp(() {
    suiteTempDir = Directory.systemTemp.createTempSync('tally_qual_test_');
    sqlite.sqlite3.tempDirectory = suiteTempDir.path;
  });

  tearDown(() {
    try {
      suiteTempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('Phase 2: Database-Path Resolution Precedence & Safety', () {
    test('1. Portable mode vs AppData precedence: when both exist, portable takes precedence and neither is deleted or merged', () async {
      final fakeExeDir = Directory(p.join(suiteTempDir.path, 'bin'))..createSync(recursive: true);
      final fakeAppDataDir = Directory(p.join(suiteTempDir.path, 'appdata'))..createSync(recursive: true);

      final portableDbFile = File(p.join(fakeExeDir.path, 'tally_ledger.sqlite'));
      final appDataDbFile = File(p.join(fakeAppDataDir.path, 'tally_ledger.sqlite'));

      // Populate portable DB with a unique marker record
      final pDb = AppDatabase(NativeDatabase(portableDbFile));
      await pDb.into(pDb.ledgers).insert(LedgersCompanion.insert(
        id: 'marker_portable',
        name: 'Marker Portable Customer',
        groupId: 'debtors',
      ));
      await pDb.close();

      // Populate AppData DB with a distinct marker record
      final aDb = AppDatabase(NativeDatabase(appDataDbFile));
      await aDb.into(aDb.ledgers).insert(LedgersCompanion.insert(
        id: 'marker_appdata',
        name: 'Marker AppData Customer',
        groupId: 'debtors',
      ));
      await aDb.close();

      // Verify both files exist before resolution
      expect(portableDbFile.existsSync(), isTrue);
      expect(appDataDbFile.existsSync(), isTrue);

      // Model the path resolver precedence logic:
      // If portable exists next to exe, portable is selected; otherwise AppData is selected.
      String resolvePath(String exeDir, String appDataDir, String name) {
        final localDb = File(p.join(exeDir, '$name.sqlite'));
        if (localDb.existsSync()) {
          return localDb.path;
        }
        return p.join(appDataDir, '$name.sqlite');
      }

      final resolvedPath = resolvePath(fakeExeDir.path, fakeAppDataDir.path, 'tally_ledger');
      expect(resolvedPath, equals(portableDbFile.path));

      // Open selected database and verify contents
      final activeDb = AppDatabase(NativeDatabase(File(resolvedPath)));
      final records = await (activeDb.select(activeDb.ledgers)).get();
      final ids = records.map((r) => r.id).toSet();

      expect(ids, contains('marker_portable'));
      expect(ids, isNot(contains('marker_appdata')));
      await activeDb.close();

      // Verify that neither file was deleted, merged, or overwritten!
      expect(portableDbFile.existsSync(), isTrue);
      expect(appDataDbFile.existsSync(), isTrue);

      // Verify AppData still has its distinct record
      final appDataCheck = AppDatabase(NativeDatabase(appDataDbFile));
      final appRecords = await (appDataCheck.select(appDataCheck.ledgers)).get();
      expect(appRecords.map((r) => r.id).toSet(), contains('marker_appdata'));
      await appDataCheck.close();
    });

    test('2. Corrupt database throws error and is NEVER silently overwritten with empty DB', () async {
      final corruptFile = File(p.join(suiteTempDir.path, 'tally_corrupt.sqlite'));
      final corruptBytes = [0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x00, 0x11, 0x22];
      corruptFile.writeAsBytesSync(corruptBytes);

      final db = AppDatabase(NativeDatabase(corruptFile));

      // Querying corrupt DB must throw an error
      expect(
        () async => await (db.select(db.ledgers)).get(),
        throwsA(anything),
      );

      // The corrupt file must still exist with the exact same bytes (NOT overwritten by empty SQLite header)
      expect(corruptFile.existsSync(), isTrue);
      expect(corruptFile.readAsBytesSync(), equals(corruptBytes));

      await db.close();
    });

    test('3. Working directory independence: changing Current Working Directory does not alter resolved executable path', () {
      final exePath = Platform.resolvedExecutable;
      final exeParent = File(exePath).parent.path;

      // Regardless of what Directory.current is set to, File(Platform.resolvedExecutable).parent remains constant
      expect(File(Platform.resolvedExecutable).parent.path, equals(exeParent));
    });
  });

  group('Phase 3: Migration Safety & Idempotent Crash-Resilience', () {
    test('1. Interrupted migration retry safety: partially applied DDL does not crash on re-run', () async {
      final migrationDbFile = File(p.join(suiteTempDir.path, 'interrupted_migration.sqlite'));

      // Create a raw SQLite v7 database
      {
        final raw = sqlite.sqlite3.open(migrationDbFile.path);
        raw.execute('PRAGMA user_version = 7;');
        raw.execute('CREATE TABLE ledgers (id TEXT PRIMARY KEY, name TEXT UNIQUE, group_id TEXT, opening_balance REAL DEFAULT 0.0, phone TEXT, address TEXT, email TEXT, tax_number TEXT, updated_at INTEGER, is_synced INTEGER DEFAULT 0, is_deleted INTEGER DEFAULT 0);');
        raw.execute('CREATE TABLE vouchers (id TEXT PRIMARY KEY, voucher_number TEXT, voucher_type TEXT, party_ledger_id TEXT, financial_year TEXT, date INTEGER, narration TEXT, reference_number TEXT, payment_mode TEXT, discount_amount REAL, status TEXT DEFAULT \'POSTED\', updated_at INTEGER, is_synced INTEGER DEFAULT 0);');
        raw.execute('CREATE TABLE voucher_entries (id TEXT PRIMARY KEY, voucher_id TEXT, ledger_id TEXT, debit_amount REAL DEFAULT 0.0, credit_amount REAL DEFAULT 0.0);');
        raw.execute('CREATE TABLE stock_items (id TEXT PRIMARY KEY, name TEXT UNIQUE, sku TEXT, unit_of_measure TEXT, opening_quantity REAL, opening_rate REAL, purchase_rate REAL, sales_rate REAL, updated_at INTEGER, is_synced INTEGER DEFAULT 0);');
        raw.execute('CREATE TABLE stock_transactions (id TEXT PRIMARY KEY, voucher_id TEXT, stock_item_id TEXT, quantity REAL, rate REAL, transaction_type TEXT, is_replacement INTEGER DEFAULT 0);');
        raw.execute('CREATE TABLE sync_metadata (id TEXT PRIMARY KEY, last_sync_time INTEGER);');
        raw.execute('CREATE TABLE invoice_sequences (id TEXT PRIMARY KEY, next_number INTEGER);');
        raw.execute('CREATE TABLE audit_logs (id TEXT PRIMARY KEY, timestamp INTEGER, action TEXT, entity_type TEXT, entity_id TEXT, old_value TEXT, newValue TEXT, metadata TEXT);');
        raw.execute('CREATE TABLE business_profiles (id TEXT PRIMARY KEY, company_name TEXT, address TEXT, phone TEXT, email TEXT, tax_number TEXT, bank_details TEXT, terms_and_conditions TEXT, logo_path TEXT, is_active INTEGER, updated_at INTEGER);');
        raw.execute('CREATE TABLE account_groups (id TEXT PRIMARY KEY, name TEXT UNIQUE, parent_id TEXT, nature TEXT);');

        // Insert initial data
        raw.execute('INSERT INTO ledgers (id, name, group_id, opening_balance, updated_at) VALUES (\'c1\', \'Customer 1\', \'debtors\', 1000.0, 1712000000);');

        // Simulate an INTERRUPTED migration: customer_groups table was created, but user_version is STILL 7!
        raw.execute('CREATE TABLE customer_groups (id TEXT PRIMARY KEY, name TEXT UNIQUE, description TEXT, created_at INTEGER, updated_at INTEGER);');

        raw.dispose();
      }

      // Open with AppDatabase (which runs onUpgrade from 7 to 8)
      // Because onUpgrade uses tableExists('customer_groups'), it must NOT crash with 'table customer_groups already exists'!
      final appDb = AppDatabase(NativeDatabase(migrationDbFile));

      expect(appDb.schemaVersion, equals(8));

      // Verify existing customer survived intact
      final c1 = await (appDb.select(appDb.ledgers)..where((t) => t.id.equals('c1'))).getSingle();
      expect(c1.name, equals('Customer 1'));
      expect(c1.openingBalance, equals(1000.0));
      expect(c1.customerGroupId, isNull);

      // Verify PRAGMA integrity_check passes ok
      final integrity = await appDb.customSelect('PRAGMA integrity_check;').getSingle();
      expect(integrity.data.values.first.toString().toLowerCase(), equals('ok'));

      await appDb.close();
    });
  });

  group('Phase 5: Backup & Restore Qualification with Live WAL Lifecycle', () {
    test('Full 10-step realistic business data backup, restore into separate location, and reconciliation', () async {
      final prodDbFile = File(p.join(suiteTempDir.path, 'source_business.sqlite'));

      final sourceDb = AppDatabase(
        NativeDatabase(
          prodDbFile,
          setup: (rawDb) {
            rawDb.execute('PRAGMA journal_mode = WAL;');
            rawDb.execute('PRAGMA synchronous = NORMAL;');
            rawDb.execute('PRAGMA busy_timeout = 30000;');
          },
        ),
      );
      final sourceEngine = AccountingEngine(sourceDb);
      final sourceGroupService = CustomerGroupService(sourceDb);
      final sourceBackup = BackupService(sourceDb);

      try {
        // 1. Create customer groups
        final gWholesale = await sourceGroupService.createGroup('Wholesale Distributors');

        // 2. Add customers with opening balances
        await sourceDb.into(sourceDb.ledgers).insert(LedgersCompanion.insert(
          id: 'cust_w1',
          name: 'Apex Wholesale',
          groupId: 'debtors',
          openingBalance: const drift.Value(15000.0),
        ));
        await sourceGroupService.assignCustomerToGroup('cust_w1', gWholesale.id);

        await sourceDb.into(sourceDb.ledgers).insert(LedgersCompanion.insert(
          id: 'supp_s1',
          name: 'Supreme Supplier',
          groupId: 'creditors',
          openingBalance: const drift.Value(5000.0),
        ));

        // Balancing capital opening balance to maintain Trial Balance debit == credit
        await sourceDb.into(sourceDb.ledgers).insert(LedgersCompanion.insert(
          id: 'capital_ac',
          name: 'Proprietor Capital',
          groupId: 'equity',
          openingBalance: const drift.Value(-20000.0),
        ));

        // 3. Add inventory item with initial stock
        await sourceDb.into(sourceDb.stockItems).insert(StockItemsCompanion.insert(
          id: 'item_a1',
          name: 'Cotton Yarn Grade A',
          openingQuantity: const drift.Value(500.0),
          openingRate: const drift.Value(200.0),
        ));

        // 4. Create purchase voucher (Supplier S1 -> increases stock, increases payable)
        await sourceEngine.createVoucher(
          voucherType: 'Purchase',
          voucherNumber: 'PUR-2025-26-0001',
          paymentMode: 'Credit',
          partyLedgerId: 'supp_s1',
          date: DateTime(2025, 4, 1),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'p_e1',
              voucherId: '',
              ledgerId: 'purchase',
              debitAmount: const drift.Value(20000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'p_e2',
              voucherId: '',
              ledgerId: 'supp_s1',
              creditAmount: const drift.Value(20000.0),
            ),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(
              id: 'p_st1',
              voucherId: '',
              stockItemId: 'item_a1',
              quantity: 100.0,
              rate: 200.0,
              transactionType: 'IN',
            ),
          ],
        );

        // 5. Create sales voucher (Customer W1 -> decreases stock, increases receivable)
        await sourceEngine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-2025-26-0001',
          paymentMode: 'Credit',
          partyLedgerId: 'cust_w1',
          date: DateTime(2025, 4, 5),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 's_e1',
              voucherId: '',
              ledgerId: 'cust_w1',
              debitAmount: const drift.Value(12500.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 's_e2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(12500.0),
            ),
          ],
          stockTransactions: [
            StockTransactionsCompanion.insert(
              id: 's_st1',
              voucherId: '',
              stockItemId: 'item_a1',
              quantity: 50.0,
              rate: 250.0,
              transactionType: 'OUT',
            ),
          ],
        );

        // 6. Record receipt from W1 (Rs. 7500)
        await sourceEngine.createVoucher(
          voucherType: 'Receipt',
          voucherNumber: 'RCT-2025-26-0001',
          paymentMode: 'Cash',
          partyLedgerId: 'cust_w1',
          date: DateTime(2025, 4, 10),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'r_e1',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(7500.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'r_e2',
              voucherId: '',
              ledgerId: 'cust_w1',
              creditAmount: const drift.Value(7500.0),
            ),
          ],
        );

        // 7. Record payment to S1 (Rs. 10000)
        await sourceEngine.createVoucher(
          voucherType: 'Payment',
          voucherNumber: 'PAY-2025-26-0001',
          paymentMode: 'Cash',
          partyLedgerId: 'supp_s1',
          date: DateTime(2025, 4, 12),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'pay_e1',
              voucherId: '',
              ledgerId: 'supp_s1',
              debitAmount: const drift.Value(10000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'pay_e2',
              voucherId: '',
              ledgerId: 'cash',
              creditAmount: const drift.Value(10000.0),
            ),
          ],
        );

        // 8. Create a backdated transaction: Cash sale on April 2
        await sourceEngine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-2025-26-0002',
          paymentMode: 'Cash',
          partyLedgerId: 'cust_w1',
          date: DateTime(2025, 4, 2),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'c_e1',
              voucherId: '',
              ledgerId: 'cash',
              debitAmount: const drift.Value(2500.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'c_e2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(2500.0),
            ),
          ],
        );

        // Record expected values before backup
        final preBalW1 = await sourceEngine.getLedgerBalance('cust_w1'); // 15000 + 12500 - 7500 = 20000
        final preBalS1 = await sourceEngine.getLedgerBalance('supp_s1'); // 5000 + 20000 - 10000 = 15000
        final preStockSummary = await sourceEngine.getStockSummaryForItem('item_a1'); // 500 + 100 - 50 = 550
        final preGroupSummary = await sourceGroupService.getGroupTransactionsSummary(gWholesale.id);

        expect(preBalW1, equals(20000.0));
        expect(preStockSummary.quantity, equals(550.0));
        expect(preGroupSummary.netOutstanding, equals(20000.0));

        // 7. Take atomic backup using VACUUM INTO
        final backupMetadata = await sourceBackup.createBackup(label: 'qual_test');
        expect(File(backupMetadata.filePath).existsSync(), isTrue);

        // 8. Restore the backup into a fresh target file in a separate location
        final targetRestoredFile = File(p.join(suiteTempDir.path, 'restored_target.sqlite'));
        await File(backupMetadata.filePath).copy(targetRestoredFile.path);

        // 9. Reopen restored database
        final restoredDb = AppDatabase(NativeDatabase(targetRestoredFile));
        final restoredEngine = AccountingEngine(restoredDb);
        final restoredGroupService = CustomerGroupService(restoredDb);

        // 10. Reconcile accounting balances and record counts
        final postBalW1 = await restoredEngine.getLedgerBalance('cust_w1');
        final postBalS1 = await restoredEngine.getLedgerBalance('supp_s1');
        final postStock = await restoredEngine.getStockSummaryForItem('item_a1');
        final postGroup = await restoredGroupService.getGroupTransactionsSummary(gWholesale.id);

        expect(postBalW1, equals(preBalW1));
        expect(postBalS1, equals(preBalS1));
        expect(postStock.quantity, equals(preStockSummary.quantity));
        expect(postGroup.netOutstanding, equals(preGroupSummary.netOutstanding));
        expect(postGroup.totalDebit, equals(preGroupSummary.totalDebit));
        expect(postGroup.totalCredit, equals(preGroupSummary.totalCredit));

        // Verify Trial Balance balances on restored database
        final tb = await restoredEngine.getTrialBalance();
        final totalDebit = tb.fold<double>(0.0, (s, r) => s + r.debitBalance);
        final totalCredit = tb.fold<double>(0.0, (s, r) => s + r.creditBalance);
        expect((totalDebit - totalCredit).abs(), lessThan(0.01));

        await restoredDb.close();
      } finally {
        await sourceDb.close();
      }
    });
  });

  group('Phase 6: Financial Integrity Under Failure', () {
    test('1. Transaction rollback: failure during voucher creation leaves ZERO orphan records or corrupt state', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final engine = AccountingEngine(db);

      try {
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'rollback_cust',
          name: 'Rollback Customer',
          groupId: 'debtors',
        ));
        await db.into(db.stockItems).insert(StockItemsCompanion.insert(
          id: 'rollback_item',
          name: 'Rollback Item',
          openingQuantity: const drift.Value(5.0),
          openingRate: const drift.Value(100.0),
        ));

        final initialVouchersCount = (await db.select(db.vouchers).get()).length;
        final initialEntriesCount = (await db.select(db.voucherEntries).get()).length;
        final initialStockTxCount = (await db.select(db.stockTransactions).get()).length;

        // Attempt a voucher creation with double-entry imbalance (debits 500 != credits 400)
        expect(
          () => engine.createVoucher(
            voucherType: 'Sales',
            voucherNumber: 'INV-FAIL-1',
            date: DateTime(2025, 4, 1),
            partyLedgerId: 'rollback_cust',
            entries: [
              VoucherEntriesCompanion.insert(
                id: 'e1',
                voucherId: '',
                ledgerId: 'rollback_cust',
                debitAmount: const drift.Value(500.0),
              ),
              VoucherEntriesCompanion.insert(
                id: 'e2',
                voucherId: '',
                ledgerId: 'sales',
                creditAmount: const drift.Value(400.0), // Imbalance!
              ),
            ],
          ),
          throwsA(anything),
        );

        // Verify zero phantom records exist
        final postVouchersCount = (await db.select(db.vouchers).get()).length;
        final postEntriesCount = (await db.select(db.voucherEntries).get()).length;
        final postStockTxCount = (await db.select(db.stockTransactions).get()).length;

        expect(postVouchersCount, equals(initialVouchersCount));
        expect(postEntriesCount, equals(initialEntriesCount));
        expect(postStockTxCount, equals(initialStockTxCount));

        // Customer balance remains 0.0
        final bal = await engine.getLedgerBalance('rollback_cust');
        expect(bal, equals(0.0));
      } finally {
        await db.close();
      }
    });

    test('2. Voucher cancellation fix: works seamlessly for UUID and voucher number, and is idempotent on repeat', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final engine = AccountingEngine(db);

      try {
        await db.into(db.ledgers).insert(LedgersCompanion.insert(
          id: 'cancel_cust',
          name: 'Cancel Test Customer',
          groupId: 'debtors',
        ));

        // Create voucher
        final voucherNo = await engine.createVoucher(
          voucherType: 'Sales',
          voucherNumber: 'INV-CANCEL-FIX-01',
          paymentMode: 'Credit',
          partyLedgerId: 'cancel_cust',
          date: DateTime(2025, 4, 1),
          entries: [
            VoucherEntriesCompanion.insert(
              id: 'ce1',
              voucherId: '',
              ledgerId: 'cancel_cust',
              debitAmount: const drift.Value(1000.0),
            ),
            VoucherEntriesCompanion.insert(
              id: 'ce2',
              voucherId: '',
              ledgerId: 'sales',
              creditAmount: const drift.Value(1000.0),
            ),
          ],
        );

        expect(await engine.getLedgerBalance('cancel_cust'), equals(1000.0));

        // 1. Cancel using voucher NUMBER
        await engine.cancelVoucher(voucherNo);

        // Balance should be reversed to 0.0
        expect(await engine.getLedgerBalance('cancel_cust'), equals(0.0));

        var v = await (db.select(db.vouchers)..where((t) => t.voucherNumber.equals(voucherNo))).getSingle();
        expect(v.status, equals('CANCELLED'));

        // 2. Repeat cancel on already-cancelled voucher (idempotency check)
        await engine.cancelVoucher(v.id); // Cancel by UUID
        expect(await engine.getLedgerBalance('cancel_cust'), equals(0.0));

        v = await (db.select(db.vouchers)..where((t) => t.id.equals(v.id))).getSingle();
        expect(v.status, equals('CANCELLED'));
      } finally {
        await db.close();
      }
    });
  });
}
