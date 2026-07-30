import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _format = NumberFormat('#,##0.00', 'fr_FR');
  static String _symbol = 'DH';

  static String get symbol => _symbol;
  static set symbol(String s) => _symbol = s;

  static String format(double amount) => '$_symbol ${_format.format(amount)}';
}
