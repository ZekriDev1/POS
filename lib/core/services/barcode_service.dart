import 'dart:async';
import 'package:flutter/services.dart';

class BarcodeService {
  Timer? _timer;
  String _buffer = '';
  final int timeoutMs;
  final void Function(String barcode) onBarcode;

  BarcodeService({
    required this.onBarcode,
    this.timeoutMs = 250,
  });

  void handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey.keyLabel;
      if (key.length == 1) {
        _buffer += key;
        _timer?.cancel();
        _timer = Timer(Duration(milliseconds: timeoutMs), () {
          if (_buffer.length >= 4) {
            onBarcode(_buffer);
          }
          _buffer = '';
        });
      }
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
