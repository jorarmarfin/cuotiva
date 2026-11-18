import 'dart:convert';
import 'dart:io';

import 'package:cuotiva/core/database/app_database.dart';
import 'package:cuotiva/core/database/audit_service.dart';
import 'package:cuotiva/core/money/money.dart';
import 'package:cuotiva/core/pdf/pdf_builders.dart';
import 'package:cuotiva/core/pdf/pdf_logo.dart';
import 'package:cuotiva/core/pdf/pdf_text.dart';
import 'package:cuotiva/features/collections/data/collections_repository.dart';
import 'package:cuotiva/features/contacts/data/contacts_repository.dart';
import 'package:cuotiva/features/payments/data/payments_repository.dart';
import 'package:cuotiva/features/receivables/data/receivables_repository.dart';
import 'package:cuotiva/features/payments/data/attachments_repository.dart';
import 'package:image/image.dart' as img;
import 'package:cuotiva/features/reports/data/reports_repository.dart';
import 'package:cuotiva/features/reports/domain/report_models.dart';
import 'package:cuotiva/features/settlements/data/settlements_repository.dart';
import 'package:cuotiva/features/spaces/data/spaces_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PaymentsRepository payments;
  late ReceivablesRepository receivables;
  late ReportsRepository reports;
  late SettlementsRepository settlements;
  late CollectionsRepository collections;
  late ContactsRepository contacts;
  late Space space;

  DateTime clock() => DateTime(2026, 11, 17, 10);

  /// Texto visible del PDF sin comprimir: cada palabra es un `[(..)]TJ`.
  String text(List<int> pdf) =>
      RegExp(r'\[\((.*?)\)\]TJ')
          .allMatches(latin1.decode(pdf))
          .map((m) => m.group(1))
          .join(' ');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    payments = PaymentsRepository(db, audit, uuid, clock);
    settlements = SettlementsRepository(db, audit, uuid, clock);
    receivables = ReceivablesRepository(
      db,
      audit,
      uuid,
      clock,
      collected: payments.confirmedTotal,
    );
    reports = ReportsRepository(db, clock);
    collections = CollectionsRepository(db, audit, uuid, clock);
    contacts = ContactsRepository(db, audit, uuid, clock);
    space = await SpacesRepository(
      db,
      audit,
      uuid,
      clock,
    ).create(name: 'Negocio', color: 1);
  });
  tearDown(() => db.close());

  test('§12.6 PDF: tres movimientos confirmados y saldo cero', () async {
    final rosa = await contacts.create(
      displayName: 'Rosa Pérez',
      phone: '999111222',
    );
    final col = await collections.create(spaceId: space.id, title: 'Buzos');
    final r = await receivables.create(
      collectionId: col.id,
      contactId: rosa.id,
      principal: Money.parse('120'),
    );
    await payments.register(receivableId: r.id, amount: Money.parse('30'));
    final p40 = await payments.register(
      receivableId: r.id,
      amount: Money.parse('40'),
      confirmNow: false,
      method: 'yape',
    );
    // Mientras está por verificar, va en la sección de pendientes.
    var data = await reports.statementFor(r.id);
    expect(data.confirmed, hasLength(1));
    expect(data.pending, hasLength(1));
    expect(data.balanceMinor, 9000);

    await payments.confirm(p40.id);
    await payments.register(receivableId: r.id, amount: Money.parse('50'));

    data = await reports.statementFor(r.id);
    expect(data.confirmed.map((m) => m.amountMinor), [3000, 4000, 5000]);
    expect(data.pending, isEmpty);
    expect(data.balanceMinor, 0);
    expect(data.confirmedMinor, 12000);

    final bytes = await buildStatementPdf(data, compress: false);
    final s = text(bytes);
    expect(latin1.decode(bytes).startsWith('%PDF'), isTrue);
    expect(s, contains('Estado de cuenta'));
    expect(s, contains('Rosa P'));
    expect(s, contains('S/ 30.00'));
    expect(s, contains('S/ 40.00'));
    expect(s, contains('S/ 50.00'));
    expect(s, contains('S/ 0.00'));
    expect(s, contains('informativo, no un comprobante tributario'));
    expect(
      s,
      isNot(contains('999111222')),
      reason: 'teléfono omitido por defecto',
    );
    expect(s, isNot(contains('Pendientes de verificaci')));
  });

  test('opciones: teléfono, notas y pendientes solo si se piden', () async {
    final c = await contacts.create(displayName: 'Ana', phone: '988777666');
    final col = await collections.create(spaceId: space.id, title: 'Cuota');
    final r = await receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('100'),
      notes: 'nota-interna-xyz',
    );
    await payments.register(
      receivableId: r.id,
      amount: Money.parse('20'),
      confirmNow: false,
    );
    final data = await reports.statementFor(r.id);

    final plain = text(await buildStatementPdf(data, compress: false));
    expect(plain, isNot(contains('988777666')));
    expect(plain, isNot(contains('nota-interna-xyz')));
    expect(plain, contains('Pendientes de verificaci'));

    final full = text(
      await buildStatementPdf(
        data,
        compress: false,
        options: const StatementOptions(includePhone: true, includeNotes: true),
      ),
    );
    expect(full, contains('988777666'));
    expect(full, contains('nota-interna-xyz'));

    final noPending = text(
      await buildStatementPdf(
        data,
        compress: false,
        options: const StatementOptions(includePending: false),
      ),
    );
    expect(noPending, isNot(contains('Pendientes de verificaci')));
  });

  test('estado de cuenta largo pagina sin errores', () async {
    final c = await contacts.create(displayName: 'Luis');
    final col = await collections.create(spaceId: space.id, title: 'Larga');
    final r = await receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('5000'),
    );
    for (var i = 0; i < 80; i++) {
      await payments.register(receivableId: r.id, amount: Money.parse('10'));
    }
    final data = await reports.statementFor(r.id);
    final raw = latin1.decode(await buildStatementPdf(data, compress: false));
    expect(RegExp(r'/Type/Page(?!s)').allMatches(raw).length, greaterThan(1));
  });

  test(
    '§12.9 reporte de campaña de terceros: entregado y por entregar',
    () async {
      final col = await collections.create(
        spaceId: space.id,
        title: 'Pasajes',
        fundsOwnership: 'third_party',
      );
      for (final n in ['Ana', 'Beto']) {
        final c = await contacts.create(displayName: n);
        final r = await receivables.create(
          collectionId: col.id,
          contactId: c.id,
          principal: Money.parse('400'),
        );
        await payments.register(receivableId: r.id, amount: Money.parse('300'));
      }
      await settlements.register(
        collectionId: col.id,
        amount: Money.parse('500'),
        recipientName: 'Organizador',
      );
      final data = await reports.campaignReport(col.id);
      expect(data.committedMinor, 80000);
      expect(data.collectedMinor, 60000);
      expect(data.pendingMinor, 20000);
      expect(data.deliveredMinor, 50000);
      expect(data.toDeliverMinor, 10000);
      expect(data.participants.map((p) => p.name), ['Ana', 'Beto']);

      final s = text(await buildCampaignPdf(data, compress: false));
      expect(s, contains('Fondos de terceros'));
      expect(s, contains('Por entregar'));
      expect(s, contains('S/ 100.00'));
      expect(s, contains('Organizador'));
    },
  );

  test('pdfSafe reemplaza emojis y símbolos fuera de Latin-1', () {
    expect(pdfSafe('Niño – Ñandú 😀'), 'Niño - Ñandú ?');
    expect(pdfSafe('S/ 1,200.00'), 'S/ 1,200.00');
  });
  test('comprobantes: se reducen y solo van al PDF si se piden', () async {
    final tmp = await Directory.systemTemp.createTemp('cuotiva_att');
    addTearDown(() => tmp.delete(recursive: true));
    const uuid = Uuid();
    final audit = AuditService(db, uuid, clock);
    final atts = AttachmentsRepository(db, audit, uuid, clock, () async => tmp);
    final repo = ReportsRepository(db, clock, atts);

    final big = img.Image(width: 2000, height: 1000);
    final src = File('${tmp.path}/foto.png')
      ..writeAsBytesSync(img.encodePng(big));
    final c = await contacts.create(displayName: 'Eva');
    final col = await collections.create(spaceId: space.id, title: 'Y');
    final r = await receivables.create(
      collectionId: col.id,
      contactId: c.id,
      principal: Money.parse('100'),
    );
    final pay = await payments.register(
      receivableId: r.id,
      amount: Money.parse('10'),
    );
    await atts.add(paymentId: pay.id, source: src);

    expect((await repo.statementFor(r.id)).images, isEmpty);
    final data = await repo.statementFor(r.id, includeAttachments: true);
    expect(data.images, hasLength(1));
    final out = img.decodeJpg(data.images.single)!;
    expect(out.width, 800);
    expect(out.height, 400);

    final withImg = await buildStatementPdf(
      data,
      compress: false,
      options: const StatementOptions(includeAttachments: true),
    );
    final without = await buildStatementPdf(data, compress: false);
    expect(text(withImg), contains('Comprobantes'));
    expect(text(without), isNot(contains('Comprobantes')));
  });

  test('el logo se incluye en el PDF y se reduce de tamaño', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final logo = await loadPdfLogo();
    expect(logo, isNotNull);
    final small = img.decodePng(logo!)!;
    expect(small.width, 160);
    expect(logo.length, lessThan(100 * 1024));

    final data = StatementData(
      spaceName: 'Negocio',
      collectionTitle: 'Buzos',
      personName: 'Rosa',
      currency: 'PEN',
      principalMinor: 12000,
      confirmedMinor: 0,
      balanceMinor: 12000,
      statusLabel: 'Pendiente',
      confirmed: const [],
      pending: const [],
      installments: const [],
      issuedAt: DateTime(2026, 11, 17),
    );
    final con = await buildStatementPdf(data, compress: false, logo: logo);
    final sin = await buildStatementPdf(data, compress: false);
    expect(latin1.decode(con), contains('/Subtype/Image'));
    expect(latin1.decode(sin), isNot(contains('/Subtype/Image')));
  });
}
