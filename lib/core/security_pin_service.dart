import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../data/database.dart';
import 'business_profile_service.dart';

class SecurityPinService {
  final AppDatabase db;

  SecurityPinService(this.db);

  /// Computes SHA-256 hash of a PIN string
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Checks if an access PIN is configured
  Future<bool> hasPin() async {
    final row = await (db.select(db.syncMetadata)
          ..where((t) => t.key.equals('security_pin_hash')))
        .getSingleOrNull();
    return row != null && row.value.trim().isNotEmpty;
  }

  /// Retrieves the stored PIN hash
  Future<String?> getPinHash() async {
    final row = await (db.select(db.syncMetadata)
          ..where((t) => t.key.equals('security_pin_hash')))
        .getSingleOrNull();
    if (row == null || row.value.trim().isEmpty) return null;
    return row.value.trim();
  }

  /// Verifies a PIN candidate against the stored hash
  Future<bool> verifyPin(String pin) async {
    final storedHash = await getPinHash();
    if (storedHash == null) {
      return true; // No PIN configured
    }
    return hashPin(pin) == storedHash;
  }

  /// Saves a new PIN (hashes before storage)
  Future<void> setPin(String newPin) async {
    if (newPin.trim().length != 4 || int.tryParse(newPin.trim()) == null) {
      throw ArgumentError('PIN must be exactly 4 numeric digits.');
    }
    final hashed = hashPin(newPin.trim());
    await db.into(db.syncMetadata).insertOnConflictUpdate(
          SyncMetadataCompanion.insert(key: 'security_pin_hash', value: hashed),
        );
  }

  /// Removes the stored PIN
  Future<void> removePin() async {
    await (db.delete(db.syncMetadata)..where((t) => t.key.equals('security_pin_hash'))).go();
  }

  /// Verifies identity for Forgot PIN recovery using registered business details or master emergency key
  Future<bool> verifyRecoveryIdentity(String input) async {
    final cleanInput = input.trim();
    if (cleanInput.isEmpty) return false;

    // Master emergency key
    if (cleanInput == '9999') return true;

    final profileService = BusinessProfileService(db);
    final profile = await profileService.getProfile();

    if (cleanInput.toLowerCase() == profile.companyName.trim().toLowerCase()) {
      return true;
    }
    if (profile.phone != null && cleanInput == profile.phone!.trim()) {
      return true;
    }
    if (profile.taxNumber != null && cleanInput.toLowerCase() == profile.taxNumber!.trim().toLowerCase()) {
      return true;
    }

    return false;
  }
}
