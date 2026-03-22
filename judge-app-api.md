# Judge App – API & Real-time Communication Reference

Dokument popisuje flow komunikace mezi backendem a aplikací porotce:
REST endpointy + Centrifugo WebSocket zprávy.

---

## Centrifugo – kanál porotce

Každý porotce naslouchá na svém privátním kanálu:

```
judges:{user_uuid}
```

Autorizace kanálu probíhá přes:
```
POST /api/v1/broadcasting/auth
Authorization: Bearer <token>
```

---

## Centrifugo zprávy (příchozí na klientovi)

Všechny zprávy mají strukturu:
```json
{
  "event": "<EVENT_NAME>",
  "data": { ... }
}
```

### START_ROUND

Spuštění kola – porotce má načíst detail kola a připravit UI.

```json
{
  "event": "START_ROUND",
  "data": {
    "roundUuid": "019c675e-aecc-737e-9864-1866f36f6d22",
    "timestamp": "2026-03-22 10:00:00"
  }
}
```

**Akce klienta:**
1. Načíst detail kola přes REST (viz níže `GET /rounds/{uuid}`)
2. Zobrazit seznam párů a tanců – hodnocení zatím zamčené

---

### START_DANCE

Spuštění konkrétního tance – porotce má zobrazit formulář hodnocení.

```json
{
  "event": "START_DANCE",
  "data": {
    "roundUuid": "019c675e-aecc-737e-9864-1866f36f6d22",
    "disciplineDanceUuid": "abc123...",
    "action": "PULL_ACTIVE_STATE",
    "timestamp": "2026-03-22 10:05:00"
  }
}
```

**Akce klienta:**
1. Pole `action: "PULL_ACTIVE_STATE"` signalizuje, že klient má (znovu) načíst aktivní stav
2. Zavolat `GET /api/v1/disciplines/{disciplineUuid}/active-state`
3. Odemknout hodnocení pro `disciplineDanceUuid`

---

### END_ROUND

Ukončení kola – hodnocení uzavřeno, UI přejde do stavu čekání.

```json
{
  "event": "END_ROUND",
  "data": {
    "roundUuid": "019c675e-aecc-737e-9864-1866f36f6d22",
    "timestamp": "2026-03-22 10:30:00"
  }
}
```

**Akce klienta:**
1. Zamknout formulář hodnocení
2. Zobrazit stav „Kolo ukončeno, čekejte"
3. Odeslat případně lokálně vyrovnané (offline) hodnocení do fronty

---

## REST Endpointy

Všechny endpointy vyžadují:
```
Authorization: Bearer <token>
Content-Type: application/json
```

---

### Autentizace

| Metoda | URL | Popis |
|--------|-----|-------|
| POST | `/api/v1/auth/login` | Přihlášení, vrátí JWT token |
| POST | `/api/v1/auth/refresh` | Obnovení tokenu |
| GET  | `/api/v1/auth/me` | Info o přihlášeném uživateli |

---

### Detail kola (po přijetí START_ROUND)

```
GET /api/v1/rounds/{roundUuid}?include=scheduleItem,heats,heats.heatPairs,discipline,discipline.disciplineJudges,discipline.disciplineJudges.user,discipline.disciplinePairs
```

Vrátí kompletní data kola včetně párů, porotců a plánovaných tanců.
Porotce zavolá tento endpoint po přijetí zprávy `START_ROUND`.

---

### Aktivní stav disciplíny (reconnect / obnova)

```
GET /api/v1/disciplines/{disciplineUuid}/active-state
```

Vrátí aktuální stav z Redis cache – použití při:
- Opětovném připojení zařízení (WiFi výpadek, refresh)
- Zpracování `START_DANCE` zprávy (viz `action: PULL_ACTIVE_STATE`)

**Odpověď (kolo probíhá):**
```json
{
  "data": {
    "current_round": { ... },
    "current_dance": { ... },
    "all_round_pairs": [ ... ]
  }
}
```

**Odpověď (žádný aktivní stav):**
```json
{
  "data": null
}
```

Cache klíč: `active_state_discipline_{disciplineUuid}` – TTL 24 hodin, maže se při `END_ROUND`.

---

### Hromadné uložení hodnocení

```
POST /api/v1/scores/bulk
```

**Payload:**
```json
{
  "round_uuid": "019c675e-aecc-737e-9864-1866f36f6d22",
  "discipline_dance_uuid": "abc123...",
  "scores": [
    { "discipline_pair_uuid": "pair-uuid-1", "value": 1 },
    { "discipline_pair_uuid": "pair-uuid-2", "value": 0 }
  ]
}
```

- `value`: `0`/`1` pro kola (křížky) nebo `1–6` pro finále
- Interně provede `upsert` – bezpečné volat opakovaně (idempotentní)
- Porotce je identifikován z JWT tokenu (`judge_uuid = user.id`)

**Offline / queue strategie:**
- Pokud požadavek selže (WiFi výpadek), klient uloží payload lokálně
- Po obnovení připojení odešle frontu postupně
- Díky `upsert` logice je opakované odeslání bezpečné

---

## Flow – celkový přehled

```
[Cockpit / Admin]                    [Backend]                    [Porotce]
      |                                  |                             |
      | POST /rounds/{uuid}/start-round  |                             |
      |--------------------------------->|                             |
      |                                  | WS: START_ROUND ----------->|
      |                                  |                             | GET /rounds/{uuid}?include=...
      |                                  |<----------------------------|
      |                                  | 200 (data kola) ----------->|
      |                                  |                             |
      | POST /rounds/{uuid}/start-dance  |                             |
      | { discipline_dance_uuid }        |                             |
      |--------------------------------->|                             |
      |                                  | WS: START_DANCE ----------->|
      |                                  |                             | GET /disciplines/{uuid}/active-state
      |                                  |<----------------------------|
      |                                  | 200 (aktivní stav) -------->|
      |                                  |                             | [porotce hodnotí]
      |                                  |                             |
      |                                  |   POST /scores/bulk ------->|
      |                                  |<----------------------------|
      |                                  | 200 OK ─────────────────── |
      |                                  |                             |
      | POST /rounds/{uuid}/end-round    |                             |
      |--------------------------------->|                             |
      |                                  | WS: END_ROUND ------------->|
      |                                  |                             | [zamknout UI]
```

---

## Poznámky / TODO

- `POST /rounds/{uuid}/start-dance` – vyžaduje body `{ "discipline_dance_uuid": "..." }`
- Validace kompletnosti hodnocení před `end-round` je zatím TODO (backend)
- Autorizace `active-state` endpointu – zatím bez policy (TODO: pouze porotce dané disciplíny)
- Autorizace `scores/bulk` – zatím bez kontroly, že porotce patří do disciplíny (TODO)
