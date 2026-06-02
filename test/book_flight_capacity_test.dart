import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/screens/book_flight/book_flight_screen.dart';
import 'package:my_app/services/emissions_service.dart';

void main() {
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
