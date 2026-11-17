import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/repository_providers.dart';
import '../providers/contacts_providers.dart';

/// Crear (contactId == null) o editar una persona.
class ContactFormScreen extends ConsumerStatefulWidget {
  const ContactFormScreen({super.key, this.contactId});
  final String? contactId;

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
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
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.contactId;
    if (id != null) {
      final c = await ref.read(contactsRepositoryProvider).find(id);
      if (c != null) {
        _name.text = c.displayName;
        _phone.text = c.phone ?? '';
        _email.text = c.email ?? '';
        _notes.text = c.notes ?? '';
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(contactsRepositoryProvider);
    try {
      if (widget.contactId == null) {
        await repo.create(
          displayName: _name.text,
          phone: _phone.text,
          email: _email.text,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await repo.update(
          widget.contactId!,
          displayName: _name.text,
          phone: _phone.text,
          email: _email.text,
          notes: _notes.text,
        );
        ref.invalidate(contactByIdProvider(widget.contactId!));
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
    final editing = widget.contactId != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar persona' : 'Nueva persona')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingresa un nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Correo (opcional)',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                          ? null
                          : 'Correo inválido';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Observaciones (opcional)',
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
