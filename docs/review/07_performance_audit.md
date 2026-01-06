# Performance Audit

**Deliverable:** `docs/review/07_performance_audit.md`
**Date:** 2026-01-06
**Phase:** Review Phase 4 - Quality Infrastructure

---

## Executive Summary

The EVE DMV codebase has **84 GenServer modules**, of which **47 are properly supervised** and **37 are potentially orphaned**. No obvious N+1 query patterns were detected in the `Enum.map + Ash.load` anti-pattern search. The application has a well-structured supervision tree with database-dependent processes conditionally started.

---

## 1. GenServer Supervision Audit

### 1.1 Overview

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Total GenServer modules | 84 | - | - |
| Supervised GenServers | 47 | 84 | Needs Review |
| Potentially orphaned | 37 | 0 | Investigate |

### 1.2 Supervised GenServers (47 modules)

The following GenServers are properly started in `application.ex`:

| Module | Supervision Type |
|--------|------------------|
| `EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysisService` | Direct |
| `EveDmv.Contexts.CombatIntelligence.Domain.StreamingBattleAnalyzer` | Direct |
| `EveDmv.Contexts.Corporation.Core.CorporationAnalyzer` | Direct |
| `EveDmv.Contexts.KillmailProcessing.Domain.HistoricalFetchWorker` | Conditional |
| `EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient` | Direct |
| `EveDmv.Contexts.Surveillance.Domain.MatchingEngine` | Conditional |
| `EveDmv.Core.Events.EventBus` | Direct |
| `EveDmv.Enrichment.ReEnrichmentWorker` | Conditional |
| `EveDmv.Enrichment.RealTimePriceUpdater` | Conditional |
| `EveDmv.Eve.StaticDataLoader.SdeStartupService` | Conditional |
| `EveDmv.Historical.ImportPipeline` | Conditional |
| `EveDmv.Historical.ImportProgressMonitor` | Conditional |
| `EveDmv.Intelligence.*` (multiple) | Direct/Conditional |
| `EveDmv.Killmails.*` (multiple) | Direct/Conditional |
| `EveDmv.Platform.*` (multiple) | Conditional |
| `EveDmv.Telemetry.QueryMonitor` | Conditional |
| `EveDmv.Users.TokenRefreshService` | Direct |
| ... and 27 more | Various |

### 1.3 Potentially Orphaned GenServers (37 modules)

The following GenServers were not found directly referenced in `application.ex`. They may be started by other supervisors, used as on-demand processes, or truly orphaned:

#### Finding 7.1.1: Context Domain GenServers

- **Severity:** Medium
- **Files:**
  - `EveDmv.Contexts.BattleAnalysis.Core.BattleDetector`
  - `EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.BattleAnalysisCoordinator`
  - `EveDmv.Contexts.CombatIntelligence.Infrastructure.KillmailEventProcessor`
  - `EveDmv.Contexts.CombatIntelligence.Infrastructure.StaticDataEventProcessor`
  - `EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer`
  - `EveDmv.Contexts.KillmailProcessing.Domain.KillmailOrchestrator`
  - `EveDmv.Contexts.MarketIntelligence.Domain.PriceService`
  - `EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer`

**Recommendation:** Review if these are started by context supervisors or should be added to the main supervision tree.

#### Finding 7.1.2: Surveillance GenServers

- **Severity:** High
- **Files:**
  - `EveDmv.Contexts.Surveillance.Domain.AlertService`
  - `EveDmv.Contexts.Surveillance.Domain.NotificationService`
  - `EveDmv.Contexts.Surveillance.Infrastructure.KillmailEventProcessor`
  - `EveDmv.Contexts.Surveillance.Infrastructure.MatchCache`
  - `EveDmv.Contexts.Surveillance.Infrastructure.NotificationDispatcher`
  - `EveDmv.Contexts.Surveillance.Infrastructure.ProfileRepository`
  - `EveDmv.Intelligence.AlertSystem` (maps to `surveillance/domain/alert_system.ex`)

**Recommendation:** Surveillance is a critical feature. Verify these GenServers are properly supervised, possibly through `EveDmv.Contexts.ThreatSurveillance` supervisor.

#### Finding 7.1.3: Threat Assessment/Surveillance GenServers

- **Severity:** High
- **Files:**
  - `EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer`
  - `EveDmv.Contexts.ThreatSurveillance.Domain.AlertManagementService`
  - `EveDmv.Contexts.ThreatSurveillance.Domain.NotificationService`
  - `EveDmv.Contexts.ThreatSurveillance.Domain.SurveillanceMatchingEngine`
  - `EveDmv.Contexts.ThreatSurveillance.Domain.ThreatAssessmentEngine`

**Recommendation:** These may be started by the `EveDmv.Contexts.ThreatSurveillance` supervisor (line 96 in application.ex). Verify supervision chain.

#### Finding 7.1.4: Platform/Monitoring GenServers

- **Severity:** Medium
- **Files:**
  - `EveDmv.Monitoring.AlertDispatcher`
  - `EveDmv.Monitoring.ErrorRecoveryWorker`
  - `EveDmv.Monitoring.ErrorTracker`
  - `EveDmv.Monitoring.MissingDataTracker`
  - `EveDmv.Monitoring.PipelineMonitor`
  - `EveDmv.Intelligence.TelemetryReporter`

**Recommendation:** These may be started by `EveDmv.Monitoring.ErrorRecoverySupervisor` (line 53 in application.ex). Verify supervision chain.

#### Finding 7.1.5: Utility GenServers

- **Severity:** Low
- **Files:**
  - `EveDmv.Eve.CircuitBreaker`
  - `EveDmv.External.Eve.MarketDataService`
  - `EveDmv.IntelligenceEngine.PluginRegistry`
  - `EveDmv.Platform.Cache.MultiLayerCache`
  - `EveDmv.Shutdown.GracefulShutdown`
  - `EveDmv.StaticData.ShipAttributeImporter`
  - `EveDmv.Telemetry.PerformanceReporter`
  - `EveDmv.Workers.AnalysisWorkerPool`
  - `EveDmv.Workers.CacheWarmingWorker`
  - `EveDmv.Intelligence.CacheCleanupWorker`
  - `EveDmv.Intelligence.AnalysisScheduler`

**Recommendation:** Some may be started by nested supervisors. Others (like `GracefulShutdown`) may be intentionally not supervised. Review each for proper lifecycle management.

---

## 2. N+1 Query Detection

### 2.1 Analysis Results

**No N+1 patterns detected** using the `Enum.map.*Ash.load` or `Enum.each.*Ash.load` pattern search.

This is positive, but manual review of query patterns is still recommended for:
- LiveView `handle_event` callbacks that load related data
- API endpoints that return nested resources

### 2.2 Ash.read! Usage

Found **30+ usages** of `Ash.read!` across the codebase. Most appear to be single queries, not N+1 patterns. Key locations:

| File | Count | Notes |
|------|-------|-------|
| `surveillance/domain/chain_intelligence.ex` | 4 | May need review for batch operations |
| `system_analysis/domain/heatmap_generator.ex` | 3 | Sequential queries for different regions |
| `search_suggestion_service.ex` | 5 | Separate queries by entity type |

### 2.3 Recommendation

Review these files for potential optimization:
1. `surveillance/domain/chain_intelligence.ex` - Consider batching related queries
2. `system_analysis/domain/heatmap_generator.ex` - Could potentially combine region queries

---

## 3. Supervision Tree Analysis

### 3.1 Application Startup

The main supervisor uses `strategy: :one_for_one`, which is appropriate for independent processes.

### 3.2 Conditional Startup

Several processes are conditionally started based on environment:

| Condition | Processes Affected |
|-----------|-------------------|
| `environment != :test` | Database workers, monitoring, historical fetch |
| `PIPELINE_ENABLED=true` | KillmailPipeline |
| `MOCK_SSE_SERVER_ENABLED=true` | MockSSEServer |

### 3.3 Nested Supervisors

The application uses nested supervisors for related process groups:

| Supervisor | Purpose |
|------------|---------|
| `EveDmv.Eve.ReliabilitySupervisor` | ESI API reliability (circuit breakers) |
| `EveDmv.Monitoring.ErrorRecoverySupervisor` | Error monitoring and recovery |
| `EveDmv.Infrastructure.EventBusSupervisor` | Domain event infrastructure |
| `EveDmv.Intelligence.Core.Supervisor` | Intelligence analysis tasks |
| `EveDmv.Contexts.ThreatSurveillance` | Threat surveillance processes |

---

## 4. Caching Analysis

### 4.1 Cache Layers

The application has multiple cache layers:

| Cache | Type | Purpose |
|-------|------|---------|
| `EveDmv.Shared.Infrastructure.UnifiedCache` | GenServer | Main unified cache |
| `EveDmv.Eve.EsiCache` | GenServer | ESI API response cache |
| `EveDmv.Platform.Cache.StaticDataCache` | GenServer | Ship/system name cache |
| `EveDmv.Platform.Cache.QueryCache` | GenServer | Database query cache |
| `EveDmv.Platform.Cache.AnalysisCache` | GenServer | Analysis result cache |
| `:battle_fitting_cache` | ETS | Battle fitting data |
| `:static_data_type_cache` | ETS | Static type data |
| `:static_data_system_cache` | ETS | Static system data |

### 4.2 Cache Concerns

#### Finding 7.4.1: Multiple Cache GenServers

- **Severity:** Low
- **Description:** Having multiple cache GenServers may lead to cache coherency issues
- **Recommendation:** Review if caches can be consolidated or if there's a clear invalidation strategy

#### Finding 7.4.2: Potential Duplicate Caches

- **Note:** Comment in `application.ex` line 205: `# EveDmv.Platform.Database.QueryCache, # Removed - duplicate of EveDmv.Platform.Cache.QueryCache`
- **Status:** Already addressed - duplicate was removed

---

## 5. Database Performance

### 5.1 Raw SQL Usage

The codebase uses `Ash.read!` extensively, which is good. Raw SQL (`Ecto.Adapters.SQL.query`) is used sparingly:
- Application startup checks
- Complex aggregation queries
- Materialized view operations

### 5.2 Database Workers

Multiple database-related GenServers handle background tasks:

| Worker | Purpose |
|--------|---------|
| `CacheWarmer` | Pre-warm query caches |
| `CacheInvalidator` | Invalidate stale cache entries |
| `CacheHashManager` | Manage cache hashes |
| `ConnectionPoolMonitor` | Monitor connection pool health |
| `PartitionManager` | Manage table partitions |
| `MaterializedViewRefresher` | Refresh materialized views |
| `MaterializedViewOptimizer` | Optimize view performance |
| `MaterializedViewManager` | Manage view lifecycle |
| `ArchiveManager` | Archive old data |
| `QueryPlanAnalyzer` | Analyze slow queries |

---

## 6. Dialyzer Status

### 6.1 Current State

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Total errors | 342 | 0 | Needs Work |
| Skipped errors | 340 | 0 | Review |
| Unnecessary skips | 0 | 0 | Pass |

### 6.2 Sample Errors

```
lib/eve_dmv_web/live/battle_analysis_live.ex:634:8:no_return
Function format_error_reason/1 has no local return.

lib/eve_dmv_web/live/battle_analysis_live.ex:642:41:guard_fail
The guard test: is_binary(...) can never succeed.
```

### 6.3 Recommendation

Review `.dialyzer_ignore.exs` to determine which errors should be fixed vs. legitimately ignored.

---

## 7. Prioritized Performance Backlog

### Tier 1 - Critical (Supervision)

| Task | Estimated Effort |
|------|------------------|
| Verify surveillance GenServers are supervised | Small |
| Verify threat assessment GenServers are supervised | Small |
| Document supervision tree structure | Medium |

### Tier 2 - High (Query Optimization)

| Task | Estimated Effort |
|------|------------------|
| Review chain_intelligence.ex query patterns | Medium |
| Review heatmap_generator.ex for batching | Small |
| Audit Ash.read! usage for missing preloads | Medium |

### Tier 3 - Medium (Dialyzer)

| Task | Estimated Effort |
|------|------------------|
| Fix no_return errors in battle_analysis_live.ex | Small |
| Review dialyzer ignores for cleanup | Large |

---

## 8. Summary Metrics

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Supervised GenServers | 56% | 100% | 44% |
| N+1 query patterns | 0 | 0 | Pass |
| Dialyzer errors | 342 | 0 | 342 |
| Cache layers | 8 | <5 | Review |

---

## 9. Recommendations

1. **Immediate:** Audit all 37 potentially orphaned GenServers to confirm supervision status
2. **Short-term:** Document the complete supervision tree hierarchy
3. **Medium-term:** Review cache architecture for potential consolidation
4. **Long-term:** Work toward zero dialyzer errors by addressing root causes

---

*Generated: 2026-01-06*
