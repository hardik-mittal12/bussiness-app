import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class SqliteVerifier {
  static Future<Map<String, dynamic>> verifyDatabaseFile(String backupFilePath) async {
    final file = File(backupFilePath);
    if (!await file.exists()) {
      return {
        'isSuccess': false,
        'message': 'Backup file does not exist: $backupFilePath',
      };
    }

    sqlite.Database? sqliteDb;
    try {
      sqliteDb = sqlite.sqlite3.open(backupFilePath);
      final integrityRes = sqliteDb.select('PRAGMA integrity_check;');
      final integrityResult = integrityRes.first.values.first?.toString() ?? 'unknown';

      if (integrityResult.toLowerCase() != 'ok') {
        return {
          'isSuccess': false,
          'message': 'Integrity check failed: $integrityResult',
          'integrityCheckOutput': integrityResult,
        };
      }

      final tablesCheck = sqliteDb.select(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('vouchers', 'voucher_entries', 'stock_items', 'ledgers');",
      );

      final tableNames = tablesCheck.map((r) => r.values.first.toString()).toSet();
      if (!tableNames.containsAll({'vouchers', 'voucher_entries', 'stock_items', 'ledgers'})) {
        return {
          'isSuccess': false,
          'message': 'Backup file is missing required tables: vouchers, entries, stock, or ledgers.',
        };
      }

      final counts = <String, int>{};
      for (final t in ['vouchers', 'voucher_entries', 'stock_items', 'ledgers']) {
        final countRes = sqliteDb.select('SELECT COUNT(*) FROM $t;');
        counts[t] = countRes.first.values.first as int? ?? 0;
      }

      return {
        'isSuccess': true,
        'message': 'Backup verification successful.',
        'tableCounts': counts,
        'integrityCheckOutput': integrityResult,
      };
    } catch (e) {
      return {
        'isSuccess': false,
        'message': 'Failed reading database file: $e',
      };
    } finally {
      sqliteDb?.dispose();
    }
  }
}
