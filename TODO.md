# EVE DMV Implementation TODO List

This comprehensive implementation list is based on code review feedback and identifies actionable improvements across architecture, code quality, bug fixes, and process improvements.

## High Priority Items

### Architecture Improvements
- [ ] **arch-1**: Implement EveDmv.Intelligence.Analyzer behaviour contract with telemetry and logging
- [ ] **arch-3**: Set up Intelligence.Supervisor with DynamicSupervisor for analysis jobs
- [ ] **code-1**: Split AnalyticsEngine into PlayerStatsEngine and ShipStatsEngine (keep <300 LoC)

### Critical Bug Fixes
- [ ] **fix-1**: Fix infinite recursion in assets/vendor/topbar.js progress function
- [ ] **fix-2**: Add safe access checks for killmail victim_character_id to prevent KeyError
- [ ] **fix-3**: Add participants association to KillmailEnriched schema
- [ ] **fix-15**: Fix corporation_live.ex to use database-level filtering instead of in-memory
- [ ] **fix-25**: Use Task.Supervisor instead of Task.start for unsupervised tasks
- [ ] **fix-26**: Extract duplicate killmail processing logic into shared KillmailProcessor module

### Process Improvements
- [ ] **tools-1**: Enable Dialyzer with PLT caching in CI pipeline
- [ ] **tools-3**: Un-skip E2E tests and run them in CI

### Security Fixes
- [ ] **fix-33**: Restrict solar system data modification to admin users only

### Performance Optimizations
- [ ] **perf-1**: Optimize type_resolver.ex to use bulk queries instead of N+1 queries

## Medium Priority Items

### Code Quality Improvements
- [ ] **arch-2**: Extract math utilities to EveDmv.Intelligence.Math module
- [ ] **arch-4**: Add caching layer using Cachex/Nebulex for analysis results
- [ ] **arch-5**: Centralize configuration constants in config files or Application.get_env wrappers
- [ ] **code-2**: Refactor IntelligenceCoordinator.analyze_character_comprehensive/2 into smaller functions
- [ ] **code-4**: Add missing moduledocs and set up ex_doc CI failures for missing docs
- [ ] **tools-2**: Add comprehensive Credo ruleset with custom checks for moduledocs, LoC, complexity

### Bug Fixes
- [ ] **fix-4**: Fix Float.round calls to handle integer inputs correctly
- [ ] **fix-5**: Replace hardcoded character ID "1234567" in dashboard_live.ex with dynamic value
- [ ] **fix-7**: Add error handling to safe_decimal_new function for invalid binary input
- [ ] **fix-8**: Remove unnecessary transaction wrapper in character_analyzer.ex Task.async_stream
- [ ] **fix-9**: Fix gang size calculation by excluding victim from participant count
- [ ] **fix-11**: Fix HTTP 304 response handling in ESI client to return cached data or error
- [ ] **fix-12**: Replace Date.from_iso8601! with Date.from_iso8601 for safe parsing
- [ ] **fix-13**: Add caching for ESI universe data (types, groups, categories) with 1-week TTL
- [ ] **fix-14**: Replace String.to_integer with safe parsing in character_intel_live.ex
- [ ] **fix-16**: Use bulk operations for item type creation in static_data_loader.ex
- [ ] **fix-19**: Fix HEEx template syntax in surveillance_live.html.heex line 92
- [ ] **fix-20**: Add check constraints for enumerated fields in analytics and surveillance migrations
- [ ] **fix-21**: Replace hardcoded ISK multipliers with actual ISK calculations in analytics_engine.ex
- [ ] **fix-22**: Fix analytics_engine.ex to return error tuples instead of empty lists
- [ ] **fix-23**: Add defensive checks for empty lists in analytics_engine.ex
- [ ] **fix-24**: Fix corporation intel link in corporation_live.html.heex to use correct route
- [ ] **fix-27**: Fix bare rescue blocks to catch specific exceptions only
- [ ] **fix-28**: Fix rate_limiter.ex to use per-request timeout values
- [ ] **fix-29**: Extract duplicated performance calculation logic in player_stats.ex and ship_stats.ex
- [ ] **fix-30**: Fix solo performance ratio calculation to handle zero losses correctly
- [ ] **fix-31**: Add missing :solo_kills attribute to ship_stats.ex schema
- [ ] **fix-34**: Add timeout handling for ESI data fetching in player_profile_live.ex
- [ ] **fix-35**: Fix bulk notification updates to handle individual errors in surveillance_live.ex
- [ ] **fix-36**: Use is_victim flag instead of damage_dealt for kill/loss detection

### UI/UX Improvements
- [ ] **ui-1**: Extract player_profile_live.html.heex sections into separate function components
- [ ] **ui-2**: Create helper functions for template calculations in player_profile_live.ex

### Performance Optimizations
- [ ] **perf-2**: Monitor and optimize killmail pipeline insert performance

## Low Priority Items

### Code Style & Naming
- [ ] **code-5**: Standardize naming conventions across intelligence modules (Metrics/Analyzer/Formatter)
- [ ] **fix-6**: Replace 'var' with 'const' in topbar.js for newProgress variable
- [ ] **fix-10**: Change ship categorization fallback from "small" to "unknown"
- [ ] **fix-32**: Simplify nested case statements in price_service.ex

### Configuration Improvements
- [ ] **fix-17**: Make region ID configurable in esi_strategy.ex instead of hardcoded
- [ ] **fix-18**: Make abyssal filament type ID ranges configurable in mutamarket_strategy.ex
- [ ] **config-1**: Use ConfigHelper.safe_string_to_integer in runtime.exs
- [ ] **config-2**: Make excluded ship type IDs configurable in price_helper.ex

### Documentation & Testing
- [ ] **code-3**: Consolidate test data generators in test/support/factories/intel_factory.ex
- [ ] **tools-4**: Convert benchmarks to ExUnit @tag :benchmark suite
- [ ] **docs-1**: Fix markdown formatting in all documentation files
- [ ] **docs-2**: Add explanatory comments for partial success behavior in type_resolver.ex

### UI Polish
- [ ] **ui-3**: Test and fix responsive grid layout in home.html.heex

## Implementation Notes

### Architecture Refactoring
The biggest wins will come from implementing the Analyzer behaviour contract and setting up proper supervision. This will provide consistency across all intelligence modules and better error handling.

### Performance Focus
Database query optimization (especially the N+1 queries in type_resolver.ex) and switching to bulk operations will have the most impact on performance.

### Error Handling
Many fixes focus on replacing unsafe operations with safe alternatives and adding proper error handling throughout the codebase.

### Task Supervision
Multiple items involve replacing unsupervised `Task.start` calls with properly supervised tasks to prevent resource leaks and improve fault tolerance.

## Next Steps

1. Start with high-priority architectural improvements (Analyzer behaviour, supervision)
2. Fix critical bugs that could cause runtime failures
3. Enable quality gates (Dialyzer, E2E tests) in CI
4. Work through medium-priority items systematically
5. Address low-priority items as time permits

This TODO list provides a roadmap for improving code quality, performance, and maintainability while addressing immediate bugs and security concerns.

## Intelligence System

### Corporation Intelligence Analysis
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:139`  
**Task**: Implement corporation intelligence analysis when data is available  
**Details**: Currently returns placeholder data. Need to implement actual analysis of corporation members and patterns.

### Fleet Analysis Functions
**Location**: `lib/eve_dmv/intelligence/correlation_engine.ex:633`  
**Task**: Implement these functions when fleet analysis is ready  
**Details**: Several commented-out functions for ship progression consistency and behavioral analysis are waiting for fleet data integration.

### Employment Gap Detection
**Location**: `lib/eve_dmv/intelligence/wh_vetting_analyzer.ex:958`  
**Task**: Implement employment gap detection when ESI is available  
**Details**: Currently returns empty array for employment gaps. Need ESI integration to fetch employment history and detect suspicious gaps.

## API Infrastructure

### Fallback Controller
**Location**: `lib/eve_dmv_web/controllers/api/api_keys_controller.ex:14`  
**Task**: Create fallback controller  
**Details**: API controller is missing fallback error handling. Need to implement `EveDmvWeb.FallbackController` for consistent API error responses.

## Priority

- **High Priority**: Fallback Controller (affects API reliability)
- **Medium Priority**: Employment Gap Detection (security feature)
- **Low Priority**: Corporation Intelligence Analysis, Fleet Analysis Functions (enhancement features)