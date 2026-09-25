import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../data/database.dart';

class AuditLogService {
  final AppDatabase db;
  final Uuid _uuid = const Uuid();

  AuditLogService(this.db);

  Future<void> logAction({
    required String action, // e.g. 'CREATE', 'UPDATE', 'CANCEL', 'DELETE', 'BACKUP', 'RESTORE'
    required String entityType, // e.g. 'Voucher', 'StockItem', 'Ledger', 'Settings'
    required String entityId,
    String? oldValue,
    String? newValue,
    String? metadata,
  }) async {
    try {
      await db.into(db.auditLogs).insert(
        AuditLogsCompanion.insert(
          id: _uuid.v4(),
          timestamp: Value(DateTime.now()),
          userDevice: const Value('Desktop'),
          action: action,
          entityType: entityType,
          entityId: entityId,
          oldValue: Value(oldValue),
          newValue: Value(newValue),
          metadata: Value(metadata),
        ),
      );
    } catch (e) {
      // Fail safely without crashing production writes, but print log trace
      print('AuditLog error: $e');
    }
  }

  Future<List<AuditLog>> getRecentLogs({int limit = 100}) async {
    final query = db.select(db.auditLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);
    return query.get();
  }
}
