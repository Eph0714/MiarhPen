import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miarhpen/app.dart';
import 'package:miarhpen/features/auth/application/auth_provider.dart';

void main() {
  testWidgets('App boots and lands on the Welcome screen for a fresh install', (
    tester,
  ) async {
    // Override the current-user lookup instead of touching the real sqlite
    // database — `flutter test` has no platform channel for the real
    // path_provider/sqflite plugins, and the router's very first redirect
    // decision only depends on whether a user exists yet. Overriding this
    // one provider keeps the test meaningful (it still exercises real
    // go_router redirect logic and renders the real welcome screen)
    // without depending on native I/O.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [currentUserProvider.overrideWith((ref) async => null)],
        child: const MiarhPenApp(),
      ),
    );
    await tester.pumpAndSettle();

    // No user exists yet on a fresh install, so the router redirects to
    // the Welcome screen, offering only "Create New Account" (no accounts
    // exist yet, so "Login to Existing Account" is hidden).
    expect(find.text('MiarhPen'), findsWidgets);
    expect(find.text('CREATE NEW ACCOUNT'), findsOneWidget);
    expect(find.text('LOGIN TO EXISTING ACCOUNT'), findsNothing);
  });
}
