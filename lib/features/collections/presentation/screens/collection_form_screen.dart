import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../spaces/presentation/providers/spaces_providers.dart';
import '../../domain/collection_labels.dart';
import '../providers/collections_providers.dart';

/// Crear (collectionId == null) o editar un cobro. [spaceId] preselecciona espacio.
class CollectionFormScreen extends ConsumerStatefulWidget {
  const CollectionFormScreen({super.key, this.collectionId, this.spaceId});
  final String? collectionId;
  final String? spaceId;

  @override
  ConsumerState<CollectionFormScreen> createState() =>
      _CollectionFormScreenState();
}

class _CollectionFormScreenState extends ConsumerState<CollectionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  String? _spaceId;
  String _kind = 'other';
  bool _thirdParty = false;
  DateTime? _dueAt;
  bool _loaded = false;
  bool _saving = false;

  bool get _editing => widget.collectionId != null;

  @override
  void initState() {
    super.initState();
    _spaceId = widget.spaceId;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_editing) {
      final c = await ref
          .read(collectionsRepositoryProvider)
          .find(widget.collectionId!);
      if (c != null) {
        _title.text = c.title;
        _notes.text = c.notes ?? '';
        _spaceId = c.spaceId;
        _kind = c.kind;
        _thirdParty = c.fundsOwnership == 'third_party';
        _dueAt = c.dueAt;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (d != null) setState(() => _dueAt = d);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(collectionsRepositoryProvider);
    try {
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      if (_editing) {
        await repo.update(
          widget.collectionId!,
          title: _title.text,
          kind: _kind,
          dueAt: _dueAt,
          notes: notes,
        );
        ref.invalidate(collectionByIdProvider(widget.collectionId!));
      } else {
        await repo.create(
          spaceId: _spaceId!,
          title: _title.text,
          kind: _kind,
          fundsOwnership: _thirdParty ? 'third_party' : 'self',
          dueAt: _dueAt,
          notes: notes,
        );
      }
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final spaces = ref.watch(activeSpacesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar cobro' : 'Nuevo cobro')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _title,
                    decoration: const InputDecoration(
                      labelText: 'Título (ej. Trajes 2027)',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un título'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  spaces.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) =>
                        Text('No se pudieron cargar los espacios: $e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return Card(
                          child: ListTile(
                            title: const Text('Primero crea un espacio'),
                            trailing: const Icon(Icons.add),
                            onTap: () => context.push('/espacios/nuevo'),
                          ),
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: list.any((s) => s.id == _spaceId)
                            ? _spaceId
                            : null,
                        decoration: const InputDecoration(labelText: 'Espacio'),
                        items: [
                          for (final s in list)
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                        ],
                        onChanged: _editing
                            ? null
                            : (v) => setState(() => _spaceId = v),
                        validator: (v) => v == null ? 'Elige un espacio' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _kind,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: [
                      for (final e in collectionKindLabels.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _kind = v ?? 'other'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fondos de terceros'),
                    subtitle: const Text(
                      'Recaudo para entregar a otra persona u organización',
                    ),
                    value: _thirdParty,
                    onChanged: _editing
                        ? null
                        : (v) => setState(() => _thirdParty = v),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: Text(
                      _dueAt == null
                          ? 'Fecha límite (opcional)'
                          : DateFormat.yMMMd('es').format(_dueAt!),
                    ),
                    trailing: _dueAt == null
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _dueAt = null),
                          ),
                    onTap: _pickDate,
                  ),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Notas (opcional)',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar'),
                  ),
                ],
              ),
            ),
    );
  }
}
