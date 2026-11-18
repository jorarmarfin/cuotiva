import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pdf/pdf_builders.dart';
import '../../../../core/pdf/pdf_logo.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/slug.dart';
import '../../domain/report_models.dart';
import '../widgets/pdf_preview_scaffold.dart';

/// Estado de cuenta individual con opciones de contenido/privacidad.
class StatementPreviewScreen extends ConsumerStatefulWidget {
  const StatementPreviewScreen({super.key, required this.receivableId});
  final String receivableId;

  @override
  ConsumerState<StatementPreviewScreen> createState() => _State();
}

class _State extends ConsumerState<StatementPreviewScreen> {
  var _options = const StatementOptions();
  var _name = 'estado-de-cuenta';

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, bool value, StatementOptions Function(bool) f) =>
        FilterChip(
          label: Text(label),
          selected: value,
          onSelected: (v) => setState(() => _options = f(v)),
        );
    return PdfPreviewScaffold(
      title: 'Estado de cuenta',
      fileName: () => _name,
      rebuildKey: _options,
      controls: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          children: [
            chip(
              'Teléfono',
              _options.includePhone,
              (v) => _options.copyWith(includePhone: v),
            ),
            chip(
              'Notas internas',
              _options.includeNotes,
              (v) => _options.copyWith(includeNotes: v),
            ),
            chip(
              'Cuotas',
              _options.includeInstallments,
              (v) => _options.copyWith(includeInstallments: v),
            ),
            chip(
              'Comprobantes',
              _options.includeAttachments,
              (v) => _options.copyWith(includeAttachments: v),
            ),
            chip(
              'Pendientes',
              _options.includePending,
              (v) => _options.copyWith(includePending: v),
            ),
          ],
        ),
      ),
      buildPdf: () async {
        final data = await ref
            .read(reportsRepositoryProvider)
            .statementFor(
              widget.receivableId,
              includeAttachments: _options.includeAttachments,
            );
        _name = reportFileName('estado-de-cuenta', [
          data.collectionTitle,
          data.personName,
        ]);
        return buildStatementPdf(
          data,
          options: _options,
          logo: await loadPdfLogo(),
        );
      },
    );
  }
}
