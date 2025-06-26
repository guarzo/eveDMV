# Pull Request Checklist

## Schema & Migrations

- [ ] Migration adds new tables/columns with `IF NOT EXISTS` and reversible down steps
- [ ] Partitioned tables (`killmails_raw`, `killmails_enriched`) are created with `PARTITION BY RANGE` on timestamp fields
- [ ] Join table `users_characters` correctly defines composite PK and FKs
- [ ] New indexes (GIN, composite, trigram) are added on parent tables, not just partitions
- [ ] All tables have proper `NOT NULL` constraints, defaults, and audit columns (`inserted_at`/`updated_at`)

## Data Ingestion Pipeline

- [ ] Broadway pipeline module subscribes to the wanderer-kills SSE feed, not raw zKillboard
- [ ] Single producer with transformer → `:db_insert` → `:pubsub` topology is correctly configured
- [ ] Bulk inserts into `KillmailRaw`, `KillmailEnriched`, and `Participant` use `Repo.insert_all` inside a transaction
- [ ] On-conflict handling (`:nothing`) ensures idempotency

## Enrichment & Price Clients

- [ ] `EveTracker.Prices` wrapper cleanly falls back Janice → Mutamarket → static heuristic
- [ ] HTTP clients respect `Retry-After`, implement exponential back-off and max retry limits
- [ ] Cachex usage for price lookups has correct TTLs (1 h Janice, 6 h Mutamarket)
- [ ] Static SDE import script populates `eve_item_types` and reloads on changes

## Caching & Inverted Indexes

- [ ] ETS tables defined with appropriate types (`:set`, `:bag`), keys, and stored `fetched_at` timestamps
- [ ] GenServer(s) or Cachex cleanup tasks remove expired entries at the configured intervals
- [ ] Profile inverted indexes (`:by_module_tag`, `:by_system_id`) rebuild on profile create/update/delete
- [ ] Presence (online chars) uses Redis via `Phoenix.Presence`, not ETS

## Surveillance Filters & Matching

- [ ] JSON filter schema (recursive condition + rules) matches the spec
- [ ] Filter-tree compilation into anonymous functions is correct and cached in ETS
- [ ] Candidate-profile lookup via inverted indexes reduces evaluation to expected ~150 profiles
- [ ] Matching logic covers all operators (`eq`, `gt`, `in`, `contains_any`, etc.)

## LiveView & UI Components

- [ ] `LiveKillFeed` LiveView uses `temporary_assigns` for `:kills`, with fixed window (e.g. 100 entries)
- [ ] Throttling/debouncing implemented in `handle_info` to batch UI updates every ~100 ms
- [ ] "Load More" pagination fetches via `/api/kill_feed?before_id=…&limit=…` without polluting LiveView state
- [ ] Character switcher and role‐based UI flows correctly update session context and LiveViews

## ESI & SSE Failover

- [ ] ESI client modules handle token refresh, 401/403 retries, and redirect to login on permanent failure
- [ ] SSE producer can swap URLs (wanderer-kills → zKillboard) via `Broadway.configure_producer/2`
- [ ] Dead-letter or retry queue for failed enrichment re-queues killmails after an hour

## Indexing & Performance

- [ ] Partitioning scripts (monthly/weekly) created and tested locally
- [ ] Indexes on `(timestamp DESC)`, `(system_id, timestamp)`, `GIN(module_tags)`, trigram on names, etc., exist on parents
- [ ] Telemetry metrics added for ingestion throughput, enrichment failures, filter evaluations, cache hits/misses

## Testing & Quality

**Unit tests cover:**
- [ ] Tag extraction logic
- [ ] ISK/mass-balance/usefulness calculations
- [ ] Price lookup fallbacks
- [ ] Filter-tree compilation & matching

**Integration tests for:**
- [ ] Broadway pipeline message flow
- [ ] ESI and Janice/MutaMarket client mocking
- [ ] LiveView components (using `Phoenix.LiveViewTest`)

**CI Quality:**
- [ ] CI runs `mix format --check`, `mix credo`, `mix dialyzer`, `mix test --cover`
- [ ] Edge cases (token expiry, corp transfer mid-session, stale enrichment) simulated

## Documentation

- [ ] README updated with:
  - Architecture overview
  - Partition management instructions
  - Cache eviction details
  - How to import static SDE and schedule nightly sync
- [ ] API docs in `/priv/swagger` or similar reflect all endpoints and contracts
- [ ] Module `@docs` and function specs (`@spec`) present on all public functions

## Security & Configuration

- [ ] Sensitive URLs (EVE SSO, Janice, Mutamarket) pulled from environment/config—no hard-coded secrets
- [ ] HTTPS enforced, CSP headers in Phoenix endpoint
- [ ] Rate-limit middleware applied to inbound API routes as needed
- [ ] Session cookies marked `secure`, `http_only`, and encrypted

## Deployment & CI/CD

- [ ] Dockerfile builds a slim prod image: assets precompiled, `MIX_ENV=prod`
- [ ] Kubernetes manifests or Docker Compose updated with:
  - ETS/Cachex cleanup jobs (as separate cronjob or sidecar)
  - Partition-creation cronjob
- [ ] GitHub Actions workflow covers build → test → lint → dialyzer → push image → deploy to staging

