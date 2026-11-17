import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
import '../../../core/security/crypto_service.dart';
import '../domain/payment_errors.dart';

/// Comprobantes de pago. El archivo se copia al almacenamiento privado de la
/// app (nunca se referencia la galería) y se guarda su SHA-256.
/// El cifrado en disco llega en la Fase 4 (`encrypted` queda en false).
class AttachmentsRepository {
  AttachmentsRepository(
    this._db,
    this._audit,
    this._uuid,
    this._clock,
    this._rootDir, [
    this._cipher,
  ]);

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Directorio privado donde viven los adjuntos (inyectable para tests).
  final Future<Directory> Function() _rootDir;

  /// AES-GCM para cifrar en disco; sin él (tests) se guarda en claro.
  final Future<AeadCipher> Function()? _cipher;

  static const maxBytes = 10 * 1024 * 1024;
  static const _extByMime = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  static String? mimeFromPath(String path) =>
      switch (p.extension(path).toLowerCase()) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        _ => null,
      };

  Stream<List<Attachment>> watchByPayment(String paymentId) =>
      (_db.select(_db.attachments)
            ..where((a) => a.paymentId.equals(paymentId))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  Future<File> fileOf(Attachment a) async =>
      File(p.join((await _rootDir()).path, a.relativePath));

  Future<Attachment> add({
    required String paymentId,
    required File source,
    String? mimeType,
  }) async {
    final mime = mimeType ?? mimeFromPath(source.path);
    final ext = _extByMime[mime];
    if (mime == null || ext == null) {
      throw PaymentException('Formato no admitido (usa JPG, PNG o WebP)');
    }
    if (!await source.exists()) {
      throw PaymentException('No se encontró el archivo seleccionado');
    }
    final size = await source.length();
    if (size == 0) throw PaymentException('El archivo está vacío');
    if (size > maxBytes) throw PaymentException('La imagen supera los 10 MB');

    final payment = await (_db.select(
      _db.payments,
    )..where((x) => x.id.equals(paymentId))).getSingleOrNull();
    if (payment == null) throw PaymentException('Pago no encontrado');
    if (payment.status == 'voided' || payment.status == 'rejected') {
      throw PaymentException(
        'No se agregan comprobantes a un pago anulado o rechazado',
      );
    }

    final id = _uuid.v4();
    final root = await _rootDir();
    final relative = p.join('attachments', '$id.$ext');
    final dest = File(p.join(root.path, relative));
    await dest.parent.create(recursive: true);
    final plain = await source.readAsBytes();
    // El checksum es del contenido original: sirve para verificar tras descifrar.
    final checksum = sha256.convert(plain).toString();
    final cipher = await _cipher?.call();
    await dest.writeAsBytes(
      cipher == null ? plain : await cipher.encrypt(plain, aad: id.codeUnits),
      flush: true,
    );

    try {
      final now = _clock();
      return await _db.transaction(() async {
        await _db
            .into(_db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: id,
                createdAt: now,
                updatedAt: now,
                paymentId: paymentId,
                relativePath: relative,
                mimeType: mime,
                byteSize: size,
                checksum: checksum,
                encrypted: Value(cipher != null),
              ),
            );
        await _audit.log(
          entityType: 'attachment',
          entityId: id,
          action: 'add',
          newValues: {
            'paymentId': paymentId,
            'byteSize': size,
            'checksum': checksum,
          },
        );
        return (await (_db.select(
          _db.attachments,
        )..where((a) => a.id.equals(id))).getSingle());
      });
    } catch (_) {
      if (await dest.exists()) await dest.delete(); // no dejar huérfanos
      rethrow;
    }
  }

  /// Solo mientras el pago sigue por verificar; la evidencia de un pago
  /// confirmado se conserva.
  Future<void> remove(String attachmentId) async {
    final a = await (_db.select(
      _db.attachments,
    )..where((x) => x.id.equals(attachmentId))).getSingleOrNull();
    if (a == null) throw PaymentException('Comprobante no encontrado');
    final payment = await (_db.select(
      _db.payments,
    )..where((x) => x.id.equals(a.paymentId))).getSingle();
    if (payment.status != 'pending_verification') {
      throw PaymentException(
        'Solo se quitan comprobantes de pagos por verificar',
      );
    }
    await _db.transaction(() async {
      await (_db.delete(
        _db.attachments,
      )..where((x) => x.id.equals(attachmentId))).go();
      await _audit.log(
        entityType: 'attachment',
        entityId: attachmentId,
        action: 'remove',
        oldValues: {'paymentId': a.paymentId, 'checksum': a.checksum},
      );
    });
    final f = await fileOf(a);
    if (await f.exists()) await f.delete();
  }

  /// Contenido original del comprobante (descifrado si hace falta).
  Future<Uint8List> readBytes(Attachment a) async {
    final raw = await (await fileOf(a)).readAsBytes();
    if (!a.encrypted) return raw;
    final cipher = await _cipher?.call();
    if (cipher == null) {
      throw PaymentException('No hay clave para descifrar el comprobante');
    }
    return cipher.decrypt(raw, aad: a.id.codeUnits);
  }

  /// Cifra los comprobantes que quedaron en claro (versiones previas al
  /// cifrado). Devuelve cuántos cifró. Escribe a un temporal y renombra.
  Future<int> encryptPending() async {
    final cipher = await _cipher?.call();
    if (cipher == null) return 0;
    final pending = await (_db.select(
      _db.attachments,
    )..where((a) => a.encrypted.equals(false))).get();
    var n = 0;
    for (final a in pending) {
      final f = await fileOf(a);
      if (!await f.exists()) continue;
      final plain = await f.readAsBytes();
      if (sha256.convert(plain).toString() != a.checksum) continue; // dañado
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(
        await cipher.encrypt(plain, aad: a.id.codeUnits),
        flush: true,
      );
      await tmp.rename(f.path);
      await (_db.update(
        _db.attachments,
      )..where((x) => x.id.equals(a.id))).write(
        AttachmentsCompanion(
          encrypted: const Value(true),
          updatedAt: Value(_clock()),
        ),
      );
      n++;
    }
    return n;
  }

  /// Verifica que el archivo exista y que, ya descifrado, coincida con el
  /// checksum guardado (detecta pérdida o alteración).
  Future<bool> verify(Attachment a) async {
    try {
      if (!await (await fileOf(a)).exists()) return false;
      return sha256.convert(await readBytes(a)).toString() == a.checksum;
    } on CryptoException {
      return false;
    }
  }
}
