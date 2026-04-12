import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../judging/controllers/judging_controller.dart';
import '../../judging/widgets/debug_panel.dart';
import '../../judging/widgets/idle_view.dart';
import '../../judging/widgets/round_started_view.dart';
import '../../judging/widgets/scoring_view.dart';
import '../../judging/widgets/round_ended_view.dart';

/// Hlavní obrazovka hodnocení.
///
/// Přebírá původní `CompetitionDetailScreen` (debug log) a rozšiřuje ji
/// o plnou logiku hodnocení dle stavového automatu [JudgingController].
///
/// Debug panel (původní debug log) je stále dostupný přes ikonu v AppBaru.
class CompetitionDetailScreen extends ConsumerWidget {
  // competitionId je k dispozici pro budoucí použití (filtrování, header...)
  final String competitionId;

  const CompetitionDetailScreen({super.key, required this.competitionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(judgingControllerProvider(competitionId));
    final controller = ref.read(judgingControllerProvider(competitionId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: _appBarTitle(state),
        actions: [
          // Ikona offline fronty – zobrazí se pokud jsou čekající hodnocení
          if (state.error != null && state.error!.contains('Offline'))
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.wifi_off, color: Colors.orange, size: 20),
            ),
          // Debug tlačítko – otevře log panel jako bottom sheet
          IconButton(
            icon: const Icon(Icons.terminal),
            tooltip: 'Debug log',
            onPressed: () => DebugPanel.show(
              context,
              connectionStatus: state.connectionStatus,
              logEntries: state.debugLog,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chybový banner (pokud existuje chyba)
          if (state.error != null) _ErrorBanner(message: state.error!),

          // Hlavní obsah dle fáze
          Expanded(child: _buildBody(context, state, controller)),
        ],
      ),
    );
  }

  /// Vrátí titulek AppBaru podle aktuální fáze.
  Widget _appBarTitle(JudgingState state) {
    String getDisciplineAndRound() {
      final round = state.round;
      if (round == null) return 'Hodnocení';
      final parts = <String>[];
      if (round.disciplineName.isNotEmpty) parts.add(round.disciplineName);
      if (round.name.isNotEmpty) parts.add(round.name);
      return parts.isNotEmpty ? parts.join(' • ') : 'Hodnocení';
    }

    return switch (state.phase) {
      JudgingPhase.idle => const Text('Čekáme na kolo'),
      JudgingPhase.loading => const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Načítám...'),
          ],
        ),
      JudgingPhase.roundStarted => Text(getDisciplineAndRound()),
      JudgingPhase.danceActive => Text(getDisciplineAndRound()),
      JudgingPhase.roundEnded => const Text('Kolo ukončeno'),
    };
  }

  /// Vybere správný widget pro aktuální fázi hodnocení.
  Widget _buildBody(
    BuildContext context,
    JudgingState state,
    JudgingController controller,
  ) {
    switch (state.phase) {
      case JudgingPhase.idle:
        return const IdleView();

      case JudgingPhase.loading:
        return const Center(child: CircularProgressIndicator());

      case JudgingPhase.roundStarted:
        final round = state.round;
        if (round == null) return const IdleView();
        return RoundStartedView(round: round);

      case JudgingPhase.danceActive:
        final activeState = state.activeState;
        final round = state.round;
        if (activeState == null) return const IdleView();

        // isFinale: preferujeme hodnotu z active-state, fallback na round
        final isFinale =
            activeState.currentRound?.isFinale ?? round?.isFinale ?? false;

        return ScoringView(
          activeState: activeState,
          isFinale: isFinale,
          scores: state.scores,
          onScoreChanged: controller.setScore,
          onSubmit: controller.submitScores,
          isSubmitting: state.isSubmitting,
          scoresSubmitted: state.scoresSubmitted,
          scoresLocked: state.scoresLocked,
          advancementTarget: state.advancementTarget,
        );

      case JudgingPhase.roundEnded:
        return const RoundEndedView();
    }
  }
}

/// Červený banner pro zobrazení chybové zprávy.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isOffline = message.contains('Offline') || message.contains('offline');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isOffline ? Colors.orange.shade100 : Colors.red.shade100,
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.wifi_off : Icons.error_outline,
            size: 16,
            color: isOffline ? Colors.orange.shade800 : Colors.red.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color:
                    isOffline ? Colors.orange.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
