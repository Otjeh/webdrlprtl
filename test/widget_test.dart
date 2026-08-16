import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:webdlrprtl01/main.dart';
import 'package:webdlrprtl01/models/user_profile.dart';

void main() {
  test('Pairing QR targets the iDiGi Android application', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(
      buildPairingQrPayload('pairing-id'),
      'intent://pair/pairing-id#Intent;scheme=idigi;package=eu.fivea.idigi;end',
    );
    expect(
      buildPairingQrMessage('12345'),
      'Scan to open iDiGi on Android or enter code 12345',
    );
  });

  test('Pairing QR uses the iDiGi custom scheme outside Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    expect(buildPairingQrPayload('pairing-id'), 'idigi://pair/pairing-id');
    expect(
      buildPairingQrMessage('12345'),
      'Scan with iDiGi app or enter code 12345',
    );
  });

  testWidgets('Settings lists LoA modules in ascending order', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    final loa1 = tester.getTopLeft(find.text('LoA1'));
    final loa2 = tester.getTopLeft(find.text('LoA2'));
    final loa3 = tester.getTopLeft(find.text('LoA3'));

    expect(loa1.dy, lessThan(loa2.dy));
    expect(loa2.dy, lessThan(loa3.dy));
  });

  testWidgets('App renders the Modena login screen first', (tester) async {
    await tester.pumpWidget(const IdigiConfigApp());

    expect(find.text('Modena Dealer Portal'), findsNWidgets(2));
    expect(find.text('MODENA'), findsNothing);
    expect(find.text('Gmail address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.byTooltip('Administrator'), findsOneWidget);
    expect(find.text('Product Journey Script'), findsNothing);
    expect(find.text('Approval Flow'), findsNothing);
  });

  testWidgets('Empty dashboard opens the product catalog', (tester) async {
    const user = UserProfile(
      email: 'dealer.manager@gmail.com',
      nik: '3201012001010002',
      role: 'Dealer Distribution Manager',
      code: 'dlr.DDD-dist-mgr.CCC',
      loa: 'LoA3',
      name: 'Dealer Manager',
    );

    await tester.pumpWidget(
      const MaterialApp(home: DealerDashboardPage(user: user)),
    );

    await tester.pumpAndSettle();
    expect(find.text('Product Catalog'), findsOneWidget);
    expect(find.byIcon(Icons.folder_outlined), findsNWidgets(8));
  });

  testWidgets('Administrator screen lists and selects registered users', (
    tester,
  ) async {
    await tester.pumpWidget(const IdigiConfigApp());
    await tester.tap(find.byTooltip('Administrator'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'otjeh@fivea.eu');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Open admin page'));
    await tester.pumpAndSettle();

    expect(find.text('Registered users'), findsOneWidget);
    expect(find.text('Add new user'), findsOneWidget);
    expect(find.textContaining('dealer.admin@gmail.com'), findsOneWidget);

    await tester.tap(find.text('Dealer Admin'));
    await tester.pump();

    expect(find.text('User details and credentials'), findsOneWidget);
    expect(
      find.text(
        'Passwords are managed by Supabase Auth and cannot be displayed here.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNWidgets(7));
    expect(find.text('New password'), findsOneWidget);
    expect(find.text('Confirm new password'), findsOneWidget);
    expect(find.text('dealer.admin@gmail.com'), findsOneWidget);

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pump();
    expect(find.text('Warehouse Manager'), findsOneWidget);
    expect(find.text('Logistics Manager'), findsOneWidget);
    await tester.tap(find.text('Warehouse Manager'));

    await tester.enterText(find.byType(TextFormField).at(5), 'newpass123');
    await tester.enterText(find.byType(TextFormField).at(6), 'newpass123');
    await tester.ensureVisible(find.text('Save password'));
    await tester.tap(find.text('Save password'));
    await tester.pumpAndSettle();

    expect(find.text('User details and credentials'), findsNothing);
    expect(find.text('Registered users'), findsOneWidget);
    expect(
      find.text('Password updated. Select a user to make another change.'),
      findsOneWidget,
    );
  });

  testWidgets('Approval rows restrict actions to the matching user', (
    tester,
  ) async {
    const user = UserProfile(
      email: 'dealer.admin@gmail.com',
      nik: '3201012001010001',
      role: 'Dealer Distribution Admin',
      code: 'dlr.DDD-dist-adm.BBB',
      loa: 'LoA1',
      name: 'Dealer Admin',
    );

    await tester.pumpWidget(
      const MaterialApp(home: ApprovalQueuePage(user: user)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Approve'), findsNWidgets(2));
    expect(find.text('Reject'), findsNWidgets(2));
    expect(find.text('Approval note'), findsNWidgets(2));

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('No action'), findsNWidgets(2));
  });

  testWidgets('Product catalog shows eight folders and role-based ordering', (
    tester,
  ) async {
    const user = UserProfile(
      email: 'dealer.manager@gmail.com',
      nik: '3201012001010002',
      role: 'Dealer Distribution Manager',
      code: 'dlr.DDD-dist-mgr.CCC',
      loa: 'LoA3',
      name: 'Dealer Manager',
    );

    await tester.pumpWidget(
      const MaterialApp(home: ProductCatalogPage(user: user)),
    );

    expect(find.byIcon(Icons.folder_outlined), findsNWidgets(8));
    final cookingCategory = find.byKey(const ValueKey('category-Cooking'));
    await tester.ensureVisible(cookingCategory);
    await tester.tap(cookingCategory);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('Cooking Essential'), findsOneWidget);
    expect(find.textContaining('Stock: 12'), findsOneWidget);
    expect(find.textContaining('Stock: 4'), findsOneWidget);
    expect(find.text('Admin only'), findsNWidgets(2));
    expect(find.text('Allocate'), findsNothing);
  });
}
