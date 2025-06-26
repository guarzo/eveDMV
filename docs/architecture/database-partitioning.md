# Database Partitioning Strategy

## 1. Declarative Range Partitioning by Timestamp

We'll use built-in PostgreSQL range partitioning on the `timestamp` column of `killmails_raw` (and mirror it in `killmails_enriched`). Each month (or week) becomes its own child table, so scans and index bloat stay bounded.

```sql
-- Parent table
CREATE TABLE killmails_raw (
  killmail_id   BIGINT        PRIMARY KEY,
  timestamp     TIMESTAMPTZ   NOT NULL,
  system_id     BIGINT        NOT NULL,
  ship_type_id  BIGINT        NOT NULL,
  raw_payload   JSONB         NOT NULL,
  inserted_at   TIMESTAMPTZ   DEFAULT now()
) PARTITION BY RANGE (timestamp);

-- Monthly partitions (e.g. June 2025)
CREATE TABLE killmails_raw_2025_06 PARTITION OF killmails_raw
  FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');

-- And similarly for killmails_enriched, referencing the same partitions:
CREATE TABLE killmails_enriched (
  killmail_id      BIGINT        PRIMARY KEY REFERENCES killmails_raw(killmail_id),
  isk_value        NUMERIC       NOT NULL,
  module_tags      TEXT[]        NOT NULL,
  enrichment_blob  JSONB         NOT NULL,
  enriched_at      TIMESTAMPTZ   DEFAULT now()
) PARTITION BY RANGE (enriched_at);

CREATE TABLE killmails_enriched_2025_06 PARTITION OF killmails_enriched
  FOR VALUES FROM ('2025-06-01') TO ('2025-07-01');
```

## 2. Automated Partition Management

- Scripted creation of upcoming partitions via a scheduled job (e.g. a small Elixir task or cron) that runs at month-end to create next month's partition
- Retention policy: Drop or archive partitions older than our retention window (e.g. 12 months)

**Example Elixir pseudo-code (using postgrex):**

```elixir
# at the end of every month…
Repo.query!("
  CREATE TABLE IF NOT EXISTS killmails_raw_#{year}_#{month:02d}
    PARTITION OF killmails_raw
    FOR VALUES FROM ('#{year}-#{month}-01') TO ('#{next_year}-#{next_month}-01');
")
```

## 3. Co-Partitioning Enriched Data

By aligning ranges of `killmails_enriched` with `killmails_raw`, we ensure that any time-range query only touches the matching child tables in both raw and enriched sets.

### Why This Works

- **Writes** go directly to the current partition—no global locking
- **Queries** for recent data hit only the latest 1–2 partitions
- **Index size** on each child remains small, ensuring sub-200 ms lookups
- **Drop/archive** old partitions in bulk instead of row-by-row deletes

## 4. Index Strategy

### 4.1 killmails_raw (RANGE-partitioned by timestamp)

```sql
-- Primary key (already in place)
ALTER TABLE killmails_raw
  ADD PRIMARY KEY (killmail_id);

-- Fast "latest kills" queries:
CREATE INDEX ON killmails_raw (timestamp DESC);

-- Filter by system + time (e.g. "show me Jita kills in last hour"):
CREATE INDEX ON killmails_raw (system_id, timestamp DESC);

-- Filter by ship type + time (e.g. "show me carriers killed today"):
CREATE INDEX ON killmails_raw (ship_type_id, timestamp DESC);

-- If you need to join to participants frequently:
CREATE INDEX ON killmails_raw (killmail_id);
```

> **Note:** Defining these on the parent table auto-creates them on every child partition.

### 4.2 killmails_enriched (co-partitioned by enriched_at)

```sql
-- PK / FK back to raw:
ALTER TABLE killmails_enriched
  ADD PRIMARY KEY (killmail_id);

-- Fast lookups by enrichment timestamp:
CREATE INDEX ON killmails_enriched (enriched_at DESC);

-- Range filters on ISK (e.g. "kills > 100 M"):
CREATE INDEX ON killmails_enriched (isk_value);

-- Module-tag filtering: GIN index on the text array
CREATE INDEX ON killmails_enriched USING GIN (module_tags);

-- If you ever search inside the JSON blob:
CREATE INDEX ON killmails_enriched USING GIN (enrichment_blob jsonb_path_ops);
```

### 4.3 killmail_participants

```sql
-- Composite PK covers most joins:
ALTER TABLE killmail_participants
  ADD PRIMARY KEY (killmail_id, character_id);

-- Quickly find all kills by a character:
CREATE INDEX ON killmail_participants (character_id, killmail_id DESC);

-- Same for corps / alliances:
CREATE INDEX ON killmail_participants (corporation_id, killmail_id DESC);
CREATE INDEX ON killmail_participants (alliance_id, killmail_id DESC);
```

### 4.4 Lookup Tables & Search (Characters/Corps/Alliances/Systems)

```sql
-- PKs on eve_id already exist. For name-based autosuggest use trigram:
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX ON characters USING GIN (name gin_trgm_ops);
CREATE INDEX ON corporations USING GIN (name gin_trgm_ops);
CREATE INDEX ON alliances USING GIN (name gin_trgm_ops);
CREATE INDEX ON systems USING GIN (name gin_trgm_ops);

-- If you need fast filter by corp/alliance on char page:
CREATE INDEX ON characters (corporation_id);
CREATE INDEX ON characters (alliance_id);
```

### 4.5 User ↔ Character Link

```sql
-- Join table lookups:
CREATE INDEX ON users_characters (user_id);
CREATE INDEX ON users_characters (character_id);
```

### 4.6 Surveillance Profiles & Filters

```sql
-- Profiles owned by a user:
CREATE INDEX ON surveillance_profiles (user_id);

-- Quickly fetch all filters for a profile:
CREATE INDEX ON surveillance_filters (profile_id, order_index);

-- If you need to evaluate by filter_type:
CREATE INDEX ON surveillance_filters (filter_type);

-- JSONB indexing for complex value objects (e.g. arrays of IDs):
CREATE INDEX ON surveillance_filters USING GIN (value);
```

## 5. Why This Strategy Works

- **Time-range queries** (latest X, X within last hour) hit the small, recent partitions with `timestamp DESC`
- **Composite indexes** on `(system_id, timestamp)` and `(character_id, killmail_id)` cover your most-common filter patterns
- **GIN indexes** on `module_tags` and JSON fields let you do arbitrary array or JSON searches (e.g. `"module_tags @> ['T2 Guns']"`)
- **Trigram indexes** on names power sub-300 ms autosuggest across large lookup tables
- **Parent-level definitions** ensure partitions stay in sync without manual repetition

With these in place—and assuming your typical "live feed" and drill-down queries are well parameterized—you'll consistently hit sub-200 ms even at high volumes.

