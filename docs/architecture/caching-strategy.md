# Caching Strategy

## 1. ETS Tables

We'll use ETS for low-latency, in-memory lookups of hot data. Each table is `:set` or `:bag` depending on whether keys are unique or can map to many profiles.

| Table Name | Type | Key | Value | TTL / Eviction |
|---|---|---|---|---|
| `:char_corp_cache` | `:set` | `character_id` | `%{corporation_id, alliance_id, fetched_at}` | TTL 10 min; `:timer.send_interval/3`–cleanup |
| `:corp_history_cache` | `:set` | `character_id` | `[%{corp_id, start_date, end_date}, …]` | TTL 1 hr; cleanup periodic |
| `:enrichment_cache` | `:set` | `killmail_id` | `%{enrichment_blob, enriched_at}` | TTL 24 hr; cleanup periodic |
| `:price_cache` | `:bag` | `{:source, region_id, type_id}` | `{price_decimal, fetched_at}` | Janice: TTL 1 hr; Muta: TTL 6 hr |
| `:static_meta` | `:set` | `type_id` | `%{type_name, group_id, …}` | No eviction (reload on update) |
| `:by_module_tag` | `:bag` | `"T2"`, `"Hybrid"`, … | `profile_id` | Manual rebuild on profile change |
| `:by_system_id` | `:bag` | `system_id` | `profile_id` | Manual rebuild on profile change |
| `:compiled_profiles` | `:set` | `profile_id` | `fun(killmail) -> boolean` | Evict/reload on profile change |

**Cleanup:** we run a GenServer every minute to delete expired entries (compare `fetched_at + TTL < now`).

## 2. Redis vs. ETS vs. Database

| Use Case | Storage | Rationale |
|---|---|---|
| Hot lookups (Corp & Alliance by char) | ETS | Sub-100 µs lookups, ephemeral per-node, no cross-node coordination needed |
| Enriched killmail cache | ETS | High-volume, local fan-out; no need to share across nodes |
| Price lookups (Janice / Mutamarket) | Cachex | Built on ETS under the hood, TTLs, and statistics out of the box |
| Inverted indexes for filter matching | ETS | Fast set/flat maps of tag→profiles |
| Presence tracking (online chars) | Redis | Cross-node, used by Phoenix.Presence |
| Session data | Database | Persistent, shared across nodes |
| User preferences & profiles | Database | Durable, transactional |
| Static metadata (item types) | Database | Authoritative source; small table; loaded into ETS on boot |

## 3. Eviction & Invalidation

### 3.1 Time-Based Eviction
For all TTL'd tables (`:char_corp_cache`, `:enrichment_cache`, `:price_cache`), we:

1. Store `{key, value, fetched_at}`
2. Every minute, our `CacheCleaner` GenServer scans tables, removes entries where `fetched_at + TTL < now`

### 3.2 Event-Driven Invalidation

**Profile Changes:** when a user creates/updates/deletes a surveillance profile, we:
1. Recompile the filter tree → new fun in `:compiled_profiles`
2. Rebuild `:by_module_tag` and `:by_system_id` ETS tables from scratch by scanning all active profiles

**Static Data Updates:** when we re-import the SDE into `eve_item_types`, we:
1. Truncate & reload the database table
2. Clear the `:static_meta` ETS table and repopulate from DB on the next lookup

**Deployment / Rolling Upgrade:** at app startup, we flush all ETS tables to ensure fresh state

## 4. Query Routing

- **Character → Corp lookup:** first check `:char_corp_cache`; on miss, hit ESI via our Characters context, then write ETS
- **Kill enrichment:** first check `:enrichment_cache`; on miss or stale, let Broadway re-enqueue, but return stale data immediately if UI requests it
- **Price lookup:** call `EveTracker.Prices.lookup/1`, which consults `:price_cache` (Cachex)
- **Filter matching:** use `:by_module_tag` and `:by_system_id` to get candidates, then `:compiled_profiles` to finalize

## 5. Monitoring & Metrics

- Cache hit/miss counters for each ETS table (via Telemetry)
- Eviction counts per table per minute
- Profile index rebuild duration and frequency

This blend of ETS for speed, Cachex for TTL'd lookups, Redis for cross-node state, and Postgres for durability gives us both the performance and consistency we need at scale