import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/restart_host.dart';
import '../../../../core/backup/backup_envelope.dart';
import '../../../../core/backup/backup_service.dart';
import '../../../../core/pdf/pdf_share_service.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';

/// Respaldo y restauración cifrados con frase de recuperación.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _phrase = TextEditingController();
  var _show = false;
  var _busy = false;
  var _saved = false;

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _create() async {
    try {
      BackupEnvelope.checkPassphrase(_phrase.text);
    } on BackupException catch (e) {
      _toast(e.message);
      return;
    }
    if (!_saved) {
      _toast('Confirma que guardaste la frase de recuperación');
      return;
    }
    setState(() => _busy = true);
    try {
      final svc = await ref.read(backupServiceProvider.future);
      final bytes = await svc.create(
        _phrase.text,
        ref.read(appDatabaseProvider),
      );
      final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
      await shareBytes(bytes, 'cuotiva-respaldo-$stamp.cuotiva');
    } on BackupException catch (e) {
      _toast(e.message);
    } on Object catch (e) {
      _toast('No se pudo crear el respaldo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPhrase() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Frase de recuperación'),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Frase del respaldo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  Future<void> _restore() async {
    final picked = await FilePicker.pickFile();
    final path = picked?.path;
    if (path == null) return;
    final phrase = await _askPhrase();
    if (phrase == null || !mounted) return;

    setState(() => _busy = true);
    final svc = await ref.read(backupServiceProvider.future);
    try {
      final summary = await svc.stageRestore(
        await File(path).readAsBytes(),
        phrase,
      );
      if (!mounted) return;
      final ok = await _confirm(summary);
      if (ok == true && mounted) {
        RestartHost.restart(context); // aplica el cambio al reiniciar
      } else {
        await svc.discardPendingRestore();
      }
    } on BackupException catch (e) {
      _toast(e.message);
    } on Object catch (e) {
      await svc.discardPendingRestore();
      _toast('No se pudo restaurar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool?> _confirm(BackupSummary s) {
    final df = DateFormat('d MMM y, HH:mm', 'es');
    String line(String label, String key) => '$label: ${s.counts[key] ?? 0}';
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Reemplazar los datos actuales?'),
        content: Text(
          'Respaldo del ${df.format(s.createdAt)}\n\n'
          '${line('Espacios', 'spaces')}\n'
          '${line('Personas', 'contacts')}\n'
          '${line('Cobros', 'collections')}\n'
          '${line('Obligaciones', 'receivables')}\n'
          '${line('Abonos', 'payments')}\n'
          '${line('Comprobantes', 'attachments')}\n\n'
          'Se reemplazarán TODOS los datos de este dispositivo. Se guarda '
          'una copia de lo actual por si algo falla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo y restauración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Crear respaldo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'El archivo incluye todos tus datos y comprobantes, cifrados con '
            'una frase de recuperación. No incluye tu PIN. Si pierdes la '
            'frase, el respaldo NO se puede abrir y no hay forma de '
            'recuperarlo.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phrase,
            obscureText: !_show,
            decoration: InputDecoration(
              labelText:
                  'Frase de recuperación (mín. ${BackupEnvelope.minPassphraseLength})',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _show ? 'Ocultar' : 'Mostrar',
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _phrase.text)),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() {
                _phrase.text = BackupEnvelope.generatePassphrase();
                _show = true;
                _saved = false;
              }),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generar una frase segura'),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _saved,
            onChanged: (v) => setState(() => _saved = v ?? false),
            title: const Text('Guardé la frase en un lugar seguro'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _create,
            icon: const Icon(Icons.save_alt),
            label: Text(_busy ? 'Trabajando…' : 'Crear y compartir respaldo'),
          ),
          const Divider(height: 40),
          Text(
            'Restaurar respaldo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Reemplaza los datos de este dispositivo por los del archivo. '
            'Antes de aplicar se valida la integridad y te mostramos qué '
            'contiene.',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restore,
            icon: const Icon(Icons.restore),
            label: const Text('Elegir archivo de respaldo'),
          ),
        ],
      ),
    );
  }
}
