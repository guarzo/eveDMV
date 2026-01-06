# Phase 8: Feature Flags and Transitory Code Audit

**Deliverable:** `docs/review/08_transitory_code_audit.md`
**Date Generated:** 2026-01-06
**Review Phase:** 8 of 8 (Partial - Updated during Phase 3)

---

## Executive Summary

This audit inventories feature flags, deprecated code, legacy adapters, and fallback patterns that represent transitory code for cleanup. Key findings:

- **5 feature flags** documented with environment variables
- **1 legacy adapter** actively bridging old and new systems
- **30+ fallback/legacy comments** indicating backward compatibility code
- **40+ environment variables** documented for configuration
- **0 disabled/unused files** remaining (good!)
- **0 @deprecated annotations** (good!)

---

## 8.1 Feature Flag Inventory

### Feature Flag Infrastructure

| Location | Purpose |
|----------|---------|
| `lib/eve_dmv/config/unified_config.ex:206` | Central `feature_enabled?/1` function |
| `lib/eve_dmv/core/config/config.ex:364` | Delegated `feature_enabled?/1` wrapper |
| `lib/eve_dmv/core/domain/intelligence/core/config.ex:103` | Intelligence-specific feature checks |

### Active Feature Flags

#### Finding 8.1.1: Pipeline Enabled Flag

- **Flag:** `:pipeline_enabled`
- **Environment Variable:** `PIPELINE_ENABLED`
- **Default:** `true`
- **Purpose:** Controls Broadway killmail ingestion pipeline
- **Code Paths:**
  - `lib/eve_dmv/core/config/config.ex:229`
  - `lib/eve_dmv/config/unified_config.ex:20`
  - `config/runtime.exs:106`
- **Recommendation:** Keep - Legitimate operational control

---

#### Finding 8.1.2: Mock SSE Server Flag

- **Environment Variable:** `MOCK_SSE_SERVER_ENABLED`
- **Default:** `"false"`
- **Location:** `lib/eve_dmv/application.ex:264`, `config/runtime.exs:107`
- **Purpose:** Use mock SSE server for development testing
- **Recommendation:** Keep - Development utility

---

#### Finding 8.1.3: SDE Auto Update Flag

- **Environment Variable:** `SDE_AUTO_UPDATE`
- **Default:** `"true"`
- **Location:** `config/runtime.exs:109`
- **Purpose:** Enable/disable automatic Static Data Export updates
- **Recommendation:** Keep - Operational control

---

#### Finding 8.1.4: Historical Fetch Enabled Flag

- **Environment Variable:** `HISTORICAL_FETCH_ENABLED`
- **Default:** `"true"`
- **Location:** `config/runtime.exs:153`
- **Purpose:** Enable/disable background 2-year historical killmail fetch worker
- **Recommendation:** Keep - Operational control for resource management

---

#### Finding 8.1.5: Structured Logging Flag

- **Environment Variable:** `DISABLE_STRUCTURED_LOGGING`
- **Default:** Not set (structured logging enabled)
- **Location:** `config/runtime.exs:188`, `config/runtime_logger.exs:7`
- **Purpose:** Disable structured JSON logging for debugging
- **Recommendation:** Keep - Debugging utility

---

### 8.1.4 Environment Variables Summary

See **Appendix B** for complete environment variable inventory (40+ variables).

---

## 8.2 Legacy Adapter Audit

### Finding 8.2.1: Intelligence Legacy Adapter

- **File:** `lib/eve_dmv/core/infrastructure/legacy_adapter.ex`
- **Lines:** 428
- **Severity:** Medium
- **Effort:** Medium (1-4hr)

**Description:**
The `EveDmv.Intelligence.LegacyAdapter` module provides backward compatibility by wrapping the new Intelligence Engine plugin system with old analyzer interfaces.

**Current Callers (documented in file):**
- `EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.CharacterAnalyzer`

**Functions Provided:**
| Function | Purpose | New System Equivalent |
|----------|---------|----------------------|
| `analyze_character/1` | Character analysis | `IntelligenceEngine.analyze(:character, id)` |
| `analyze_characters/1` | Batch character analysis | `IntelligenceEngine.analyze(:character, ids, parallel: true)` |
| `analyze_corporation/1` | Corporation analysis | `IntelligenceEngine.analyze(:corporation, id)` |
| `analyze_fleet/1` | Fleet analysis | `IntelligenceEngine.analyze(:fleet, id)` |
| `analyze_threat/2` | Threat analysis | `IntelligenceEngine.analyze(:threat, id)` |
| `invalidate_character_cache/1` | Cache invalidation | `IntelligenceEngine.invalidate_cache(:character, id)` |
| `get_comprehensive_character_analysis/1` | Full analysis | `IntelligenceEngine.analyze(:character, id, scope: :full)` |

**Removal Plan:**
1. Update `CharacterAnalyzer` to use bounded context APIs directly
2. Verify no other callers exist
3. Remove legacy adapter module
4. Update tests

**Recommendation:** Schedule for removal after CharacterAnalyzer migration

---

### Finding 8.2.2: Legacy Adapter Reference in CharacterAnalyzer

- **File:** `lib/eve_dmv/contexts/character_intelligence/domain/analyzers/character_analyzer.ex`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Description:**
This file references `LegacyAdapter`, indicating it's the primary consumer of the legacy infrastructure.

**Recommendation:** Update to use Intelligence Engine directly, then remove LegacyAdapter.

---

## 8.3 Fallback and Legacy Code Patterns

### Fallback Comments by Category

#### Legitimate Fallbacks (Keep)

| File | Line | Pattern | Reason to Keep |
|------|------|---------|----------------|
| `fleet_utils.ex` | 313 | `# Fallback` | Handles edge case timestamps |
| `fleet_utils.ex` | 330 | `# Fallback to current time` | Default for missing timestamps |
| `price_service.ex` | 170 | `# Fallback to expensive price calculation` | Legitimate cache miss handling |
| `wanderer_client.ex` | 542 | `# Fallback: try to extract systems` | API response format variance |
| `error_classifier.ex` | 50 | `# Fallback to unknown` | Default error classification |
| `chain_intelligence.ex` | 244 | `# Fallback if query fails` | Error recovery |

---

#### Migration-Related Legacy Code (Review for Removal)

##### Finding 8.3.1: Profile Legacy Filter Configuration

- **File:** `lib/eve_dmv/surveillance/profile.ex`
- **Line:** 87
- **Pattern:** `# Legacy filter configuration (deprecated - kept for migration)`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Description:** Old filter format being maintained for migration compatibility.

**Current Code:**
```elixir
# Legacy filter configuration (deprecated - kept for migration)
```

**Recommendation:** Verify migration is complete, then remove legacy format support.

---

##### Finding 8.3.2: Profile Legacy Format Support

- **File:** `lib/eve_dmv/surveillance/profile.ex`
- **Line:** 169
- **Pattern:** `# Legacy format - still valid`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Recommendation:** Document which format is "legacy" and plan removal.

---

##### Finding 8.3.3: Cache Legacy Defaults

- **File:** `lib/eve_dmv/core/utils/cache.ex`
- **Line:** 50
- **Pattern:** `# Legacy defaults for backward compatibility`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Recommendation:** Review if legacy defaults are still needed.

---

##### Finding 8.3.4: Config Legacy Functions

- **File:** `lib/eve_dmv/core/config/config.ex`
- **Line:** 387
- **Pattern:** `# Legacy Functions (for backward compatibility)`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Recommendation:** Audit callers and migrate to new config API.

---

##### Finding 8.3.5: Wanderer Client Legacy Format Support

- **File:** `lib/eve_dmv/external/wanderer/wanderer_client.ex`
- **Lines:** 560, 633
- **Pattern:** `# Legacy format support`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Description:** Supports old API response formats from wanderer-kills.

**Recommendation:** Check if wanderer-kills still sends legacy formats. If not, remove.

---

##### Finding 8.3.6: Display Service Legacy Participants Format

- **File:** `lib/eve_dmv/external/killmails/display_service.ex`
- **Lines:** 261, 273, 288
- **Pattern:** `# Fallback to old participants format`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Description:** Handles old killmail participant format.

**Recommendation:** Verify if old format killmails still exist in database.

---

##### Finding 8.3.7: Battle Analysis Legacy Analysis

- **File:** `lib/eve_dmv/contexts/battle_analysis.ex`
- **Lines:** 384, 407
- **Pattern:** `# Legacy analysis for backward compatibility`
- **Severity:** Medium
- **Effort:** Medium (1-4hr)

**Description:** Old analysis method kept as fallback.

**Recommendation:** Verify new analysis is stable, then remove legacy path.

---

##### Finding 8.3.8: Chain Monitor Legacy Handlers

- **File:** `lib/eve_dmv/contexts/surveillance/domain/chain_monitor.ex`
- **Lines:** 163, 175
- **Pattern:** `# Legacy handler - keeping for backward compatibility`
- **Severity:** Low
- **Effort:** Small (<1hr)

**Description:** Old event handlers maintained for compatibility.

**Recommendation:** Verify no systems send legacy events, then remove.

---

## 8.4 Deprecated Code Audit

### @deprecated Annotations

**Result:** 0 `@deprecated` annotations found

This is positive - no functions are marked deprecated but still present.

---

## 8.5 Disabled and Unused Files

### Disabled Files

**Result:** 0 files with `.disabled`, `.unused`, or `.bak` extensions found

This is positive - no disabled files cluttering the codebase.

---

## Summary: Prioritized Cleanup Tasks

### High Priority

| # | Finding | Effort | Action |
|---|---------|--------|--------|
| 1 | Remove Legacy Adapter | Medium | Migrate CharacterAnalyzer, then delete |

### Medium Priority

| # | Finding | Effort | Action |
|---|---------|--------|--------|
| 2 | Battle Analysis Legacy Path | Medium | Verify new path, remove legacy |
| 3 | Config Legacy Functions | Small | Audit callers, migrate |

### Low Priority

| # | Finding | Effort | Action |
|---|---------|--------|--------|
| 4 | Profile Legacy Filter | Small | Verify migration complete |
| 5 | Cache Legacy Defaults | Small | Review necessity |
| 6 | Wanderer Legacy Format | Small | Check API compatibility |
| 7 | Display Service Old Format | Small | Verify data migration |
| 8 | Chain Monitor Legacy Handlers | Small | Verify event sources |

---

## Appendix A: Analysis Commands Used

```bash
# Find legacy adapter references
grep -rln "LegacyAdapter\|legacy_adapter" lib/

# Find fallback/legacy comments
grep -rn "# [Ff]allback\|# [Ll]egacy\|# [Oo]ld\|# deprecated" lib/

# Find disabled/unused files
find lib -name "*.disabled" -o -name "*.unused" -o -name "*.bak"

# Find @deprecated annotations
grep -rn "@deprecated" lib/

# Find feature flag usage
grep -rn "feature_enabled?\|System.get_env.*ENABLE\|System.get_env.*USE_" lib/

# List environment variables in config
grep -rn "System.get_env" config/
```

---

## Appendix B: Environment Variable Inventory

### Core Application Config

| Variable | Default | Purpose |
|----------|---------|---------|
| `SECRET_KEY_BASE` | Required | Phoenix secret key |
| `DATABASE_URL` | Required | PostgreSQL connection |
| `PHX_HOST` | `example.com` | Production hostname |
| `PHX_PORT` / `PORT` | `4010` | HTTP port |
| `PHX_SERVER` | - | Enable Phoenix server |
| `DNS_CLUSTER_QUERY` | - | DNS-based clustering |

### EVE SSO Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `EVE_SSO_CLIENT_ID` | `your-eve-sso-client-id` | OAuth client ID |
| `EVE_SSO_CLIENT_SECRET` | `your-eve-sso-client-secret` | OAuth client secret |
| `EVE_SSO_REDIRECT_URI` | `http://localhost:4010/auth/...` | OAuth callback URL |
| `TOKEN_SIGNING_SECRET` | - | JWT token signing |

### External Services Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `WANDERER_KILLS_SSE_URL` | `http://localhost:8080/sse` | Killmail SSE endpoint |
| `WANDERER_KILLS_WS_URL` | `ws://localhost:4004/socket` | Killmail WebSocket |
| `WANDERER_KILLS_BASE_URL` | `http://host.docker.internal:4004` | Killmail API base |
| `WANDERER_BASE_URL` | `http://host.docker.internal:4004` | Wanderer API base |
| `WANDERER_WS_URL` | `ws://host.docker.internal:4004/socket/events` | Wanderer WebSocket |
| `WANDERER_API_TOKEN` | - | Wanderer API authentication |
| `DEFAULT_CHAIN_ID` | - | Default wormhole chain ID |
| `JANICE_BASE_URL` | `https://janice.e-351.com/api` | Janice pricing API |
| `MUTAMARKET_BASE_URL` | `https://mutamarket.com/api/v1` | MutaMarket API |
| `ESI_BASE_URL` | `https://esi.evetech.net` | EVE ESI API |

### Pipeline Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `BATCH_SIZE` | `100` | Broadway batch size |
| `BATCH_TIMEOUT` | `30000` | Broadway batch timeout (ms) |
| `PIPELINE_CONCURRENCY` | `12` | Broadway processor concurrency |
| `BATCHER_CONCURRENCY` | `4` | Broadway batcher concurrency |
| `PRICE_CACHE_TTL_HOURS` | `24` | Price cache TTL |

### Historical Fetch Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `HISTORICAL_FETCH_RATE_LIMIT` | `1000` | Delay between API calls (ms) |
| `HISTORICAL_FETCH_MAX_PAGES` | `100` | Max pages to fetch per entity |
| `HISTORICAL_FETCH_LOOKBACK_DAYS` | `730` | Days of history (2 years) |
| `HISTORICAL_FETCH_CHECK_INTERVAL` | `30000` | Worker queue check interval (ms) |

### Database Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `POOL_SIZE` | `20` | Connection pool size |
| `DB_QUEUE_TARGET` | `50` | DBConnection queue target |
| `DB_QUEUE_INTERVAL` | `1000` | DBConnection queue interval |
| `DB_TIMEOUT` | `15000` | Query timeout (ms) |
| `DB_CONNECT_TIMEOUT` | `5000` | Connection timeout (ms) |
| `DATABASE_SSL` | `false` | Enable SSL |
| `DB_STATEMENT_TIMEOUT` | `30000` | Statement timeout (ms) |

### Static Data Configuration

| Variable | Default | Purpose |
|----------|---------|---------|
| `STATIC_DATA_LOAD_DELAY` | `5000` | Delay before loading static data (ms) |

---

*Generated as part of EVE DMV Code Review - Phase 8*
*Updated during Phase 2 (Ash Framework) and Phase 3 (Architecture) Reviews*
