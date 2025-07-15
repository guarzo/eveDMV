# Sprint 17: Code Quality & Architecture Refactoring

**Duration**: 2 weeks  
**Start Date**: 2025-09-06  
**End Date**: 2025-09-20  
**Sprint Goal**: Address technical debt, implement architectural improvements, and establish sustainable code quality practices  
**Philosophy**: "Clean code is not just about style - it's about maintainability, performance, and team productivity"

---

## 🎯 Sprint Objective

### Primary Goal
Implement the architectural improvements identified in the code quality analysis, eliminate technical debt, and establish robust development practices that will support long-term project growth.

### Success Criteria
- [ ] Zero compilation warnings and Credo violations
- [ ] Supervisor architecture consolidated and simplified
- [ ] Database query performance optimized
- [ ] Test coverage above 85% with property-based testing
- [ ] Observability and monitoring implemented
- [ ] Secret management and security hardened

### Explicitly Out of Scope
- New feature development
- UI/UX improvements
- Business logic changes
- External API integrations (unless for monitoring)

---

## 📊 Sprint Backlog

### **Phase 1: Critical Architecture Fixes (Week 1)**
*Total: 34 points*

| Story ID | Description | Points | Priority | Current Issue | Definition of Done |
|----------|-------------|---------|----------|---------------|-------------------|
| ARCH-1 | Consolidate task supervisor architecture | 8 | CRITICAL | 3 duplicate supervisors (~300 LOC) | Single GenericTaskSupervisor with policy macros |
| ARCH-2 | Replace Process dictionary with ETS-based metadata | 5 | CRITICAL | Hidden mutable state, crash leaks | ETS table scoped to supervisors |
| ARCH-3 | Implement graceful task shutdown mechanisms | 5 | HIGH | brutal_kill drops work silently | Proper timeout handling with fallbacks |
| ARCH-4 | Remove runtime system commands | 3 | HIGH | System.cmd blocks schedulers | Move to CI-only, keep telemetry APIs |
| ARCH-5 | Implement secret detection and scrubbing | 5 | HIGH | Secrets may leak in logs | Logger filters and scrubbers |
| ARCH-6 | Enable warnings-as-errors and strict Credo | 3 | HIGH | Quality drift over time | Fail CI on warnings/violations |
| ARCH-7 | Break cyclic dependencies between contexts | 5 | MEDIUM | Tight coupling between domains | Behavior contracts and boundaries |

### **Phase 2: Performance & Database Optimization (Week 2)**
*Total: 32 points*

| Story ID | Description | Points | Priority | Current Issue | Definition of Done |
|----------|-------------|---------|----------|---------------|-------------------|
| PERF-1 | Optimize N+1 query patterns | 8 | HIGH | 5x materialized view existence checks | Batched queries and ETS caching |
| PERF-2 | Migrate complex raw SQL to Ecto DSL | 8 | MEDIUM | Maintenance risk, injection potential | Composable, validated queries |
| PERF-3 | Implement comprehensive caching strategy | 6 | HIGH | Heavy queries re-run each request | TTL-backed ETS/Redis caching |
| PERF-4 | Add database query monitoring and alerting | 5 | MEDIUM | No query performance visibility | Query metrics and slow query alerts |
| PERF-5 | Implement background pre-aggregation jobs | 5 | LOW | Real-time aggregation performance hit | Oban jobs for metrics |

### **Phase 3: Observability & Testing (Overlap Week 1-2)**
*Total: 29 points*

| Story ID | Description | Points | Priority | Current Issue | Definition of Done |
|----------|-------------|---------|----------|---------------|-------------------|
| OBS-1 | Implement OpenTelemetry spans and tracing | 8 | HIGH | No request tracing, hard to debug latency | Distributed tracing with span context |
| OBS-2 | Add structured logging with JSON format | 3 | MEDIUM | Inconsistent log formats | Standardized, aggregatable logs |
| OBS-3 | Implement Prometheus metrics export | 5 | MEDIUM | No operational metrics | /metrics endpoint with custom metrics |
| TEST-1 | Add property-based testing for killmail pipeline | 5 | HIGH | Only unit tests, malformed JSON risk | StreamData validation tests |
| TEST-2 | Improve test coverage to 85%+ | 5 | MEDIUM | Current coverage unknown | Comprehensive test suite |
| TEST-3 | Add integration tests for critical workflows | 3 | LOW | Limited end-to-end testing | Key user journeys tested |

**Total Sprint Points**: 95 (Reasonable scope for architecture focus)

---

## 📈 Detailed Implementation Plan

### **Week 1: Core Architecture Improvements**

**Day 1-2: Task Supervisor Consolidation (ARCH-1, ARCH-2)**

**New Generic Task Supervisor Implementation:**
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
      
      def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
        # Clean up metadata on process death
        :ets.delete(@metadata_table, pid)
        {:noreply, state}
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

**Day 3: Graceful Shutdown & System Commands (ARCH-3, ARCH-4)**
- Implement proper task timeout handling
- Remove System.cmd calls from runtime code
- Move static analysis to CI only

**Day 4-5: Security & Quality Gates (ARCH-5, ARCH-6, ARCH-7)**
- Implement Logger.filter_parameters for secret scrubbing
- Enable warnings-as-errors in mix.exs
- Analyze and break cyclic dependencies

### **Week 2: Performance & Observability**

**Day 6-7: Database Optimization (PERF-1, PERF-2)**

**N+1 Query Fix Example:**
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

**Day 8: Caching & Background Jobs (PERF-3, PERF-5)**
- Implement TTL-backed caching for expensive queries
- Add Oban jobs for metric pre-aggregation

**Day 9-10: Observability Implementation (OBS-1, OBS-2, OBS-3)**

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

---

## 🔍 Key Refactoring Targets

### Supervisor Architecture Simplification
**Before**: 3 supervisors × ~100 lines = 300 lines of duplicated code
**After**: 1 generic macro + 3 concrete implementations × ~10 lines = 40 lines total
**Benefit**: Consistent behavior, easier maintenance, guaranteed telemetry

### Database Query Optimization
**Before**: 
```elixir
# Multiple separate queries
view1_exists = query("SELECT ... pg_matviews WHERE matviewname = 'view1'")
view2_exists = query("SELECT ... pg_matviews WHERE matviewname = 'view2'")
view3_exists = query("SELECT ... pg_matviews WHERE matviewname = 'view3'")
```

**After**:
```elixir
# Single batched query with caching
view_status = SchemaCache.check_multiple_views(["view1", "view2", "view3"])
```

### Security Enhancement
**Before**:
```elixir
Logger.error("API call failed: #{inspect(reason)}")  # May leak secrets
```

**After**:
```elixir
Logger.error("API call failed", error: scrub_secrets(reason))
```

---

## ✅ Quality Gates & Success Criteria

### Code Quality Metrics
- [ ] **Zero compilation warnings** in any environment
- [ ] **Zero Credo violations** with strict configuration
- [ ] **Dialyzer passes** without issues
- [ ] **Cyclomatic complexity** under 10 for all functions
- [ ] **Test coverage** above 85% with meaningful tests

### Performance Benchmarks
- [ ] **Database queries** - 95th percentile under 100ms
- [ ] **N+1 patterns** eliminated - max 5 queries per request
- [ ] **Memory usage** stable under load
- [ ] **Task execution** - 99% complete within configured timeouts

### Observability Requirements
- [ ] **Distributed tracing** covers all major workflows
- [ ] **Structured logs** enable effective debugging
- [ ] **Metrics export** provides operational visibility
- [ ] **Error tracking** captures and categorizes all failures

---

## 🚨 Risk Management

### High Risk Items
1. **Supervisor Migration** - Risk of breaking existing task execution
   - *Mitigation*: Gradual migration with extensive testing
   
2. **Database Query Changes** - Risk of performance regression
   - *Mitigation*: Benchmark before/after with production data
   
3. **ETS Memory Usage** - Risk of memory leaks in metadata tables
   - *Mitigation*: Proper cleanup on process termination

### Testing Strategy
- **Unit tests** for all new supervisor functionality
- **Integration tests** for database query optimization
- **Load tests** for performance regression detection
- **Property-based tests** for edge case validation

---

## 📊 Success Metrics

### Technical Debt Reduction
- **Lines of duplicated code**: 300 → 40 (87% reduction)
- **Cyclic dependencies**: Current count → 0
- **Code complexity**: Measure before/after with complexity tools

### Performance Improvements
- **Query count per request**: Measure reduction in N+1 patterns
- **Response time**: 95th percentile improvement
- **Memory usage**: Stable usage under load

### Development Velocity
- **Build time**: Faster compilation with fewer warnings
- **Debug time**: Faster issue resolution with better observability
- **Onboarding time**: Cleaner code reduces ramp-up time

---

## 🔧 Implementation Tools & Libraries

### New Dependencies
```elixir
# mix.exs additions
defp deps do
  [
    # Existing deps...
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:stream_data, "~> 0.6", only: [:test, :dev]},
    {:benchee, "~> 1.1", only: [:dev]},
    {:con_cache, "~> 1.0"}  # If choosing ConCache over ETS
  ]
end
```

### Configuration Updates
```elixir
# config/config.exs
config :opentelemetry,
  service_name: "eve_dmv",
  traces_exporter: {:otel_exporter_stdout, []}

config :logger,
  format: {Jason, :encode},
  filter_parameters: ["password", "secret", "token", "key"]

# Enable warnings as errors in dev
config :elixir, :ansi_enabled, true
```

---

## 🚀 Long-term Benefits

### Maintainability
- Consolidated supervisor logic easier to modify and debug
- Standardized patterns reduce cognitive load
- Better separation of concerns between domains

### Performance
- Optimized database access patterns
- Reduced memory footprint from eliminated duplication
- Better resource utilization through proper task management

### Observability
- Comprehensive visibility into system behavior
- Faster problem diagnosis and resolution
- Data-driven optimization opportunities

### Team Productivity
- Faster development with quality gates
- Reduced time spent on debugging
- Easier onboarding for new developers

---

## 📝 Post-Sprint Actions

### Documentation Updates
- [ ] Update architectural decision records
- [ ] Document new supervisor patterns
- [ ] Create observability runbooks

### CI/CD Enhancements
- [ ] Add performance regression detection
- [ ] Implement quality gate enforcement
- [ ] Set up monitoring and alerting

### Knowledge Transfer
- [ ] Team training on new patterns
- [ ] Code review guidelines update
- [ ] Best practices documentation

---

**Remember**: This sprint is an investment in long-term productivity. Every improvement should make the codebase easier to understand, modify, and debug. Focus on sustainable patterns that will benefit the team for months to come.