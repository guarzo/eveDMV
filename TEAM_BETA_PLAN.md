# Team Beta - Database & Performance Implementation Plan

> **AI Assistant Instructions for Database & Performance Team**
> 
> You are Team Beta, responsible for database optimization, migrations, and performance improvements. You **depend on Team Alpha's security fixes** before starting most tasks.

## 🎯 **Your Mission**

Optimize database performance, complete Ash Framework implementation, fix migration issues, and establish high-performance data access patterns.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo --strict
mix dialyzer
mix test --warnings-as-errors
git add -A && git commit -m "descriptive message"
```

### **No Stubs or Placeholders**
- **NEVER** create placeholder implementations
- **NEVER** use TODO comments in production code  
- **NEVER** return hardcoded data - implement real functionality
- If you can't implement something fully, split into smaller tasks

### **Dependencies**
- **WAIT** for Team Alpha security fixes before modifying config files
- **COORDINATE** schema changes 24 hours in advance with all teams
- **YOU MERGE SECOND** every Friday (after Team Alpha)

## 📋 **Phase 1 Tasks (Weeks 1-4) - DATABASE FOUNDATION**

### **Week 1: WAIT FOR TEAM ALPHA** ⏸️
**IMPORTANT**: Do not start until Team Alpha completes security fixes

#### Task 1.1: Clean Up Dead Code While Waiting
**Safe files to clean (no dependencies)**:

Move test files to proper locations:
```bash
mkdir -p test/support/killmails
mkdir -p test/support/intelligence
mv lib/eve_dmv/killmails/pipeline_test.ex test/support/killmails/
mv lib/eve_dmv/killmails/test_data_generator.ex test/support/killmails/
```

Update import paths in existing tests.

### **Week 2: Fix Migration Issues** 🗄️

#### Task 2.1: Fix Inconsistent Down Function
**File**: `priv/repo/migrations_backup/20250701000000_add_performance_indexes.exs`

Remove invalid index drop from down function (lines 42-51):
```elixir
def down do
  # Remove this invalid line:
  # drop index(:solar_systems, [:system_id, :security_status])
  
  # Keep only the valid index drops
  drop index(:killmails_enriched, [:victim_character_id])
  drop index(:killmails_enriched, [:victim_corporation_id])
end
```

#### Task 2.2: Add Migration Comments
**File**: `priv/repo/migrations/20250701041613_add_performance_optimizations.exs`

Add comprehensive comments explaining each index:
```elixir
def up do
  # Optimize character intelligence queries
  create index(:killmails_enriched, [:victim_character_id], 
    comment: "Speeds up character analysis queries in intelligence modules")
  
  # Optimize corporation surveillance queries  
  create index(:killmails_enriched, [:victim_corporation_id],
    comment: "Speeds up corporation member activity analysis")
    
  # Add comments for all other indexes...
end
```

#### Task 2.3: Validate Migration Consistency
Create script to validate all migrations:
```bash
# Create scripts/validate_migrations.sh
mix ecto.rollback --all
mix ecto.migrate
mix ecto.rollback --step 5
mix ecto.migrate
```

### **Week 3: Ash Framework Completion** ⚡

#### Task 3.1: Fix Bulk Operations in Static Data Loader
**File**: `lib/eve_dmv/eve/static_data_loader.ex`

Replace individual creates with proper bulk operations (around line 400+):
```elixir
# OLD (inefficient):
# Enum.each(ships, fn ship ->
#   case Ash.create(ship_changeset, domain: Api) do
#     {:ok, _} -> :ok
#     {:error, _} -> # fallback to individual create
#   end
# end)

# NEW (efficient):
case Ash.bulk_create(ship_changesets, ShipType, :create,
       domain: EveDmv.Api,
       return_records?: false,
       return_errors?: true,
       stop_on_error?: false) do
  %{records: records, errors: []} ->
    Logger.info("Successfully loaded #{length(records)} ships")
  %{errors: errors} when length(errors) > 0 ->
    Logger.error("Failed to load #{length(errors)} ships: #{inspect(errors)}")
end
```

#### Task 3.2: Enable Ash Relationships
**Files**: All resource files with commented relationships

Uncomment and properly configure Ash relationships:
```elixir
# In killmail resources:
belongs_to :victim_character, Character do
  attribute_writable? false
  allow_nil? true
end

has_many :participants, Participant do
  read_action :for_killmail
end
```

Test that relationships load properly and update intelligence analyzers to use them.

#### Task 3.3: Add Database Connection Pool Configuration
**File**: `config/config.exs`

Add comprehensive connection pool settings:
```elixir
config :eve_dmv, EveDmv.Repo,
  pool_size: 20,
  queue_target: 50,
  queue_interval: 1000,
  timeout: 15_000,
  ownership_timeout: 20_000,
  pool_timeout: 5_000
```

Tune settings based on application load patterns.

### **Week 4: Performance Monitoring** 📊

#### Task 4.1: Replace Placeholder Performance Monitor
**File**: `lib/eve_dmv/telemetry/performance_monitor.ex`

Remove placeholder implementation and create real monitoring:
```elixir
def get_performance_summary do
  # Replace static data with real metrics
  %{
    database: get_database_metrics(),
    query_performance: get_slow_queries(),
    connection_pool: get_pool_metrics(),
    cache_hit_rates: get_cache_metrics()
  }
end

defp get_database_metrics do
  # Query actual database performance stats
  query = """
  SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup
  FROM pg_stat_user_tables
  WHERE schemaname = 'public'
  """
  
  case Ecto.Adapters.SQL.query(EveDmv.Repo, query) do
    {:ok, %{rows: rows, columns: columns}} ->
      Enum.map(rows, fn row ->
        Enum.zip(columns, row) |> Map.new()
      end)
    {:error, _} -> []
  end
end
```

#### Task 4.2: Add Query Performance Tracking
Create `lib/eve_dmv/telemetry/query_monitor.ex`:
```elixir
defmodule EveDmv.Telemetry.QueryMonitor do
  @moduledoc """
  Monitors database query performance
  """
  
  def track_query(query_time, query_type, table_name) do
    :telemetry.execute(
      [:eve_dmv, :repo, :query],
      %{duration: query_time},
      %{type: query_type, table: table_name}
    )
    
    if query_time > 1000 do
      Logger.warning("Slow query detected: #{query_type} on #{table_name} took #{query_time}ms")
    end
  end
end
```

**END OF PHASE 1** - Database foundation complete

## 📋 **Phase 2 Tasks (Weeks 5-8) - PERFORMANCE OPTIMIZATION**

### **Week 5: Query Optimization** ⚡

#### Task 5.1: Implement Query Result Caching
Create `lib/eve_dmv/database/query_cache.ex`:
```elixir
defmodule EveDmv.Database.QueryCache do
  @moduledoc """
  Caches expensive query results
  """
  
  use GenServer
  
  @cache_table :query_cache
  @default_ttl 300_000  # 5 minutes
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def get_or_compute(cache_key, compute_fn, ttl \\ @default_ttl) do
    case :ets.lookup(@cache_table, cache_key) do
      [{^cache_key, value, expires_at}] when expires_at > System.monotonic_time(:millisecond) ->
        value
      _ ->
        value = compute_fn.()
        expires_at = System.monotonic_time(:millisecond) + ttl
        :ets.insert(@cache_table, {cache_key, value, expires_at})
        value
    end
  end
end
```

#### Task 5.2: Optimize N+1 Queries in Intelligence Modules
**Files**: Intelligence analyzer modules

Add proper preloading to prevent N+1 queries:
```elixir
# In character analyzer:
def analyze_character(character_id) do
  # Instead of individual queries for each participant
  killmails = 
    KillmailEnriched
    |> Ash.Query.filter(victim_character_id == ^character_id or 
                       participants.character_id == ^character_id)
    |> Ash.Query.load([:participants, :victim_character, :victim_corporation])
    |> Ash.read!(domain: Api)
  
  # Process all data in memory instead of additional queries
end
```

#### Task 5.3: Implement Database Indexes for Intelligence Queries
Create new migration for intelligence-specific indexes:
```elixir
def up do
  # Optimize character intelligence queries
  create index(:participants, [:character_id, :killmail_id])
  create index(:participants, [:corporation_id, :killmail_id])
  
  # Optimize temporal queries
  create index(:killmails_enriched, [:killmail_time, :victim_character_id])
  create index(:killmails_enriched, [:killmail_time, :system_id])
  
  # Optimize ship type queries
  create index(:participants, [:ship_type_id, :character_id])
end
```

### **Week 6: Cache Implementation** 🗃️

#### Task 6.1: Enhance Name Resolver Cache
**File**: `lib/eve_dmv/eve/name_resolver.ex`

Improve caching strategy with TTL and batch loading:
```elixir
def character_names(character_ids) when is_list(character_ids) do
  # Batch load missing names to prevent N+1
  {cached, missing} = split_cached_and_missing(character_ids, :character)
  
  if not Enum.empty?(missing) do
    fresh_names = fetch_character_names_batch(missing)
    cache_names(fresh_names, :character)
    Map.merge(cached, fresh_names)
  else
    cached
  end
end

defp split_cached_and_missing(ids, type) do
  Enum.reduce(ids, {%{}, []}, fn id, {cached, missing} ->
    case get_from_cache(id, type) do
      nil -> {cached, [id | missing]}
      name -> {Map.put(cached, id, name), missing}
    end
  end)
end
```

#### Task 6.2: Implement Intelligent Cache Warming
Create `lib/eve_dmv/database/cache_warmer.ex`:
```elixir
defmodule EveDmv.Database.CacheWarmer do
  @moduledoc """
  Pre-populates caches with frequently accessed data
  """
  
  use GenServer
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_cache_warming()
    {:ok, %{}}
  end
  
  def handle_info(:warm_caches, state) do
    warm_name_caches()
    warm_static_data_caches()
    warm_intelligence_caches()
    
    schedule_cache_warming()
    {:noreply, state}
  end
  
  defp warm_name_caches do
    # Pre-load most frequently accessed character/corporation names
  end
end
```

### **Week 7: Database Performance Tuning** 📈

#### Task 7.1: Implement Connection Pool Monitoring
Add comprehensive connection pool monitoring:
```elixir
defmodule EveDmv.Database.PoolMonitor do
  def get_pool_stats do
    pool_info = DBConnection.get_pool_info(EveDmv.Repo)
    
    %{
      pool_size: pool_info.pool_size,
      checked_out: pool_info.checked_out,
      checked_in: pool_info.checked_in,
      waiting: pool_info.waiting
    }
  end
  
  def check_pool_health do
    stats = get_pool_stats()
    utilization = stats.checked_out / stats.pool_size
    
    if utilization > 0.8 do
      Logger.warning("High database pool utilization: #{round(utilization * 100)}%")
    end
    
    stats
  end
end
```

#### Task 7.2: Optimize Partition Management
**Files**: Partition-related functions

Improve partition creation and maintenance:
```elixir
defmodule EveDmv.Database.PartitionManager do
  def ensure_partitions_exist(table_name, months_ahead \\ 3) do
    current_date = Date.utc_today()
    
    for month_offset <- 0..months_ahead do
      partition_date = Date.add(current_date, month_offset * 30)
      partition_name = "#{table_name}_#{Date.to_string(partition_date, :basic)}"
      
      unless partition_exists?(partition_name) do
        create_partition(table_name, partition_name, partition_date)
      end
    end
  end
  
  defp create_partition(table_name, partition_name, date) do
    start_date = Date.beginning_of_month(date)
    end_date = Date.end_of_month(date)
    
    query = """
    CREATE TABLE #{partition_name} PARTITION OF #{table_name}
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """
    
    Ecto.Adapters.SQL.query!(EveDmv.Repo, query)
  end
end
```

### **Week 8: Advanced Database Features** 🚀

#### Task 8.1: Implement Read Replicas Support
Prepare database configuration for read replicas:
```elixir
# config/config.exs
config :eve_dmv, EveDmv.ReadRepo,
  adapter: Ecto.Adapters.Postgres,
  # ... read replica configuration

# Create read-only repo for analytics queries
defmodule EveDmv.ReadRepo do
  use Ecto.Repo,
    otp_app: :eve_dmv,
    adapter: Ecto.Adapters.Postgres
end
```

#### Task 8.2: Database Health Monitoring
Create comprehensive database health checks:
```elixir
defmodule EveDmv.Database.HealthCheck do
  def run_health_checks do
    %{
      connection: check_connection(),
      partitions: check_partitions(),
      indexes: check_index_usage(),
      vacuum: check_vacuum_stats(),
      replication_lag: check_replication_lag()
    }
  end
  
  defp check_connection do
    case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1") do
      {:ok, _} -> :healthy
      {:error, reason} -> {:error, reason}
    end
  end
end
```

**END OF PHASE 2** - Performance optimization complete

## 📋 **Phase 3 Tasks (Weeks 9-12) - ADVANCED FEATURES**

### **Week 9: Advanced Caching** 🗃️

#### Task 9.1: Implement Distributed Caching
Plan and implement distributed caching strategy if needed.

#### Task 9.2: Cache Invalidation Strategy
Implement smart cache invalidation based on data changes.

### **Week 10: Query Optimization** ⚡

#### Task 10.1: Implement Query Plan Analysis
Create tools for automatic query plan analysis and optimization.

#### Task 10.2: Materialized Views
Implement materialized views for complex intelligence queries.

### **Week 11: Database Scaling** 📈

#### Task 11.1: Database Sharding Preparation
Plan database sharding strategy for future scaling.

#### Task 11.2: Archive Strategy
Implement data archiving for old killmail data.

### **Week 12: Performance Testing** 🧪

#### Task 12.1: Load Testing
Implement comprehensive database load testing.

#### Task 12.2: Performance Benchmarking
Create benchmarks for all database operations.

## 📋 **Phase 4 Tasks (Weeks 13-16) - OPTIMIZATION**

### **Week 13-16: Final Optimization**
- Complete performance tuning
- Optimize all slow queries
- Implement final caching strategies
- Document performance characteristics

## 🚨 **Emergency Procedures**

### **If You Cause a Database Migration Issue**
1. **IMMEDIATELY** stop and assess impact
2. **NOTIFY** all teams if migration affects them
3. **ROLLBACK** the migration if safe to do so
4. **FIX** the issue before proceeding
5. **TEST** thoroughly in development first

### **If You Need to Change Database Schema**
1. **ANNOUNCE** schema changes 24 hours in advance
2. **COORDINATE** with Team Gamma (they use your schemas)
3. **ENSURE** backwards compatibility when possible
4. **UPDATE** all affected queries and tests

### **If Performance Degrades**
1. **IDENTIFY** the cause immediately
2. **REVERT** recent changes if they caused it
3. **OPTIMIZE** the slow queries
4. **MONITOR** to ensure fix is effective

## ✅ **Success Criteria**

By the end of 16 weeks, you must achieve:
- [ ] **All database migrations** working flawlessly
- [ ] **Ash Framework** fully implemented without fallbacks
- [ ] **Database performance** optimized for intelligence workloads
- [ ] **Connection pool** properly configured and monitored
- [ ] **Query performance** under 100ms for 95% of queries
- [ ] **Caching strategy** implemented and effective
- [ ] **Database monitoring** and health checks in place

Remember: **You are the data foundation for the entire project. Team Gamma's intelligence features depend on your database performance and reliability.**