import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tally_ledger_desktop/core/data_exchange_service.dart';
import 'package:tally_ledger_desktop/data/database.dart';

void main() {
  late AppDatabase sourceDb;
  late AppDatabase targetDb;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tally_full_restore_test_');
    sourceDb = AppDatabase(NativeDatabase.memory());
    targetDb = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await sourceDb.close();
    await targetDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'full restore imports all voucher types into the active database',
    () async {
      await sourceDb
          .into(sourceDb.ledgers)
          .insert(
            LedgersCompanion.insert(
              id: 'customer',
              name: 'Customer',
              groupId: 'debtors',
            ),
          );
      await sourceDb
          .into(sourceDb.stockItems)
          .insert(StockItemsCompanion.insert(id: 'item', name: 'Item'));
      const voucherTypes = ['Sales', 'Purchase', 'Receipt', 'Payment'];
      for (var index = 0; index < voucherTypes.length; index++) {
        final voucherId = 'voucher_$index';
        await sourceDb
            .into(sourceDb.vouchers)
            .insert(
              VouchersCompanion.insert(
                id: voucherId,
                voucherNumber: 'V-${index + 1}',
                voucherType: voucherTypes[index],
                date: DateTime(2026, 1, index + 1),
              ),
            );
        await sourceDb
            .into(sourceDb.voucherEntries)
            .insert(
              VoucherEntriesCompanion.insert(
                id: 'entry_$index',
                voucherId: voucherId,
                ledgerId: 'customer',
                debitAmount: drift.Value(index + 1.0),
              ),
            );
        if (index < 2) {
          await sourceDb
              .into(sourceDb.stockTransactions)
              .insert(
                StockTransactionsCompanion.insert(
                  id: 'stock_$index',
                  voucherId: voucherId,
                  stockItemId: 'item',
                  quantity: index == 0 ? -1.0 : 1.0,
                  rate: 100.0,
                  transactionType: index == 0 ? 'OUT' : 'IN',
                ),
              );
        }
      }

      final snapshotPath =
          '${tempDir.path}${Platform.pathSeparator}snapshot.sqlite';
      await sourceDb.customStatement("VACUUM INTO '$snapshotPath'");
      final snapshotBytes = await File(snapshotPath).readAsBytes();
      final manifestBytes = utf8.encode(
        jsonEncode({'app': 'Tally Ledger Desktop'}),
      );
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'tally_ledger.sqlite',
            snapshotBytes.length,
            snapshotBytes,
          ),
        )
        ..addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
        );
      final archiveBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      final restored = await DataExchangeService(
        targetDb,
      ).restoreFullApplicationBackup(archiveBytes);

      expect(restored, isTrue);
      final vouchers = await targetDb.select(targetDb.vouchers).get();
      expect(
        vouchers.map((voucher) => voucher.voucherType).toSet(),
        voucherTypes.toSet(),
      );
      expect(
        await targetDb.select(targetDb.voucherEntries).get(),
        hasLength(4),
      );
      expect(
        await targetDb.select(targetDb.stockTransactions).get(),
        hasLength(2),
      );
    },
  );
}
