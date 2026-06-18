class ParsedFlightNumber {
  const ParsedFlightNumber({required this.carrier, required this.number});

  final String carrier;
  final int number;
}

ParsedFlightNumber? parseFlightNumber(String input) {
  final cleaned = input.trim().toUpperCase();
  final regex = RegExp(r'^([A-Z][A-Z0-9])\s*[-]?\s*(\d{1,5})$');
  final match = regex.firstMatch(cleaned);
  if (match == null) return null;

  final number = int.tryParse(match.group(2)!);
  if (number == null) return null;

  return ParsedFlightNumber(carrier: match.group(1)!, number: number);
}
