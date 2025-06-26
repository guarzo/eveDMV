# Service Integration Guide

## A. wanderer-kills Service Integration

### 1. SSE Feed API Contract

We'll consume an SSE (Server-Sent Events) stream from wanderer-kills. Each event is a JSON blob representing a fully enriched killmail:

**Endpoint:**
```
GET https://wanderer-kills.example.com/sse
```

**Event Name:** `message` (default SSE)

**Payload Schema:**
```json
{
  "killmail_id": 123456789,
  "timestamp": "2025-06-25T15:42:00Z",
  "system": { "id": 30000142, "name": "Jita" },
  "ship": { "type_id": 22452, "name": "Rifter" },
  "participants": [
    {
      "character_id": 1111,
      "corporation_id": 2222,
      "alliance_id": null,
      "ship_type_id": 22452,
      "damage_done": 500,
      "final_blow": true
    }
  ],
  "raw_payload": { … },
  "isk_value": 150000000.0,
  "fitting_summary": "3×Autocannon II,2×Shield Extender I",
  "module_tags": ["T2 Guns","Shield Extender","High Slot"],
  "weapon_usage": [
    { "module":"Autocannon II","count":3 }
  ],
  "pilot_efficiency": [
    { "character_id":1111,"efficiency_score":0.87 }
  ]
}
```

### 2. Rate Limiting & 429 Handling

**Client-side:**
- Track `Retry-After` headers on HTTP/SSE reconnect attempts
- On HTTP 429, back off for the specified `Retry-After` or default to exponential back-off (500 ms → 1 s → 2 s → max 30 s)

**Server-side:**
- Broadway's `:max_demand` and `:min_demand` settings throttle the SSE producer if downstream backpressure occurs

### 3. Fallback Strategy

If the wanderer-kills SSE feed is unreachable or rate-limited for > 1 minute:

1. **Switch to zKillboard SSE** as a secondary producer:
   ```elixir
   Broadway.configure_producer(EveTracker.KillmailPipeline,
     module: {Broadway.SSE.Producer, url: "https://zkillboard.com/sse"}
   )
   ```

2. **Local Enrichment:** revert to our original Broadway enrichment stage, calling wanderer-kills HTTP endpoints (with back-off) as a fallback

3. **Alerting:** Emit a `:warning` Telemetry event so we can alert ops and restore the primary stream when available

## B. ESI (CCP's EVE Swagger Interface) Integration

### 1. Endpoints & Usage Patterns

| Purpose | Endpoint | Frequency |
|---|---|---|
| Character Info | `GET /latest/characters/{character_id}/` | On login + TTL refresh |
| Corp / Alliance IDs | Same as above (includes `corporation_id` + `alliance_id`) | On login + 10 min TTL |
| Corp History | `GET /latest/characters/{id}/corporationhistory/` | Once per session |
| Universe Type Metadata | `GET /latest/universe/types/` (paged) | Nightly full import (or differential) |
| System Security Status | `GET /latest/universe/systems/{system_id}/` | On kill ingestion |
| Killmails (fallback) | `GET /v1/killmails/recent/` | Only if both SSE feeds down |
| Refresh Token | `POST /latest/oauth/token` | As needed (automatic) |

### 2. Rate Limit Management

**Token Pooling:**
- Each user's `access_token` has its own rate limit (100 requests per 60 s default)
- For static data (universe types), use a service account or rotate through multiple tokens to avoid user quotas

**Dynamic Back-Off:**
- On HTTP 420 (enhance your calm) or 429, back off per `Retry-After` header
- Use a global ETS tracker of recent calls per token to prevent burst violations

**Batching & Paging:**
- Universe types: fetch in pages of 1000 with `pages=…` and use `If-Modified-Since` / `If-None-Match` to do differential imports

### 3. Static Data Refresh Strategy

**Nightly Differential Sync:**
1. Store ESI's response headers (`ETag`, `Last-Modified`) from the last run
2. On each subsequent run, include `If-None-Match`/`If-Modified-Since` to fetch only changed types
3. Fallback to full reload if the server doesn't support caching headers

**On-Demand Lookup:**
- For any unknown `type_id`, fall back to `GET /universe/types/{type_id}/` at runtime and cache the result in both Postgres and `:static_meta` ETS

---

With these integrations in place—leveraging wanderer-kills for SSE plus robust ESI usage and fallbacks—your tracker will remain resilient, respectful of third-party quotas, and always up to date.