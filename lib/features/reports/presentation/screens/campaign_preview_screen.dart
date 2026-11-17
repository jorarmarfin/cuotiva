import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/pdf/pdf_builders.dart';
import '../../../../core/providers/repository_providers.dart';
import '../widgets/pdf_preview_scaffold.dart';

/// Reporte de un cobro (campaña): totales, participantes y fondos de terceros.
class CampaignPreviewScreen extends ConsumerWidget {
  const CampaignPreviewScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PdfPreviewScaffold(
    title: 'Reporte de cobro',
    fileName: 'reporte_de_cobro',
    buildPdf: () async => buildCampaignPdf(
      await ref.read(reportsRepositoryProvider).campaignReport(collectionId),
    ),
  );
}
