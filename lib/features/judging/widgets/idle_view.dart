import 'package:flutter/material.dart';

/// Zobrazí se při fázi [JudgingPhase.idle] a [JudgingPhase.roundEnded].
///
/// Čekací obrazovka – porotce čeká na pokyn od organizátora.
class IdleView extends StatelessWidget {
  /// Zobrazí-li se po ukončení kola, text se mírně liší.
  final bool isAfterRound;

  const IdleView({super.key, this.isAfterRound = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isAfterRound ? Icons.check_circle_outline : Icons.hourglass_empty,
              size: 72,
              color: isAfterRound ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              isAfterRound ? 'Kolo ukončeno' : 'Čekáme na start kola',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isAfterRound
                  ? 'Hodnocení bylo uzavřeno. Čekejte prosím na další pokyn.'
                  : 'Brzy začne kolo. Připravte se prosím.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
