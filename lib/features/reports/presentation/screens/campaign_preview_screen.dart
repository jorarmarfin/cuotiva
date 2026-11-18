import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pdf/pdf_builders.dart';
import '../../../../core/pdf/pdf_logo.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/utils/slug.dart';
import '../widgets/pdf_preview_scaffold.dart';

/// Reporte de un cobro (campaña): totales, participantes y fondos de terceros.
class CampaignPreviewScreen extends ConsumerStatefulWidget {
  const CampaignPreviewScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  ConsumerState<CampaignPreviewScreen> createState() => _CampaignState();
}

class _CampaignState extends ConsumerState<CampaignPreviewScreen> {
  var _name = 'reporte-de-cobro';

  @override
  Widget build(BuildContext context) => PdfPreviewScaffold(
    title: 'Reporte de cobro',
    fileName: () => _name,
    buildPdf: () async {
      final data = await ref
          .read(reportsRepositoryProvider)
          .campaignReport(widget.collectionId);
      _name = reportFileName('reporte-de-cobro', [data.title]);
      return buildCampaignPdf(data, logo: await loadPdfLogo());
    },
  );
}
