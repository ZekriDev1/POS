import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrinterService {
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
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  if (phone != null) pw.Text(phone, style: const pw.TextStyle(fontSize: 10)),
                  if (address != null) pw.Text(address, style: const pw.TextStyle(fontSize: 10)),
                  if (tvaNumber != null) pw.Text('TVA: $tvaNumber', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('INVOICE', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
                  pw.Text('No: $invoiceNumber', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Date: ${date.day}/${date.month}/${date.year}', style: const pw.TextStyle(fontSize: 10)),
                  if (customerName != null) pw.Text('Customer: $customerName', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Payment: $paymentMethod', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['#', 'Product', 'Qty', 'Price', 'Total'],
            data: items.asMap().entries.map((e) => [
              '${e.key + 1}',
              e.value.name,
              '${e.value.quantity}',
              '${e.value.price.toStringAsFixed(2)} DH',
              '${(e.value.price * e.value.quantity).toStringAsFixed(2)} DH',
            ]).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Subtotal: ${subtotal.toStringAsFixed(2)} DH'),
                  if (showTax && taxRate > 0)
                    pw.Text('TVA (${taxRate.toStringAsFixed(1)}%): ${tax.toStringAsFixed(2)} DH'),
                  pw.Divider(),
                  pw.Text('Total: ${total.toStringAsFixed(2)} DH',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (footer != null) ...[
            pw.SizedBox(height: 32),
            pw.Text(footer, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ],
        ],
      ),
    );
    return pdf.save();
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final double price;
  const InvoiceItem({required this.name, required this.quantity, required this.price});
}
