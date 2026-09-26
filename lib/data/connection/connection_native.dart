import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import '../path_resolver.dart';

QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final tempDir = await getTempDirectoryPath();
    try {
      sqlite3.tempDirectory = tempDir;
    } catch (_) {}

    final dbPath = await getCustomDatabasePath('tally_ledger');
    final file = File(dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
