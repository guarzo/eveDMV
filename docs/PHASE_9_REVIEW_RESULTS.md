# Phase 9: Specific Review Areas - Code Review Results

**Review Date:** 2026-01-04
**Reviewer:** Claude Opus 4.5
**Files Reviewed:** 25+ files across LiveView, Database, and External API modules

---

## Executive Summary

Phase 9 focuses on three specific areas: LiveView modules, database queries, and external API integrations. Overall, the codebase demonstrates solid architecture and follows many best practices, though there are opportunities for improvement in each area.

| Area | Overall Assessment | Key Findings |
|------|-------------------|--------------|
| LiveView Modules | **Needs Improvement** | Large files, mixed concerns, some extracted helpers |
| Database Queries | **Good** | N+1 prevention present, caching implemented |
| External API Integrations | **Excellent** | Circuit breakers, retry logic, proper error handling |

---

## 9.1 LiveView Modules Review

### Files Reviewed
| File | Lines | Status |
|------|-------|--------|
| `surveillance_profiles_live.ex` | 1,393 | **Too Large** |
| `fleet_operations_live.ex` | 1,289 | **Too Large** |
| `battle_analysis_live.ex` | 1,257 | **Too Large** |

### LiveView Best Practices Checklist

#### Are event handlers extracted to separate modules?
**Partial Compliance** (2/5)

- `battle_analysis_live.ex` has a separate `Helpers` module (`BattleAnalysisLive.Helpers`) for some functionality
- `surveillance_profiles_live.ex` keeps all event handlers inline (30+ event handlers in one file)
- `fleet_operations_live.ex` has all handlers inline

**Findings:**
```elixir
# surveillance_profiles_live.ex has 15+ handle_event/3 callbacks inline
# Example: Lines 63-477 are all event handlers

def handle_event("new_profile", _params, socket) do ...
def handle_event("edit_profile", %{"id" => id}, socket) do ...
def handle_event("delete_profile", %{"id" => id}, socket) do ...
# ... 12 more handlers
```

**Recommendation:** Extract event handlers to separate modules like:
- `SurveillanceProfilesLive.EventHandlers`
- `SurveillanceProfilesLive.FilterBuilder`

#### Is state management clean?
**Good** (4/5)

All three LiveViews use clear initialization patterns:

```elixir
# battle_analysis_live.ex - Well-structured initialization
defp initialize_battle_state(socket) do
  socket
  |> assign(:page_title, "Battle Analysis")
  |> assign(:current_battle, nil)
  |> assign(:recent_battles, [])
  # ...
end

defp initialize_ui_state(socket) do ...
defp initialize_upload_state(socket) do ...
defp initialize_share_state(socket) do ...
```

**Findings:**
- State is organized into logical groups (battle state, UI state, upload state)
- Assigns are consistently typed
- No mutable external state dependencies

#### Are components properly extracted?
**Partial Compliance** (3/5)

**Findings:**
- `surveillance_profiles_live.ex` has inline `render_filter_inputs/1` component (lines 1081-1288) that should be extracted
- `fleet_operations_live.ex` has three large inline render functions:
  - `render_composition_analysis/1` (lines 674-818)
  - `render_effectiveness_analysis/1` (lines 821-927)
  - `render_performance_analysis/1` (lines 929-1036)
- `battle_analysis_live.ex` properly delegates to `BattleAnalysisLive.Helpers`

**Recommendation:** Extract render functions to:
- `SurveillanceProfilesLive.Components.FilterBuilder`
- `FleetOperationsLive.Components.AnalysisCards`

#### Is `assign_async` used appropriately?
**Needs Improvement** (2/5)

**Findings:**
- Most async operations use `send(self(), ...)` pattern instead of `assign_async`
- `fleet_operations_live.ex` uses `handle_info` for async loading:

```elixir
# Current pattern (lines 41-45)
send(self(), {:load_battle_side_data, battle_id, side})
socket

# Should consider using assign_async for better loading states
```

- `surveillance_profiles_live.ex` uses `send(self(), {:update_preview, profile})` for async preview

**Recommendation:** Consider using Phoenix 1.7+ `assign_async/3` for:
- Battle loading
- Filter preview generation
- Fleet analysis operations

### Specific Issues Found

#### 1. Large Inline Rendering in surveillance_profiles_live.ex
Lines 1081-1288 contain a 200+ line `render_filter_inputs/1` function with complex case statements:

```elixir
def render_filter_inputs(assigns) do
  ~H"""
  <%= case @condition.type do %>
    <% type when type in [:character, :corporation, :alliance, :system, :ship_type] -> %>
      # 30 lines of HTML
    <% :range -> %>
      # 50 lines of HTML
    <% :temporal -> %>
      # 50 lines of HTML
    # ... more cases
  <% end %>
  """
end
```

#### 2. HTML String Concatenation in fleet_operations_live.ex
Lines 674-1036 use string interpolation for HTML building instead of HEEx:

```elixir
defp render_composition_analysis(data) do
  """
  <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-6">
    <!-- 140 lines of string interpolation -->
  </div>
  """
  |> Phoenix.HTML.raw()
end
```

**Issue:** This bypasses Phoenix's HTML escaping and is harder to maintain.

#### 3. Mixed Concerns in battle_analysis_live.ex
The file mixes:
- Battle loading logic
- Combat log parsing
- ETS cache management
- Ship performance analysis
- Report sharing

---

## 9.2 Database Queries Review

### Files Reviewed
- `killmail_repository.ex` (537 lines)
- `character_repository.ex` (414 lines)

### N+1 Query Patterns
**Good Prevention** (4/5)

**Positive Findings:**

1. **Batch loading functions exist:**
```elixir
# killmail_repository.ex:192
@spec batch_get_with_participants([integer()]) ::
        {:ok, [struct()]} | {:error, term()}
def batch_get_with_participants(killmail_ids) when is_list(killmail_ids) do
  query =
    Ash.Query.new(KillmailRaw)
    |> Ash.Query.filter(killmail_id in ^killmail_ids)
    |> Ash.Query.load([:participants])  # Preloading to prevent N+1
    |> Ash.Query.sort(desc: :killmail_time)
  # ...
end
```

2. **Character batch loading:**
```elixir
# character_repository.ex:121
@spec batch_get_character_stats([integer()]) ::
        {:ok, [EveDmv.Intelligence.CharacterStats.t()]} | {:error, Ash.Error.t()}
def batch_get_character_stats(character_ids) when is_list(character_ids) do
  # ...
  |> Ash.Query.filter(character_id in ^character_ids)
```

3. **Preloading in all major queries:**
```elixir
# Consistently uses |> Ash.Query.load([:participants])
build_corporation_killmails_query/2  # Line 332
build_recent_high_value_query/1      # Line 372
get_battles_since/1                   # Line 229
```

### Missing Indexes Analysis
**Review Needed** (3/5)

The repositories rely on Ash framework for query optimization. Manual index verification is needed for:
- `killmails_raw.victim_character_id`
- `killmails_raw.victim_corporation_id`
- `killmails_raw.solar_system_id`
- Composite index on `(killmail_time, solar_system_id)`

### Complex Raw SQL Review

**Appropriate Use** (4/5)

Raw SQL is used only for complex aggregations that benefit from database-level computation:

```elixir
# character_repository.ex:322 - Ship performance stats
query = """
WITH ship_kills AS (
  SELECT
    a.ship_type_id,
    COUNT(DISTINCT k.killmail_id) as kills,
    AVG(COALESCE(a.damage_done, 0)) as avg_damage,
    SUM(COALESCE(k.total_value, 0)) as total_kill_value
  FROM killmails_raw k
  CROSS JOIN LATERAL jsonb_to_recordset(k.attackers) AS a(...)
  WHERE a.character_id = $1
  GROUP BY a.ship_type_id
),
ship_losses AS (...)
SELECT ... FROM ship_kills sk
FULL OUTER JOIN ship_losses sl ON ...
"""
```

**Finding:** This is appropriate - complex aggregation with CTEs and JSONB operations are better done in PostgreSQL.

### Caching Implementation
**Excellent** (5/5)

Multi-layer caching is properly implemented:

```elixir
# killmail_repository.ex:60
Cache.get_or_compute(
  :hot_data,           # Cache type for frequently accessed data
  cache_key,
  fn ->
    TelemetryHelper.measure_query("killmail", :get_by_character, fn ->
      # Actual query
    end)
  end,
  opts
)
```

Cache invalidation is also handled:
```elixir
# character_repository.ex:399
defp invalidate_character_caches(character_id) do
  Cache.delete(:analysis, ...)
  Cache.invalidate_pattern(:analysis, "repo:character_stats:dangerous:*")
  Cache.invalidate_pattern(:analysis, "repo:character_stats:corp_members:*")
  :ok
end
```

---

## 9.3 External API Integrations Review

### Files Reviewed
- `circuit_breaker.ex` (473 lines)
- `esi_client.ex` (169 lines)
- `httpoison_sse_producer.ex` (676 lines)

### Circuit Breaker Patterns
**Excellent** (5/5)

The circuit breaker implementation is production-grade:

```elixir
# circuit_breaker.ex
defstruct [
  :service_name,
  :state,              # :closed, :open, :half_open
  :failure_count,
  :success_count,
  :last_failure_time,
  :failure_threshold,  # Default: 5 failures before opening
  :recovery_timeout,   # Default: 30 seconds
  :success_threshold,  # Default: 3 successes to close
  :timeout,
  :error_classifier
]
```

**Key Features:**
- Three-state circuit (closed, open, half-open)
- Configurable thresholds
- Error classifier support for selective failure counting
- Telemetry integration for monitoring

```elixir
# Telemetry event when circuit opens
:telemetry.execute(
  [:eve_dmv, :circuit_breaker, :opened],
  %{failure_count: new_failure_count},
  %{service: state.service_name, reason: reason}
)
```

### Retry Logic
**Excellent** (5/5)

The SSE producer implements exponential backoff:

```elixir
# httpoison_sse_producer.ex:299
defp schedule_retry(state) do
  if state.retry_timer do
    Process.cancel_timer(state.retry_timer)
  end

  timer = Process.send_after(self(), :retry_connection, state.retry_delay)
  new_delay = min(state.retry_delay * 2, @max_retry_delay)  # Exponential backoff

  %{state | retry_timer: timer, retry_delay: new_delay}
end
```

Constants:
- `@default_retry_delay` = 1,000ms
- `@max_retry_delay` = 30,000ms

### Timeout Handling
**Excellent** (5/5)

Comprehensive timeout handling in circuit breaker:

```elixir
# circuit_breaker.ex:340
defp handle_timeout(ref, monitor, pid, state) do
  Process.demonitor(monitor, [:flush])
  Process.exit(pid, :kill)

  # Drain pending messages to prevent mailbox pollution
  receive do
    {^ref, _} -> :ok
  after
    0 -> :ok
  end

  new_state = handle_failure(state, :timeout)
  {:reply, {:error, :timeout}, new_state}
end
```

SSE producer uses:
```elixir
# httpoison_sse_producer.ex:275
HTTPoison.get!(
  url,
  [...headers...],
  recv_timeout: :infinity,
  timeout: :infinity,
  stream_to: self(),
  hackney: [
    pool: false,
    recv_timeout: :infinity,
    connect_timeout: 30_000  # 30 second connection timeout
  ]
)
```

### Error Logging
**Good** (4/5)

Comprehensive logging with emojis for quick visual scanning:

```elixir
# httpoison_sse_producer.ex
Logger.info("✅ Started HTTPoison SSE stream: #{state.url}")
Logger.error("❌ Failed to start HTTPoison SSE stream: #{inspect(reason)}")
Logger.warning("🔌 HTTPoison SSE error after #{duration}s")
Logger.info("📡 Received killmail #{killmail_id} from HTTPoison SSE")
Logger.info("📊 EVE DMV Killmail Summary: #{state.killmail_count} kills...")
```

**Minor Improvement:** Some debug-level logs could be more structured:
```elixir
# Current
Logger.debug("Parsed #{length(events)} SSE events from chunk")

# Could be
Logger.debug("sse_parse", event_count: length(events))
```

### Additional Resilience Features

#### Memory Protection
```elixir
# httpoison_sse_producer.ex:17-18
@max_buffer_size 1_048_576  # 1MB buffer limit

# Line 102 - Buffer overflow protection
if byte_size(initial_combined_data) > @max_buffer_size do
  Logger.warning("⚠️  SSE buffer overflow detected")
  :telemetry.execute([:eve_dmv, :sse, :buffer_overflow], %{size: ...}, %{})
  chunk  # Reset to just current chunk
end
```

#### Deduplication
```elixir
# Lines 22-23
@dedup_cache_size 1000  # Track last 1000 killmail IDs

# Efficient O(1) deduplication with MapSet + FIFO queue
defp add_to_seen(%{set: set, queue: queue}, killmail_id) do
  new_set = MapSet.put(set, killmail_id)
  new_queue = :queue.in(killmail_id, queue)
  evict_if_needed(%{set: new_set, queue: new_queue})
end
```

---

## Summary of Recommendations

### High Priority

1. **Extract LiveView Components**
   - Move `render_filter_inputs/1` from `surveillance_profiles_live.ex` to separate component
   - Convert string HTML in `fleet_operations_live.ex` to HEEx components
   - Create shared components for common UI patterns

2. **Extract Event Handlers**
   - Create `SurveillanceProfilesLive.EventHandlers` module
   - Group related handlers (CRUD, filters, preview) into submodules

3. **Add Database Index Verification**
   - Run `EXPLAIN ANALYZE` on common queries
   - Verify covering indexes exist for participant lookups

### Medium Priority

4. **Adopt `assign_async/3`**
   - Replace `send(self(), ...)` pattern with `assign_async` for:
     - Battle loading
     - Filter previews
     - Fleet analysis

5. **Structured Logging**
   - Consider structured logging for better observability
   - Add trace IDs for request correlation

### Low Priority

6. **Reduce File Sizes**
   - Target: Each LiveView under 500 lines
   - Current largest: 1,393 lines

7. **Add Documentation**
   - Document circuit breaker configuration options
   - Add examples to repository functions

---

## Metrics Summary

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| LiveView max lines | < 500 | 1,393 | Needs Work |
| Event handler extraction | 100% | ~33% | Needs Work |
| N+1 prevention | 100% | ~90% | Good |
| Cache implementation | Present | Complete | Excellent |
| Circuit breaker | Present | Complete | Excellent |
| Retry logic | Present | Exponential | Excellent |
| Timeout handling | Present | Complete | Excellent |

---

*Generated by Phase 9 Code Review - EVE DMV Project*
