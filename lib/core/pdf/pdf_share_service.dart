import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Guarda el PDF en la carpeta temporal y abre la hoja nativa de compartir
/// (WhatsApp u otras apps). No usa ninguna API de mensajería.
Future<void> sharePdf(Uint8List bytes, String fileName) async {
  final dir = await getTemporaryDirectory();
  final safe = fileName.replaceAll(RegExp(r'[^\w\-.]+'), '_');
  final file = File('${dir.path}/$safe.pdf');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: fileName,
    ),
  );
}
