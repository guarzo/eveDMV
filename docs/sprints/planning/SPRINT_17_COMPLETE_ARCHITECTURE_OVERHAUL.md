# Sprint 17-18: Complete Architecture Overhaul

**Duration**: 4 weeks (extended for comprehensive refactoring)  
**Start Date**: TBD  
**End Date**: TBD  
**Sprint Goal**: Execute comprehensive architecture refactoring combining directory restructuring, supervisor consolidation, performance optimization, and quality improvements  
**Philosophy**: "Clean code is not just about style - it's about maintainability, performance, and team productivity"

---

## 🎯 Sprint Objective

### Primary Goal
Execute a complete architecture overhaul that combines directory flattening, supervisor consolidation, performance optimization, and quality improvements in a logical sequence to avoid conflicts and maximize benefits.

### Success Criteria
- [ ] Reduce module count from 350+ to ~200 files (30% reduction)
- [ ] Flatten directory structure from 5+ levels to maximum 2 levels
- [ ] Consolidate supervisor architecture (300 → 40 lines of code)
- [ ] Zero compilation warnings and Credo violations
- [ ] All tests pass with 85%+ coverage
- [ ] Database query performance optimized (N+1 eliminated)
- [ ] Boundary enforcement prevents circular dependencies
- [ ] Observability and monitoring implemented
- [ ] Build time improved by 20%

### Explicitly Out of Scope
- New feature development
- UI/UX improvements (unless needed for testing)
- Business logic changes
- External API integrations (unless for monitoring)
- Database schema changes

---

## 📊 Sprint Backlog

### **Phase 1: Directory Restructuring (Week 1)**
*Foundation work - must be completed before other phases*

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| ARCH-1A | Flatten contexts/*/domain/* → contexts/* | 8 | CRITICAL | All modules moved, git history preserved |
| ARCH-1B | Consolidate analytics + intelligence/analyzers | 5 | CRITICAL | Single analytics directory, no duplication |
| ARCH-1C | Merge config/* modules → shared/config.ex | 3 | HIGH | Unified configuration, all functionality preserved |
| ARCH-1D | Consolidate utils/* → shared/utils.ex | 3 | HIGH | Single utils file, all functions work |
| ARCH-1E | Flatten infrastructure/* → infra/* | 2 | MEDIUM | Shorter paths, preserved functionality |
| ARCH-1F | Update all imports and module references | 5 | CRITICAL | No broken imports, tests pass |

**Week 1 Total**: 26 points

### **Phase 2: Supervisor & Task Management (Week 2)**
*Build on flattened structure*

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| ARCH-2A | Implement GenericTaskSupervisor macro system | 8 | CRITICAL | Single supervisor pattern, 300→40 LOC reduction |
| ARCH-2B | Replace Process dictionary with ETS metadata | 5 | HIGH | ETS table scoped to supervisors, no crashes |
| ARCH-2C | Implement graceful task shutdown mechanisms | 5 | HIGH | Proper timeout handling, no brutal_kill |
| ARCH-2D | Remove runtime system commands | 3 | MEDIUM | Move to CI-only, keep telemetry APIs |
| ARCH-2E | Migrate existing supervisors to new pattern | 5 | HIGH | All supervisors use consistent pattern |

**Week 2 Total**: 26 points

### **Phase 3: Performance & Boundaries (Week 3)**
*Optimize the cleaned structure*

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| PERF-3A | Add boundary enforcement with boundary gem | 5 | HIGH | Zero circular dependencies detected |
| PERF-3B | Optimize N+1 query patterns with ETS caching | 8 | HIGH | Batched queries, 5x performance improvement |
| PERF-3C | Migrate complex raw SQL to Ecto DSL | 6 | MEDIUM | Composable, validated queries |
| PERF-3D | Implement comprehensive caching strategy | 5 | HIGH | TTL-backed ETS/Redis caching |
| PERF-3E | Consolidate database query_* modules → queries.ex | 3 | MEDIUM | Single queries file, all queries work |

**Week 3 Total**: 27 points

### **Phase 4: Quality & Observability (Week 4)**
*Polish and monitoring*

| Story ID | Description | Points | Priority | Definition of Done |
|----------|-------------|---------|----------|-------------------|
| QUAL-4A | Enable warnings-as-errors and strict Credo | 3 | HIGH | Fail CI on warnings/violations |
| QUAL-4B | Implement secret detection and scrubbing | 3 | HIGH | Logger filters and scrubbers |
| QUAL-4C | Add property-based testing for critical paths | 5 | MEDIUM | StreamData validation tests |
| OBS-4D | Implement OpenTelemetry spans and tracing | 6 | HIGH | Distributed tracing with span context |
| OBS-4E | Add structured logging with JSON format | 3 | MEDIUM | Standardized, aggregatable logs |
| OBS-4F | Add database query monitoring and alerting | 3 | LOW | Query metrics and slow query alerts |

**Week 4 Total**: 23 points

**Total Sprint Points**: 102 (Realistic for 4-week architecture sprint)

---

## 📈 Detailed Week-by-Week Plan

### **Week 1: Foundation - Directory Restructuring**
*"Get the structure right first"*

**Day 1-2: Core Directory Flattening (ARCH-1A, ARCH-1B)**
```bash
# Create new simplified structure
mkdir -p lib/eve_dmv/{analytics,intelligence,surveillance}
mkdir -p lib/eve_dmv/{killmails,market,shared}

# Preserve git history with moves
git mv lib/eve_dmv/contexts/character_intelligence/domain/* lib/eve_dmv/intelligence/
git mv lib/eve_dmv/contexts/surveillance/domain/* lib/eve_dmv/surveillance/
git mv lib/eve_dmv/intelligence/analyzers/* lib/eve_dmv/analytics/
```

**Day 3: Configuration Consolidation (ARCH-1C)**
```bash
# Merge all config modules
cat lib/eve_dmv/config/*.ex > lib/eve_dmv/shared/config.ex
rm -rf lib/eve_dmv/config/
```

**Day 4: Utilities & Infrastructure (ARCH-1D, ARCH-1E)**
```bash
# Consolidate utilities
cat lib/eve_dmv/utils/*.ex > lib/eve_dmv/shared/utils.ex
rm -rf lib/eve_dmv/utils/

# Flatten infrastructure
git mv lib/eve_dmv/contexts/*/infrastructure/* lib/eve_dmv/*/infra/
```

**Day 5: Import Updates (ARCH-1F)**
```bash
# Global find/replace for module references
find lib -name "*.ex" -exec sed -i 's/EveDmv.Contexts.CharacterIntelligence/EveDmv.Intelligence/g' {} \;
find lib -name "*.ex" -exec sed -i 's/EveDmv.Config\./EveDmv.Shared.Config./g' {} \;

# Verify no broken imports
mix compile --warnings-as-errors
mix test
```

**Week 1 Success Criteria:**
- [ ] All files successfully moved with git history preserved
- [ ] Directory depth reduced to max 2 levels
- [ ] All tests pass after import updates
- [ ] Application starts without errors

### **Week 2: Supervisor Architecture Revolution**
*"Consolidate the foundation"*

**Day 6-7: Generic Supervisor Implementation (ARCH-2A)**

**New Architecture Pattern:**
```elixir
defmodule EveDmv.Supervisors.GenericTaskSupervisor do
  @moduledoc """
  Behaviour + macro that generates purpose-specific DynamicSupervisors
  with consistent limits, logging and telemetry.
  """
  
  defmacro __using__(opts) do
    max_task_duration = Keyword.fetch!(opts, :max_task_duration)
    warning_duration = Keyword.fetch!(opts, :warning_duration)
    max_children = Keyword.fetch!(opts, :max_children)
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:eve_dmv, :task])
    
    quote bind_quoted: [
      max_task_duration: max_task_duration,
      warning_duration: warning_duration,
      max_children: max_children,
      telemetry_prefix: telemetry_prefix
    ] do
      use DynamicSupervisor
      require Logger
      
      @metadata_table :"#{__MODULE__}_metadata"
      
      def start_link(opts \\ []) do
        # Create ETS table for metadata
        :ets.new(@metadata_table, [:set, :public, :named_table])
        DynamicSupervisor.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def start_task(fun, desc \\ "task", timeout \\ max_task_duration) do
        timeout = min(timeout, max_task_duration)
        
        spec = %{
          id: make_ref(),
          start: {Task, :start_link, [fn -> run_with_monitoring(fun, desc, timeout) end]},
          restart: :temporary,
          type: :worker,
          shutdown: timeout + 1_000  # Graceful shutdown
        }
        
        DynamicSupervisor.start_child(__MODULE__, spec)
      end
      
      defp run_with_monitoring(fun, desc, timeout) do
        pid = self()
        start_time = System.monotonic_time(:millisecond)
        
        # Store metadata in ETS instead of process dictionary
        :ets.insert(@metadata_table, {pid, %{desc: desc, start_time: start_time}})
        
        try do
          result = fun.()
          emit_telemetry(:completed, start_time, desc)
          result
        catch
          kind, reason ->
            emit_telemetry(:failed, start_time, desc, {kind, reason})
            :erlang.raise(kind, reason, __STACKTRACE__)
        after
          :ets.delete(@metadata_table, pid)
        end
      end
      
      defp emit_telemetry(event, start_time, desc, error \\ nil) do
        duration = System.monotonic_time(:millisecond) - start_time
        metadata = %{description: desc}
        measurements = %{duration: duration}
        
        if error do
          metadata = Map.put(metadata, :error, error)
        end
        
        :telemetry.execute(telemetry_prefix ++ [event], measurements, metadata)
      end
    end
  end
end
```

**Day 8: ETS Migration (ARCH-2B)**
- Replace all Process.put/get with ETS operations
- Ensure proper cleanup on process termination

**Day 9: Graceful Shutdown (ARCH-2C)**
- Implement proper task timeout handling
- Add graceful shutdown with fallback to brutal_kill

**Day 10: Supervisor Migration (ARCH-2D, ARCH-2E)**
- Migrate existing supervisors to use new pattern
- Remove System.cmd calls from runtime code

**Week 2 Success Criteria:**
- [ ] Single GenericTaskSupervisor macro replaces 3 duplicate supervisors
- [ ] Code reduction: 300 → 40 lines (87% reduction)
- [ ] ETS metadata storage working correctly
- [ ] All existing functionality preserved

### **Week 3: Performance & Boundary Enforcement**
*"Optimize the clean structure"*

**Day 11-12: Boundary Implementation (PERF-3A)**
```bash
# Add boundary dependency
echo '{:boundary, "~> 0.10", runtime: false}' >> mix.exs
mix deps.get

# Add boundary definitions to major contexts
```

**Day 13-14: Database Optimization (PERF-3B, PERF-3C)**

**N+1 Query Elimination:**
```elixir
defmodule EveDmv.Cache.SchemaCache do
  @cache_table :schema_cache
  
  def start_link(_opts) do
    :ets.new(@cache_table, [:set, :public, :named_table])
    {:ok, self()}
  end
  
  def materialized_view_exists?(view_name) do
    case :ets.lookup(@cache_table, {:matview, view_name}) do
      [{_, exists, expires}] when expires > System.system_time(:second) -> 
        exists
      _ ->
        exists = query_view_existence(view_name)
        expires = System.system_time(:second) + 300  # 5 min TTL
        :ets.insert(@cache_table, {{:matview, view_name}, exists, expires})
        exists
    end
  end
  
  def check_multiple_views(view_names) do
    query = """
    SELECT matviewname, TRUE 
    FROM pg_matviews 
    WHERE schemaname = 'public' 
      AND matviewname = ANY($1)
    """
    
    case Repo.query(query, [view_names]) do
      {:ok, result} -> build_existence_map(result, view_names)
      {:error, _} -> Enum.map(view_names, &{&1, false})
    end
  end
end
```

**Day 15: Caching & Consolidation (PERF-3D, PERF-3E)**
- Implement TTL-backed caching for expensive queries
- Consolidate database query_* modules into single queries.ex

**Week 3 Success Criteria:**
- [ ] Zero circular dependencies (boundary enforced)
- [ ] N+1 query patterns eliminated
- [ ] Database queries consolidated
- [ ] Caching strategy implemented

### **Week 4: Quality Gates & Observability**
*"Polish and monitor"*

**Day 16-17: Quality Gates (QUAL-4A, QUAL-4B)**
```elixir
# mix.exs - Enable warnings as errors
def project do
  [
    # ... existing config
    elixirc_options: [warnings_as_errors: true],
  ]
end

# Logger configuration for secret scrubbing
config :logger,
  format: {Jason, :encode},
  filter_parameters: ["password", "secret", "token", "key", "client_secret"]
```

**Day 18: Property-Based Testing (QUAL-4C)**
```elixir
defmodule EveDmv.KillmailPipelinePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  property "killmail pipeline handles all valid JSON structures" do
    check all killmail_data <- killmail_generator() do
      result = EveDmv.Killmails.Pipeline.process(killmail_data)
      assert {:ok, _} = result
    end
  end
  
  defp killmail_generator do
    gen all killmail_id <- integer(1..999_999_999),
            victim <- character_generator(),
            attackers <- list_of(character_generator(), min_length: 1) do
      %{
        "killmail_id" => killmail_id,
        "victim" => victim,
        "attackers" => attackers
      }
    end
  end
end
```

**Day 19-20: Observability Implementation (OBS-4D, OBS-4E, OBS-4F)**

**OpenTelemetry Integration:**
```elixir
defmodule EveDmv.Telemetry.Tracer do
  def trace_task_execution(description, fun) do
    OpenTelemetry.Tracer.with_span("task.execute", %{
      "task.description" => description,
      "task.supervisor" => self() |> inspect()
    }) do
      start_time = System.monotonic_time()
      
      try do
        result = fun.()
        
        OpenTelemetry.Span.set_attributes([
          {"task.status", "completed"},
          {"task.duration_ms", System.monotonic_time() - start_time |> 
                               System.convert_time_unit(:native, :millisecond)}
        ])
        
        result
      catch
        kind, reason ->
          OpenTelemetry.Span.set_attributes([
            {"task.status", "failed"},
            {"task.error.kind", kind},
            {"task.error.reason", inspect(reason)}
          ])
          
          :erlang.raise(kind, reason, __STACKTRACE__)
      end
    end
  end
end
```

**Week 4 Success Criteria:**
- [ ] All quality gates enforced in CI
- [ ] Secret scrubbing implemented
- [ ] Property-based tests added for critical paths
- [ ] OpenTelemetry tracing active
- [ ] Structured logging implemented

---

## ✅ Sprint Completion Checklist

### Architecture Quality
- [ ] Module count reduced from 350+ to ~200 files (30% reduction)
- [ ] Maximum directory depth is 2 levels
- [ ] Zero circular dependencies (boundary enforced)
- [ ] Supervisor code reduced from 300 to 40 lines
- [ ] All file moves preserve git history

### Code Quality
- [ ] Zero compilation warnings in any environment
- [ ] Zero Credo violations with strict configuration
- [ ] All tests pass (`mix test`)
- [ ] Static analysis passes (`mix credo`)
- [ ] Type checking passes (`mix dialyzer`)
- [ ] Test coverage above 85%

### Performance
- [ ] Build time improved by 20%
- [ ] N+1 query patterns eliminated
- [ ] Database queries consolidated and optimized
- [ ] Memory usage stable or improved
- [ ] No runtime performance regression

### Observability
- [ ] Distributed tracing covers major workflows
- [ ] Structured logs enable effective debugging
- [ ] Query performance monitoring active
- [ ] Secret scrubbing prevents data leaks

---

## 🔍 Manual Validation

### Validation Checklist Creation
- [ ] Create `manual_validate_complete_architecture_sprint.md`
- [ ] Test all major application flows after each week
- [ ] Verify module loading and import resolution
- [ ] Test supervisor task execution
- [ ] Validate caching and performance improvements

### Weekly Validation Points
- **Week 1**: All modules load, tests pass, application starts
- **Week 2**: Task execution works, supervisors function correctly
- **Week 3**: Queries perform well, boundaries prevent cycles
- **Week 4**: Observability captures data, quality gates enforce standards

---

## 📊 Sprint Metrics

### Architecture Metrics
- **Module Count**: 350+ → ~200 (30% reduction)
- **Directory Depth**: 5+ levels → 2 levels max
- **Supervisor Code**: 300 → 40 lines (87% reduction)
- **Circular Dependencies**: Current count → 0

### Performance Metrics
- **Build Time**: Target 20% improvement
- **Query Count**: Measure N+1 elimination
- **Memory Usage**: Monitor ETS table efficiency
- **Response Time**: 95th percentile improvement

### Quality Metrics
- **Test Coverage**: Target 85%+
- **Compilation Warnings**: 0
- **Credo Violations**: 0
- **Property Test Coverage**: Critical paths covered

---

## 🔄 Sprint Retrospective Template

### What Went Well
1. [Architecture simplification benefits]
2. [Performance improvements achieved]
3. [Quality gates effectiveness]

### What Didn't Go Well
1. [Unexpected migration complexity]
2. [Performance regression discovered]
3. [Integration challenges]

### Key Learnings
1. [Architecture pattern insights]
2. [Migration strategy improvements]
3. [Team productivity impact]

### Action Items for Next Sprint
- [ ] Monitor architecture drift prevention
- [ ] Implement automated compliance checks
- [ ] Plan feature development leveraging new structure

---

## 🚀 Long-term Benefits

### Developer Experience
- **Faster navigation**: Shorter paths, intuitive structure
- **Easier debugging**: Consolidated supervisors, better observability
- **Reduced cognitive load**: Fewer duplicate patterns

### System Performance
- **Build time**: 20% faster compilation
- **Query performance**: N+1 patterns eliminated
- **Memory efficiency**: ETS replaces process dictionary

### Maintainability
- **Single source of truth**: Consolidated configurations and utilities
- **Enforced boundaries**: Prevent architecture drift
- **Quality gates**: Automatic enforcement of standards

---

## 🛠 Required Dependencies

```elixir
# mix.exs additions
defp deps do
  [
    # Existing deps...
    {:boundary, "~> 0.10", runtime: false},
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:stream_data, "~> 0.6", only: [:test, :dev]},
    {:benchee, "~> 1.1", only: [:dev]}
  ]
end
```

---

**Remember**: This is a comprehensive architecture overhaul that sets the foundation for faster development and better maintainability. Every change should preserve functionality while dramatically improving code organization, performance, and observability.