import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/security_pin_service.dart';
import 'package:tally_ledger_desktop/core/business_profile_service.dart';

void main() {
  late AppDatabase db;
  late SecurityPinService pinService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    pinService = SecurityPinService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SecurityPinService Tests', () {
    test('Initial state: hasPin is false and getPinHash is null', () async {
      expect(await pinService.hasPin(), isFalse);
      expect(await pinService.getPinHash(), isNull);
      expect(await pinService.verifyPin('1234'), isTrue); // When no pin is configured
    });

    test('Set 4-digit PIN hashes and verifies correctly', () async {
      await pinService.setPin('1234');
      expect(await pinService.hasPin(), isTrue);

      final hash = await pinService.getPinHash();
      expect(hash, isNotNull);
      expect(hash, equals(SecurityPinService.hashPin('1234')));

      expect(await pinService.verifyPin('1234'), isTrue);
      expect(await pinService.verifyPin('0000'), isFalse);
      expect(await pinService.verifyPin('9999'), isFalse);
    });

    test('Rejects invalid PIN formats', () async {
      expect(() => pinService.setPin('123'), throwsA(isA<ArgumentError>()));
      expect(() => pinService.setPin('12345'), throwsA(isA<ArgumentError>()));
      expect(() => pinService.setPin('abcd'), throwsA(isA<ArgumentError>()));
    });

    test('Change PIN updates hash and previous PIN becomes invalid', () async {
      await pinService.setPin('1234');
      expect(await pinService.verifyPin('1234'), isTrue);

      await pinService.setPin('5678');
      expect(await pinService.verifyPin('5678'), isTrue);
      expect(await pinService.verifyPin('1234'), isFalse);
    });

    test('Remove PIN removes hash and disables protection', () async {
      await pinService.setPin('4321');
      expect(await pinService.hasPin(), isTrue);

      await pinService.removePin();
      expect(await pinService.hasPin(), isFalse);
      expect(await pinService.getPinHash(), isNull);
    });

    test('Recovery verification with master key 9999', () async {
      expect(await pinService.verifyRecoveryIdentity('9999'), isTrue);
      expect(await pinService.verifyRecoveryIdentity(' 9999 '), isTrue);
    });

    test('Recovery verification with business profile details', () async {
      final profileService = BusinessProfileService(db);
      await profileService.updateProfile(
        companyName: 'Acme Traders Private Limited',
        phone: '+91 9988776655',
        taxNumber: '27AABCU9603R1ZM',
      );

      // Verify with exact or case-insensitive company name
      expect(await pinService.verifyRecoveryIdentity('Acme Traders Private Limited'), isTrue);
      expect(await pinService.verifyRecoveryIdentity('acme traders private limited'), isTrue);

      // Verify with registered phone
      expect(await pinService.verifyRecoveryIdentity('+91 9988776655'), isTrue);

      // Verify with GSTIN
      expect(await pinService.verifyRecoveryIdentity('27AABCU9603R1ZM'), isTrue);
      expect(await pinService.verifyRecoveryIdentity('27aabcu9603r1zm'), isTrue);

      // Random wrong input fails
      expect(await pinService.verifyRecoveryIdentity('Unknown Company'), isFalse);
      expect(await pinService.verifyRecoveryIdentity('123456'), isFalse);
      expect(await pinService.verifyRecoveryIdentity(''), isFalse);
    });
  });
}
