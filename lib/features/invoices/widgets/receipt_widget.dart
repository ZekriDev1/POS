import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class ReceiptItem {
  final String name;
  final String unit;
  final int quantity;
  final double price;

  const ReceiptItem({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.price,
  });

  double get total => quantity * price;
}

class ReceiptWidget extends StatelessWidget {
  final String storeName;
  final String? storePhone;
  final String? storeCity;
  final String? storeTvaNumber;
  final String date;
  final String time;
  final String orderNumber;
  final String cashier;
  final String paymentMethod;
  final List<ReceiptItem> items;
  final double taxRate;
  final String? footerMessage;
  final String currencySymbol;

  const ReceiptWidget({
    super.key,
    required this.storeName,
    this.storePhone,
    this.storeCity,
    this.storeTvaNumber,
    required this.date,
    required this.time,
    required this.orderNumber,
    required this.cashier,
    required this.paymentMethod,
    required this.items,
    required this.taxRate,
    this.footerMessage,
    this.currencySymbol = 'DH',
  });

  double get _subtotal => items.fold(0.0, (sum, item) => sum + item.total);
  double get _taxAmount => _subtotal * taxRate / 100;
  double get _grandTotal => _subtotal + _taxAmount;

  String _fmt(double amount) {
    final f = NumberFormat('#,##0.00', 'fr_FR');
    return '${f.format(amount)} $currencySymbol';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderSection(
              storeName: storeName,
              storePhone: storePhone,
              storeCity: storeCity,
              storeTvaNumber: storeTvaNumber,
            ),
            const _DashedDivider(),
            _MetaSection(
              date: date,
              time: time,
              orderNumber: orderNumber,
              cashier: cashier,
              paymentMethod: paymentMethod,
            ),
            const _DashedDivider(),
            _ItemsTable(items: items, fmt: _fmt),
            const _DashedDivider(),
            _TotalsSection(
              subtotal: _subtotal,
              taxRate: taxRate,
              taxAmount: _taxAmount,
              grandTotal: _grandTotal,
              fmt: _fmt,
            ),
            if (footerMessage != null && footerMessage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FooterSection(message: footerMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final String storeName;
  final String? storePhone;
  final String? storeCity;
  final String? storeTvaNumber;

  const _HeaderSection({
    required this.storeName,
    this.storePhone,
    this.storeCity,
    this.storeTvaNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black, width: 3),
          bottom: BorderSide(color: Colors.black, width: 3),
        ),
      ),
      child: Column(
        children: [
          Text(
            storeName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Courier New',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          if (storePhone != null && storePhone!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              storePhone!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87),
            ),
          ],
          if (storeCity != null && storeCity!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              storeCity!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87),
            ),
          ],
          if (storeTvaNumber != null && storeTvaNumber!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'TVA: ${storeTvaNumber!}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  final String date;
  final String time;
  final String orderNumber;
  final String cashier;
  final String paymentMethod;

  const _MetaSection({
    required this.date,
    required this.time,
    required this.orderNumber,
    required this.cashier,
    required this.paymentMethod,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(':التاريخ $date', style: style),
              Text(':الساعة $time', style: style),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(':رقم الطلب $orderNumber', style: style),
              Text(':البائع $cashier', style: style),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(':طريقة الدفع $paymentMethod', style: style),
              const SizedBox.shrink(),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsTable extends StatelessWidget {
  final List<ReceiptItem> items;
  final String Function(double) fmt;

  const _ItemsTable({required this.items, required this.fmt});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontFamily: 'Courier New',
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );
    const cellStyle = TextStyle(fontFamily: 'Courier New', fontSize: 10, color: Colors.black87);
    const borderSide = BorderSide(color: Colors.black, width: 0.5);

    final columnWidths = const {
      0: FixedColumnWidth(60),  // Total (المجموع)
      1: FixedColumnWidth(50),  // Price (السعر)
      2: FlexColumnWidth(),     // Item (السلعة)
      3: FixedColumnWidth(40),  // Unit (الوحدة)
      4: FixedColumnWidth(36),  // Qty (الكمية)
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: columnWidths,
          border: TableBorder(
            horizontalInside: borderSide,
            bottom: borderSide,
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black, width: 1.5)),
              ),
              children: [
                _headerCell('المجموع', headerStyle),
                _headerCell('السعر', headerStyle),
                _headerCell('السلعة', headerStyle),
                _headerCell('الوحدة', headerStyle),
                _headerCell('الكمية', headerStyle),
              ],
            ),
            ...items.map((item) => TableRow(
              children: [
                _cell(fmt(item.total), cellStyle, align: TextAlign.center),
                _cell(fmt(item.price), cellStyle, align: TextAlign.center),
                _cell(item.name, cellStyle),
                _cell(item.unit, cellStyle, align: TextAlign.center),
                _cell('${item.quantity}', cellStyle, align: TextAlign.center),
              ],
            )),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '(لا توجد عناصر)',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black45),
            ),
          ),
      ],
    );
  }

  static Widget _headerCell(String text, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }

  static Widget _cell(String text, TextStyle style, {TextAlign align = TextAlign.start}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(text, style: style, textAlign: align),
    );
  }
}

class _TotalsSection extends StatelessWidget {
  final double subtotal;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final String Function(double) fmt;

  const _TotalsSection({
    required this.subtotal,
    required this.taxRate,
    required this.taxAmount,
    required this.grandTotal,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87);
    const valueStyle = TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black87);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _totalRow('المبلغ قبل الضريبة (HT)', fmt(subtotal), labelStyle, valueStyle),
          const SizedBox(height: 2),
          _totalRow('الضريبة ($taxRate%)', fmt(taxAmount), labelStyle, valueStyle),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المجموع (TTC)',
                  style: TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  fmt(grandTotal),
                  style: const TextStyle(
                    fontFamily: 'Courier New',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _totalRow(String label, String value, TextStyle labelStyle, TextStyle valueStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _FooterSection extends StatelessWidget {
  final String message;

  const _FooterSection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Colors.black54),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashGap = 3.0;
        final count = (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) => Container(
            width: dashWidth,
            height: 1,
            color: Colors.black54,
          )),
        );
      },
    );
  }
}
