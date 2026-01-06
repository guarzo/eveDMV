# Test Coverage Audit

**Deliverable:** `docs/review/05_test_coverage_audit.md`
**Date:** 2026-01-06
**Phase:** Review Phase 4 - Quality Infrastructure

---

## Executive Summary

The EVE DMV codebase has **significant test coverage gaps**, with only **15% of context source files having corresponding test files** (51 tests / 330 sources). All 15 API modules have test files, which is positive, but domain services, analyzers, and infrastructure modules are severely undertested.

---

## 1. Coverage Overview

### 1.1 Overall Statistics

| Metric | Value |
|--------|-------|
| Total context source files | 330 |
| Total context test files | 51 |
| Test-to-source ratio | 15% |
| Source files without tests | 297 |
| API modules with tests | 15/15 (100%) |

### 1.2 Coverage by Context

| Context | Tests | Sources | Coverage | Priority |
|---------|-------|---------|----------|----------|
| threat_assessment | 4 | 6 | 67% | Low |
| threat_surveillance | 5 | 8 | 62% | Low |
| system_analysis | 3 | 6 | 50% | Medium |
| market_intelligence | 2 | 6 | 33% | Medium |
| battle_analysis | 13 | 48 | 27% | High |
| killmail_processing | 3 | 12 | 25% | High |
| player_profile | 1 | 6 | 17% | Medium |
| surveillance | 4 | 27 | 15% | Critical |
| character_intelligence | 3 | 28 | 11% | Critical |
| corporation_intelligence | 2 | 23 | 9% | Critical |
| corporation | 2 | 23 | 9% | Critical |
| combat_intelligence | 4 | 45 | 9% | Critical |
| fleet_operations | 2 | 31 | 6% | Critical |
| intelligence_infrastructure | 1 | 16 | 6% | High |
| intelligence | 1 | 21 | 5% | Critical |
| combat | 1 | 19 | 5% | High |
| battle_sharing | 0 | 5 | 0% | High |

---

## 2. Critical Gaps - Priority 1 (Context APIs)

All API modules have test files. This is good practice. No critical gaps at the API level.

---

## 3. High Priority Gaps - Domain Services

### 3.1 Finding 5.3.1: battle_sharing Domain (0% coverage)

- **Files Missing Tests:** 5
- **Severity:** High
- **Effort:** Medium (1-4hr per file)
- **Files:**
  - `lib/eve_dmv/contexts/battle_sharing/domain/battle_curator.ex`
  - `lib/eve_dmv/contexts/battle_sharing/domain/community_manager.ex`
  - `lib/eve_dmv/contexts/battle_sharing/domain/tactical_highlight_manager.ex`
  - `lib/eve_dmv/contexts/battle_sharing/domain/video_link_validator.ex`
  - `lib/eve_dmv/contexts/battle_sharing/domain/video_processor.ex`

### 3.2 Finding 5.3.2: combat_intelligence Domain (41 files missing tests)

- **Files Missing Tests:** 41 of 45
- **Severity:** Critical
- **Effort:** Large (>4hr total)
- **Key Missing Tests:**
  - `domain/advanced_fleet_analyzer.ex`
  - `domain/analyzers/battle_phase_analyzer.ex`
  - `domain/analyzers/coordination_analyzer.ex`
  - `domain/analyzers/engagement_analyzer.ex`
  - `domain/analyzers/movement_analyzer.ex`
  - `domain/battle_analysis/battle_analysis_coordinator.ex`
  - `domain/intelligence_scoring.ex`
  - `domain/threat_assessor.ex`

### 3.3 Finding 5.3.3: surveillance Domain (23 files missing tests)

- **Files Missing Tests:** 23 of 27
- **Severity:** Critical
- **Effort:** Large (>4hr total)
- **Key Missing Tests:**
  - `domain/advanced_filter_engine.ex`
  - `domain/alert_system.ex`
  - `domain/chain_activity_tracker.ex`
  - `domain/chain_analysis/*.ex` (5 files)
  - `domain/matching_engine.ex`
  - `domain/notification_service.ex`

### 3.4 Finding 5.3.4: character_intelligence Domain (25 files missing tests)

- **Files Missing Tests:** 25 of 28
- **Severity:** Critical
- **Effort:** Large (>4hr total)
- **Key Missing Tests:**
  - `analyzers/character_intelligence_analyzer.ex`
  - `domain/analyzers/character_analyzer.ex`
  - `domain/analyzers/gang_synergy_analyzer.ex`
  - `domain/generators/comparison_engine.ex`
  - `domain/generators/insight_generator.ex`
  - `domain/threat_scoring_engine.ex`

### 3.5 Finding 5.3.5: fleet_operations Domain (30 files missing tests)

- **Files Missing Tests:** 30 of 31
- **Severity:** Critical
- **Effort:** Large (>4hr total)
- **Key Missing Tests:**
  - `analyzers/composition_analyzer.ex`
  - `analyzers/fleet_acquisition_planner.ex`
  - `analyzers/fleet_readiness_analyzer.ex`
  - `analyzers/fleet_ship_cost_calculator.ex`
  - `domain/doctrine_manager.ex`
  - `domain/fleet_intelligence_service.ex`

---

## 4. Medium Priority Gaps - Infrastructure

### 4.1 Finding 5.4.1: killmail_processing Infrastructure

- **Files Missing Tests:** 9
- **Severity:** Medium
- **Key Files:**
  - `domain/enrichment_service.ex`
  - `domain/historical_service.ex`
  - `domain/ingestion_service.ex`
  - `domain/killmail_orchestrator.ex`
  - `domain/statistics_service.ex`

### 4.2 Finding 5.4.2: market_intelligence Infrastructure

- **Files Missing Tests:** 4
- **Severity:** Medium
- **Key Files:**
  - `domain/market_analyzer.ex`
  - `domain/price_service.ex`
  - `domain/valuation_service.ex`
  - `infrastructure/external_price_client.ex`

---

## 5. Test Quality Assessment

### 5.1 Existing Test Patterns

Based on the test file locations, the codebase follows standard Elixir testing conventions:
- Test files mirror source file structure under `test/`
- Test files use `_test.exs` suffix
- API modules are consistently tested

### 5.2 Recommendations for Test Creation

| Module Type | Test Type | Priority |
|-------------|-----------|----------|
| Domain services | Unit tests with mocks | High |
| Analyzers | Unit tests with fixtures | High |
| Infrastructure | Integration tests | Medium |
| Helpers/Formatters | Unit tests | Low |

---

## 6. Prioritized Test Creation Backlog

### Tier 1 - Critical (Business Logic)

| File | Context | Estimated Effort |
|------|---------|------------------|
| `combat_intelligence/domain/threat_assessor.ex` | combat_intelligence | Medium |
| `combat_intelligence/domain/intelligence_scoring.ex` | combat_intelligence | Medium |
| `surveillance/domain/matching_engine.ex` | surveillance | Large |
| `surveillance/domain/notification_service.ex` | surveillance | Medium |
| `character_intelligence/domain/threat_scoring_engine.ex` | character_intelligence | Medium |
| `fleet_operations/analyzers/composition_analyzer.ex` | fleet_operations | Medium |

### Tier 2 - High (Analyzers)

| File | Context | Estimated Effort |
|------|---------|------------------|
| `battle_analysis/core/battle_detector.ex` | battle_analysis | Large |
| `battle_analysis/core/timeline_builder.ex` | battle_analysis | Medium |
| `combat_intelligence/domain/analyzers/*.ex` (5 files) | combat_intelligence | Large |
| `character_intelligence/domain/analyzers/*.ex` (5 files) | character_intelligence | Large |

### Tier 3 - Medium (Infrastructure)

| File | Context | Estimated Effort |
|------|---------|------------------|
| `killmail_processing/domain/ingestion_service.ex` | killmail_processing | Medium |
| `surveillance/domain/chain_analysis/*.ex` (5 files) | surveillance | Large |
| `market_intelligence/domain/price_service.ex` | market_intelligence | Medium |

---

## 7. Summary Metrics

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Context test coverage | 15% | 70% | 55% |
| API module coverage | 100% | 100% | 0% |
| Domain service coverage | ~10% | 80% | 70% |
| Infrastructure coverage | ~5% | 50% | 45% |
| Files needing tests | 297 | <100 | 197 |

---

## 8. Recommendations

1. **Immediate Priority:** Create tests for threat scoring and matching engine modules - these are critical security-related features
2. **Short-term:** Add tests for all domain analyzers in combat_intelligence and character_intelligence
3. **Medium-term:** Build test fixtures for killmail data to enable consistent testing across contexts
4. **Long-term:** Achieve 70% overall coverage by systematically testing domain services

---

*Generated: 2026-01-06*
