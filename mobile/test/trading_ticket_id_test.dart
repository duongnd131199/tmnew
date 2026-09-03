import 'package:flutter_test/flutter_test.dart';
import 'package:trading_mobile/core/utils/trading_ticket_id.dart';

void main() {
  group('displayTradingTicketId', () {
    test('preserves an existing short numeric trading ticket', () {
      expect(displayTradingTicketId('10156857101'), '10156857101');
      expect(displayTradingTicketId(' 12345 '), '12345');
    });

    test('maps a server GUID to a stable 11-digit numeric ticket', () {
      expect(
        displayTradingTicketId('894faaa5-5d41-49bd-8a52-5daf0281d948'),
        '11615687251',
      );
      expect(
        displayTradingTicketId('894faaa5-5d41-49bd-8a52-5daf0281d948'),
        matches(RegExp(r'^\d{11}$')),
      );
    });

    test('keeps representative server IDs distinct', () {
      expect(
        displayTradingTicketId('5ff94719-e61a-4c05-bbab-bb6f81c15369'),
        '71383708458',
      );
      expect(
        displayTradingTicketId('5ff94719-e61a-4c05-bbab-bb6f81c15369'),
        isNot('11615687251'),
      );
    });

    test('shortens long numeric and demo IDs with the same contract', () {
      expect(displayTradingTicketId('101568571012345'), '11003026972');
      expect(displayTradingTicketId('demo-position-1'), '46274091712');
    });

    test('does not manufacture a ticket for an empty ID', () {
      expect(displayTradingTicketId(''), isEmpty);
      expect(displayTradingTicketId('   '), isEmpty);
    });
  });
}
