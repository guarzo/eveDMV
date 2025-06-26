# Data Freshness Management

## 1. Enrichment Data Freshness

### TTL on Cached Enrichment
We cache each enriched killmail (the full wanderer-kills JSON) in ETS with a 24 hour TTL.

### Re-fetch Window
If a killmail is requested (e.g. detail page) and its enrichment is older than 24 hours, we transparently re-enqueue it for enrichment (via the retry-queue), but continue to serve the stale data until the new result arrives.

### Configurable Threshold
In app config:

```elixir
config :eve_tracker, :enrichment_ttl, hours: 24
```

Allows tuning to 12 h or 48 h if needed for load vs. freshness.

## 2. ESI Character/Corp Data Changes

### Short-Lived Cache
Character → corp/alliance lookups (and later role lookups) live in ETS with a 10 minute TTL.

### Per-Request Check
A Phoenix Plug (or LiveView mount hook) checks the cache TTL:

If expired, it calls ESI `/v4/characters/{id}/` and `/v4/characters/{id}/corporationhistory` to refresh.

### Session Context Update
When corp/alliance changes mid-session, we:

1. Update the ETS entry
2. Invalidate any corp-scoped caches (e.g. participant‐by‐corp indexes)
3. Push a small LiveView banner:
   > **Notice:** Your corporation has been updated to NewCorp. ACLs refreshed.

### Graceful Failure
If ESI is unreachable, continue using the last cached values and log a warning.

## 3. Permanently Failed Enrichment

### Retry Policy
Broadway "enrichment" stage uses exponential back-off with max 3 attempts.

### Dead-Letter Queue
After 3 failures, we tag the record with `enrichment_failed_at` timestamp in `killmails_enriched`.

We push the `killmail_id` onto a periodic "retry queue" (via a GenServer or Oban job) that runs every 10 minutes to re-try any `enrichment_failed_at` older than 1 hour.

### UI Handling
In the feed/detail pages, show the raw payload + a muted warning icon:

> ⚠️ "Enrichment unavailable"

### Alerting & Monitoring
- Increment a Prometheus metric `killmail_enrichment_failures_total`
- If failure rate > 1% over a 5 minute window, send an alert so we can investigate external service availability

## Summary

- **Enrichment data** lives for 24 h, auto-re-queued when stale
- **Character/Corp info** is cached 10 min, auto-refreshed per request
- **Permanent failures** enter a retry queue and are surfaced in the UI with a warning, while metrics drive alerting

This combination keeps everything both timely and resilient—users get the freshest data we can deliver, without ever seeing hard errors when external services hiccup.