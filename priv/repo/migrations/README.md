# EVE DMV Migration Organization

This directory contains the reorganized migrations for the EVE DMV application, generated fresh from Ash resources with a clean structure.

## Migration Structure

### 1. Core Schema (01_core_schema)
- **Extensions**: PostgreSQL extensions (UUID, etc.)
- **Core Tables**: 
  - users, tokens, api_keys (authentication)
  - killmails_raw, participants (main data)
  - eve_item_types, eve_solar_systems (static data)
  - character_stats (intelligence)

### 2. Surveillance Schema (02_surveillance_schema)
- surveillance_profiles
- surveillance_profile_matches
- surveillance_notifications

### 3. Analytics Schema (03_analytics_schema)
- player_stats
- ship_stats

### 4. Battle Analysis Schema (04_battle_analysis_schema)
- battles
- battle_killmails
- combat_logs
- ship_fittings

### 5. Performance Indexes (05_performance_indexes)
Comprehensive indexing strategy including:
- Killmail query optimization
- Participant analysis indexes
- Intelligence & analytics indexes
- Surveillance system indexes
- Battle analysis indexes
- Authentication indexes
- Static data access indexes

### 6. Advanced Features (06_advanced_features)
- **Table Partitioning**: Monthly partitions for killmails_raw
- **Materialized Views**:
  - character_activity_summary
  - system_activity_heatmap
  - ship_type_usage
- **Helper Functions**:
  - calculate_threat_score()
  - classify_engagement()
- **Automatic Partitioning**: Trigger for creating new monthly partitions

## Benefits of This Organization

1. **Clear Separation**: Each domain has its own migration
2. **Performance Isolation**: Performance features are separate from schema
3. **Maintainability**: Easy to understand what each migration does
4. **Rollback Safety**: Can rollback specific features without affecting core schema
5. **Deployment Flexibility**: Can deploy base schema first, then add optimizations

## Running Migrations

```bash
# Run all migrations
mix ecto.migrate

# Run up to a specific migration
mix ecto.migrate --to 20250719212136

# Rollback last migration
mix ecto.rollback

# Rollback to specific version
mix ecto.rollback --to 20250719212136
```

## Notes

- The partitioned `killmails_raw` table is created alongside the regular table
- Materialized views should be refreshed periodically (see IncrementalViewRefresher)
- All indexes are created with CONCURRENTLY to avoid blocking
- The base_filter on battles table is handled with proper SQL constraints