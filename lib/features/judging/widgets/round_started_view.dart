import 'package:flutter/material.dart';
import '../../../core/models/round.dart';
import '../../../core/theme/app_colors.dart';

/// Zobrazí se při fázi [JudgingPhase.roundStarted].
///
/// Ukazuje základní info o kole a seznam párů. Hodnocení je zamčené.
class RoundStartedView extends StatelessWidget {
  final RoundDetail round;

  const RoundStartedView({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info o kole - Clean modern header
        _RoundHeader(round: round),

        // Seznam párů (zobrazen ve stejné mřížce jako hlasování)
        Expanded(
          child: round.pairs.isEmpty
              ? const Center(
                  child: Text(
                    'Žádné páry k zobrazení.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: round.pairs.length,
                  itemBuilder: (context, index) {
                    final pair = round.pairs[index];
                    return _WaitingGridCard(pair: pair);
                  },
                ),
        ),
      ],
    );
  }
}

class _RoundHeader extends StatelessWidget {
  final RoundDetail round;

  const _RoundHeader({required this.round});

  @override
  Widget build(BuildContext context) {
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
                  color: const Color(0xFFDDC8FF),
                  borderRadius: BorderRadius.circular(6), 
                ),
                child: const Text(
                  "PŘÍPRAVA", 
                  style: TextStyle(
                    color: Color(0xFF572BA0), 
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (round.disciplineName.isNotEmpty)
                Text(
                  round.disciplineName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Plus Jakarta Sans',
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                )
              else
                Text(
                  round.name,
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
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.outlineVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  '${round.pairs.length}',
                  style: const TextStyle(
                    color: AppColors.onSurfaceVariant, 
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

/// Zamčená mřížková karta představující přípravnou fázi pro pár
class _WaitingGridCard extends StatelessWidget {
  final DisciplinePair pair;

  const _WaitingGridCard({required this.pair});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest, // bílá karta
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: AppColors.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            pair.bibNumberStr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'Plus Jakarta Sans',
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Icon(
            Icons.lock_outline,
            color: AppColors.outlineVariant,
            size: 24,
          ),
        ],
      ),
    );
  }
}
