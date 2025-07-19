# Query Safety Implementation Guide

## Overview

Query safety has been implemented to prevent runaway queries and protect the database from performance issues. This guide documents how to apply query safety to Ash resources.

## Implementation Components

### 1. Query Safety Preparation Module
**File**: `/workspace/lib/eve_dmv/ash/preparations/query_safety.ex`

This module provides the core preparation that can be added to any Ash resource to enforce query limits.

### 2. Configuration Module  
**File**: `/workspace/lib/eve_dmv/ash/query_safety_config.ex`

Centralized configuration for query limits per resource type.

### 3. Query Helpers
**File**: `/workspace/lib/eve_dmv/database/query_helpers.ex`

Low-level query safety utilities that can be used outside of Ash.

## How to Apply Query Safety to a Resource

Add a preparations block to your resource:

```elixir
defmodule EveDmv.YourDomain.YourResource do
  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  # ... other configuration ...

  # Add this block
  preparations do
    prepare EveDmv.Ash.Preparations.QuerySafety, [limit: 1000] do
      on [:read, :your_custom_action]  # Specify which actions to apply to
    end
  end
end
```

## Configuration Options

- `limit`: Maximum number of records to return (default: 1000, max: 10,000)
- `timeout`: Query timeout in milliseconds (default: 30,000, max: 120,000)
- `allow_unlimited`: Allow queries without limits (use with caution)

## Default Limits by Resource Type

| Resource | Default Limit | Notes |
|----------|--------------|-------|
| KillmailRaw | 500 | High-volume table |
| Participant | 1000 | Many records per killmail |
| CharacterStats | 1000 | - |
| Profile | 100 | Lower volume |
| ProfileMatch | 500 | - |
| Battle | 100 | Complex aggregations |
| SolarSystem | 5000 | Static data, rarely changes |
| ItemType | 5000 | Static data, rarely changes |

## Example Implementation

The `KillmailRaw` resource has been updated with query safety:

```elixir
# Preparations for query safety
preparations do
  prepare EveDmv.Ash.Preparations.QuerySafety, [limit: 500] do
    on [:read, :recent_kills, :by_system, :by_victim_character]
  end
end
```

## Resources Requiring Updates

High-priority resources that should have query safety applied:

1. ✅ `EveDmv.Killmails.KillmailRaw` - DONE
2. ⏳ `EveDmv.Killmails.Participant`
3. ⏳ `EveDmv.Intelligence.CharacterStats`
4. ⏳ `EveDmv.Analytics.PlayerStats`
5. ⏳ `EveDmv.Analytics.ShipStats`
6. ⏳ `EveDmv.Surveillance.Profile`
7. ⏳ `EveDmv.Surveillance.ProfileMatch`
8. ⏳ `EveDmv.Contexts.BattleAnalysis.Resources.Battle`
9. ⏳ `EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail`

## Using Query Safety Outside of Ash

For non-Ash queries, use the `QueryHelpers` module:

```elixir
import EveDmv.Database.QueryHelpers

# Apply safety limits
query
|> apply_safe_limit(limit: 500)
|> Repo.all()

# With timeout
{safe_query, opts} = query |> with_safety(limit: 500, timeout: 60_000)
Repo.all(safe_query, opts)

# Streaming large datasets
query
|> stream_query(batch_size: 1000)
|> Stream.each(&process_record/1)
|> Stream.run()
```

## Best Practices

1. **Always apply limits** to read actions that could return large datasets
2. **Use lower limits** for complex queries with joins or aggregations  
3. **Allow unlimited queries sparingly** and only for admin or export functions
4. **Monitor slow queries** to adjust limits as needed
5. **Use streaming** for large data exports instead of increasing limits

## Monitoring

After applying query safety, monitor:
- Query execution times
- Memory usage during queries
- Timeout errors (may need to adjust limits)
- User feedback on pagination needs

## Next Steps

1. Apply query safety to remaining high-priority resources
2. Add query safety to new resources as they're created
3. Monitor and adjust limits based on usage patterns
4. Consider implementing cursor-based pagination for better performance