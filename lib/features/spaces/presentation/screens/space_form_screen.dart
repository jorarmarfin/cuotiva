import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../domain/space_presets.dart';
import '../providers/spaces_providers.dart';

/// Crear (spaceId == null) o editar un espacio.
class SpaceFormScreen extends ConsumerStatefulWidget {
  const SpaceFormScreen({super.key, this.spaceId});
  final String? spaceId;

  @override
  ConsumerState<SpaceFormScreen> createState() => _SpaceFormScreenState();
}

class _SpaceFormScreenState extends ConsumerState<SpaceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'other';
  String _icon = 'folder';
  int _color = spaceColors.first;
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.spaceId;
    if (id != null) {
      final s = await ref.read(spacesRepositoryProvider).find(id);
      if (s != null && mounted) {
        setState(() {
          _name.text = s.name;
          _desc.text = s.description ?? '';
          _type = s.type;
          _icon = s.icon;
          _color = s.color;
        });
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _pickType(SpaceType t) => setState(() {
    _type = t.key;
    _icon = t.icon;
    _color = t.color;
    if (_name.text.trim().isEmpty && t.key != 'other') _name.text = t.label;
  });

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(spacesRepositoryProvider);
    try {
      final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
      if (widget.spaceId == null) {
        await repo.create(
          name: _name.text,
          color: _color,
          type: _type,
          icon: _icon,
          description: desc,
        );
      } else {
        await repo.update(
          widget.spaceId!,
          name: _name.text,
          color: _color,
          type: _type,
          icon: _icon,
          description: desc,
        );
        ref.invalidate(spaceByIdProvider(widget.spaceId!));
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
    final editing = widget.spaceId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar espacio' : 'Nuevo espacio')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in spaceTypes)
                        ChoiceChip(
                          avatar: Icon(spaceIconData(t.icon), size: 18),
                          label: Text(t.label),
                          selected: _type == t.key,
                          onSelected: (_) => _pickType(t),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _desc,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  const Text('Color'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final c in spaceColors)
                        GestureDetector(
                          onTap: () => setState(() => _color = c),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: Color(c),
                            child: _color == c
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Ícono'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in spaceIcons.entries)
                        ChoiceChip(
                          label: Icon(e.value, size: 20),
                          selected: _icon == e.key,
                          onSelected: (_) => setState(() => _icon = e.key),
                        ),
                    ],
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
