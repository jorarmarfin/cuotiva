import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/audit_service.dart';
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
    this._rootDir,
  );

  final AppDatabase _db;
  final AuditService _audit;
  final Uuid _uuid;
  final DateTime Function() _clock;

  /// Directorio privado donde viven los adjuntos (inyectable para tests).
  final Future<Directory> Function() _rootDir;

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
    await source.copy(dest.path);

    try {
      final checksum = (await sha256.bind(dest.openRead()).first).toString();
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

  /// Verifica que el archivo exista y coincida con el checksum guardado.
  Future<bool> verify(Attachment a) async {
    final f = await fileOf(a);
    if (!await f.exists()) return false;
    return (await sha256.bind(f.openRead()).first).toString() == a.checksum;
  }
}
