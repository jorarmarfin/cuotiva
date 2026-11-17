import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../domain/installment_planner.dart';

class _Row {
  _Row(this.dueAt, String amount)
    : controller = TextEditingController(text: amount);
  DateTime dueAt;
  final TextEditingController controller;
}

/// Define o edita el plan de cuotas de una obligación. Las fechas e importes
/// son editables y la suma debe ser exactamente el total.
class InstallmentPlanScreen extends ConsumerStatefulWidget {
  const InstallmentPlanScreen({super.key, required this.receivableId});
  final String receivableId;

  @override
  ConsumerState<InstallmentPlanScreen> createState() =>
      _InstallmentPlanScreenState();
}

class _InstallmentPlanScreenState extends ConsumerState<InstallmentPlanScreen> {
  final _rows = <_Row>[];
  final _count = TextEditingController(text: '3');
  int _principal = 0;
  bool _hadPlan = false;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _count.dispose();
    for (final r in _rows) {
      r.controller.dispose();
    }
    super.dispose();
  }

  String _fmt(int minor) => (minor / 100).toStringAsFixed(2);

  Future<void> _load() async {
    final r = await ref
        .read(receivablesRepositoryProvider)
        .find(widget.receivableId);
    final existing = await ref
        .read(installmentsRepositoryProvider)
        .list(widget.receivableId);
    if (!mounted) return;
    setState(() {
      _principal = r?.principalMinor ?? 0;
      _hadPlan = existing.isNotEmpty;
      for (final i in existing) {
        _rows.add(_Row(i.dueAt, _fmt(i.amountMinor)));
      }
      _loaded = true;
    });
  }

  void _generate() {
    final n = int.tryParse(_count.text.trim()) ?? 0;
    try {
      final first = DateTime.now().add(const Duration(days: 30));
      final drafts = InstallmentPlanner.even(
        principalMinor: _principal,
        count: n,
        firstDue: first,
      );
      setState(() {
        for (final r in _rows) {
          r.controller.dispose();
        }
        _rows
          ..clear()
          ..addAll([
            for (final d in drafts) _Row(d.dueAt, _fmt(d.amountMinor)),
          ]);
      });
    } on PlanException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _pickDate(_Row row) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: row.dueAt,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => row.dueAt = d);
  }

  /// null si algún importe es inválido.
  List<InstallmentDraft>? _drafts() {
    final out = <InstallmentDraft>[];
    for (final r in _rows) {
      try {
        out.add(
          InstallmentDraft(
            dueAt: r.dueAt,
            amountMinor: Money.parse(r.controller.text).minor,
          ),
        );
      } on FormatException {
        return null;
      }
    }
    return out;
  }

  /// Mensaje de estado de la suma (null si cuadra).
  String? _sumMessage() {
    final d = _drafts();
    if (d == null) return 'Hay importes inválidos';
    if (d.isEmpty) return null;
    final sum = d.fold<int>(0, (s, x) => s + x.amountMinor);
    final diff = _principal - sum;
    if (diff == 0) return null;
    return diff > 0
        ? 'Faltan ${Money.minor(diff).format()} para completar ${Money.minor(_principal).format()}'
        : 'Exceden el total en ${Money.minor(-diff).format()}';
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _save() async {
    final drafts = _drafts();
    if (drafts == null) return _toast('Hay importes inválidos');
    setState(() => _saving = true);
    try {
      await ref
          .read(installmentsRepositoryProvider)
          .setPlan(widget.receivableId, drafts);
      if (mounted) context.pop();
    } on PlanException catch (e) {
      setState(() => _saving = false);
      _toast(e.message);
    } catch (e) {
      setState(() => _saving = false);
      _toast('No se pudo guardar: $e');
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar el plan?'),
        content: const Text(
          'La obligación vuelve a pago libre. Los abonos no se modifican.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(installmentsRepositoryProvider)
        .clearPlan(widget.receivableId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final msg = _loaded ? _sumMessage() : null;
    final fmt = DateFormat.yMMMd('es');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan de cuotas'),
        actions: [
          if (_hadPlan)
            IconButton(
              tooltip: 'Quitar plan',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Total a repartir: ${Money.minor(_principal).format()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'N.° de cuotas',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: _generate,
                      child: const Text('Generar iguales'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < _rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.event, size: 18),
                            label: Text(fmt.format(_rows[i].dueAt)),
                            onPressed: () => _pickDate(_rows[i]),
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _rows[i].controller,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'S/ ',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar cuota',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setState(
                            () => _rows.removeAt(i).controller.dispose(),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar cuota'),
                  onPressed: () => setState(() {
                    final last = _rows.isEmpty
                        ? DateTime.now()
                        : _rows.last.dueAt;
                    _rows.add(
                      _Row(InstallmentPlanner.addMonths(last, 1), '0.00'),
                    );
                  }),
                ),
                if (msg != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      msg,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving || _rows.isEmpty || msg != null
                      ? null
                      : _save,
                  child: Text(_saving ? 'Guardando…' : 'Guardar plan'),
                ),
              ],
            ),
    );
  }
}
