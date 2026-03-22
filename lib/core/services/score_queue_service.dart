import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider – inicializuje se přes override v main.dart (stejně jako StorageService).
final scoreQueueServiceProvider = Provider<ScoreQueueService>((ref) {
  throw UnimplementedError('scoreQueueServiceProvider musí být overridden v main.dart');
});

// ─────────────────────────────────────────────────────────────────────────────
// Datové modely pro hodnocení
// ─────────────────────────────────────────────────────────────────────────────

/// Jeden záznam hodnocení páru.
class ScoreEntry {
  final String disciplinePairUuid;
  final int value; // 0/1 pro kola, 1–6 pro finále

  const ScoreEntry({required this.disciplinePairUuid, required this.value});

  Map<String, dynamic> toJson() => {
        'discipline_pair_uuid': disciplinePairUuid,
        'value': value,
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
        disciplinePairUuid: json['discipline_pair_uuid'] as String,
        value: json['value'] as int,
      );
}

/// Kompletní payload pro POST /api/v1/scores/bulk.
class ScorePayload {
  final String roundUuid;
  final String disciplineDanceUuid;
  final List<ScoreEntry> scores;

  const ScorePayload({
    required this.roundUuid,
    required this.disciplineDanceUuid,
    required this.scores,
  });

  Map<String, dynamic> toJson() => {
        'round_uuid': roundUuid,
        'discipline_dance_uuid': disciplineDanceUuid,
        'scores': scores.map((s) => s.toJson()).toList(),
      };

  factory ScorePayload.fromJson(Map<String, dynamic> json) => ScorePayload(
        roundUuid: json['round_uuid'] as String,
        disciplineDanceUuid: json['discipline_dance_uuid'] as String,
        scores: (json['scores'] as List<dynamic>)
            .map((s) => ScoreEntry.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ScoreQueueService
// ─────────────────────────────────────────────────────────────────────────────

/// Správce offline fronty hodnocení.
///
/// Pokud odeslání hodnocení selže (WiFi výpadek), payload se uloží sem.
/// Po obnovení spojení se fronta odešle znovu.
///
/// Backend endpoint (POST /scores/bulk) je idempotentní (upsert),
/// takže opakované odeslání je bezpečné.
class ScoreQueueService {
  static const _queueKey = 'score_offline_queue';

  final SharedPreferences _prefs;

  ScoreQueueService(this._prefs);

  // ── Čtení ──────────────────────────────────────────────────────────────────

  /// Vrátí všechny čekající payloady ve frontě.
  List<ScorePayload> getQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => ScorePayload.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Poškozená data – vrátíme prázdnou frontu
      return [];
    }
  }

  /// Vrátí true pokud fronta obsahuje alespoň jeden čekající payload.
  bool get hasItems => getQueue().isNotEmpty;

  /// Počet čekajících payloadů.
  int get length => getQueue().length;

  // ── Zápis ──────────────────────────────────────────────────────────────────

  /// Přidá payload na konec fronty.
  Future<void> enqueue(ScorePayload payload) async {
    final queue = getQueue();
    queue.add(payload);
    await _persist(queue);
  }

  /// Odstraní první payload z fronty (volá se po úspěšném odeslání).
  Future<void> dequeue() async {
    final queue = getQueue();
    if (queue.isNotEmpty) {
      queue.removeAt(0);
      await _persist(queue);
    }
  }

  /// Vymaže celou frontu (např. při odhlášení).
  Future<void> clear() async {
    await _prefs.remove(_queueKey);
  }

  // ── Interní ────────────────────────────────────────────────────────────────

  Future<void> _persist(List<ScorePayload> queue) async {
    final encoded = jsonEncode(queue.map((p) => p.toJson()).toList());
    await _prefs.setString(_queueKey, encoded);
  }
}
