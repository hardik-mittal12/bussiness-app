import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Database opens, executes schema creation and version check', () async {
    expect(db.schemaVersion, equals(5));
  });

  test('Foreign key constraints are enforced', () async {
    final fkRes = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    expect(fkRes.data.values.first, equals(1));
  });

  test('PRAGMA integrity_check returns ok', () async {
    final res = await db.customSelect('PRAGMA integrity_check;').getSingle();
    expect(res.data.values.first.toString().toLowerCase(), equals('ok'));
  });

  test('Default Account Groups and Ledgers are seeded', () async {
    final groups = await db.select(db.accountGroups).get();
    expect(groups.isNotEmpty, isTrue);

    final cashLedger = await (db.select(db.ledgers)..where((t) => t.id.equals('cash'))).getSingleOrNull();
    expect(cashLedger, isNotNull);
    expect(cashLedger!.name, equals('Cash Ledger'));
  });
}
