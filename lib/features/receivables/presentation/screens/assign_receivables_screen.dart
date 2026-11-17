import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/money/money.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/widgets/app_loader.dart';
import '../providers/receivables_providers.dart';

/// Asigna un mismo importe a una o varias personas (ej. S/ 150 a cada padre).
class AssignReceivablesScreen extends ConsumerStatefulWidget {
  const AssignReceivablesScreen({super.key, required this.collectionId});
  final String collectionId;

  @override
  ConsumerState<AssignReceivablesScreen> createState() =>
      _AssignReceivablesScreenState();
}

class _AssignReceivablesScreenState
    extends ConsumerState<AssignReceivablesScreen> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _selected = <String>{};
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige al menos una persona')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(receivablesRepositoryProvider)
          .bulkCreate(
            collectionId: widget.collectionId,
            contactIds: _selected.toList(),
            principal: Money.parse(_amount.text),
            skipExisting: true,
          );
      if (!mounted) return;
      final skipped = _selected.length - created.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${created.length} asignada(s)${skipped > 0 ? ' · $skipped ya tenían obligación' : ''}',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo asignar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(allContactsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar personas'),
        actions: [
          IconButton(
            tooltip: 'Nueva persona',
            icon: const Icon(Icons.person_add_alt),
            onPressed: () => context.push('/personas/nuevo'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Importe por persona',
                  prefixText: 'S/ ',
                ),
                validator: (v) {
                  try {
                    final m = Money.parse(v ?? '');
                    return m.isPositive ? null : 'Debe ser mayor a cero';
                  } on FormatException {
                    return 'Importe inválido (ej. 150 o 150.50)';
                  }
                },
              ),
            ),
            Expanded(
              child: contacts.when(
                loading: () => const AppLoader(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Aún no tienes personas.\nAgrega una con el botón de arriba.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView(
                    children: [
                      for (final c in list)
                        CheckboxListTile(
                          value: _selected.contains(c.id),
                          title: Text(c.displayName),
                          subtitle: c.phone == null ? null : Text(c.phone!),
                          onChanged: (v) => setState(
                            () => v == true
                                ? _selected.add(c.id)
                                : _selected.remove(c.id),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving
                          ? 'Asignando…'
                          : 'Asignar a ${_selected.length} persona(s)',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
