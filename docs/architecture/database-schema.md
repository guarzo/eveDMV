# Entity Relationship Diagram

## Database Schema Overview

```mermaid
erDiagram
    USERS ||--o{ USERS_CHARACTERS : links
    USERS_CHARACTERS }o--|| CHARACTERS : "has"
    
    SURVEILLANCE_PROFILES ||--o{ SURVEILLANCE_FILTERS : has
    SURVEILLANCE_FILTERS }o--|| SURVEILLANCE_PROFILES : parent

    CHARACTERS }o--|| CORPORATIONS : "member_of"
    CORPORATIONS }o--|| ALLIANCES : "member_of"
    CHARACTERS ||--o{ KILLMAIL_PARTICIPANTS : appears_in
    CORPORATIONS ||--o{ KILLMAIL_PARTICIPANTS : appears_in
    ALLIANCES   ||--o{ KILLMAIL_PARTICIPANTS : appears_in

    SYSTEMS ||--o{ KILLMAILS_RAW : location_of
    KILLMAILS_RAW ||--o{ KILLMAIL_PARTICIPANTS : includes
    KILLMAILS_RAW ||--|| KILLMAILS_ENRICHED : enriched_by

    USERS {
      UUID       id PK
      text       name
      jsonb      preferences    "map settings, notifications, etc."
      timestamptz inserted_at
      timestamptz updated_at
    }

    USERS_CHARACTERS {
      UUID       user_id PK FK
      bigint     character_id PK FK
      timestamptz linked_at
    }

    SURVEILLANCE_PROFILES {
      UUID       id PK
      UUID       user_id FK
      text       name
      int        priority
      jsonb      settings     "volume, duration, hotkeys"
      timestamptz inserted_at
      timestamptz updated_at
    }

    SURVEILLANCE_FILTERS {
      UUID       id PK
      UUID       profile_id FK
      text       filter_type  "character|corp|alliance|system|ship|module_tag|min_isk"
      text       operator     "eq|gt|lt|in|and|or"
      jsonb      value        "e.g. {\"ids\":[123,456]} or 100000000"
      UUID       parent_id    FK
      int        order_index  "chain order"
    }

   CHARACTERS {
      bigint     eve_id PK
      text       name
      bigint     corporation_id FK
      bigint     alliance_id    FK
      jsonb      attributes     "roles, cached stats"
      timestamptz inserted_at
      timestamptz updated_at
    }

    CORPORATIONS {
      bigint     eve_id PK
      text       name
      bigint     alliance_id FK
      timestamptz inserted_at
      timestamptz updated_at
    }

    ALLIANCES {
      bigint     eve_id PK
      text       name
      timestamptz inserted_at
      timestamptz updated_at
    }

    SYSTEMS {
      bigint     eve_id PK
      text       name
      float      security_status
      timestamptz inserted_at
      timestamptz updated_at
    }

    KILLMAILS_RAW {
      bigint     killmail_id PK
      timestamptz timestamp
      bigint     system_id FK
      bigint     ship_type_id   "destroyed ship"
      jsonb      raw_payload
      timestamptz inserted_at
    }

    KILLMAILS_ENRICHED {
      bigint     killmail_id PK FK
      numeric    isk_value
      text       fitting_summary
      jsonb      module_tags      "e.g. [\"T2 Guns\",\"T3 Armor\"]"
      jsonb      enrichment_blob  "full wanderer-kills JSON"
      timestamptz enriched_at
    }

    KILLMAIL_PARTICIPANTS {
      bigint     killmail_id PK FK
      bigint     character_id PK FK
      bigint     corporation_id       FK
      bigint     alliance_id          FK
      bigint     ship_type_id
      int        damage_done
      boolean    final_blow
    }
```

## Entity Descriptions

### Core User Management
- **USERS**: Application users with preferences and settings
- **USERS_CHARACTERS**: Many-to-many link between users and EVE characters
- **CHARACTERS**: EVE Online character data with corp/alliance affiliations

### Organization Hierarchy
- **CORPORATIONS**: EVE corporations with optional alliance membership
- **ALLIANCES**: EVE alliances containing multiple corporations
- **SYSTEMS**: EVE solar systems with security status

### Killmail Data
- **KILLMAILS_RAW**: Raw killmail data from zKillboard/ESI (partitioned by timestamp)
- **KILLMAILS_ENRICHED**: Enhanced killmail data from wanderer-kills service
- **KILLMAIL_PARTICIPANTS**: All characters involved in each killmail

### Surveillance System
- **SURVEILLANCE_PROFILES**: User-defined alert profiles with notification settings
- **SURVEILLANCE_FILTERS**: Chained filters with operators for complex matching logic

## Key Relationships

1. **User → Character Linking**: Users can link multiple EVE characters via `USERS_CHARACTERS`
2. **Killmail Enrichment**: 1:1 relationship between raw and enriched killmail data
3. **Hierarchical Filters**: `SURVEILLANCE_FILTERS` can reference parent filters for chaining
4. **EVE Hierarchy**: Characters belong to corporations, which may belong to alliances
5. **Participation Tracking**: Many-to-many relationship between killmails and characters

## Partitioning Notes

- `KILLMAILS_RAW` and `KILLMAILS_ENRICHED` are range-partitioned by timestamp
- Monthly partitions ensure optimal query performance and manageable index sizes
- See [PartitioningStrategy.md](./PartitioningStrategy.md) for detailed implementation