# Idiomatic Elixir Patterns Audit

**Generated:** 2026-01-06
**Scope:** Phase 1 - Review Phase 1 (Initial Analysis)

---

## Baseline Metrics

| Metric | Value | Target | Status |
|--------|-------|--------|--------|
| Source Files | 845 | - | - |
| Test Files | 114 | ~280 (1:3 ratio) | Gap: 166 files |
| Ash Resources | 49 | - | - |
| @spec Annotations | 1,669 | 80%+ coverage | Needs audit |
| @impl Annotations | 908 | All callbacks | Good coverage |
| @moduledoc false | 15 | <10 | Minor gap |
| GenServers | 84 | - | - |
| Raw SQL Queries (files) | 13 | <20 | OK |
| Bounded Contexts | 17 | 10-12 | Over target |
| Feature Flags | 9 | 2-3 | Needs cleanup |
| @deprecated | 0 | 0 | OK |
| Disabled/Unused Files | 0 | 0 | OK |
| Files >500 Lines | 186 | <50 | Critical gap |

---

## 1.1 Callback Implementation Annotations (@impl)

### Summary

The codebase has **good @impl annotation coverage**. Analysis found 908 `@impl` annotations across 84 GenServer modules. The codebase uses the `@impl ModuleName` format (e.g., `@impl GenServer`) rather than `@impl true`.

### Modules with Low @impl Coverage

Only 2 modules were identified with potentially incomplete @impl coverage:

#### Finding 1.1.1: Low @impl in memory_monitor.ex

- **File:** `lib/eve_dmv/memory_monitor.ex`
- **Severity:** Low
- **Effort:** Small (<1hr)
- **@impl Count:** 2
- **Description:** Memory monitor has only 2 @impl annotations. Should verify all GenServer callbacks are annotated.

#### Finding 1.1.2: Low @impl in static_data_event_processor.ex

- **File:** `lib/eve_dmv/contexts/combat_intelligence/infrastructure/static_data_event_processor.ex`
- **Severity:** Low
- **Effort:** Small (<1hr)
- **@impl Count:** 2
- **Description:** Event processor has only 2 @impl annotations. Should verify all GenServer callbacks are annotated.

### LiveView @impl Status

Only 1 LiveView file found (`lib/eve_dmv_web.ex`) which is the module definition, not an actual LiveView. All actual LiveView modules in `lib/eve_dmv_web/live/` appear to have proper @impl annotations.

### Broadway @impl Status

Broadway modules have @impl annotations present. No critical gaps identified.

---

## 1.2 Type Specifications (@spec) Coverage

### Summary

The codebase has 1,669 @spec annotations. Most API modules have good coverage, but some gaps exist.

### API Module @spec Coverage

| Context | Specs | Functions | Coverage | Status |
|---------|-------|-----------|----------|--------|
| battle_analysis | 4 | 4 | 100% | OK |
| combat_intelligence | 13 | 15 | 87% | Minor gap |
| corporation_intelligence | 11 | 11 | 100% | OK |
| fleet_operations | 14 | 14 | 100% | OK |
| killmail_processing | 16 | 22 | 73% | Needs work |
| market_intelligence | 8 | 7 | 114%* | OK |
| surveillance | 16 | 16 | 100% | OK |
| system_analysis | 11 | 11 | 100% | OK |

*Note: 114% indicates some specs for private functions or multiple specs for overloaded functions.

#### Finding 1.2.1: killmail_processing API Missing @spec

- **File:** `lib/eve_dmv/contexts/killmail_processing/api.ex`
- **Severity:** Medium
- **Effort:** Medium (1-4hr)
- **Coverage:** 73% (16/22)
- **Description:** The killmail_processing API module is missing 6 @spec annotations. As a critical data pipeline, this should have 100% coverage.
- **Recommendation:** Add @spec to all public functions in this module.

#### Finding 1.2.2: combat_intelligence API Missing @spec

- **File:** `lib/eve_dmv/contexts/combat_intelligence/api.ex`
- **Severity:** Low
- **Effort:** Small (<1hr)
- **Coverage:** 87% (13/15)
- **Description:** Missing 2 @spec annotations.
- **Recommendation:** Add @spec to remaining public functions.

---

## 1.3 Pattern Matching Best Practices

### 1.3.1 Nil Check Anti-Patterns

Found **40+ instances** of `!= nil` or `== nil` checks that could potentially use pattern matching.

#### Finding 1.3.1: Nil checks in surveillance matching

- **File:** `lib/eve_dmv/surveillance/matching/killmail_field_extractor.ex`
- **Lines:** 174, 181, 188
- **Severity:** Low
- **Effort:** Small (<1hr)
- **Current Code:**
  ```elixir
  &(&1 != nil)
  ```
- **Recommendation:** Most of these are in `Enum.filter` callbacks where `!= nil` is idiomatic. Consider reviewing for cases where pattern matching would improve clarity.

#### Finding 1.3.2: Nil checks in battle service

- **File:** `lib/eve_dmv/core/services/battle_service.ex`
- **Lines:** 146, 174, 183
- **Severity:** Low
- **Effort:** Small (<1hr)
- **Current Code:**
  ```elixir
  |> Enum.filter(&(&1 != nil))
  ```
- **Recommendation:** This pattern is acceptable in pipelines. No action required unless performance is critical.

### Assessment

Most nil checks are in `Enum.filter` callbacks where the `&(&1 != nil)` pattern is idiomatic. A few cases in conditional logic could benefit from pattern matching but are not critical.

---

## 1.4 Error Handling Consistency

### Error Tuple Pattern Analysis

Analysis of error tuple patterns reveals **inconsistent error formats**:

| Pattern | Count | Example |
|---------|-------|---------|
| `{:error, reason}` (variable) | 830 | Generic catch-all |
| `{:error, error}` (variable) | 381 | Generic catch-all |
| `{:error, _}` (ignored) | 305 | Swallowed errors |
| `{:error, term()}` (typed) | 198 | Typed but broad |
| `{:error, :not_found}` | 149 | Specific atom |
| `{:error, atom()}` (typed) | 99 | Typed but broad |
| `{:error, _reason}` (ignored) | 69 | Swallowed errors |
| `{:error, :query_failed}` | 52 | Specific atom |
| `{:error, String.t()}` (typed) | 45 | String errors |
| `{:error, :service_unavailable}` | 33 | Specific atom |
| `{:error, :insufficient_data}` | 28 | Specific atom |
| `{:error, any()}` (typed) | 27 | Very broad |

#### Finding 1.4.1: Inconsistent Error Types

- **Severity:** Medium
- **Effort:** Large (>4hr)
- **Description:** The codebase uses a mix of error formats:
  - Atoms: `:not_found`, `:query_failed`, `:service_unavailable`
  - Strings: Generic error messages
  - Tuples: `{:http_error, status}`, `{field, :invalid_type}`
  - Mixed: Some modules use atoms, others use strings
- **Recommendation:** Create a centralized error type module:
  ```elixir
  defmodule EveDmv.Error do
    @type t ::
      :not_found |
      :query_failed |
      :service_unavailable |
      {:validation_error, field :: atom(), reason :: atom()} |
      {:external_error, service :: atom(), details :: term()}
  end
  ```

### Catch-All Error Handlers

Found **25 instances** of catch-all error handlers (`_ -> :error` or `_ -> {:error, ...}`).

#### Finding 1.4.2: Catch-All Handlers Hiding Context

- **File:** `lib/eve_dmv/contexts/battle_analysis.ex`
- **Lines:** 216, 275
- **Severity:** Medium
- **Effort:** Small (<1hr)
- **Current Code:**
  ```elixir
  _ -> :error
  ```
- **Recommendation:** Replace with specific error atoms that provide context:
  ```elixir
  other -> {:error, {:unexpected_format, other}}
  ```

---

## 1.5 Other Idiomatic Patterns

### Single-Expression Pipes

Found **30+ instances** of single-expression pipes. Most are acceptable stylistic choices (e.g., `|> new()`, `|> length()`). No critical issues identified.

### Map.get Usage

No significant anti-patterns found with `Map.get` on required keys. The codebase generally uses proper pattern matching.

---

## Priority Summary

| Finding | Severity | Effort | Priority |
|---------|----------|--------|----------|
| 1.2.1 killmail_processing @spec | Medium | Medium | High |
| 1.4.1 Inconsistent Error Types | Medium | Large | Medium |
| 1.4.2 Catch-All Handlers | Medium | Small | Medium |
| 1.2.2 combat_intelligence @spec | Low | Small | Low |
| 1.1.1 memory_monitor @impl | Low | Small | Low |
| 1.1.2 static_data_event_processor @impl | Low | Small | Low |

---

## Recommendations

1. **Immediate (High Priority):**
   - Add missing @spec to `killmail_processing/api.ex`

2. **Short-term (Medium Priority):**
   - Create centralized error types module
   - Replace catch-all error handlers with specific atoms

3. **Long-term (Low Priority):**
   - Audit remaining GenServers for @impl completeness
   - Consider refactoring some nil checks to pattern matching where it improves readability
