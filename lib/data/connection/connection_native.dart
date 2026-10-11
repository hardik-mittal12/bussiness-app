import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import '../path_resolver.dart';

void _backgroundIsolateSetup() {
  try {
    final dir = Directory.systemTemp;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    sqlite3.tempDirectory = dir.path;
  } catch (_) {}
}

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final tempDir = await getTempDirectoryPath();
    try {
      final dir = Directory(tempDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      sqlite3.tempDirectory = dir.path;
    } catch (_) {}

    final dbPath = await getCustomDatabasePath('tally_ledger');
    final file = File(dbPath);
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: _backgroundIsolateSetup,
      setup: (rawDb) {
        try {
          rawDb.execute('PRAGMA journal_mode = WAL;');
          rawDb.execute('PRAGMA busy_timeout = 30000;');
          rawDb.execute('PRAGMA foreign_keys = ON;');
          rawDb.execute('PRAGMA synchronous = NORMAL;');
          rawDb.execute('PRAGMA wal_autocheckpoint = 1000;');
        } catch (_) {}
      },
    );
  });
}
