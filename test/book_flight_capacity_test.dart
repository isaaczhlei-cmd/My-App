import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/book_flight/book_flight_screen.dart';
import 'package:my_app/services/emissions_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('search button label opens provider choices', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Search Flights'), findsOneWidget);
    expect(find.text('Compare Flights'), findsNothing);

    await tester.tap(find.text('Search Flights'));
    await tester.pumpAndSettle();

    expect(find.text('Kayak'), findsOneWidget);
    expect(find.text('Google Flights'), findsOneWidget);
    expect(find.text('Skyscanner'), findsOneWidget);
  });

  testWidgets('default route shows a variety of flight results', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Available Flights'), findsOneWidget);
    expect(find.textContaining('Delta DL'), findsOneWidget);
    expect(find.textContaining('American AA'), findsOneWidget);
    expect(find.textContaining('JetBlue B6'), findsOneWidget);
  });

  testWidgets('selected provider receives prefilled search values', (
    tester,
  ) async {
    Uri? launchedUrl;

    await tester.pumpWidget(
      MaterialApp(
        home: BookFlightScreen(
          onLaunchUrl: (url) async {
            launchedUrl = url;
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search Flights'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kayak'));
    await tester.pumpAndSettle();

    expect(launchedUrl, isNotNull);
    expect(launchedUrl!.host, 'www.kayak.com');
    expect(launchedUrl!.path, contains('/flights/JFK-LAX/'));
    expect(launchedUrl!.path, endsWith('/1/e'));
  });

  testWidgets('passenger stepper stops at the selected route cabin capacity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    final addPassenger = find.byIcon(Icons.add);
    for (var i = 0; i < 250; i++) {
      await tester.tap(addPassenger);
      await tester.pump();
    }

    expect(find.text('200'), findsWidgets);
    expect(find.text('201'), findsNothing);
    expect(find.text('Max 200 for Economy'), findsOneWidget);
  });

  testWidgets('switching cabins clamps passengers and filters results', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    final addPassenger = find.byIcon(Icons.add);
    for (var i = 0; i < 250; i++) {
      await tester.tap(addPassenger);
      await tester.pump();
    }

    await tester.tap(find.byType(DropdownButton<CabinClass>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('First').last);
    await tester.pumpAndSettle();

    expect(find.text('20'), findsWidgets);
    expect(find.text('Max 20 for First'), findsOneWidget);
    expect(find.textContaining('JetBlue B6'), findsNothing);
  });
}
