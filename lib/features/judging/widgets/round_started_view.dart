import 'package:flutter/material.dart';

import '../../../core/models/round.dart';

/// Zobrazí se při fázi [JudgingPhase.roundStarted].
///
/// Ukazuje základní info o kole (název, disciplína, styl hodnocení)
/// a seznam párů. Hodnocení je zamčené – čekáme na START_DANCE event.
class RoundStartedView extends StatelessWidget {
  final RoundDetail round;

  const RoundStartedView({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info o kole
        _RoundInfoCard(round: round),

        // Informační banner – čekáme na tanec
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.orange.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'Čekáme na spuštění tance...',
                style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Počet párů
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            '${round.pairs.length} párů',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),

        // Seznam párů (jen startovní čísla – jména nejsou v API odpovědi)
        Expanded(
          child: round.pairs.isEmpty
              ? Center(
                  child: Text(
                    'Žádné páry nenačteny.',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : _PairsGrid(pairs: round.pairs),
        ),
      ],
    );
  }
}

/// Karta s informacemi o kole.
class _RoundInfoCard extends StatelessWidget {
  final RoundDetail round;

  const _RoundInfoCard({required this.round});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.06),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Název kola
          Text(
            round.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),

          // Název disciplíny
          if (round.disciplineName.isNotEmpty)
            Text(
              round.disciplineName,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[600]),
            ),

          const SizedBox(height: 10),

          // Tagy: typ hodnocení + počet párů
          Row(
            children: [
              _Tag(
                label: round.evaluationSystemLabel,
                color: round.isFinale ? Colors.amber : Colors.blue,
                icon: round.isFinale ? Icons.format_list_numbered : Icons.close,
              ),
              const SizedBox(width: 8),
              _Tag(
                label: '${round.pairs.length} párů',
                color: Colors.grey,
                icon: Icons.people_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barevný tag s ikonou.
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Tag({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid startovních čísel – přehledné zobrazení všech párů v kole.
class _PairsGrid extends StatelessWidget {
  final List<DisciplinePair> pairs;

  const _PairsGrid({required this.pairs});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.2,
      ),
      itemCount: pairs.length,
      itemBuilder: (context, index) {
        final pair = pairs[index];
        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            pair.bibNumberStr,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        );
      },
    );
  }
}
