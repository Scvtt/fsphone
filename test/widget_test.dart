import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsphone/main.dart';

import 'test_softphone.dart';

void main() {
  testWidgets('Login offers a password and a one-time token', (tester) async {
    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('One-time token'), findsOneWidget);
    expect(find.text('Provision with QR'), findsOneWidget);
  });

  testWidgets('A test sign-in opens the keypad and accepts digits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));
    await _signIn(tester);

    expect(find.text('Keypad'), findsWidgets);
    expect(find.text('Registered · WSS'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dial-key-2')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('dial-key-1')));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byKey(const Key('dial-display')),
        matching: find.text('21'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Contacts are reachable from the rail', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));
    await _signIn(tester);

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    expect(find.text('No contacts match that search.'), findsOneWidget);
    expect(find.text('Company'), findsWidgets);
    expect(find.byKey(const Key('shell-search')), findsOneWidget);
  });

  testWidgets('The QR code does not register by itself', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));
    await tester.tap(find.byKey(const Key('login-qr')));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Registered · WSS'), findsNothing);
  });

  testWidgets('Dial pad fits the minimum window', (tester) async {
    tester.view.physicalSize = const Size(1100, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));
    await _signIn(tester);

    expect(tester.getSize(find.byKey(const Key('nav-rail'))).width, 132);
    final hash = tester.getRect(find.byKey(const ValueKey('dial-key-#')));
    expect(hash.top, greaterThanOrEqualTo(0));
    expect(hash.bottom, lessThanOrEqualTo(720));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Attended transfer can switch back, and hang up still works', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FsPhoneApp(softphone: TestSoftphone()));
    await _signIn(tester);
    await tester.tap(find.byKey(const ValueKey('dial-key-2')));
    await tester.tap(find.byKey(const ValueKey('dial-key-0')));
    await tester.tap(find.byKey(const ValueKey('dial-key-5')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('place-call')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-keypad')));
    await tester.pump();
    expect(find.byKey(const Key('keypad-back')), findsOneWidget);
    await tester.tap(find.byKey(const Key('keypad-back')));
    await tester.pump();
    expect(find.byKey(const Key('keypad-back')), findsNothing);

    await tester.tap(find.text('Transfer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('transfer-number')), '200');
    await tester.pump();
    await tester.tap(find.text('Attended'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Complete transfer'), findsOneWidget);
    expect(find.text('Switch back'), findsOneWidget);
    await tester.tap(find.text('Switch back'));
    await tester.pump();
    expect(find.text('205'), findsWidgets);
    expect(find.text('200 is on hold.'), findsOneWidget);

    await tester.tap(find.text('Contacts'));
    await tester.pump();
    await tester.tap(find.text('Keypad'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('hang-up')));
    await tester.pump();

    expect(find.byKey(const Key('hang-up')), findsNothing);
    expect(find.text('Complete transfer'), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('dial-display')),
        matching: find.text('205'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('login-server')),
    'wss://pbx.example.com:7443',
  );
  await tester.enterText(find.byKey(const Key('login-extension')), '1001');
  await tester.enterText(find.byKey(const Key('login-secret')), 'secret');
  await tester.tap(find.byKey(const Key('login-submit')));
  await tester.pumpAndSettle();
}
