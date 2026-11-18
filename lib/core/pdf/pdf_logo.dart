import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

Uint8List? _cached;

/// Logo de Cuotiva reducido para PDF (el original pesa ~600 KB y se repetiría
/// en cada documento). Devuelve null si no se puede cargar: el PDF se genera
/// igual, sin logo.
Future<Uint8List?> loadPdfLogo() async {
  if (_cached != null) return _cached;
  try {
    final data = await rootBundle.load('assets/images/logo.png');
    final src = img.decodePng(data.buffer.asUint8List());
    if (src == null) return null;
    final small = img.copyResize(src, width: 160, height: 160);
    return _cached = Uint8List.fromList(img.encodePng(small));
  } catch (_) {
    return null;
  }
}
