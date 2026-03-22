import 'dart:async';
import 'dart:convert';

import 'package:centrifuge/centrifuge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/active_state.dart';
import '../../../core/models/round.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/centrifugo_service.dart';
import '../../../core/services/score_queue_service.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../realtime/providers/centrifugo_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Stavový automat hodnocení
// ─────────────────────────────────────────────────────────────────────────────

/// Fáze procesu hodnocení.
enum JudgingPhase {
  /// Čekáme na start kola – úvodní obrazovka.
  idle,

  /// Načítáme data z API (getRound / getActiveState).
  loading,

  /// Kolo bylo zahájeno, zobrazujeme seznam párů. Hodnocení je zamčené.
  roundStarted,

  /// Tanec byl spuštěn, formulář hodnocení je otevřen.
  danceActive,

  /// Kolo bylo ukončeno – UI zamčeno, čekáme na další kolo.
  roundEnded,
}

// ─────────────────────────────────────────────────────────────────────────────
// JudgingState
// ─────────────────────────────────────────────────────────────────────────────

/// Neměnný stav celého procesu hodnocení.
class JudgingState {
  /// Aktuální fáze (idle → roundStarted → danceActive → roundEnded).
  final JudgingPhase phase;

  /// Data kola načtená po START_ROUND (disciplíny, páry, ...).
  final RoundDetail? round;

  /// Aktivní stav disciplíny načtený po START_DANCE.
  final ActiveState? activeState;

  /// Lokální hodnocení: disciplinePairUuid → hodnota (0/1 nebo 1–6).
  final Map<String, int> scores;

  /// true pokud právě probíhá odesílání hodnocení na API.
  final bool isSubmitting;

  /// true pokud bylo hodnocení tohoto tance úspěšně odesláno (nebo zařazeno do offline fronty).
  final bool scoresSubmitted;

  /// true pokud je hodnocení uzamčeno – po potvrzeném odeslání nelze dál měnit.
  /// Resetuje se až při novém tanci (START_DANCE).
  final bool scoresLocked;

  /// Chybová zpráva pro zobrazení v UI (null = žádná chyba).
  /// Pro chybu validace (špatný počet křížků) se nastavuje dočasně.
  final String? error;

  /// Debug log – záznamy jsou seřazeny od nejnovějšího (index 0 = nejnovější).
  final List<String> debugLog;

  /// Stav Centrifugo spojení (zobrazuje se v debug panelu).
  final String connectionStatus;

  const JudgingState({
    this.phase = JudgingPhase.idle,
    this.round,
    this.activeState,
    this.scores = const {},
    this.isSubmitting = false,
    this.scoresSubmitted = false,
    this.scoresLocked = false,
    this.error,
    this.debugLog = const [],
    this.connectionStatus = 'Nepřipojeno',
  });

  JudgingState copyWith({
    JudgingPhase? phase,
    RoundDetail? round,
    // null explicitně resetuje activeState (při START_ROUND)
    Object? activeState = _keep,
    Map<String, int>? scores,
    bool? isSubmitting,
    bool? scoresSubmitted,
    bool? scoresLocked,
    // null explicitně maže error
    Object? error = _keep,
    List<String>? debugLog,
    String? connectionStatus,
  }) {
    return JudgingState(
      phase: phase ?? this.phase,
      round: round ?? this.round,
      activeState: activeState == _keep
          ? this.activeState
          : activeState as ActiveState?,
      scores: scores ?? this.scores,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      scoresSubmitted: scoresSubmitted ?? this.scoresSubmitted,
      scoresLocked: scoresLocked ?? this.scoresLocked,
      error: error == _keep ? this.error : error as String?,
      debugLog: debugLog ?? this.debugLog,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  /// Vrátí true pokud jsou všechny páry ohodnoceny.
  bool get allPairsScored {
    final pairs = activeState?.allRoundPairs ?? [];
    if (pairs.isEmpty) return false;
    return pairs.every((p) => scores.containsKey(p.uuid));
  }

  /// Počet křížků (hodnota 1) ve stávajícím hodnocení.
  int get selectedCrossCount =>
      scores.values.where((v) => v == 1).length;

  /// Cílový počet křížků pro aktuální kolo (0 = finálový systém).
  int get advancementTarget =>
      activeState?.currentRound?.advancementTarget ?? 0;
}

// Sentinel hodnota pro copyWith – umožňuje explicitně předat null.
const _keep = Object();

// ─────────────────────────────────────────────────────────────────────────────
// JudgingController
// ─────────────────────────────────────────────────────────────────────────────

/// Hlavní StateNotifier pro logiku hodnocení.
///
/// Zpracovává Centrifugo eventy (START_ROUND, START_DANCE, END_ROUND),
/// volá REST API a spravuje offline frontu hodnocení.
class JudgingController extends StateNotifier<JudgingState> {
  final CentrifugoService _centrifugo;
  final ApiService _api;
  final ScoreQueueService _queue;
  final String _userUuid;

  Subscription? _subscription;
  StreamSubscription<PublicationEvent>? _publicationSub;
  StreamSubscription<String>? _statusSub;

  JudgingController({
    required CentrifugoService centrifugo,
    required ApiService api,
    required ScoreQueueService queue,
    required String userUuid,
  })  : _centrifugo = centrifugo,
        _api = api,
        _queue = queue,
        _userUuid = userUuid,
        super(const JudgingState()) {
    _init();
  }

  // ── Inicializace ────────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Sledujeme stav Centrifugo spojení a propisujeme ho do state
    _statusSub = _centrifugo.statusStream.listen((status) {
      if (mounted) state = state.copyWith(connectionStatus: status);
    });
    state = state.copyWith(connectionStatus: _centrifugo.currentStatus);

    // Přihlásíme se k privátnímu kanálu porotce
    final channel = 'judges:$_userUuid';
    _addDebugLog('🔌 Přihlašuji se k: $channel');

    _subscription = await _centrifugo.subscribe(channel);
    if (_subscription == null) {
      _addDebugLog('❌ Nepodařilo se přihlásit k $channel');
      return;
    }

    // Nasloucháme zprávám
    _publicationSub = _subscription!.publication.listen(_handlePublication);
    _addDebugLog('✅ Připojeno, naslouchám na $channel');

    // Při startu zkusíme odeslat případné offline hodnocení
    await _flushQueue();
  }

  // ── Centrifugo event handling ───────────────────────────────────────────────

  /// Dekóduje a dispatchuje příchozí Centrifugo publikaci.
  void _handlePublication(PublicationEvent event) {
    try {
      final payload = jsonDecode(utf8.decode(event.data)) as Map<String, dynamic>;
      final eventName = payload['event'] as String? ?? '';
      final eventData = (payload['data'] as Map<String, dynamic>?) ?? {};

      _addDebugLog('📩 Event: $eventName');

      switch (eventName) {
        case 'START_ROUND':
          _handleStartRound(eventData);
        case 'START_DANCE':
          _handleStartDance(eventData);
        case 'END_ROUND':
          _handleEndRound(eventData);
        default:
          _addDebugLog('❓ Neznámý event: $eventName | data: $eventData');
      }
    } catch (e) {
      _addDebugLog('⚠️ Chyba parsování eventu: $e');
    }
  }

  /// Zpracuje START_ROUND – načte detail kola z API.
  Future<void> _handleStartRound(Map<String, dynamic> data) async {
    final roundUuid = data['roundUuid'] as String?;
    if (roundUuid == null) {
      _addDebugLog('⚠️ START_ROUND: chybí roundUuid');
      return;
    }

    state = state.copyWith(phase: JudgingPhase.loading, error: null);
    _addDebugLog('🔄 Načítám kolo: $roundUuid');

    try {
      final round = await _api.getRound(roundUuid);
      state = state.copyWith(
        phase: JudgingPhase.roundStarted,
        round: round,
        activeState: null, // reset z předchozího kola
        scores: {},
        scoresSubmitted: false,
        scoresLocked: false,
        error: null,
      );
      _addDebugLog('✅ "${round.name}" načteno – ${round.pairs.length} párů'
          ' | ev.system: ${round.evaluationSystem}');
    } catch (e) {
      state = state.copyWith(phase: JudgingPhase.idle, error: e.toString());
      _addDebugLog('❌ Chyba načítání kola: $e');
    }
  }

  /// Zpracuje START_DANCE – načte aktivní stav disciplíny.
  Future<void> _handleStartDance(Map<String, dynamic> data) async {
    final action = data['action'] as String?;
    if (action != 'PULL_ACTIVE_STATE') {
      _addDebugLog("⚠️ START_DANCE: neznámá akce '$action'");
      return;
    }

    final disciplineUuid = state.round?.disciplineUuid;
    if (disciplineUuid == null || disciplineUuid.isEmpty) {
      _addDebugLog('⚠️ START_DANCE: chybí disciplineUuid – přijat START_DANCE před START_ROUND?');
      return;
    }

    state = state.copyWith(phase: JudgingPhase.loading, error: null);
    _addDebugLog('🔄 Načítám aktivní stav: $disciplineUuid');

    try {
      final activeState = await _api.getActiveState(disciplineUuid);
      if (!activeState.hasActiveState) {
        state = state.copyWith(phase: JudgingPhase.roundStarted);
        _addDebugLog('⚠️ Active-state je prázdný – vracím se na seznam párů');
        return;
      }

      state = state.copyWith(
        phase: JudgingPhase.danceActive,
        activeState: activeState,
        scores: {},
        scoresSubmitted: false,
        scoresLocked: false,
        error: null,
      );
      final dance = activeState.currentDance;
      _addDebugLog(
        '✅ Tanec: ${dance?.name ?? '?'} (${dance?.shortName ?? '?'})'
        ' – ${activeState.allRoundPairs.length} párů',
      );
    } catch (e) {
      // Při chybě vrátíme do stavu kola (ne idle), aby páry zůstaly viditelné
      state = state.copyWith(phase: JudgingPhase.roundStarted, error: e.toString());
      _addDebugLog('❌ Chyba načítání active-state: $e');
    }
  }

  /// Zpracuje END_ROUND – zamkne UI, případně auto-odešle hodnocení.
  void _handleEndRound(Map<String, dynamic> data) {
    _addDebugLog('🏁 END_ROUND – kolo ukončeno');

    // Pokud má porotce neuložené hodnocení, odešleme ho
    if (state.scores.isNotEmpty && !state.scoresSubmitted) {
      _addDebugLog('📤 Auto-odesílám neuložené hodnocení...');
      submitScores();
    }

    state = state.copyWith(phase: JudgingPhase.roundEnded);
  }

  // ── Hodnocení ───────────────────────────────────────────────────────────────

  /// Nastaví hodnotu hodnocení pro jeden pár.
  ///
  /// [pairUuid] – discipline_pair_uuid
  /// [value]    – 0/1 pro kola, 1–6 pro finále
  ///
  /// Po uzamčení (scoresLocked) změny nejsou povoleny.
  void setScore(String pairUuid, int value) {
    if (state.scoresLocked) return;
    final newScores = Map<String, int>.from(state.scores);
    newScores[pairUuid] = value;
    state = state.copyWith(scores: newScores, scoresSubmitted: false);
  }

  /// Odešle aktuální hodnocení na API.
  ///
  /// Pro křížkový systém (isFinale = false) ověřuje, že počet označených párů
  /// odpovídá přesně [advancement_target]. Všechny neoznačené páry se pošlou
  /// jako 0 (idempotentní upsert na serveru).
  ///
  /// Vrátí false pokud validace neprojde (chybná zpráva se uloží do state).
  /// Při síťové chybě (offline) uloží payload do fronty [ScoreQueueService].
  Future<bool> submitScores() async {
    final round = state.round;
    final activeState = state.activeState;

    if (round == null || activeState == null) {
      _addDebugLog('⚠️ submitScores: chybí round nebo activeState');
      return false;
    }

    final danceUuid = activeState.currentDance?.uuid ?? '';
    if (danceUuid.isEmpty) {
      _addDebugLog('⚠️ submitScores: chybí dance UUID');
      return false;
    }

    final isFinale = activeState.currentRound?.isFinale ?? round.isFinale;
    final allPairs = activeState.allRoundPairs;

    // ── Validace křížkového systému ────────────────────────────────────────
    if (!isFinale) {
      final target = activeState.currentRound?.advancementTarget ?? 0;
      final crossCount = state.scores.values.where((v) => v == 1).length;
      if (target > 0 && crossCount != target) {
        final msg = 'Označte přesně $target párů (nyní: $crossCount)';
        state = state.copyWith(error: msg);
        _addDebugLog('⚠️ Validace: $msg');
        return false;
      }
    }

    // ── Sestavení payloadu – všechny páry, neoznačené jako 0 ──────────────
    final scoreEntries = allPairs.map((p) {
      final value = state.scores[p.uuid] ?? 0;
      return ScoreEntry(disciplinePairUuid: p.uuid, value: value);
    }).toList();

    final payload = ScorePayload(
      roundUuid: round.uuid,
      disciplineDanceUuid: danceUuid,
      scores: scoreEntries,
    );

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      await _api.submitScores(payload);
      state = state.copyWith(
        isSubmitting: false,
        scoresSubmitted: true,
        scoresLocked: true,
      );
      _addDebugLog('✅ Hodnocení odesláno a uzamčeno (${payload.scores.length} párů)');
      return true;
    } catch (e) {
      // Offline – uložíme do fronty; upsert logika na serveru zajistí bezpečnost
      await _queue.enqueue(payload);
      state = state.copyWith(
        isSubmitting: false,
        scoresSubmitted: true,
        scoresLocked: true,
        error: 'Offline – hodnocení uloženo do fronty',
      );
      _addDebugLog('📥 Offline: hodnocení zařazeno do fronty (${_queue.length} položek)');
      return true;
    }
  }

  // ── Offline fronta ──────────────────────────────────────────────────────────

  /// Pokusí se odeslat všechny položky z offline fronty.
  Future<void> _flushQueue() async {
    if (!_queue.hasItems) return;
    _addDebugLog('🔄 Odesílám offline frontu (${_queue.length} položek)...');

    while (_queue.hasItems) {
      final payload = _queue.getQueue().first;
      try {
        await _api.submitScores(payload);
        await _queue.dequeue();
        _addDebugLog('✅ Offline fronta: odesláno kolo ${_shortUuid(payload.roundUuid)}');
      } catch (_) {
        _addDebugLog('⚠️ Offline fronta: stále offline, přerušuji');
        break;
      }
    }
  }

  // ── Debug log ───────────────────────────────────────────────────────────────

  void _addDebugLog(String message) {
    if (!mounted) return;
    final time = DateTime.now().toIso8601String().split('T').last.split('.').first;
    final log = '$time – $message';
    // Novější záznamy jsou na začátku; max 200 položek
    final newLog = [log, ...state.debugLog];
    state = state.copyWith(
      debugLog: newLog.length > 200 ? newLog.sublist(0, 200) : newLog,
    );
  }

  String _shortUuid(String uuid) =>
      uuid.length > 8 ? '${uuid.substring(0, 8)}...' : uuid;

  // ── Dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _publicationSub?.cancel();
    _statusSub?.cancel();
    _subscription?.unsubscribe();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────────────────────────────────────

/// Provider pro JudgingController.
///
/// autoDispose zajistí, že controller (a Centrifugo subscription) se uvolní
/// při opuštění obrazovky. Při opětovném vstupu se vytvoří nový controller.
final judgingControllerProvider =
    StateNotifierProvider.autoDispose<JudgingController, JudgingState>((ref) {
  return JudgingController(
    centrifugo: ref.read(centrifugoServiceProvider),
    api: ApiService(),
    queue: ref.read(scoreQueueServiceProvider),
    userUuid: ref.read(authControllerProvider).user?.id ?? '',
  );
});
