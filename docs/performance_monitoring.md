# Performance Monitoring System

## Overview

EVE DMV now includes a comprehensive performance monitoring system that tracks query performance, identifies bottlenecks, and provides real-time visibility into system health.

## Components

### 1. Performance Tracker (`EveDmv.Monitoring.PerformanceTracker`)
- GenServer that collects and stores performance metrics
- Tracks database queries, API calls, and LiveView operations
- Maintains metrics in ETS for fast access
- Automatic cleanup of old metrics (24-hour retention)

### 2. Performance Dashboard (`/admin/performance`)
- Real-time dashboard showing:
  - Query performance statistics (min/max/avg/percentiles)
  - Slow query detection
  - Performance degradation alerts
  - High-frequency operation analysis
  - Time-based filtering (minute/hour/day)

### 3. Telemetry Integration
- Automatic tracking via Phoenix telemetry
- Captures Ecto query performance
- Tracks LiveView mount/event handling times
- Monitors HTTP endpoint response times

### 4. Query Optimization

#### Character Analysis
- Created `EveDmv.Database.CharacterQueries` with optimized queries
- Avoids expensive JSONB array operations
- Uses proper indexes for fast lookups
- Limits result sets to prevent memory issues

#### Corporation Analysis  
- Created `EveDmv.Database.CorporationQueries` with optimized queries
- Prevents N+1 query problems
- Efficient aggregation queries
- Proper use of CTEs for complex operations

### 5. Database Indexes
Run `mix eve.db_indexes --create` to create performance indexes:
- Character lookups: `idx_killmails_victim_character`
- Corporation lookups: `idx_killmails_victim_corp`
- Alliance lookups: `idx_killmails_victim_alliance`
- Time-based queries: `idx_killmails_killmail_time`
- Composite indexes for common query patterns
- GIN index for JSONB attacker searches

## Usage

### Tracking Custom Queries

```elixir
import EveDmv.Database.QueryPerformance

# Track a database query
track_query "my_complex_query" do
  Repo.query(sql, params)
end

# Track with metadata
tracked_query("character_lookup", 
  fn -> fetch_character_data(id) end,
  metadata: %{character_id: id}
)
```

### Analyzing Performance

1. Visit `/admin/performance` to see real-time metrics
2. Use `mix eve.db_indexes --analyze` to check query performance
3. Check application logs for threshold warnings

### Performance Thresholds

Default thresholds that trigger warnings:
- Database queries: 1000ms
- API calls: 2000ms  
- LiveView operations: 500ms

## Best Practices

1. **Use optimized query modules** - Use `CharacterQueries` and `CorporationQueries` instead of raw SQL
2. **Add appropriate indexes** - Run the index creation task after adding new query patterns
3. **Monitor the dashboard** - Check regularly for performance degradation
4. **Track custom operations** - Add tracking to expensive operations
5. **Set reasonable limits** - Always limit result sets to prevent memory issues

## Troubleshooting

### High Query Times
1. Check if proper indexes exist
2. Look for N+1 query patterns
3. Consider query result caching
4. Add pagination for large result sets

### Performance Degradation
1. Check the performance dashboard for patterns
2. Look for high-frequency operations consuming resources
3. Review recent code changes
4. Check database table statistics (VACUUM/ANALYZE)

## Future Improvements

- [ ] Add alerting for performance threshold breaches
- [ ] Implement query result caching strategies
- [ ] Add more granular tracking for specific operations
- [ ] Create performance regression tests
- [ ] Add export functionality for metrics