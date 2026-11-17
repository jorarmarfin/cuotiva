import 'package:drift/drift.dart';

/// Base: UUID como PK de texto + marcas de tiempo (CUOTIVA_SPEC §8).
mixin BaseTable on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Spaces extends Table with BaseTable {
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get type => text().withDefault(const Constant('other'))();
  IntColumn get color => integer()(); // ARGB
  TextColumn get icon => text().withDefault(const Constant('folder'))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class Contacts extends Table with BaseTable {
  TextColumn get displayName => text().withLength(min: 1, max: 120)();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class Collections extends Table with BaseTable {
  TextColumn get spaceId => text().references(Spaces, #id)();
  TextColumn get title => text().withLength(min: 1, max: 120)();
  // credit_sale | loan | fundraising | service | other
  TextColumn get kind => text().withDefault(const Constant('other'))();
  // self | third_party
  TextColumn get fundsOwnership => text().withDefault(const Constant('self'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK (funds_ownership IN ('self','third_party'))",
    "CHECK (kind IN ('credit_sale','loan','fundraising','service','other'))",
  ];
}

class Receivables extends Table with BaseTable {
  TextColumn get collectionId => text().references(Collections, #id)();
  TextColumn get contactId => text().references(Contacts, #id)();
  IntColumn get principalMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  DateTimeColumn get dueAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK (principal_minor > 0)',
    'UNIQUE (collection_id, contact_id)',
  ];
}

class Installments extends Table with BaseTable {
  TextColumn get receivableId => text().references(Receivables, #id)();
  IntColumn get sequence => integer()();
  DateTimeColumn get dueAt => dateTime()();
  IntColumn get amountMinor => integer()();

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor > 0)',
    'CHECK (sequence > 0)',
    'UNIQUE (receivable_id, sequence)',
  ];
}

class AuditLogs extends Table with BaseTable {
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get oldValuesJson => text().nullable()();
  TextColumn get newValuesJson => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Abonos. Solo `confirmed` descuenta saldo (CUOTIVA_SPEC §4.2).
class Payments extends Table with BaseTable {
  TextColumn get receivableId => text().references(Receivables, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  DateTimeColumn get occurredAt => dateTime()();
  // cash | yape | plin | transfer | card | other
  TextColumn get method => text().withDefault(const Constant('cash'))();
  // pending_verification | confirmed | rejected | voided
  TextColumn get status =>
      text().withDefault(const Constant('pending_verification'))();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get verifiedAt => dateTime().nullable()();
  DateTimeColumn get voidedAt => dateTime().nullable()();
  TextColumn get voidReason => text().nullable()();

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor > 0)',
    "CHECK (status IN ('pending_verification','confirmed','rejected','voided'))",
    "CHECK (method IN ('cash','yape','plin','transfer','card','other'))",
  ];
}

/// Parte de un pago aplicada a una cuota. Sin plan de cuotas el pago
/// afecta directamente el saldo de la obligación.
class PaymentAllocations extends Table with BaseTable {
  TextColumn get paymentId => text().references(Payments, #id)();
  TextColumn get installmentId => text().references(Installments, #id)();
  IntColumn get amountMinor => integer()();

  @override
  List<String> get customConstraints => [
    'CHECK (amount_minor > 0)',
    'UNIQUE (payment_id, installment_id)',
  ];
}

/// Comprobantes (copiados al almacenamiento privado de la app).
class Attachments extends Table with BaseTable {
  TextColumn get paymentId => text().references(Payments, #id)();
  TextColumn get relativePath => text()();
  TextColumn get mimeType => text()();
  IntColumn get byteSize => integer()();
  TextColumn get checksum => text()();
  BoolColumn get encrypted => boolean().withDefault(const Constant(false))();
}
