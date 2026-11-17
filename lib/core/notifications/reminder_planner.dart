/// Algo que vence: una cuota o una obligación sin plan.
class DueItem {
  const DueItem({
    required this.key,
    required this.person,
    required this.concept,
    required this.dueAt,
    required this.amountMinor,
  });

  /// Identificador estable (cuota o obligación) para derivar el id de alarma.
  final String key;
  final String person;
  final String concept;
  final DateTime dueAt;
  final int amountMinor;
}

class ReminderSettings {
  const ReminderSettings({
    this.enabled = false,
    this.daysBefore = 1,
    this.hour = 9,
    this.hideContent = true,
  });

  final bool enabled;
  final int daysBefore;
  final int hour;

  /// Oculta nombres e importes en la pantalla de bloqueo.
  final bool hideContent;

  static const daysOptions = [0, 1, 2, 3, 7];

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    bool? hideContent,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    daysBefore: daysBefore ?? this.daysBefore,
    hour: hour ?? this.hour,
    hideContent: hideContent ?? this.hideContent,
  );

  String encode() =>
      '${enabled ? 1 : 0}:$daysBefore:$hour:${hideContent ? 1 : 0}';

  static ReminderSettings decode(String? s) {
    final p = s?.split(':');
    if (p == null || p.length != 4) return const ReminderSettings();
    return ReminderSettings(
      enabled: p[0] == '1',
      daysBefore: int.tryParse(p[1]) ?? 1,
      hour: (int.tryParse(p[2]) ?? 9).clamp(0, 23),
      hideContent: p[3] != '0',
    );
  }
}

enum ReminderKind { upcoming, dueToday, overdue }

class ReminderSpec {
  const ReminderSpec({
    required this.id,
    required this.when,
    required this.kind,
    required this.title,
    required this.body,
    required this.publicTitle,
    required this.publicBody,
  });

  final int id;
  final DateTime when;
  final ReminderKind kind;
  final String title;
  final String body;

  /// Texto genérico que se ve con la pantalla bloqueada.
  final String publicTitle;
  final String publicBody;
}

/// Calcula qué notificaciones programar. Pura: no toca plugins.
abstract final class ReminderPlanner {
  /// Android limita las alarmas pendientes; se programan las más próximas.
  static const maxReminders = 60;

  static DateTime _dayAt(DateTime d, int hour) =>
      DateTime(d.year, d.month, d.day, hour);

  /// Id estable de 31 bits a partir de la clave y el tipo.
  static int idFor(String key, ReminderKind kind) {
    var h = 0x811c9dc5;
    for (final c in '$key|${kind.index}'.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return h;
  }

  static List<ReminderSpec> plan(
    List<DueItem> items,
    ReminderSettings s,
    DateTime now,
    String Function(int minor) money,
  ) {
    if (!s.enabled) return const [];
    final out = <ReminderSpec>[];
    for (final i in items) {
      final due = DateTime(i.dueAt.year, i.dueAt.month, i.dueAt.day);
      final amount = money(i.amountMinor);
      void add(ReminderKind kind, DateTime when, String title, String body) {
        if (!when.isAfter(now)) return;
        out.add(
          ReminderSpec(
            id: idFor(i.key, kind),
            when: when,
            kind: kind,
            title: title,
            body: body,
            publicTitle: 'Cuotiva',
            publicBody: 'Tienes cobros pendientes',
          ),
        );
      }

      if (s.daysBefore > 0) {
        add(
          ReminderKind.upcoming,
          _dayAt(due.subtract(Duration(days: s.daysBefore)), s.hour),
          'Cuota por vencer',
          '${i.person}: $amount (${i.concept}) vence en ${s.daysBefore} día(s)',
        );
      }
      add(
        ReminderKind.dueToday,
        _dayAt(due, s.hour),
        'Vence hoy',
        '${i.person}: $amount (${i.concept})',
      );
      add(
        ReminderKind.overdue,
        _dayAt(due.add(const Duration(days: 1)), s.hour),
        'Cuota vencida',
        '${i.person} no ha pagado $amount (${i.concept})',
      );
    }
    out.sort((a, b) => a.when.compareTo(b.when));
    return out.length > maxReminders ? out.sublist(0, maxReminders) : out;
  }
}
