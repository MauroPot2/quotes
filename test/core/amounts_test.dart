import 'package:flutter_test/flutter_test.dart';
import 'package:preventivo/core/formatting/amounts.dart';

void main() {
  group('Amounts', () {
    test('parses Italian euro values exactly to cents', () {
      expect(Amounts.parseCents('1.234,56'), 123456);
      expect(Amounts.parseCents('12,5'), 1250);
      expect(Amounts.parseCents('0'), 0);
      expect(Amounts.parseCents('1,234'), isNull);
      expect(Amounts.parseCents('-3'), isNull);
    });

    test('parses quantities as thousandths', () {
      expect(Amounts.parseQuantity('1,5'), 1500);
      expect(Amounts.parseQuantity('0,125'), 125);
      expect(Amounts.quantity(1250), '1,25');
      expect(Amounts.quantity(2000), '2');
      expect(Amounts.parseQuantity('1,0001'), isNull);
    });
  });
}
