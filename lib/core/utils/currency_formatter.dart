import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _format = NumberFormat('#,##0.00', 'fr_FR');

  static String format(double amount) => 'DH ${_format.format(amount)}';
}
