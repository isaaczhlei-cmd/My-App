import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flightprint/screens/book_flight/book_flight_screen.dart';

void main() {
  testWidgets('shows local comparison result cards', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Best Matches'), findsOneWidget);
    expect(find.textContaining('checked'), findsOneWidget);
    expect(find.textContaining('CO₂'), findsWidgets);
  });

  testWidgets('passenger stepper stops at the selected route cabin capacity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    final addPassenger = find.byKey(const ValueKey('increment-passengers'));
    await tester.ensureVisible(addPassenger);
    await tester.pumpAndSettle();
    for (var i = 0; i < 199; i++) {
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

    final addPassenger = find.byKey(const ValueKey('increment-passengers'));
    await tester.ensureVisible(addPassenger);
    await tester.pumpAndSettle();
    for (var i = 0; i < 199; i++) {
      await tester.tap(addPassenger);
      await tester.pump();
    }

    final firstCabin = find.text('First');
    await tester.ensureVisible(firstCabin);
    await tester.pumpAndSettle();
    await tester.tap(firstCabin);
    await tester.pumpAndSettle();

    expect(find.text('20'), findsWidgets);
    expect(find.text('Max 20 for First'), findsOneWidget);
    expect(find.textContaining('JetBlue B6'), findsNothing);
  });

  testWidgets('airline input filters book flight matches', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BookFlightScreen()));
    await tester.pumpAndSettle();

    final airlineInput = find.widgetWithText(TextField, 'Type airline name');
    await tester.ensureVisible(airlineInput);
    await tester.enterText(airlineInput, 'Delta');
    await tester.pumpAndSettle();

    expect(find.text('Delta'), findsWidgets);
    expect(find.textContaining('Delta DL'), findsWidgets);
    expect(find.textContaining('United UA'), findsNothing);
  });
}
