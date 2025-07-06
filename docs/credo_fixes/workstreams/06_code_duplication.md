# Workstream 6: Code Duplication Removal

## Overview
- **Total Errors**: 15+ errors (1.6% of all errors)
- **Complexity**: HIGH - Requires design decisions
- **Impact**: Better maintainability, DRY principle, 1.6% error reduction
- **Time Estimate**: 4-6 hours

## Duplicate Code Instances

### 1. Time Formatting Functions (6 instances)
```elixir
# Duplicated in multiple LiveView modules
defp format_datetime(%DateTime{} = datetime) do
  Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
end

defp format_relative_time(datetime) do
  diff = DateTime.diff(DateTime.utc_now(), datetime)
  cond do
    diff < 60 -> "#{diff}s ago"
    diff < 3600 -> "#{div(diff, 60)}m ago"
    diff < 86400 -> "#{div(diff, 3600)}h ago"
    true -> "#{div(diff, 86400)}d ago"
  end
end
```

**Found in:**
- `lib/eve_dmv_web/live/kill_feed_live.ex`
- `lib/eve_dmv_web/live/surveillance_live.ex`
- `lib/eve_dmv_web/live/player_profile_live.ex`
- `lib/eve_dmv_web/live/corporation_live.ex`
- `lib/eve_dmv_web/live/alliance_live.ex`
- `lib/eve_dmv_web/live/intelligence_dashboard_live.ex`

### 2. Metrics Calculation Pattern (3 instances)
```elixir
# Duplicated analyzer pattern
defp calculate_current_metrics(state) do
  total_count = state.metrics.total_analyses
  
  if total_count > 0 do
    %{
      total: total_count,
      cache_hit_rate: state.metrics.cache_hits / total_count,
      average_time_ms: state.metrics.average_analysis_time_ms,
      # ... similar calculations
    }
  else
    %{total: 0, cache_hit_rate: 0.0, average_time_ms: 0}
  end
end
```

**Found in:**
- `lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex`
- `lib/eve_dmv/contexts/corporation_analysis/domain/corporation_analyzer.ex`
- `lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex`

### 3. Error Response Formatting (4 instances)
```elixir
# Duplicated error handling
defp format_error_response(error) do
  case error do
    {:error, %Ecto.Changeset{} = changeset} ->
      {:error, format_changeset_errors(changeset)}
    {:error, reason} when is_binary(reason) ->
      {:error, reason}
    {:error, reason} ->
      {:error, inspect(reason)}
    _ ->
      {:error, "An unexpected error occurred"}
  end
end
```

### 4. Pagination Logic (2 instances)
```elixir
# Duplicated pagination calculation
defp calculate_pagination(total_items, page, per_page) do
  total_pages = ceil(total_items / per_page)
  
  %{
    page: page,
    per_page: per_page,
    total_items: total_items,
    total_pages: total_pages,
    has_previous: page > 1,
    has_next: page < total_pages
  }
end
```

## Refactoring Strategy

### Step 1: Create Shared Modules

#### A. Time Formatting Helpers
```elixir
# Create: lib/eve_dmv_web/helpers/time_formatter.ex
defmodule EveDmvWeb.Helpers.TimeFormatter do
  @moduledoc """
  Shared time formatting functions for LiveView modules.
  """
  
  def format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
  
  def format_datetime(nil), do: "N/A"
  
  def format_relative_time(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime)
    
    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86400)}d ago"
    end
  end
  
  def format_relative_time(nil), do: "N/A"
  
  # Add other time-related helpers
  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)
    
    "#{hours}h #{minutes}m #{seconds}s"
  end
end
```

#### B. Metrics Calculator
```elixir
# Create: lib/eve_dmv/shared/metrics_calculator.ex
defmodule EveDmv.Shared.MetricsCalculator do
  @moduledoc """
  Shared metrics calculation logic for analyzer modules.
  """
  
  def calculate_current_metrics(%{metrics: metrics} = state) do
    total_count = Map.get(metrics, :total_analyses, 0)
    
    if total_count > 0 do
      %{
        total: total_count,
        cache_hit_rate: calculate_rate(metrics.cache_hits, total_count),
        cache_miss_rate: calculate_rate(metrics.cache_misses, total_count),
        average_time_ms: Map.get(metrics, :average_analysis_time_ms, 0),
        last_updated: DateTime.utc_now()
      }
    else
      default_metrics()
    end
  end
  
  defp calculate_rate(numerator, denominator) when denominator > 0 do
    Float.round(numerator / denominator * 100, 2)
  end
  defp calculate_rate(_, _), do: 0.0
  
  defp default_metrics do
    %{
      total: 0,
      cache_hit_rate: 0.0,
      cache_miss_rate: 0.0,
      average_time_ms: 0,
      last_updated: DateTime.utc_now()
    }
  end
end
```

#### C. Error Formatter
```elixir
# Create: lib/eve_dmv/shared/error_formatter.ex
defmodule EveDmv.Shared.ErrorFormatter do
  @moduledoc """
  Consistent error response formatting across the application.
  """
  
  def format_error({:error, %Ecto.Changeset{} = changeset}) do
    {:error, format_changeset_errors(changeset)}
  end
  
  def format_error({:error, reason}) when is_binary(reason) do
    {:error, reason}
  end
  
  def format_error({:error, %{message: message}}) do
    {:error, message}
  end
  
  def format_error({:error, reason}) do
    {:error, inspect(reason)}
  end
  
  def format_error(_) do
    {:error, "An unexpected error occurred"}
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
```

### Step 2: Update Files to Use Shared Modules

#### LiveView Updates
```elixir
# In each LiveView file, replace local functions with:
alias EveDmvWeb.Helpers.TimeFormatter

# Then use:
TimeFormatter.format_datetime(datetime)
TimeFormatter.format_relative_time(datetime)

# Remove the duplicate local functions
```

#### Analyzer Updates
```elixir
# In analyzer modules:
alias EveDmv.Shared.MetricsCalculator

# Replace local implementation with:
defp calculate_current_metrics(state) do
  MetricsCalculator.calculate_current_metrics(state)
end
```

### Step 3: Create Tests for Shared Modules

```elixir
# test/eve_dmv_web/helpers/time_formatter_test.exs
defmodule EveDmvWeb.Helpers.TimeFormatterTest do
  use ExUnit.Case
  alias EveDmvWeb.Helpers.TimeFormatter
  
  describe "format_datetime/1" do
    test "formats datetime correctly" do
      dt = ~U[2024-01-15 14:30:00Z]
      assert TimeFormatter.format_datetime(dt) == "2024-01-15 14:30:00 UTC"
    end
    
    test "handles nil" do
      assert TimeFormatter.format_datetime(nil) == "N/A"
    end
  end
  
  describe "format_relative_time/1" do
    test "formats seconds ago" do
      now = DateTime.utc_now()
      past = DateTime.add(now, -30, :second)
      assert TimeFormatter.format_relative_time(past) =~ "30s ago"
    end
    
    # More test cases...
  end
end
```

## Migration Plan

### Phase 1: Create Shared Modules (1 hour)
1. Create directory structure: `lib/eve_dmv/shared/` and `lib/eve_dmv_web/helpers/`
2. Implement shared modules with comprehensive functionality
3. Add documentation and typespecs

### Phase 2: Update Existing Code (2-3 hours)
1. Start with LiveView modules (highest duplication)
2. Update analyzers to use MetricsCalculator
3. Update error handling to use ErrorFormatter
4. Remove all duplicate implementations

### Phase 3: Testing (1-2 hours)
1. Create comprehensive tests for shared modules
2. Run existing tests to ensure no regression
3. Add integration tests if needed

## Additional Duplication Patterns to Consider

### Pattern 1: LiveView Assign Helpers
```elixir
# Consider creating LiveView helpers for common patterns
defmodule EveDmvWeb.LiveHelpers do
  def assign_loading(socket, loading \\ true) do
    Phoenix.Component.assign(socket, :loading, loading)
  end
  
  def assign_error(socket, error) do
    socket
    |> Phoenix.Component.assign(:error, error)
    |> Phoenix.Component.assign(:loading, false)
  end
end
```

### Pattern 2: Query Builders
```elixir
# If query patterns are duplicated
defmodule EveDmv.Shared.QueryHelpers do
  import Ecto.Query
  
  def by_date_range(query, start_date, end_date) do
    query
    |> maybe_filter_start_date(start_date)
    |> maybe_filter_end_date(end_date)
  end
  
  defp maybe_filter_start_date(query, nil), do: query
  defp maybe_filter_start_date(query, date) do
    where(query, [r], r.timestamp >= ^date)
  end
end
```

## Expected Results

### Before
```
┃ [D] ↑ Duplicate code found in kill_feed_live.ex:125, surveillance_live.ex:98
┃       (mass: 42)
Total: 15+ code duplication warnings
```

### After
```
Code duplication warnings: 0
Remaining total errors: ~915 (from 930)
Shared modules improve maintainability
Single source of truth for common functionality
```

## Success Criteria
1. Zero code duplication warnings from Credo
2. All duplicate functions replaced with shared implementations
3. Comprehensive tests for shared modules
4. No functional regression
5. Improved maintainability

## Long-term Benefits
1. **Easier Updates** - Change time format in one place
2. **Consistency** - All modules use same implementation
3. **Testing** - Test shared logic once
4. **Performance** - Potential for optimization in one place
5. **Documentation** - Central place for docs

This workstream eliminates code duplication and establishes shared utilities for common patterns.