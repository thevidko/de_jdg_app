import 'package:flutter/material.dart';

import '../../../core/models/active_state.dart';

/// Formulář hodnocení – zobrazí se při fázi [JudgingPhase.danceActive].
///
/// Pro každý pár zobrazí ovládací prvek dle typu kola:
/// - Kolo (isFinale = false): přepínač ✗ / ✓ (hodnoty 0 nebo 1 – křížky)
/// - Finále (isFinale = true): výběr čísla 1–6 (umístění)
class ScoringView extends StatelessWidget {
  final ActiveState activeState;
  final bool isFinale;

  /// Aktuální stav hodnocení: disciplinePairUuid → hodnota
  final Map<String, int> scores;

  /// Callback při změně hodnocení páru
  final void Function(String pairUuid, int value) onScoreChanged;

  /// Callback pro odeslání hodnocení – vrací Future bool (false = validace selhala)
  final Future<bool> Function() onSubmit;

  final bool isSubmitting;
  final bool scoresSubmitted;

  /// Po potvrzeném odeslání uzamkne UI – nelze měnit hodnocení
  final bool scoresLocked;

  /// Cílový počet křížků (0 = neuplatňuje se / finále)
  final int advancementTarget;

  const ScoringView({
    super.key,
    required this.activeState,
    required this.isFinale,
    required this.scores,
    required this.onScoreChanged,
    required this.onSubmit,
    this.isSubmitting = false,
    this.scoresSubmitted = false,
    this.scoresLocked = false,
    this.advancementTarget = 0,
  });

  @override
  Widget build(BuildContext context) {
    final dance = activeState.currentDance;
    final pairs = activeState.allRoundPairs;

    return Column(
      children: [
        // Hlavička – název tance + info o typu hodnocení
        _DanceHeader(dance: dance, isFinale: isFinale, pairCount: pairs.length),

        // Banner: počet křížků (jen pro křížkový systém)
        if (!isFinale && advancementTarget > 0)
          _CrossCountBanner(
            selectedCount: scores.values.where((v) => v == 1).length,
            targetCount: advancementTarget,
            isLocked: scoresLocked,
          ),

        // Odeslané hodnocení – banner potvrzení
        if (scoresSubmitted)
          _SubmittedBanner(isLocked: scoresLocked),

        // Seznam párů s hodnotícími prvky
        Expanded(
          child: pairs.isEmpty
              ? Center(
                  child: Text(
                    'Žádné páry k hodnocení.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: pairs.length,
                  itemBuilder: (context, index) {
                    final pair = pairs[index];
                    final currentValue = scores[pair.uuid];
                    return isFinale
                        ? _FinalePairRow(
                            pair: pair,
                            selectedValue: currentValue,
                            onChanged: scoresLocked
                                ? null
                                : (v) => onScoreChanged(pair.uuid, v),
                          )
                        : _RoundPairRow(
                            pair: pair,
                            isSelected: currentValue == 1,
                            onChanged: scoresLocked
                                ? null
                                : (v) => onScoreChanged(pair.uuid, v ? 1 : 0),
                          );
                  },
                ),
        ),

        // Tlačítko Odeslat – fixní u dolního okraje
        _SubmitButton(
          onSubmit: scoresLocked ? null : () => _confirmAndSubmit(context),
          isSubmitting: isSubmitting,
          isSubmitted: scoresSubmitted,
          isLocked: scoresLocked,
          scoredCount: scores.length,
          totalCount: pairs.length,
        ),
      ],
    );
  }

  /// Zobrazí AlertDialog s potvrzením a poté zavolá [onSubmit].
  Future<void> _confirmAndSubmit(BuildContext context) async {
    final crossCount = scores.values.where((v) => v == 1).length;

    // Sestavíme popis hodnocení pro dialog
    final String summary = isFinale
        ? 'Odesíláte pořadí pro ${activeState.allRoundPairs.length} párů.'
        : 'Označujete $crossCount z ${activeState.allRoundPairs.length} párů jako postupující'
            '${advancementTarget > 0 ? ' (cíl: $advancementTarget)' : ''}.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrdit odeslání'),
        content: Text(summary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Odeslat'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await onSubmit();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgety
// ─────────────────────────────────────────────────────────────────────────────

/// Hlavička s názvem tance.
class _DanceHeader extends StatelessWidget {
  final ActiveDance? dance;
  final bool isFinale;
  final int pairCount;

  const _DanceHeader({this.dance, required this.isFinale, required this.pairCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isFinale
          ? Colors.amber.withValues(alpha: 0.12)
          : Colors.green.withValues(alpha: 0.1),
      width: double.infinity,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFinale ? Colors.amber : Colors.green,
              shape: BoxShape.circle,
            ),
            child: Text(
              dance?.shortName ?? '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dance?.name ?? 'Tanec',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                isFinale
                    ? 'Finále – zadejte umístění 1–6'
                    : 'Kolo – označte postupující (✓)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '$pairCount párů',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Banner zobrazující aktuální počet křížků vs. cíl (jen pro křížkový systém).
class _CrossCountBanner extends StatelessWidget {
  final int selectedCount;
  final int targetCount;
  final bool isLocked;

  const _CrossCountBanner({
    required this.selectedCount,
    required this.targetCount,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = selectedCount == targetCount;
    final color = isLocked
        ? Colors.grey
        : isOk
            ? Colors.green
            : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            isLocked
                ? Icons.lock
                : isOk
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isLocked
                ? 'Uzamčeno – křížky odeslány'
                : 'Označeni: $selectedCount / $targetCount',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          if (!isLocked && !isOk) ...[
            const Spacer(),
            Text(
              'Potřeba přesně $targetCount',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner zobrazený po úspěšném odeslání hodnocení.
class _SubmittedBanner extends StatelessWidget {
  final bool isLocked;

  const _SubmittedBanner({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Hodnocení odesláno',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          Text(
            isLocked ? 'Uzamčeno' : 'Lze upravit a odeslat znovu',
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Řádek páru pro kolo – přepínač ✗ / ✓ (0 nebo 1).
class _RoundPairRow extends StatelessWidget {
  final ActivePair pair;
  final bool isSelected;

  /// null = uzamčeno, nelze měnit
  final ValueChanged<bool>? onChanged;

  const _RoundPairRow({
    required this.pair,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected
          ? Colors.green.withValues(alpha: locked ? 0.05 : 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? (locked ? Colors.green.shade200 : Colors.green)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: locked ? null : () => onChanged!(!isSelected),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Startovní číslo
              _NumberBadge(number: pair.bibNumberStr, highlighted: isSelected),
              const SizedBox(width: 12),
              // Heat
              Expanded(
                child: Text(
                  pair.heatName,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              // Přepínač – velký a dobře tapovatelný
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (locked ? Colors.green.shade300 : Colors.green)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSelected ? Icons.check : Icons.close,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Řádek páru pro finále – výběr umístění 1–6.
class _FinalePairRow extends StatelessWidget {
  final ActivePair pair;
  final int? selectedValue;

  /// null = uzamčeno, nelze měnit
  final ValueChanged<int>? onChanged;

  const _FinalePairRow({
    required this.pair,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _NumberBadge(
                    number: pair.bibNumberStr, highlighted: selectedValue != null),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pair.heatName,
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ),
                if (selectedValue != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: locked ? Colors.grey : Colors.amber,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '#$selectedValue',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Tlačítka 1–6
            Row(
              children: List.generate(6, (i) {
                final value = i + 1;
                final isActive = selectedValue == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: locked ? null : () => onChanged!(value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 44,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (locked ? Colors.grey : Colors.amber)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? (locked ? Colors.grey : Colors.amber)
                              : Colors.grey.shade300,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color:
                              isActive ? Colors.white : Colors.grey.shade700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Odznáček se startovním číslem páru.
class _NumberBadge extends StatelessWidget {
  final String number;
  final bool highlighted;

  const _NumberBadge({required this.number, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted
            ? Theme.of(context).primaryColor
            : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      child: Text(
        number,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: highlighted ? Colors.white : Colors.grey.shade700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Tlačítko pro odeslání hodnocení – fixní na spodním okraji.
class _SubmitButton extends StatelessWidget {
  /// null = uzamčeno nebo nelze kliknout
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final bool isSubmitted;
  final bool isLocked;
  final int scoredCount;
  final int totalCount;

  const _SubmitButton({
    required this.onSubmit,
    required this.isSubmitting,
    required this.isSubmitted,
    required this.isLocked,
    required this.scoredCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final allScored = scoredCount >= totalCount && totalCount > 0;

    Color bgColor;
    if (isLocked) {
      bgColor = Colors.grey;
    } else if (isSubmitted) {
      bgColor = Colors.green;
    } else {
      bgColor = Theme.of(context).primaryColor;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isSubmitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(isLocked
                    ? Icons.lock
                    : isSubmitted
                        ? Icons.check
                        : Icons.send),
            label: Text(
              isSubmitting
                  ? 'Odesílám...'
                  : isLocked
                      ? 'Odesláno a uzamčeno'
                      : isSubmitted
                          ? 'Odesláno ($scoredCount/$totalCount) – znovu?'
                          : allScored
                              ? 'Odeslat hodnocení'
                              : 'Odeslat ($scoredCount/$totalCount)',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
