import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrinterService {
  static pw.Font? _arabicFont;
  static pw.Font? _arabicFontBold;

  static Future<pw.Font> _getFont({bool bold = false}) async {
    if (bold && _arabicFontBold != null) return _arabicFontBold!;
    if (!bold && _arabicFont != null) return _arabicFont!;

    const paths = [
      'C:\\Windows\\Fonts\\cour.ttf',
      'C:\\Windows\\Fonts\\COUR.ttf',
    ];
    const boldPaths = [
      'C:\\Windows\\Fonts\\courbd.ttf',
      'C:\\Windows\\Fonts\\COURBD.ttf',
    ];

    final target = bold ? boldPaths : paths;
    for (final path in target) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final font = pw.Font.ttf(bytes.buffer.asByteData());
          if (bold) {
            _arabicFontBold = font;
          } else {
            _arabicFont = font;
          }
          return font;
        }
      } catch (_) {}
    }

    final fallback = pw.Font.courier();
    if (bold) {
      _arabicFontBold = fallback;
    } else {
      _arabicFont = fallback;
    }
    return fallback;
  }

  static Future<void> preloadFonts() async {
    await _getFont();
    await _getFont(bold: true);
  }

  Future<void> printInvoice({
    required String companyName,
    String? phone,
    String? address,
    String? tvaNumber,
    required String invoiceNumber,
    required DateTime date,
    String? customerName,
    required List<InvoiceItem> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    String? footer,
    required bool showTax,
    required double taxRate,
  }) async {
    final pdf = await _generatePdf(
      companyName: companyName,
      phone: phone,
      address: address,
      tvaNumber: tvaNumber,
      invoiceNumber: invoiceNumber,
      date: date,
      customerName: customerName,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      paymentMethod: paymentMethod,
      footer: footer,
      showTax: showTax,
      taxRate: taxRate,
    );
    await Printing.layoutPdf(
      onLayout: (_) => pdf,
    );
  }

  Future<Uint8List> _generatePdf({
    required String companyName,
    String? phone,
    String? address,
    String? tvaNumber,
    required String invoiceNumber,
    required DateTime date,
    String? customerName,
    required List<InvoiceItem> items,
    required double subtotal,
    required double tax,
    required double total,
    required String paymentMethod,
    String? footer,
    required bool showTax,
    required double taxRate,
  }) async {
    final font = await _getFont();
    final fontBold = await _getFont(bold: true);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(4),
        build: (ctx) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(companyName, phone, address, tvaNumber, font, fontBold),
                _dashedDivider(),
                _buildMeta(invoiceNumber, date, customerName, paymentMethod, font),
                _dashedDivider(),
                _buildItemTable(items, font, fontBold),
                _dashedDivider(),
                _buildTotals(subtotal, tax, total, showTax, taxRate, font, fontBold),
                if (footer != null && footer.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  _buildFooter(footer, font),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildHeader(String name, String? phone, String? address, String? tva,
      pw.Font font, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 2.5),
          bottom: pw.BorderSide(width: 2.5),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Text(name,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  font: fontBold, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          if (phone != null && phone.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text(phone,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
            ),
          if (address != null && address.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text(address,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
            ),
          if (tva != null && tva.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text('TVA: $tva',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
            ),
        ],
      ),
    );
  }

  pw.Widget _dashedDivider() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: List.generate(
          60,
          (_) => pw.Container(
                width: 4,
                height: 0.8,
                color: PdfColors.grey600,
              )),
    );
  }

  pw.Widget _buildMeta(String invoiceNumber, DateTime date, String? customer,
      String paymentMethod, pw.Font font) {
    final dateStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final payLabel = paymentMethod == 'cash' ? 'Espèces' : 'Carte';
    final style = pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey900);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(':التاريخ $dateStr', style: style),
              pw.Text(':الساعة $timeStr', style: style),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(':رقم الطلب $invoiceNumber', style: style),
              if (customer != null) pw.Text(':العميل $customer', style: style),
            ],
          ),
          pw.SizedBox(height: 1),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(':طريقة الدفع $payLabel', style: style),
              pw.SizedBox(),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemTable(List<InvoiceItem> items, pw.Font font, pw.Font fontBold) {
    final hStyle = pw.TextStyle(font: fontBold, fontSize: 8, fontWeight: pw.FontWeight.bold);
    final cStyle = pw.TextStyle(font: font, fontSize: 8);
    final border = pw.Border(
      bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey600),
    );

    return pw.Container(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1.2),
              ),
            ),
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
            child: pw.Row(
              children: [
                pw.Expanded(flex: 5, child: pw.Text('المجموع', style: hStyle, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 4, child: pw.Text('السعر', style: hStyle, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 6, child: pw.Text('السلعة', style: hStyle, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 3, child: pw.Text('الوحدة', style: hStyle, textAlign: pw.TextAlign.center)),
                pw.Expanded(flex: 3, child: pw.Text('الكمية', style: hStyle, textAlign: pw.TextAlign.center)),
              ],
            ),
          ),
          ...items.map((item) => pw.Container(
                decoration: pw.BoxDecoration(border: border),
                padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: pw.Text(
                      '${(item.price * item.quantity).toStringAsFixed(2)} DH',
                      style: cStyle, textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 4, child: pw.Text(
                      '${item.price.toStringAsFixed(2)} DH',
                      style: cStyle, textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 6, child: pw.Text(
                      item.name, style: cStyle, textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 3, child: pw.Text(
                      'Unité', style: cStyle, textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 3, child: pw.Text(
                      '${item.quantity}', style: cStyle, textAlign: pw.TextAlign.center)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  pw.Widget _buildTotals(double subtotal, double tax, double total, bool showTax,
      double taxRate, pw.Font font, pw.Font fontBold) {
    final style = pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey900);
    final boldStyle = pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('المبلغ قبل الضريبة (HT)', style: style),
              pw.Text('${subtotal.toStringAsFixed(2)} DH', style: style),
            ],
          ),
          if (showTax && taxRate > 0) ...[
            pw.SizedBox(height: 1),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('الضريبة ($taxRate%)', style: style),
                pw.Text('${tax.toStringAsFixed(2)} DH', style: style),
              ],
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2.0),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('المجموع (TTC)', style: boldStyle),
                pw.Text('${total.toStringAsFixed(2)} DH', style: boldStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(String message, pw.Font font) {
    return pw.Text(message,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600));
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final double price;
  const InvoiceItem({required this.name, required this.quantity, required this.price});
}
