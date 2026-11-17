import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../features/payments/domain/payment_options.dart';
import '../../features/reports/domain/report_models.dart';
import '../money/money.dart';
import 'pdf_text.dart';

/// Generadores de PDF puros (datos → bytes). A4 con paginación automática.
/// Colores del PDF: paleta fija de marca (no depende de un `BuildContext`).
const _brand = PdfColor.fromInt(0xFF6D28D9);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);

const statementDisclaimer =
    'Este documento es un estado de cuenta informativo, no un comprobante tributario.';

const _numeric = {'Importe', 'Pagado', 'Saldo', 'Cuota'};

String _m(int minor, String currency) =>
    pdfSafe(Money.minor(minor, currency: currency).format());
String _d(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

pw.Widget _header(String title, String subtitle) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Cuotiva',
          style: const pw.TextStyle(
            color: _brand,
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          pdfSafe(title),
          style: const pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      pdfSafe(subtitle),
      style: const pw.TextStyle(color: _muted, fontSize: 10),
    ),
    pw.Divider(color: _line),
  ],
);

pw.Widget _kv(String k, String v, {bool bold = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(pdfSafe(k), style: const pw.TextStyle(fontSize: 10)),
      pw.Text(
        pdfSafe(v),
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  ),
);

pw.Widget _section(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 14, bottom: 4),
  child: pw.Text(
    pdfSafe(t),
    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
  ),
);

pw.Widget _table(List<String> headers, List<List<String>> rows) =>
    pw.TableHelper.fromTextArray(
      headers: [for (final h in headers) pdfSafe(h)],
      data: [
        for (final r in rows) [for (final c in r) pdfSafe(c)],
      ],
      headerStyle: const pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        for (var i = 0; i < headers.length; i++)
          i: _numeric.contains(headers[i])
              ? pw.Alignment.centerRight
              : pw.Alignment.centerLeft,
      },
      oddRowDecoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF9FAFB),
      ),
    );

pw.Widget _footer(pw.Context ctx, DateTime issuedAt) => pw.Row(
  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  children: [
    pw.Text(
      'Emitido el ${_d(issuedAt)}',
      style: const pw.TextStyle(color: _muted, fontSize: 8),
    ),
    pw.Text(
      'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
      style: const pw.TextStyle(color: _muted, fontSize: 8),
    ),
  ],
);

pw.PageTheme _pageTheme() => const pw.PageTheme(
  pageFormat: PdfPageFormat.a4,
  margin: pw.EdgeInsets.all(36),
);

/// Estado de cuenta individual.
Future<Uint8List> buildStatementPdf(
  StatementData s, {
  StatementOptions options = const StatementOptions(),
  bool compress = true,
}) async {
  final doc = pw.Document(
    title: 'Estado de cuenta',
    author: 'Cuotiva',
    compress: compress,
  );
  final cur = s.currency;
  doc.addPage(
    pw.MultiPage(
      pageTheme: _pageTheme(),
      footer: (ctx) => _footer(ctx, s.issuedAt),
      build: (ctx) => [
        _header('Estado de cuenta', s.spaceName),
        _kv('Persona', s.personName),
        if (options.includePhone && s.phone != null) _kv('Teléfono', s.phone!),
        _kv('Concepto', s.collectionTitle),
        _kv('Moneda', cur),
        _kv('Importe original', _m(s.principalMinor, cur)),
        _kv('Estado', s.statusLabel),
        if (options.includeNotes && s.notes != null) _kv('Notas', s.notes!),
        _section('Movimientos confirmados'),
        if (s.confirmed.isEmpty)
          pw.Text(
            'Sin movimientos confirmados.',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          )
        else
          _table(
            ['Fecha', 'Método', 'Referencia', 'Importe'],
            [
              for (final p in s.confirmed)
                [
                  _d(p.date),
                  paymentMethodLabel(p.method),
                  p.reference ?? '',
                  _m(p.amountMinor, cur),
                ],
            ],
          ),
        pw.SizedBox(height: 8),
        _kv('Total confirmado', _m(s.confirmedMinor, cur), bold: true),
        _kv('Saldo pendiente', _m(s.balanceMinor, cur), bold: true),
        if (options.includeInstallments && s.installments.isNotEmpty) ...[
          _section('Cuotas'),
          _table(
            ['N°', 'Vence', 'Cuota', 'Pagado'],
            [
              for (final i in s.installments)
                [
                  '${i.sequence}',
                  _d(i.dueAt),
                  _m(i.amountMinor, cur),
                  _m(i.paidMinor, cur),
                ],
            ],
          ),
        ],
        if (options.includePending && s.pending.isNotEmpty) ...[
          _section('Pendientes de verificación (no descuentan saldo)'),
          _table(
            ['Fecha', 'Método', 'Referencia', 'Importe'],
            [
              for (final p in s.pending)
                [
                  _d(p.date),
                  paymentMethodLabel(p.method),
                  p.reference ?? '',
                  _m(p.amountMinor, cur),
                ],
            ],
          ),
        ],
        if (options.includeAttachments && s.images.isNotEmpty) ...[
          _section('Comprobantes'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final img in s.images)
                pw.Image(pw.MemoryImage(img), width: 150, height: 150),
            ],
          ),
        ],
        pw.SizedBox(height: 18),
        pw.Text(
          pdfSafe(statementDisclaimer),
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Reporte de campaña: totales, participantes y, si son fondos de terceros,
/// recaudado / entregado / por entregar.
Future<Uint8List> buildCampaignPdf(
  CampaignReportData c, {
  bool compress = true,
}) async {
  final doc = pw.Document(
    title: 'Reporte de cobro',
    author: 'Cuotiva',
    compress: compress,
  );
  doc.addPage(
    pw.MultiPage(
      pageTheme: _pageTheme(),
      footer: (ctx) => _footer(ctx, c.issuedAt),
      build: (ctx) => [
        _header('Reporte de cobro', '${c.spaceName} - ${c.title}'),
        _kv('Participantes', '${c.participants.length}'),
        _kv('Comprometido', _m(c.committedMinor, 'PEN')),
        _kv('Recaudado', _m(c.collectedMinor, 'PEN')),
        _kv('Pendiente', _m(c.pendingMinor, 'PEN'), bold: true),
        _kv('Vencido', _m(c.overdueMinor, 'PEN')),
        if (c.thirdParty) ...[
          _section('Fondos de terceros'),
          _kv('Recaudado', _m(c.collectedMinor, 'PEN')),
          _kv('Entregado', _m(c.deliveredMinor, 'PEN')),
          _kv('Por entregar', _m(c.toDeliverMinor, 'PEN'), bold: true),
          if (c.settlements.isNotEmpty)
            _table(
              ['Fecha', 'Entregado a', 'Importe'],
              [
                for (final s in c.settlements)
                  [_d(s.date), s.reference ?? '', _m(s.amountMinor, 'PEN')],
              ],
            ),
        ],
        _section('Participantes'),
        if (c.participants.isEmpty)
          pw.Text(
            'Sin participantes.',
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          )
        else
          _table(
            ['Persona', 'Importe', 'Pagado', 'Saldo', 'Estado'],
            [
              for (final p in c.participants)
                [
                  p.name,
                  _m(p.principalMinor, 'PEN'),
                  _m(p.confirmedMinor, 'PEN'),
                  _m(p.balanceMinor, 'PEN'),
                  p.statusLabel,
                ],
            ],
          ),
        pw.SizedBox(height: 18),
        pw.Text(
          pdfSafe(statementDisclaimer),
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}
