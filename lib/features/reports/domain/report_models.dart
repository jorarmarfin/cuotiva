/// Opciones de privacidad/contenido del estado de cuenta (CUOTIVA_SPEC §9).
class StatementOptions {
  const StatementOptions({
    this.includePhone = false,
    this.includeInstallments = true,
    this.includeNotes = false,
    this.includePending = true,
  });

  final bool includePhone;
  final bool includeInstallments;

  /// Notas internas de la obligación; por defecto fuera del PDF.
  final bool includeNotes;
  final bool includePending;

  StatementOptions copyWith({
    bool? includePhone,
    bool? includeInstallments,
    bool? includeNotes,
    bool? includePending,
  }) => StatementOptions(
    includePhone: includePhone ?? this.includePhone,
    includeInstallments: includeInstallments ?? this.includeInstallments,
    includeNotes: includeNotes ?? this.includeNotes,
    includePending: includePending ?? this.includePending,
  );
}

class StatementMovement {
  const StatementMovement({
    required this.date,
    required this.method,
    required this.amountMinor,
    this.reference,
  });
  final DateTime date;
  final String method;
  final int amountMinor;
  final String? reference;
}

class StatementInstallment {
  const StatementInstallment({
    required this.sequence,
    required this.dueAt,
    required this.amountMinor,
    required this.paidMinor,
  });
  final int sequence;
  final DateTime dueAt;
  final int amountMinor;
  final int paidMinor;
}

/// Datos ya calculados de un estado de cuenta individual (una obligación).
class StatementData {
  const StatementData({
    required this.spaceName,
    required this.collectionTitle,
    required this.personName,
    required this.currency,
    required this.principalMinor,
    required this.confirmedMinor,
    required this.balanceMinor,
    required this.statusLabel,
    required this.confirmed,
    required this.pending,
    required this.installments,
    required this.issuedAt,
    this.phone,
    this.notes,
  });

  final String spaceName;
  final String collectionTitle;
  final String personName;
  final String currency;
  final int principalMinor;
  final int confirmedMinor;
  final int balanceMinor;
  final String statusLabel;
  final List<StatementMovement> confirmed;

  /// Pendientes de verificación: se muestran aparte y no descuentan saldo.
  final List<StatementMovement> pending;
  final List<StatementInstallment> installments;
  final DateTime issuedAt;
  final String? phone;
  final String? notes;
}

class CampaignParticipantRow {
  const CampaignParticipantRow({
    required this.name,
    required this.principalMinor,
    required this.confirmedMinor,
    required this.balanceMinor,
    required this.statusLabel,
  });
  final String name;
  final int principalMinor;
  final int confirmedMinor;
  final int balanceMinor;
  final String statusLabel;
}

class CampaignReportData {
  const CampaignReportData({
    required this.spaceName,
    required this.title,
    required this.thirdParty,
    required this.committedMinor,
    required this.collectedMinor,
    required this.pendingMinor,
    required this.overdueMinor,
    required this.participants,
    required this.issuedAt,
    this.deliveredMinor = 0,
    this.settlements = const [],
  });

  final String spaceName;
  final String title;
  final bool thirdParty;
  final int committedMinor;
  final int collectedMinor;
  final int pendingMinor;
  final int overdueMinor;
  final List<CampaignParticipantRow> participants;
  final DateTime issuedAt;
  final int deliveredMinor;
  final List<StatementMovement> settlements;

  int get toDeliverMinor => collectedMinor - deliveredMinor;
}

/// Fila del listado de Reportes (una obligación con su saldo derivado).
class ObligationRow {
  const ObligationRow({
    required this.receivableId,
    required this.collectionId,
    required this.person,
    required this.collectionTitle,
    required this.principalMinor,
    required this.balanceMinor,
    required this.status,
    this.dueAt,
  });
  final String receivableId;
  final String collectionId;
  final String person;
  final String collectionTitle;
  final int principalMinor;
  final int balanceMinor;
  final String status; // ReceivableStatus.name
  final DateTime? dueAt;
}

class ReportFilter {
  const ReportFilter({
    this.spaceId,
    this.collectionId,
    this.status,
    this.personQuery = '',
    this.dueFrom,
    this.dueTo,
  });
  final String? spaceId;
  final String? collectionId;
  final String? status;
  final String personQuery;
  final DateTime? dueFrom;
  final DateTime? dueTo;

  ReportFilter copyWith({
    Object? spaceId = _keep,
    Object? collectionId = _keep,
    Object? status = _keep,
    String? personQuery,
    Object? dueFrom = _keep,
    Object? dueTo = _keep,
  }) => ReportFilter(
    spaceId: identical(spaceId, _keep) ? this.spaceId : spaceId as String?,
    collectionId: identical(collectionId, _keep)
        ? this.collectionId
        : collectionId as String?,
    status: identical(status, _keep) ? this.status : status as String?,
    personQuery: personQuery ?? this.personQuery,
    dueFrom: identical(dueFrom, _keep) ? this.dueFrom : dueFrom as DateTime?,
    dueTo: identical(dueTo, _keep) ? this.dueTo : dueTo as DateTime?,
  );
}

const Object _keep = Object();
