import 'package:intl/intl.dart';

/// Calculations use integer cents and thousandths: never binary floating point.
abstract final class Amounts {
  static final NumberFormat _money = NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  );

  static String money(int cents) => _money.format(cents / 100);

  static String quantity(int milli) {
    final whole = milli ~/ 1000;
    final fraction = (milli % 1000).toString().padLeft(3, '0');
    final trimmed = fraction.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? '$whole' : '$whole,$trimmed';
  }

  /// Accepts 12,50 / 12.50 / 1.250,50, rejecting more than 2 decimals.
  static int? parseCents(String input) => _parseScaled(input, 2);

  /// Accepts up to 3 fractional digits (e.g., 1,5 hours).
  static int? parseQuantity(String input) => _parseScaled(input, 3);

  static int? _parseScaled(String input, int decimals) {
    var clean = input.trim().replaceAll('€', '').replaceAll(' ', '');
    if (clean.isEmpty) return null;
    if (clean.contains(',')) clean = clean.replaceAll('.', '').replaceAll(',', '.');
    if (!RegExp(r'^\d+(?:\.\d+)?$').hasMatch(clean)) return null;
    final parts = clean.split('.');
    if (parts.length == 2 && parts[1].length > decimals) return null;
    final whole = int.tryParse(parts[0]);
    if (whole == null) return null;
    final scale = switch (decimals) { 2 => 100, 3 => 1000, _ => 1 };
    final fractional = parts.length == 2
        ? int.tryParse(parts[1].padRight(decimals, '0'))
        : 0;
    if (fractional == null) return null;
    return whole * scale + fractional;
  }
}
