import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsphone/main.dart';

void main() {
  testWidgets('Login offers a password and a one-time token', (tester) async {
    await tester.pumpWidget(const FsPhoneApp());

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

    await tester.pumpWidget(const FsPhoneApp());
    await tester.enterText(find.byKey(const Key('login-extension')), '1001');
    await tester.enterText(find.byKey(const Key('login-secret')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

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

    await tester.pumpWidget(const FsPhoneApp());
    await tester.enterText(find.byKey(const Key('login-extension')), '1001');
    await tester.enterText(find.byKey(const Key('login-secret')), 'secret');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    expect(find.text('Jordan Hale'), findsWidgets);
    expect(find.text('Company'), findsWidgets);
    expect(find.byKey(const Key('shell-search')), findsOneWidget);
  });
}
