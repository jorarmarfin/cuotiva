import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/pdf/pdf_share_service.dart';
import '../../../../core/widgets/home_button.dart';

/// Vista previa de un PDF con botón de compartir. Antes de compartir avisa
/// de que el documento contiene datos personales (CUOTIVA_SPEC §6).
class PdfPreviewScaffold extends StatelessWidget {
  const PdfPreviewScaffold({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildPdf,
    this.controls,
    this.rebuildKey,
  });

  final String title;
  final String fileName;
  final Future<Uint8List> Function() buildPdf;
  final Widget? controls;

  /// Cambia cuando el PDF debe regenerarse (opciones modificadas).
  final Object? rebuildKey;

  Future<void> _share(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datos personales'),
        content: const Text(
          'Este PDF contiene nombres y montos de personas. Compártelo solo '
          'con quien corresponda y revisa que no incluya teléfono ni notas '
          'privadas si no es necesario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Compartir'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await sharePdf(await buildPdf(), fileName);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        const HomeButton(),
        IconButton(
          tooltip: 'Compartir',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _share(context),
        ),
      ],
    ),
    body: Column(
      children: [
        ?controls,
        Expanded(
          child: PdfPreview(
            key: ValueKey(rebuildKey),
            build: (_) => buildPdf(),
            canChangeOrientation: false,
            canChangePageFormat: false,
            canDebug: false,
            useActions: false,
            pdfFileName: '$fileName.pdf',
          ),
        ),
      ],
    ),
  );
}
