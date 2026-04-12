import 'package:flutter/material.dart';

import '../../../core/models/active_state.dart';
import '../../../core/theme/app_colors.dart';

class ScoringView extends StatelessWidget {
  final ActiveState activeState;
  final bool isFinale;
  final Map<String, int> scores;
  final void Function(String pairUuid, int value) onScoreChanged;
  final Future<bool> Function() onSubmit;
  final bool isSubmitting;
  final bool scoresSubmitted;
  final bool scoresLocked;
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

    final Map<String, List<ActivePair>> groupedPairs = {};
    for (var pair in pairs) {
      groupedPairs.putIfAbsent(pair.heatName, () => []).add(pair);
    }

    final selectedCrossesCount = scores.values.where((v) => v == 1).length;

    return Stack(
      children: [
        Column(
          children: [
            // Extrémně zkomprimovaná hlavička
            _CompactScoringHeader(
              dance: dance,
              isFinale: isFinale,
              selectedCount: selectedCrossesCount,
              targetCount: advancementTarget,
              isLocked: scoresLocked,
            ),

            if (scoresSubmitted)
              _SubmittedBanner(isLocked: scoresLocked),

            Expanded(
              child: pairs.isEmpty
                  ? const Center(
                      child: Text(
                        'Žádné páry k hodnocení.',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    )
                  : isFinale
                      ? _buildFinaleList(pairs)
                      : _buildCrossesGrid(groupedPairs),
            ),
          ],
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 32,
          child: _SubmitButton(
            onSubmit: scoresLocked ? null : () => _confirmAndSubmit(context),
            isSubmitting: isSubmitting,
            isSubmitted: scoresSubmitted,
            isLocked: scoresLocked,
            allScored: isFinale
                ? (scores.values.where((v) => v > 0).length >= pairs.length)
                : (advancementTarget > 0 ? selectedCrossesCount == advancementTarget : true),
          ),
        ),
      ],
    );
  }

  Widget _buildFinaleList(List<ActivePair> pairs) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final currentValue = scores[pair.uuid];
        return _FinalePairRow(
          pair: pair,
          selectedValue: currentValue,
          usedValues: scores.entries
              .where((e) => e.key != pair.uuid && e.value > 0)
              .map((e) => e.value)
              .toSet(),
          onChanged: scoresLocked
              ? null
              : (v) => onScoreChanged(pair.uuid, v),
        );
      },
    );
  }

  Widget _buildCrossesGrid(Map<String, List<ActivePair>> groupedPairs) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
      children: groupedPairs.entries.map((entry) {
        final heatName = entry.key;
        final heatPairs = entry.value;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (heatName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8.0, top: 8.0),
                  child: Text(
                    heatName,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: heatPairs.length,
                itemBuilder: (context, index) {
                  final pair = heatPairs[index];
                  final currentValue = scores[pair.uuid];
                  return _GridCrossButton(
                    bibNumber: pair.bibNumberStr,
                    isSelected: currentValue == 1,
                    onTap: scoresLocked ? null : () => onScoreChanged(pair.uuid, currentValue == 1 ? 0 : 1),
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _confirmAndSubmit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrdit odeslání', style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold)),
        content: const Text('Opravdu si přejete odeslat svá hodnocení? Záznam ještě bude možné chvíli upravit.', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Zrušit', style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Odeslat', style: TextStyle(fontWeight: FontWeight.bold)),
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

class _CompactScoringHeader extends StatelessWidget {
  final ActiveDance? dance;
  final bool isFinale;
  final int selectedCount;
  final int targetCount;
  final bool isLocked;

  const _CompactScoringHeader({
    this.dance,
    required this.isFinale,
    required this.selectedCount,
    required this.targetCount,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = targetCount > 0 && selectedCount == targetCount;
    final statusColor = isLocked ? AppColors.outline : (isOk ? const Color(0xFF16A34A) : AppColors.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinale ? Colors.amber.withOpacity(0.2) : const Color(0xFFD1FADA),
                  borderRadius: BorderRadius.circular(6), 
                ),
                child: Text(
                  isFinale ? "FINÁLE" : "KOLO", 
                  style: TextStyle(
                    color: isFinale ? Colors.amber.shade900 : const Color(0xFF0F5223), 
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dance?.name ?? 'Tanec',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Plus Jakarta Sans',
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          
          if (!isFinale && targetCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLocked ? Icons.lock_rounded : (isOk ? Icons.check_circle_rounded : Icons.close_rounded),
                    color: statusColor,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$selectedCount/$targetCount',
                    style: TextStyle(
                      color: statusColor, 
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmittedBanner extends StatelessWidget {
  final bool isLocked;
  const _SubmittedBanner({required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FADA),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF0F5223), size: 16),
            const SizedBox(width: 8),
            Text(
              isLocked ? 'Uzamčeno – odesláno' : 'Úspěšně odesláno. Lze upravit.',
              style: const TextStyle(color: Color(0xFF0F5223), fontWeight: FontWeight.w700, fontFamily: 'Inter', fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mřížkové tlačítko pro křížky - upraveno tak aby jasně zobrazovalo křížek "X"
class _GridCrossButton extends StatelessWidget {
  final String bibNumber;
  final bool isSelected;
  final VoidCallback? onTap;

  const _GridCrossButton({
    required this.bibNumber,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF7F5FF) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                bibNumber,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Plus Jakarta Sans',
                  color: isSelected ? AppColors.primary : AppColors.onSurface,
                ),
              ),
            ),
            // Vodoznakový velký křížek pro jasnou signalizaci
            if (isSelected)
              Positioned(
                bottom: 4,
                right: 4,
                child: Icon(
                  Icons.close_rounded,
                  color: AppColors.primary.withOpacity(1.0),
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Finálový výpis (umístění)
class _FinalePairRow extends StatelessWidget {
  final ActivePair pair;
  final int? selectedValue;
  final Set<int> usedValues;
  final ValueChanged<int>? onChanged;

  const _FinalePairRow({
    required this.pair,
    required this.selectedValue,
    this.usedValues = const {},
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = onChanged == null;
    final pairCount = usedValues.length + (selectedValue != null ? 1 : 0);
    final maxValue = pairCount < 6 ? 6 : pairCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selectedValue != null ? const Color(0xFFF7F5FF) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: selectedValue != null 
                ? Border.all(color: AppColors.primary, width: 2)
                : Border.all(color: AppColors.outline.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            // Startovní číslo - nyní velmi prominentní velký čtverec vlevo
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selectedValue != null ? AppColors.primary : const Color(0xFFF1F0F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                pair.bibNumberStr,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: selectedValue != null ? Colors.white : AppColors.onSurface,
                  fontSize: 22,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tlačítka pro umístění rozprostřená horizontálně
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(maxValue, (i) {
                  final value = i + 1;
                  final isActive = selectedValue == value;
                  final isTaken = !isActive && usedValues.contains(value);

                  Color bgColor;
                  Color borderColor;
                  Color textColor;
                  
                  if (isActive) {
                    bgColor = locked ? Colors.grey : AppColors.primary;
                    borderColor = locked ? Colors.grey : AppColors.primary;
                    textColor = Colors.white;
                  } else if (isTaken) {
                    bgColor = AppColors.primary.withOpacity(0.05);
                    borderColor = AppColors.primary.withOpacity(0.3);
                    textColor = AppColors.primary.withOpacity(0.6);
                  } else {
                    bgColor = Colors.transparent;
                    borderColor = AppColors.outlineVariant.withOpacity(0.5);
                    textColor = AppColors.onSurfaceVariant;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: locked ? null : () => onChanged!(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 56,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: borderColor,
                            width: isActive ? 0 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$value',
                          style: TextStyle(
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
                            color: textColor,
                            fontSize: 20,
                            fontFamily: 'Plus Jakarta Sans',
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final bool isSubmitted;
  final bool isLocked;
  final bool allScored;

  const _SubmitButton({
    required this.onSubmit,
    required this.isSubmitting,
    required this.isSubmitted,
    required this.isLocked,
    required this.allScored,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors;
    if (isLocked) {
      gradientColors = [AppColors.outline, AppColors.outlineVariant];
    } else if (isSubmitted) {
      gradientColors = [const Color(0xFF16A34A), const Color(0xFF22C55E)];
    } else if (allScored) {
      gradientColors = [const Color(0xFF702AE1), const Color(0xFFB28CFF)];
    } else {
      gradientColors = [const Color(0xFFDCDBEB), const Color(0xFFDCDBEB)];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: (isLocked || !allScored) ? [] : [
          BoxShadow(
            color: (isSubmitted ? Colors.green : AppColors.primary).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        borderRadius: BorderRadius.circular(32),
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        ),
        onPressed: isSubmitting ? null : onSubmit,
        child: isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isLocked ? Icons.lock : isSubmitted ? Icons.check : Icons.send,
                    color: (!allScored && !isLocked && !isSubmitted) ? AppColors.onSurfaceVariant : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLocked
                        ? 'Odesláno a uzamčeno'
                        : isSubmitted
                            ? 'Změnit hodnocení'
                            : 'Odeslat hodnocení', // Zcela zjednodušeno
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: (!allScored && !isLocked && !isSubmitted) ? AppColors.onSurfaceVariant : Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
