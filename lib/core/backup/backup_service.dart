import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../features/payments/data/attachments_repository.dart';
import '../database/app_database.dart';
import '../database/encrypted_database.dart';
import '../security/crypto_service.dart';
import 'backup_envelope.dart';

/// Rutas que usa el respaldo (inyectables para tests).
class BackupPaths {
  BackupPaths({
    required this.dbFile,
    required this.attachmentsRoot,
    required this.workDir,
  });

  /// Rutas reales de la app (Android: documentos y soporte privados).
  static Future<BackupPaths> resolve() async {
    final docs = await getApplicationDocumentsDirectory();
    return BackupPaths(
      dbFile: File(p.join(docs.path, 'cuotiva.sqlite')),
      attachmentsRoot: await getApplicationSupportDirectory(),
      workDir: docs,
    );
  }

  /// Base SQLCipher activa.
  final File dbFile;

  /// Carpeta que contiene `attachments/`.
  final Directory attachmentsRoot;

  /// Carpeta temporal y de preparación de restauraciones. Debe estar en el
  /// mismo sistema de archivos que la base para poder renombrar.
  final Directory workDir;

  Directory get staging => Directory(p.join(workDir.path, 'restore_staging'));
  Directory get previous => Directory(p.join(workDir.path, 'restore_previous'));
  Directory get attachments =>
      Directory(p.join(attachmentsRoot.path, 'attachments'));
}

class BackupSummary {
  const BackupSummary(this.counts, this.createdAt, this.schemaVersion);
  final Map<String, int> counts;
  final DateTime createdAt;
  final int schemaVersion;
}

/// Respaldo y restauración completos (base + comprobantes).
///
/// - El respaldo es un ZIP (manifiesto + base SQLite en claro + comprobantes
///   en claro) dentro de un sobre AES-GCM con clave de la frase de recuperación.
/// - Restaurar NO toca los datos vivos: valida, prepara una copia re-cifrada
///   con las claves de este dispositivo y deja un marcador. El cambio real lo
///   hace [applyPendingRestore] al iniciar, con copia de lo anterior y
///   reversión si algo falla.
class BackupService {
  BackupService({
    required this.paths,
    required this.attachments,
    required this.dbHexKey,
    required this.attachmentCipher,
    required this.schemaVersion,
    required this.clock,
    this.useIsolate = true,
    this.iterations = BackupEnvelope.defaultIterations,
  });

  final BackupPaths paths;
  final AttachmentsRepository attachments;
  final Future<String> Function() dbHexKey;
  final Future<AeadCipher> Function() attachmentCipher;
  final int schemaVersion;
  final DateTime Function() clock;
  final bool useIsolate;
  final int iterations;

  static const tables = [
    'spaces',
    'contacts',
    'collections',
    'receivables',
    'installments',
    'payments',
    'payment_allocations',
    'attachments',
    'settlements',
    'audit_logs',
  ];

  static const _manifest = 'manifest.json';
  static const _dbName = 'db.sqlite';

  static Map<String, int> _counts(Database db) => {
    for (final t in tables)
      t: db.select('SELECT count(*) c FROM $t').first['c'] as int,
  };

  /// Genera el respaldo cifrado.
  Future<Uint8List> create(String passphrase, AppDatabase db) async {
    BackupEnvelope.checkPassphrase(passphrase);
    final work = await Directory(p.join(paths.workDir.path, 'backup_tmp'))
        .create(recursive: true);
    try {
      final plain = File(p.join(work.path, _dbName));
      exportEncryptedToPlain(paths.dbFile, plain, await dbHexKey());

      final files = <String, Uint8List>{};
      for (final a in await db.select(db.attachments).get()) {
        try {
          files['attachments/${p.basename(a.relativePath)}'] = await attachments
              .readBytes(a);
        } on Object catch (e) {
          throw BackupException(
            'No se pudo leer un comprobante (${p.basename(a.relativePath)}): $e',
          );
        }
      }
      final dbBytes = await plain.readAsBytes();

      final probe = sqlite3.open(plain.path);
      final Map<String, int> counts;
      try {
        counts = _counts(probe);
      } finally {
        probe.close();
      }

      final manifest = {
        'app': 'cuotiva',
        'format': BackupEnvelope.version,
        'createdAt': clock().toIso8601String(),
        'schemaVersion': schemaVersion,
        'counts': counts,
        'files': {
          _dbName: sha256.convert(dbBytes).toString(),
          for (final e in files.entries)
            e.key: sha256.convert(e.value).toString(),
        },
      };
      final zip = Archive()
        ..addFile(_file(_manifest, utf8.encode(jsonEncode(manifest))))
        ..addFile(_file(_dbName, dbBytes));
      for (final e in files.entries) {
        zip.addFile(_file(e.key, e.value));
      }
      final bytes = ZipEncoder().encode(zip);
      return await BackupEnvelope.seal(
        Uint8List.fromList(bytes),
        passphrase,
        iterations: iterations,
        useIsolate: useIsolate,
      );
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  static ArchiveFile _file(String name, List<int> data) =>
      ArchiveFile(name, data.length, data);

  /// Valida un respaldo y lo deja preparado. No altera los datos actuales.
  Future<BackupSummary> stageRestore(Uint8List data, String passphrase) async {
    final zipBytes = await BackupEnvelope.open(
      data,
      passphrase,
      useIsolate: useIsolate,
    );
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(zipBytes);
    } on Object {
      throw BackupException('Respaldo dañado (contenido ilegible)');
    }
    Uint8List? read(String name) {
      final f = zip.findFile(name);
      return f == null ? null : Uint8List.fromList(f.content as List<int>);
    }

    final mBytes = read(_manifest);
    if (mBytes == null) throw BackupException('Respaldo sin manifiesto');
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(utf8.decode(mBytes)) as Map<String, dynamic>;
    } on Object {
      throw BackupException('Manifiesto ilegible');
    }
    if (m['app'] != 'cuotiva') {
      throw BackupException('El respaldo no pertenece a Cuotiva');
    }
    final schema = m['schemaVersion'] as int? ?? 0;
    if (schema > schemaVersion) {
      throw BackupException(
        'El respaldo es de una versión más nueva de la app (esquema $schema). '
        'Actualiza Cuotiva para restaurarlo.',
      );
    }
    if (schema < 1) throw BackupException('Esquema de respaldo inválido');

    // Integridad: hash de cada archivo declarado.
    final declared = (m['files'] as Map).cast<String, String>();
    for (final e in declared.entries) {
      final b = read(e.key);
      if (b == null) throw BackupException('Falta ${e.key} en el respaldo');
      if (sha256.convert(b).toString() != e.value) {
        throw BackupException('Integridad fallida en ${e.key}');
      }
    }
    final dbBytes = read(_dbName);
    if (dbBytes == null) throw BackupException('Respaldo sin base de datos');

    final stage = paths.staging;
    if (await stage.exists()) await stage.delete(recursive: true);
    await stage.create(recursive: true);
    try {
      final plain = File(p.join(stage.path, 'plain.db'));
      await plain.writeAsBytes(dbBytes, flush: true);

      final probe = sqlite3.open(plain.path);
      final Map<String, int> counts;
      try {
        final ok = probe.select('PRAGMA integrity_check').first.values.first;
        if (ok != 'ok') {
          throw BackupException('La base del respaldo está dañada');
        }
        final v = probe.select('PRAGMA user_version').first.values.first as int;
        if (v != schema) {
          throw BackupException('Versión de base inconsistente en el respaldo');
        }
        counts = _counts(probe);
      } finally {
        probe.close();
      }
      final expected = (m['counts'] as Map).cast<String, int>();
      for (final t in tables) {
        if (expected[t] != null && expected[t] != counts[t]) {
          throw BackupException(
            'Conteo distinto en $t (${counts[t]} ≠ ${expected[t]})',
          );
        }
      }

      final encDb = File(p.join(stage.path, 'cuotiva.sqlite'));
      exportPlainToEncrypted(plain, encDb, await dbHexKey());
      await plain.delete();

      // Comprobantes: re-cifrados con la clave de este dispositivo.
      final cipher = await attachmentCipher();
      final attDir = await Directory(p.join(stage.path, 'attachments'))
          .create();
      final check = sqlite3.open(encDb.path)..applyKey(await dbHexKey());
      try {
        final rows = check.select(
          'SELECT id, relative_path, checksum FROM attachments',
        );
        for (final r in rows) {
          final name = p.basename(r['relative_path'] as String);
          final bytes = read('attachments/$name');
          if (bytes == null) {
            throw BackupException('Falta el comprobante $name');
          }
          if (sha256.convert(bytes).toString() != r['checksum']) {
            throw BackupException('Hash de comprobante distinto: $name');
          }
          await File(p.join(attDir.path, name)).writeAsBytes(
            await cipher.encrypt(bytes, aad: (r['id'] as String).codeUnits),
            flush: true,
          );
        }
        check.execute('UPDATE attachments SET encrypted = 1');
      } finally {
        check.close();
      }

      final createdAt =
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? clock();
      await File(p.join(stage.path, 'READY')).writeAsString(
        jsonEncode({
          'createdAt': createdAt.toIso8601String(),
          'schema': schema,
        }),
        flush: true,
      );
      return BackupSummary(counts, createdAt, schema);
    } catch (_) {
      if (await stage.exists()) await stage.delete(recursive: true);
      rethrow;
    }
  }

  Future<bool> get hasPendingRestore => _applier.hasPending;
  Future<void> discardPendingRestore() => _applier.discard();
  Future<bool> applyPendingRestore() => _applier.apply();

  late final _applier = RestoreApplier(paths);
}

/// Aplica una restauración preparada. No depende de la base abierta ni de
/// claves: se usa al iniciar la app, antes de abrir la base.
class RestoreApplier {
  RestoreApplier(this.paths);
  final BackupPaths paths;

  Future<bool> get hasPending async =>
      File(p.join(paths.staging.path, 'READY')).exists();

  Future<void> discard() async {
    if (await paths.staging.exists()) {
      await paths.staging.delete(recursive: true);
    }
  }

  /// Aplica una restauración preparada. Llamar al iniciar, ANTES de abrir la
  /// base. Conserva el estado anterior en `restore_previous` y lo recupera si
  /// el cambio falla a medias.
  Future<bool> apply() async {
    if (!await hasPending) {
      // Staging incompleto (cierre a mitad de preparación): se descarta.
      await discard();
      return false;
    }
    final stage = paths.staging;
    final prev = paths.previous;
    if (await prev.exists()) await prev.delete(recursive: true);
    await prev.create(recursive: true);

    final prevDb = File(p.join(prev.path, 'cuotiva.sqlite'));
    final prevAtt = Directory(p.join(prev.path, 'attachments'));
    var movedDb = false;
    var movedAtt = false;
    try {
      if (await paths.dbFile.exists()) {
        await _move(paths.dbFile, prevDb);
        movedDb = true;
      }
      if (await paths.attachments.exists()) {
        await _moveDir(paths.attachments, prevAtt);
        movedAtt = true;
      }
      await paths.dbFile.parent.create(recursive: true);
      await _move(File(p.join(stage.path, 'cuotiva.sqlite')), paths.dbFile);
      await _moveDir(
        Directory(p.join(stage.path, 'attachments')),
        paths.attachments,
      );
      await stage.delete(recursive: true);
      return true;
    } catch (_) {
      // Reversión: se devuelve lo anterior.
      if (await paths.dbFile.exists()) await paths.dbFile.delete();
      if (await paths.attachments.exists()) {
        await paths.attachments.delete(recursive: true);
      }
      if (movedDb) await _move(prevDb, paths.dbFile);
      if (movedAtt) await _moveDir(prevAtt, paths.attachments);
      rethrow;
    }
  }

  Future<void> _move(File from, File to) async {
    await to.parent.create(recursive: true);
    try {
      await from.rename(to.path);
    } on FileSystemException {
      await from.copy(to.path);
      await from.delete();
    }
  }

  Future<void> _moveDir(Directory from, Directory to) async {
    await to.parent.create(recursive: true);
    try {
      await from.rename(to.path);
    } on FileSystemException {
      await to.create(recursive: true);
      await for (final e in from.list(recursive: true)) {
        final rel = p.relative(e.path, from: from.path);
        if (e is File) {
          await Directory(p.dirname(p.join(to.path, rel)))
              .create(recursive: true);
          await e.copy(p.join(to.path, rel));
        }
      }
      await from.delete(recursive: true);
    }
  }
}
