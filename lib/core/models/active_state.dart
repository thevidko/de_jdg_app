/// Model aktivního stavu disciplíny.
///
/// Odpověď z: GET /api/v1/disciplines/{disciplineUuid}/active-state
///
/// Struktura (plain JSON, ne JSON:API):
/// {
///   "data": {
///     "current_round": { ... },
///     "current_dance": { "dance": { ... }, ... },
///     "all_round_pairs": [          ← pole HEATŮ (ne párů přímo!)
///       {
///         "uuid": "heat-uuid",
///         "name": "Heat 1",
///         "heat_pairs": [
///           { "discipline_pair_uuid": "...", "discipline_pair": { "bib_number": 101, ... } }
///         ]
///       }
///     ]
///   }
/// }
library;

class ActiveState {
  final ActiveRound? currentRound;
  final ActiveDance? currentDance;

  /// Plochý seznam párů ke hodnocení – extrahovaný ze všech heatů.
  /// Pořadí: dle pořadí heatů, uvnitř heatu dle pořadí heat_pairs.
  final List<ActivePair> allRoundPairs;

  const ActiveState({
    required this.currentRound,
    required this.currentDance,
    required this.allRoundPairs,
  });

  bool get hasActiveState => currentRound != null || currentDance != null;

  factory ActiveState.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      return const ActiveState(
        currentRound: null,
        currentDance: null,
        allRoundPairs: [],
      );
    }

    // Parsujeme heaty a z nich extrahujeme discipline pairs
    final heatsRaw = data['all_round_pairs'] as List<dynamic>? ?? [];
    final pairs = <ActivePair>[];
    for (final heatRaw in heatsRaw) {
      final heat = heatRaw as Map<String, dynamic>;
      final heatName = heat['name']?.toString() ?? '';
      final heatPairs = heat['heat_pairs'] as List<dynamic>? ?? [];
      for (final hp in heatPairs) {
        final heatPair = hp as Map<String, dynamic>;
        final pair = ActivePair.fromHeatPair(heatPair, heatName);
        if (pair != null) pairs.add(pair);
      }
    }

    // Seřadíme dle startovního čísla (bib_number)
    pairs.sort((a, b) => a.bibNumber.compareTo(b.bibNumber));

    return ActiveState(
      currentRound: data['current_round'] != null
          ? ActiveRound.fromJson(data['current_round'] as Map<String, dynamic>)
          : null,
      currentDance: data['current_dance'] != null
          ? ActiveDance.fromJson(data['current_dance'] as Map<String, dynamic>)
          : null,
      allRoundPairs: pairs,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Informace o aktuálním kole z active-state.
class ActiveRound {
  final String uuid;
  final String name;  // e.g. "Čtvrtfinále"
  final int order;
  final bool isFinale; // false = křížky (0/1), true = umístění (1-6)
  final int evaluationSystem; // raw hodnota

  /// Počet párů, kteří mají postoupit (pro křížkový systém).
  /// Porotce musí označit přesně tolik párů – ne víc, ne míň.
  final int advancementTarget;

  const ActiveRound({
    required this.uuid,
    required this.name,
    required this.order,
    required this.isFinale,
    required this.evaluationSystem,
    required this.advancementTarget,
  });

  factory ActiveRound.fromJson(Map<String, dynamic> json) {
    final evaluationSystem = _parseInt(json['evaluation_system']) ?? 0;
    return ActiveRound(
      uuid: json['uuid']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Kolo',
      order: _parseInt(json['order']) ?? 1,
      isFinale: evaluationSystem != 0,
      evaluationSystem: evaluationSystem,
      advancementTarget: _parseInt(json['advancement_target']) ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Informace o aktuálním tanci z active-state.
class ActiveDance {
  final String uuid;

  /// Plný název tance (e.g. "Slowfox", "Waltz")
  final String name;

  /// Zkratka tance (e.g. "F", "W") – z pole dance.short_name
  final String shortName;

  const ActiveDance({
    required this.uuid,
    required this.name,
    required this.shortName,
  });

  factory ActiveDance.fromJson(Map<String, dynamic> json) {
    final uuid = json['uuid']?.toString() ?? '';
    // dance info je nested pod klíčem "dance"
    final dance = json['dance'] as Map<String, dynamic>? ?? {};
    final name = dance['name']?.toString() ?? 'Neznámý tanec';
    final shortName = dance['short_name']?.toString() ?? name.substring(0, 1);

    return ActiveDance(uuid: uuid, name: name, shortName: shortName);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Jeden pár ke hodnocení – extrahovaný z heat_pair struktury.
class ActivePair {
  /// UUID discipline_pair záznamu – odesílá se jako discipline_pair_uuid při POST /scores/bulk
  final String uuid;

  /// Startovní číslo (bib_number)
  final int bibNumber;

  /// Název heatu, ve kterém pár startuje (e.g. "Heat 1") – pro příp. zobrazení
  final String heatName;

  const ActivePair({
    required this.uuid,
    required this.bibNumber,
    required this.heatName,
  });

  String get bibNumberStr => bibNumber.toString();

  /// Parsuje heat_pair objekt z all_round_pairs[].heat_pairs[].
  ///
  /// Vrátí null pokud chybí discipline_pair nebo bib_number.
  static ActivePair? fromHeatPair(Map<String, dynamic> heatPair, String heatName) {
    final disciplinePair = heatPair['discipline_pair'] as Map<String, dynamic>?;
    if (disciplinePair == null) return null;

    final uuid = disciplinePair['uuid']?.toString() ?? '';
    final bibNumber = _parseInt(disciplinePair['bib_number']);
    if (uuid.isEmpty || bibNumber == null) return null;

    return ActivePair(uuid: uuid, bibNumber: bibNumber, heatName: heatName);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
