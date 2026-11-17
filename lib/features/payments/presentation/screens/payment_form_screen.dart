import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../installments/data/installments_repository.dart';
import '../../../receivables/presentation/providers/receivables_providers.dart';
import '../providers/payments_providers.dart';
import '../../data/attachments_repository.dart';
import '../../domain/payment_errors.dart';
import '../../domain/payment_options.dart';
import '../../../../core/widgets/home_button.dart';

/// Registrar un abono. Pocos toques: importe + Guardar (efectivo se confirma
/// al instante; Yape/Plin/transferencia quedan por verificar por defecto).
class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({
    super.key,
    required this.receivableId,
    this.installmentId,
  });
  final String receivableId;

  /// Cuota preseleccionada (al tocarla en el detalle).
  final String? installmentId;

  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _images = <XFile>[];
  DateTime _date = DateTime.now();
  String _method = 'cash';
  bool _confirmNow = true;
  bool _confirmTouched = false;
  bool _saving = false;
  bool _prefilled = false;
  String? _installmentId; // null = automático (cuota más antigua)

  @override
  void initState() {
    super.initState();
    _installmentId = widget.installmentId;
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (f != null && mounted) setState(() => _images.add(f));
    } catch (e) {
      if (mounted) _toast('No se pudo abrir la imagen: $e');
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (d != null) setState(() => _date = d);
  }

  /// Sugiere el importe: lo que falta de la cuota elegida (o de la más
  /// antigua con saldo); sin plan, el saldo total.
  void _fillAmount(int balanceMinor, List<InstallmentView> open) {
    InstallmentView? target;
    for (final v in open) {
      if (_installmentId == null || v.installment.id == _installmentId) {
        target = v;
        break;
      }
    }
    final minor = target == null
        ? balanceMinor
        : (target.remainingMinor < balanceMinor
              ? target.remainingMinor
              : balanceMinor);
    _amount.text = (minor / 100).toStringAsFixed(2);
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payment = await ref
          .read(paymentsRepositoryProvider)
          .register(
            receivableId: widget.receivableId,
            amount: Money.parse(_amount.text),
            occurredAt: _date,
            method: _method,
            reference: _reference.text,
            notes: _notes.text,
            confirmNow: _confirmNow,
            installmentId: _installmentId,
          );
      var failed = 0;
      final attachments = ref.read(attachmentsRepositoryProvider);
      for (final img in _images) {
        try {
          await attachments.add(
            paymentId: payment.id,
            source: File(img.path),
            mimeType:
                AttachmentsRepository.mimeFromPath(img.path) ?? 'image/jpeg',
          );
        } on PaymentException {
          failed++;
        }
      }
      if (!mounted) return;
      if (failed > 0) {
        _toast(
          'Abono guardado, pero $failed imagen(es) no se pudieron adjuntar',
        );
      }
      context.pop();
    } on FormatException {
      setState(() => _saving = false);
      _toast('Importe inválido');
    } on PaymentException catch (e) {
      setState(() => _saving = false);
      _toast(e.message);
    } catch (e) {
      setState(() => _saving = false);
      _toast('No se pudo guardar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref
        .watch(balanceProvider(widget.receivableId))
        .asData
        ?.value;
    final plan = ref.watch(installmentPlanProvider(widget.receivableId));
    final open = [
      for (final v in plan.asData?.value ?? const <InstallmentView>[])
        if (v.remainingMinor > 0) v,
    ];
    if (!_prefilled && balance != null && plan.hasValue) {
      _prefilled = true;
      _fillAmount(balance.balanceMinor, open);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar abono'),
        actions: const [HomeButton()],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (balance != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Saldo pendiente: ${Money.minor(balance.balanceMinor).format()}',
                ),
              ),
            if (open.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue:
                    open.any((v) => v.installment.id == _installmentId)
                    ? _installmentId
                    : null,
                decoration: const InputDecoration(labelText: 'Aplicar a'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Automático (cuota más antigua)'),
                  ),
                  for (final v in open)
                    DropdownMenuItem(
                      value: v.installment.id,
                      child: Text(
                        'Cuota ${v.installment.sequence} · falta '
                        '${Money.minor(v.remainingMinor).format()}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _installmentId = v;
                  if (balance != null) _fillAmount(balance.balanceMinor, open);
                }),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amount,
              autofocus: true,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Importe',
                prefixText: 'S/ ',
              ),
              validator: (v) {
                try {
                  final m = Money.parse(v ?? '');
                  if (!m.isPositive) return 'Debe ser mayor a cero';
                  if (balance != null && m.minor > balance.balanceMinor) {
                    return 'Excede el saldo (${Money.minor(balance.balanceMinor).format()})';
                  }
                  return null;
                } on FormatException {
                  return 'Importe inválido (ej. 30 o 30.50)';
                }
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final e in paymentMethodLabels.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _method == e.key,
                    onSelected: (_) => setState(() {
                      _method = e.key;
                      if (!_confirmTouched) _confirmNow = e.key == 'cash';
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(DateFormat.yMMMd('es').format(_date)),
              onTap: _pickDate,
            ),
            TextFormField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Referencia / N.° de operación (opcional)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Notas (opcional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            const Text('Comprobantes'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _images.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_images[i].path),
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: InkWell(
                          onTap: () => setState(() => _images.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galería'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Cámara'),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Confirmar pago ahora'),
              subtitle: Text(
                _confirmNow ? 'Descuenta del saldo de inmediato.' : 'Queda "por verificar": una captura de Yape/Plin no confirma el pago por sí sola.',
              ),
              value: _confirmNow,
              onChanged: (v) => setState(() {
                _confirmNow = v;
                _confirmTouched = true;
              }),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar abono'),
            ),
          ],
        ),
      ),
    );
  }
}
