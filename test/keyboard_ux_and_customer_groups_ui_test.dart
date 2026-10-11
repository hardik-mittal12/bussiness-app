import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:tally_ledger_desktop/data/database.dart';
import 'package:tally_ledger_desktop/core/accounting_engine.dart';
import 'package:tally_ledger_desktop/core/customer_group_service.dart';
import 'package:tally_ledger_desktop/ui/payment_receipt_page.dart';
import 'package:tally_ledger_desktop/ui/ledger_list_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V8 Keyboard-First UX & Customer Search Tests', () {
    late AppDatabase db;
    late AccountingEngine engine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);

      // Seed test customers & suppliers
      await db.into(db.ledgers).insert(
            const LedgersCompanion(
              id: drift.Value('cust_1'),
              name: drift.Value('Amit Sharma Traders'),
              groupId: drift.Value('debtors'),
              openingBalance: drift.Value(0.0),
              isDeleted: drift.Value(false),
            ),
          );
      await db.into(db.ledgers).insert(
            const LedgersCompanion(
              id: drift.Value('cust_2'),
              name: drift.Value('Apex Enterprises'),
              groupId: drift.Value('debtors'),
              openingBalance: drift.Value(0.0),
              isDeleted: drift.Value(false),
            ),
          );
      await db.into(db.ledgers).insert(
            const LedgersCompanion(
              id: drift.Value('supp_1'),
              name: drift.Value('Bharat Steels'),
              groupId: drift.Value('creditors'),
              openingBalance: drift.Value(0.0),
              isDeleted: drift.Value(false),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp(Widget home) {
      return MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          Provider<AccountingEngine>.value(value: engine),
          Provider<CustomerGroupService>.value(value: CustomerGroupService(db)),
        ],
        child: MaterialApp(
          home: home,
        ),
      );
    }

    testWidgets('Customer search in Payment/Receipt filters and supports Enter selection', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const PaymentReceiptPage()));
      await tester.pumpAndSettle();

      // Find the Autocomplete search bar by its key
      final searchField = find.byKey(const ValueKey('receipt-contact-search'));
      expect(searchField, findsOneWidget);

      // Type partial customer name 'Apex'
      await tester.enterText(searchField, 'Apex');
      await tester.pumpAndSettle();

      // Options popup should display 'Apex Enterprises'
      expect(find.text('Apex Enterprises'), findsWidgets);

      // Hit Down arrow key to navigate options, then Enter key to select
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      // Verify the selected party is now populated
      expect(find.text('Apex Enterprises'), findsWidgets);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('F2 shortcut invokes voucher save action with validation', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const PaymentReceiptPage()));
      await tester.pumpAndSettle();

      // Press F2 shortcut
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      // Verify form validation error is triggered by the shortcut
      expect(find.text('Please select a valid party'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('V8 Customer Groups & Group UI Tests', () {
    late AppDatabase db;
    late AccountingEngine engine;
    late CustomerGroupService groupService;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      engine = AccountingEngine(db);
      groupService = CustomerGroupService(db);

      // Create a test group
      final g1 = await groupService.createGroup('Wholesale Dealers', description: 'Tier 1 bulk buyers');

      // Seed customers
      await db.into(db.ledgers).insert(
            LedgersCompanion(
              id: const drift.Value('c1'),
              name: const drift.Value('Delhi Wholesaler'),
              groupId: const drift.Value('debtors'),
              customerGroupId: drift.Value(g1.id),
              openingBalance: const drift.Value(0.0),
              isDeleted: const drift.Value(false),
            ),
          );
      await db.into(db.ledgers).insert(
            const LedgersCompanion(
              id: drift.Value('c2'),
              name: drift.Value('Retail Corner Store'),
              groupId: drift.Value('debtors'),
              customerGroupId: drift.Value(null),
              openingBalance: drift.Value(0.0),
              isDeleted: drift.Value(false),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp(Widget home) {
      return MultiProvider(
        providers: [
          Provider<AppDatabase>.value(value: db),
          Provider<AccountingEngine>.value(value: engine),
          Provider<CustomerGroupService>.value(value: groupService),
        ],
        child: MaterialApp(
          home: home,
        ),
      );
    }

    testWidgets('Customer list displays group badge chip and filters by group', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const LedgerListPage()));
      await tester.pumpAndSettle();

      // Verify both customers appear initially
      expect(find.text('Delhi Wholesaler'), findsOneWidget);
      expect(find.text('Retail Corner Store'), findsOneWidget);

      // Verify group badge chip is shown for Delhi Wholesaler
      expect(find.text('Wholesale Dealers'), findsWidgets);

      // Open group filter dropdown and select 'Ungrouped Customers'
      final filterDropdown = find.text('All Customers (All Groups)');
      expect(filterDropdown, findsOneWidget);
      await tester.tap(filterDropdown);
      await tester.pumpAndSettle();

      // Tap 'Ungrouped Customers'
      await tester.tap(find.text('Ungrouped Customers').last);
      await tester.pumpAndSettle();

      // Delhi Wholesaler should be filtered out, Retail Corner Store should remain
      expect(find.text('Delhi Wholesaler'), findsNothing);
      expect(find.text('Retail Corner Store'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Customer Groups Tab displays groups and allows creating new group', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(const LedgerListPage()));
      await tester.pumpAndSettle();

      // Tap on Tab 3: Customer Groups
      await tester.tap(find.text('Customer Groups'));
      await tester.pumpAndSettle();

      // Verify existing group is displayed
      expect(find.text('Wholesale Dealers'), findsOneWidget);
      expect(find.text('Tier 1 bulk buyers'), findsOneWidget);
      expect(find.text('1 Customer'), findsOneWidget);

      // Tap 'New Customer Group' button
      await tester.tap(find.text('New Customer Group'));
      await tester.pumpAndSettle();

      // Enter group name
      await tester.enterText(find.widgetWithText(TextFormField, 'Group Name *'), 'VIP Clients');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description (Optional)'), 'High net worth');
      await tester.pumpAndSettle();

      // Tap 'Create Group'
      await tester.tap(find.text('Create Group'));
      await tester.pumpAndSettle();

      // Verify new group appears in list
      expect(find.text('VIP Clients'), findsOneWidget);
      expect(find.text('High net worth'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
