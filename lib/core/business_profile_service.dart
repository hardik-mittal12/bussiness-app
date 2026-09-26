import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../data/database.dart';
import '../data/path_resolver.dart';

class BusinessProfileService extends ChangeNotifier {
  final AppDatabase db;
  BusinessProfile? _cachedProfile;
  Uint8List? _cachedLogoBytes;

  BusinessProfileService(this.db);

  BusinessProfile? get currentProfile => _cachedProfile;
  Uint8List? get currentLogoBytes => _cachedLogoBytes;

  /// Fetches raw bytes of the current company logo
  Future<Uint8List?> getLogoBytes() async {
    if (_cachedLogoBytes != null && _cachedLogoBytes!.isNotEmpty) {
      return _cachedLogoBytes;
    }

    // 1. Try reading base64 from syncMetadata
    try {
      final base64Meta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_logo_base64'))).getSingleOrNull();
      if (base64Meta != null && base64Meta.value.isNotEmpty) {
        final decoded = base64Decode(base64Meta.value);
        if (decoded.isNotEmpty) {
          _cachedLogoBytes = decoded;
          return decoded;
        }
      }
    } catch (_) {}

    // 2. Try reading from profile logoPath file
    try {
      final profile = await getProfile();
      if (profile.logoPath != null && profile.logoPath!.isNotEmpty) {
        final f = File(profile.logoPath!);
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            _cachedLogoBytes = bytes;
            // Also store base64 in syncMetadata for future instant access
            try {
              final b64 = base64Encode(bytes);
              await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_logo_base64', value: b64));
            } catch (_) {}
            return bytes;
          }
        }
      }
    } catch (_) {}

    // 3. Try reading internal company_logo.png from app support directory
    try {
      final storageDir = await getAppStorageDirectoryPath();
      if (storageDir.isNotEmpty) {
        final f = File(p.join(storageDir, 'company_logo.png'));
        if (f.existsSync()) {
          final bytes = await f.readAsBytes();
          if (bytes.isNotEmpty) {
            _cachedLogoBytes = bytes;
            return bytes;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetches the current active business profile record (or default)
  Future<BusinessProfile> getProfile() async {
    final profile = await (db.select(db.businessProfiles)
          ..where((t) => t.id.equals('default') | t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();

    if (profile != null) {
      _cachedProfile = profile;
      if (_cachedLogoBytes == null && profile.logoPath != null && profile.logoPath!.isNotEmpty) {
        getLogoBytes(); // async preload
      }
      return profile;
    }

    // Check if details exist in syncMetadata
    final nameMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_name'))).getSingleOrNull();
    final addressMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_address'))).getSingleOrNull();
    final phoneMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_phone'))).getSingleOrNull();
    final emailMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_email'))).getSingleOrNull();
    final taxMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_tax_number'))).getSingleOrNull();
    final bankMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_bank_details'))).getSingleOrNull();
    final termsMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_terms'))).getSingleOrNull();
    final logoMeta = await (db.select(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).getSingleOrNull();

    // Seed default if none exists
    await db.into(db.businessProfiles).insert(BusinessProfilesCompanion.insert(
          id: 'default',
          companyName: nameMeta?.value ?? 'My Business Enterprise',
          address: Value(addressMeta?.value ?? '123 Commercial Complex, Main Road'),
          phone: Value(phoneMeta?.value ?? '+91 9876543210'),
          email: Value(emailMeta?.value ?? 'info@mybusiness.com'),
          taxNumber: Value(taxMeta?.value ?? '27AAAAA0000A1Z5'),
          bankDetails: Value(bankMeta?.value ?? 'HDFC Bank, A/C: 50200012345678, IFSC: HDFC0001234'),
          termsAndConditions: Value(termsMeta?.value ?? 'Goods once sold will not be taken back. Subject to local jurisdiction.'),
          logoPath: Value(logoMeta?.value),
          isActive: const Value(true),
        ));

    final seeded = await (db.select(db.businessProfiles)..where((t) => t.id.equals('default'))).getSingle();
    _cachedProfile = seeded;
    return seeded;
  }

  /// Updates business profile details cleanly and ensures persistence across restarts
  Future<void> updateProfile({
    required String companyName,
    String? address,
    String? phone,
    String? email,
    String? taxNumber,
    String? bankDetails,
    String? termsAndConditions,
    String? logoPath,
  }) async {
    await db.transaction(() async {
      // Find active profile
      final active = await (db.select(db.businessProfiles)
            ..where((t) => t.id.equals('default') | t.isActive.equals(true))
            ..limit(1))
          .getSingleOrNull();
      final idToUpdate = active?.id ?? 'default';
      
      String? finalLogo = active?.logoPath;
      if (logoPath != null) {
        if (logoPath.trim().isEmpty) {
          finalLogo = null;
        } else {
          finalLogo = logoPath.trim();
        }
      }

      // Ensure active record exists
      if (active == null) {
        await db.into(db.businessProfiles).insert(BusinessProfilesCompanion.insert(
              id: idToUpdate,
              companyName: companyName,
              address: Value(address),
              phone: Value(phone),
              email: Value(email),
              taxNumber: Value(taxNumber),
              bankDetails: Value(bankDetails),
              termsAndConditions: Value(termsAndConditions),
              logoPath: Value(finalLogo),
              isActive: const Value(true),
            ));
      } else {
        await (db.update(db.businessProfiles)..where((t) => t.id.equals(idToUpdate))).write(
          BusinessProfilesCompanion(
            companyName: Value(companyName),
            address: Value(address),
            phone: Value(phone),
            email: Value(email),
            taxNumber: Value(taxNumber),
            bankDetails: Value(bankDetails),
            termsAndConditions: Value(termsAndConditions),
            logoPath: Value(finalLogo),
            isActive: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // Mirror to syncMetadata for bulletproof recovery across restarts
      await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_name', value: companyName));
      if (address != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_address', value: address));
      if (phone != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_phone', value: phone));
      if (email != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_email', value: email));
      if (taxNumber != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_tax_number', value: taxNumber));
      if (bankDetails != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_bank_details', value: bankDetails));
      if (termsAndConditions != null) await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_terms', value: termsAndConditions));
      if (finalLogo != null && finalLogo.isNotEmpty) {
        await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_logo_path', value: finalLogo));
      } else if (logoPath != null && logoPath.trim().isEmpty) {
        await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).go();
        await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_base64'))).go();
        _cachedLogoBytes = null;
      }
    });

    _cachedProfile = await (db.select(db.businessProfiles)
          ..where((t) => t.id.equals('default') | t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();

    notifyListeners();
  }

  /// Updates or removes the company logo
  Future<void> updateLogo(String? logoPath) async {
    final cleanLogo = (logoPath != null && logoPath.trim().isNotEmpty) ? logoPath.trim() : null;
    final profile = await getProfile();

    if (cleanLogo == null) {
      _cachedLogoBytes = null;
      await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_base64'))).go();
      await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).go();
      await (db.update(db.businessProfiles)..where((t) => t.id.equals(profile.id))).write(
        BusinessProfilesCompanion(
          logoPath: const Value(null),
          updatedAt: Value(DateTime.now()),
        ),
      );
      try {
        final storageDir = await getAppStorageDirectoryPath();
        if (storageDir.isNotEmpty) {
          final f = File(p.join(storageDir, 'company_logo.png'));
          if (f.existsSync()) await f.delete();
        }
      } catch (_) {}
    } else {
      Uint8List? bytes;
      try {
        final sourceFile = File(cleanLogo);
        if (sourceFile.existsSync()) {
          bytes = await sourceFile.readAsBytes();
        }
      } catch (_) {}

      String internalPath = cleanLogo;
      if (bytes != null && bytes.isNotEmpty) {
        _cachedLogoBytes = bytes;
        final base64Str = base64Encode(bytes);
        await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_logo_base64', value: base64Str));

        try {
          final storageDir = await getAppStorageDirectoryPath();
          if (storageDir.isNotEmpty) {
            final targetPath = p.join(storageDir, 'company_logo.png');
            await File(targetPath).writeAsBytes(bytes);
            internalPath = targetPath;
          }
        } catch (_) {}
      }

      await (db.update(db.businessProfiles)..where((t) => t.id.equals(profile.id))).write(
        BusinessProfilesCompanion(
          logoPath: Value(internalPath),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_logo_path', value: internalPath));
    }

    _cachedProfile = await (db.select(db.businessProfiles)..where((t) => t.id.equals(profile.id))).getSingleOrNull();
    notifyListeners();
  }
}
