import 'dart:convert';

final RegExp _shortNumericTicketPattern = RegExp(r'^\d{1,11}$');
final BigInt _fnvOffsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
final BigInt _fnvPrime = BigInt.parse('100000001b3', radix: 16);
final BigInt _uint64Mask = BigInt.parse('ffffffffffffffff', radix: 16);
final BigInt _ticketRangeStart = BigInt.from(10000000000);
final BigInt _ticketRangeSize = BigInt.from(90000000000);

/// Returns the stable, numeric ticket shown to the user for a trading entity.
///
/// The original ID must remain in domain state and command payloads. This
/// formatter is intentionally presentation-only so server GUIDs continue to
/// identify the correct order, deal, or position when an action is submitted.
String displayTradingTicketId(String rawId) {
  final id = rawId.trim();
  if (id.isEmpty || _shortNumericTicketPattern.hasMatch(id)) {
    return id;
  }

  var hash = _fnvOffsetBasis;
  for (final byte in utf8.encode(id)) {
    hash ^= BigInt.from(byte);
    hash = (hash * _fnvPrime) & _uint64Mask;
  }

  return (_ticketRangeStart + (hash % _ticketRangeSize)).toString();
}
