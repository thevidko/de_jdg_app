/// Model detailu kola soutěže.
///
/// Parsovaný z JSON:API odpovědi:
/// GET /api/v1/rounds/{uuid}?include=discipline,discipline.disciplinePairs
library;

class RoundDetail {
  final String uuid;

  /// UUID disciplíny – potřebné pro volání /disciplines/{uuid}/active-state
  final String disciplineUuid;

  /// Název kola (e.g. "Čtvrtfinále", "Semifinále", "Finále")
  final String name;

  /// Název disciplíny (e.g. "Latin ratione")
  final String disciplineName;

  /// Pořadové číslo kola v rámci disciplíny (z pole "order")
  final int order;

  /// true = umístění (1–6), false = křížky (0/1)
  ///
  /// Určeno dle pole `evaluationSystem`:
  ///   0 = křížky (kola)
  ///   1+ = umístění (finále)
  final bool isFinale;

  /// Surová hodnota evaluationSystem z API
  final int evaluationSystem;

  /// Všechny páry přiřazené do disciplíny
  final List<DisciplinePair> pairs;

  const RoundDetail({
    required this.uuid,
    required this.disciplineUuid,
    required this.name,
    required this.disciplineName,
    required this.order,
    required this.isFinale,
    required this.evaluationSystem,
    required this.pairs,
  });

  /// Parsuje JSON:API odpověď z /api/v1/rounds/{uuid}?include=discipline,discipline.disciplinePairs
  ///
  /// Reálné typy z API:
  ///   - kolo:          de_core_rounds
  ///   - disciplína:    de_core_disciplines
  ///   - pár:           de_core_discipline_pairs
  factory RoundDetail.fromJsonApi(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    final included = (json['included'] as List<dynamic>?) ?? [];

    final roundUuid = data['id'] as String? ?? '';
    final attributes = (data['attributes'] as Map<String, dynamic>?) ?? {};

    // Název kola (e.g. "Čtvrtfinále")
    final name = attributes['name']?.toString() ?? 'Kolo';

    // Pořadí kola – API posílá "order"
    final order = _parseInt(attributes['order']) ?? 1;

    // Typ hodnocení: 0 = křížky, jiné = umístění (finále)
    final evaluationSystem = _parseInt(attributes['evaluationSystem']) ?? 0;
    final isFinale = evaluationSystem != 0;

    // --- Discipline UUID z relationships ---
    final relationships = (data['relationships'] as Map<String, dynamic>?) ?? {};
    final disciplineRel = relationships['discipline'] as Map<String, dynamic>?;
    final disciplineUuid =
        ((disciplineRel?['data']) as Map<String, dynamic>?)?['id'] as String? ?? '';

    // --- Sestavíme mapu included zdrojů: "type:id" -> objekt ---
    final includedMap = <String, Map<String, dynamic>>{};
    for (final raw in included) {
      final item = raw as Map<String, dynamic>;
      final key = '${item['type']}:${item['id']}';
      includedMap[key] = item;
    }

    // --- Disciplína: typ je "de_core_disciplines" ---
    final disciplineObj = includedMap['de_core_disciplines:$disciplineUuid'];
    final discAttrs = (disciplineObj?['attributes'] as Map<String, dynamic>?) ?? {};
    final disciplineName = discAttrs['name']?.toString() ?? '';

    // --- Páry z discipline.relationships.disciplinePairs ---
    final discRels = (disciplineObj?['relationships'] as Map<String, dynamic>?) ?? {};
    final pairsRelData =
        (discRels['disciplinePairs']?['data']) as List<dynamic>?;

    final pairs = <DisciplinePair>[];
    if (pairsRelData != null) {
      for (final pairRef in pairsRelData) {
        final pairId = (pairRef as Map<String, dynamic>)['id'] as String? ?? '';
        // Typ je "de_core_discipline_pairs"
        final pairObj = includedMap['de_core_discipline_pairs:$pairId'];
        if (pairObj != null) {
          final attrs = (pairObj['attributes'] as Map<String, dynamic>?) ?? {};
          pairs.add(DisciplinePair.fromAttributes(pairId, attrs));
        }
      }
    }

    // Seřadíme dle bibNumber
    pairs.sort((a, b) => a.bibNumber.compareTo(b.bibNumber));

    return RoundDetail(
      uuid: roundUuid,
      disciplineUuid: disciplineUuid,
      name: name,
      disciplineName: disciplineName,
      order: order,
      isFinale: isFinale,
      evaluationSystem: evaluationSystem,
      pairs: pairs,
    );
  }

  /// Textový popis systému hodnocení pro zobrazení v UI.
  String get evaluationSystemLabel =>
      isFinale ? 'Umístění (1–6)' : 'Křížky (✓/✗)';
}

/// Pár přiřazený do disciplíny.
///
/// API nevrací jména párů v tomto endpointu – pouze startovní číslo (bibNumber).
class DisciplinePair {
  /// UUID discipline_pair záznamu – posílá se při POST /scores/bulk
  final String uuid;

  /// Startovní číslo (e.g. 101, 102, ...)
  final int bibNumber;

  const DisciplinePair({required this.uuid, required this.bibNumber});

  /// Startovní číslo jako string pro zobrazení v UI
  String get bibNumberStr => bibNumber.toString();

  /// Parsuje atributy z JSON:API included objektu de_core_discipline_pairs.
  factory DisciplinePair.fromAttributes(String uuid, Map<String, dynamic> attrs) {
    final bibNumber = _parseInt(attrs['bibNumber']) ?? 0;
    return DisciplinePair(uuid: uuid, bibNumber: bibNumber);
  }
}

// --- Pomocné funkce ---

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
