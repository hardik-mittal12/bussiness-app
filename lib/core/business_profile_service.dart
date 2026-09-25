import 'package:drift/drift.dart';
import '../data/database.dart';

class BusinessProfileService {
  final AppDatabase db;

  BusinessProfileService(this.db);

  /// Fetches the current active business profile record (or default)
  Future<BusinessProfile> getProfile() async {
    final profile = await (db.select(db.businessProfiles)
          ..where((t) => t.id.equals('default') | t.isActive.equals(true))
          ..limit(1))
        .getSingleOrNull();

    if (profile != null) return profile;

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

    return (await (db.select(db.businessProfiles)..where((t) => t.id.equals('default'))).getSingle());
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
      final String? finalLogo;
      if (logoPath != null) {
        finalLogo = logoPath.trim().isEmpty ? null : logoPath.trim();
      } else {
        finalLogo = active?.logoPath;
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
      } else {
        await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).go();
      }
    });
  }

  /// Updates or removes the company logo
  Future<void> updateLogo(String? logoPath) async {
    final cleanLogo = (logoPath != null && logoPath.trim().isNotEmpty) ? logoPath.trim() : null;
    final profile = await getProfile();
    await (db.update(db.businessProfiles)..where((t) => t.id.equals(profile.id))).write(
      BusinessProfilesCompanion(
        logoPath: Value(cleanLogo),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (cleanLogo != null) {
      await db.into(db.syncMetadata).insertOnConflictUpdate(SyncMetadataCompanion.insert(key: 'company_logo_path', value: cleanLogo));
    } else {
      await (db.delete(db.syncMetadata)..where((t) => t.key.equals('company_logo_path'))).go();
    }
  }
}
