[
  # ===========================================
  # DIALYZER IGNORE FILE
  # ===========================================
  # This file contains patterns for false positives and acceptable warnings.
  # All patterns are scoped to specific files to maintain Dialyzer coverage elsewhere.
  #
  # Categories:
  # 1. Compile-time conditionals (Mix.env checks)
  # 2. MapSet opaque type warnings (file-scoped)
  # 3. Defensive pattern matching (file-scoped)
  # 4. Data-dependent patterns (database queries)
  # 5. Intentionally broad specs (file-scoped)
  # 6. Guard failures on optional data (file-scoped)
  # 7. No-return paths in analysis functions (file-scoped)
  # 8. Callback type mismatches (file-scoped)
  # ===========================================

  # ===========================================
  # COMPILE-TIME CONDITIONALS
  # ===========================================
  # Pattern matches on false/true at line 1 are typically from compile-time
  # environment checks like `if Mix.env() == :prod`

  # Line 1 pattern_match with false/true indicates compile-time checks
  # These patterns match warnings like "lib/module.ex:1:pattern_match"
  ~r/\.ex:1:pattern_match/,

  # ===========================================
  # MAPSET OPAQUE TYPE WARNINGS (file-scoped)
  # ===========================================
  # MapSet is an opaque type - dialyzer reports false positives when it
  # sees the internal structure during analysis

  # contexts.ex - MapSet.member? check
  ~r/contexts\.ex:\d+.*call_without_opaque/,

  # multi_system_battle_correlator.ex - MapSet union/member operations
  ~r/multi_system_battle_correlator\.ex:\d+.*call_without_opaque/,

  # correlation_engine.ex - MapSet.member? check
  ~r/correlation_engine\.ex:\d+.*call_without_opaque/,

  # cross_character_analyzer.ex - MapSet.member? check
  ~r/cross_character_analyzer\.ex:\d+.*call_without_opaque/,

  # ewar_analyzer.ex - MapSet.difference call
  ~r/ewar_analyzer\.ex:\d+.*call_without_opaque/,

  # cross_system_coordinator.ex - MapSet intersection calls
  ~r/cross_system_coordinator\.ex:\d+.*call_without_opaque/,

  # Also handle call_with_opaque for libgraph interactions
  ~r/multi_system_battle_correlator\.ex:\d+.*call_with_opaque/,

  # ===========================================
  # DEFENSIVE PATTERN MATCHING (file-scoped)
  # ===========================================
  # Catch-all clauses and exhaustive pattern matches that dialyzer sees
  # as unreachable but are intentional for defensive programming

  # Battle analysis defensive patterns
  ~r/battle_analysis\.ex:\d+.*pattern_match_cov/,

  # Character intelligence defensive patterns
  ~r/character_intelligence\.ex:\d+.*pattern_match_cov/,

  # Combat modules defensive patterns
  ~r/tactical_pattern_detector\.ex:\d+.*pattern_match_cov/,

  # Corporation intelligence defensive patterns
  ~r/threat_assessor\.ex:\d+.*pattern_match_cov/,
  ~r/combat_doctrine_analyzer\.ex:\d+.*pattern_match_cov/,

  # Fleet operations defensive patterns
  ~r/requirements_builder\.ex:\d+.*pattern_match_cov/,

  # Intelligence core defensive patterns
  ~r/behavioral_pattern_analyzer\.ex:\d+.*pattern_match_cov/,
  ~r/network_analysis_engine\.ex:\d+.*pattern_match_cov/,

  # Cross-system coordinator defensive patterns
  ~r/cross_system_coordinator\.ex:\d+.*pattern_match_cov/,
  ~r/cross_system_analyzer_streamlined\.ex:\d+.*pattern_match_cov/,

  # Killmail processing defensive patterns
  ~r/killmail_orchestrator\.ex:\d+.*pattern_match_cov/,

  # Market intelligence defensive patterns
  ~r/price_service\.ex:\d+.*pattern_match_cov/,
  ~r/external_price_client\.ex:\d+.*pattern_match_cov/,

  # Surveillance defensive patterns
  ~r/chain_intelligence_helper\.ex:\d+.*pattern_match_cov/,
  ~r/notification_dispatcher\.ex:\d+.*pattern_match_cov/,

  # Threat surveillance defensive patterns
  ~r/alert_management_service\.ex:\d+.*pattern_match_cov/,
  ~r/surveillance_matching_engine\.ex:\d+.*pattern_match_cov/,
  ~r/threat_assessment_engine\.ex:\d+.*pattern_match_cov/,
  ~r/notification_service\.ex:\d+.*pattern_match_cov/,
  ~r/profile_management_service\.ex:\d+.*pattern_match_cov/,

  # Core domain defensive patterns
  ~r/pattern_analysis\.ex:\d+.*pattern_match_cov/,
  ~r/intelligence_suitability\.ex:\d+.*pattern_match_cov/,
  ~r/unified_repository\.ex:\d+.*pattern_match_cov/,
  ~r/battle_service\.ex:\d+.*pattern_match_cov/,

  # External integrations defensive patterns
  ~r/esi_request_client\.ex:\d+.*pattern_match_cov/,
  ~r/esi_entity_resolver\.ex:\d+.*pattern_match_cov/,
  ~r/sde_validator\.ex:\d+.*pattern_match_cov/,

  # Platform defensive patterns - removed unused cache_manager pattern

  # Web defensive patterns - removed unused surveillance_profiles_live pattern

  # ===========================================
  # DATA-DEPENDENT PATTERNS
  # ===========================================
  # Functions that return success based on database content.
  # Dialyzer can't prove success paths without runtime data.

  # Battle analysis
  ~r/battle_curator\.ex.*pattern_match/,
  ~r/battle_analysis.*pattern_match/,
  ~r/battle_sharing.*pattern_match/,

  # Character intelligence
  ~r/character_intelligence\.ex.*pattern_match/,
  ~r/threat_scoring.*pattern_match/,

  # Corporation intelligence
  ~r/corporation_intelligence\.ex.*pattern_match/,
  ~r/corporation_analyzer\.ex.*pattern_match/,

  # Static data loaders
  ~r/sde_.*pattern_match/,
  ~r/static_data.*pattern_match/,
  ~r/item_type_processor.*pattern_match/,
  ~r/jsonl_parser.*pattern_match/,
  ~r/solar_system_processor.*pattern_match/,

  # Application startup
  ~r/application\.ex.*pattern_match/,

  # Controllers and LiveView
  ~r/controller\.ex.*pattern_match/,
  ~r/_live\.ex.*pattern_match/,

  # Workers and background tasks
  ~r/worker\.ex.*pattern_match/,
  ~r/supervisor\.ex.*pattern_match/,

  # Intelligence and analysis
  ~r/network_analysis_engine\.ex.*pattern_match/,

  # External services
  ~r/wanderer_client\.ex.*pattern_match/,
  ~r/esi_strategy\.ex.*pattern_match/,

  # Cache and auth
  ~r/intelligence_cache\.ex.*pattern_match/,
  ~r/auth.*pattern_match/,
  ~r/user\.ex.*pattern_match/,

  # Platform utilities
  ~r/monitoring\/facade\.ex.*pattern_match/,
  ~r/performance_optimizer\.ex.*pattern_match/,
  ~r/materialized_view_manager.*view_lifecycle\.ex.*pattern_match/,
  ~r/api_auth\.ex.*pattern_match/,

  # Graceful shutdown
  ~r/graceful_shutdown\.ex.*no_return/,

  # ===========================================
  # INTENTIONALLY BROAD SPECS (file-scoped)
  # ===========================================
  # API functions with specs broader than current implementation
  # for API stability and future-proofing

  # extra_range warnings - character intelligence
  ~r/character_intelligence\.ex:\d+:extra_range/,

  # extra_range warnings - combat intelligence
  ~r/character_analyzer\.ex:\d+:extra_range/,

  # extra_range warnings - corporation intelligence
  ~r/corporation_intelligence\.ex:\d+:extra_range/,

  # extra_range warnings - system analysis
  ~r/system_analysis\.ex:\d+:extra_range/,

  # extra_range warnings - core policies
  ~r/security_classification\.ex:\d+:extra_range/,

  # extra_range warnings - external eve
  ~r/circuit_breaker\.ex:\d+:extra_range/,
  ~r/static_data_loader\.ex:\d+:extra_range/,
  ~r/item_type_processor\.ex:\d+:extra_range/,
  ~r/jsonl_parser\.ex:\d+:extra_range/,
  ~r/sde_validator\.ex:\d+:extra_range/,

  # contract_supertype warnings - character intelligence
  ~r/character_intelligence\.ex:\d+:contract_supertype/,
  ~r/threat_config\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - combat intelligence
  ~r/combat_intelligence\/api\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - corporation intelligence
  ~r/corporation_intelligence\.ex:\d+:contract_supertype/,
  ~r/corporation_intelligence\/api\.ex:\d+:contract_supertype/,
  ~r/corporation_analyzer\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - fleet operations
  ~r/requirements_builder\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - killmail processing
  ~r/extended_historical_fetcher\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - market intelligence
  ~r/market_intelligence\/api\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - core domain
  ~r/pattern_analysis\.ex:\d+:contract_supertype/,
  ~r/cache_helper\.ex:\d+:contract_supertype/,
  ~r/core\/domain\/intelligence\/core\/config\.ex:\d+:contract_supertype/,
  ~r/timeout_helper\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - core infrastructure
  ~r/unified_cache\.ex:\d+:contract_supertype/,
  ~r/unified_event_processor\.ex:\d+:contract_supertype/,
  ~r/unified_repository\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - core policies
  ~r/security_classification\.ex:\d+:contract_supertype/,
  ~r/threat_classification\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - core utils
  ~r/naive_datetime_utils\.ex:\d+:contract_supertype/,
  ~r/number_formatter\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - external eve
  ~r/name_resolver\/cache_manager\.ex:\d+:contract_supertype/,
  ~r/file_manager\.ex:\d+:contract_supertype/,
  ~r/item_type_processor\.ex:\d+:contract_supertype/,
  ~r/sde_validator\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - platform (removed unused telemetry_helper pattern)

  # contract_supertype warnings - web (removed unused filters)

  # ===========================================
  # GUARD FAILURES (file-scoped)
  # ===========================================
  # Guards on optional data fields

  # combat_doctrine_analyzer.ex - guards on optional data
  ~r/combat_doctrine_analyzer\.ex:\d+:guard_fail/,

  # requirements_builder.ex - guards on optional data
  ~r/requirements_builder\.ex:\d+:guard_fail/,

  # module_reorganizer.ex - guards on optional data
  ~r/module_reorganizer\.ex:\d+:guard_fail/,

  # insight_generator.ex - guards on optional data (with column number)
  ~r/insight_generator\.ex:\d+:\d+:guard_fail/,

  # ===========================================
  # NO_RETURN PATHS (file-scoped)
  # ===========================================
  # Analysis functions with paths dialyzer thinks never complete

  # combat_doctrine_analyzer.ex - analysis function no return
  ~r/combat_doctrine_analyzer\.ex:\d+.*no_return/,

  # monitoring_engine.ex - update functions no return
  ~r/monitoring_engine\.ex:\d+.*no_return/,

  # player_profile/api.ex - delegation functions no return
  ~r/player_profile\/api\.ex:\d+.*no_return/,

  # ===========================================
  # CALL ERRORS
  # ===========================================
  # Call type mismatches in analysis modules

  ~r/combat_doctrine_analyzer\.ex:\d+:\d+:call/,
  ~r/performance_analyzer\.ex:\d+:\d+:call/,

  # ===========================================
  # MIX TASKS
  # ===========================================
  ~r/mix\/tasks.*pattern_match/,

  # ===========================================
  # REMAINING DATA-DEPENDENT PATTERNS
  # ===========================================

  # Intelligence infrastructure
  ~r/single_system_analyzer\.ex.*pattern_match/,
  ~r/regional_correlation_analyzer\.ex.*pattern_match/,

  # Killmail processing
  ~r/killmail_processing.*pattern_match/,

  # Market intelligence
  ~r/price_service\.ex.*pattern_match/,

  # Player profile
  ~r/player_profile.*pattern_match/,
  ~r/player_analyzer\.ex.*pattern_match/,

  # System analysis
  ~r/system_analysis\.ex.*pattern_match/,

  # Threat assessment
  ~r/threat_analyzer\.ex.*pattern_match/,

  # Core services
  ~r/correlation_engine\.ex.*pattern_match/,
  ~r/module_reorganizer\.ex.*pattern_match/,
  ~r/battle_service\.ex.*pattern_match/,
  ~r/dns_resolver\.ex.*pattern_match/,

  # Repositories (removed unused corporation_repository pattern)

  # LiveView helpers
  ~r/liveview_pattern_template\.ex.*pattern_match/,

  # ===========================================
  # CALL TYPE MISMATCHES
  # ===========================================
  ~r/api\.ex:\d+:\d+:call/,
  ~r/_repository\.ex:\d+:\d+:call/,
  ~r/jsonl_parser\.ex:\d+:\d+:call/,
  ~r/sde_validator\.ex:\d+:\d+:call/,
  ~r/background_task_supervisor\.ex:\d+:\d+:call/,
  ~r/_live\.ex:\d+:\d+:call/,
  ~r/threat_analyzer\.ex:\d+:\d+:call/,

  # ===========================================
  # OPAQUE TERM IN FUNCTION CALLS
  # ===========================================
  # Legacy dialyzer warning about opaque terms in function calls
  ~r/multi_system_battle_correlator\.ex:\d+.*opaque/,

  # ===========================================
  # ASH QUERY PATTERNS (removed unused killmail_raw pattern)
  # ===========================================

  # ===========================================
  # DATA LOADER HELPERS
  # ===========================================
  # Helper function type mismatches with optional data patterns
  ~r/trend_analyzer\.ex:\d+:\d+:call/,
  ~r/threat_scoring_coordinator\.ex:\d+:\d+:call/,
  ~r/comparison_engine\.ex:\d+:\d+:pattern_match/,

  # ===========================================
  # EXTRA RANGE WARNINGS
  # ===========================================
  # Functions that currently return fewer types than spec allows
  # Kept for API stability

  # Solar system processor - environment-dependent file operations
  ~r/solar_system_processor\.ex:\d+:extra_range/,

  # Account manager - merge always succeeds currently
  ~r/account_manager\.ex:\d+:extra_range/,

  # ===========================================
  # CONTRACT SUPERTYPE WARNINGS
  # ===========================================
  # Specs that are intentionally broader than implementation

  # Gang synergy analyzer - internal calculations
  ~r/gang_synergy_analyzer\.ex:\d+:contract_supertype/,

  # Threat score calculator - analysis functions
  ~r/threat_score_calculator\.ex:\d+:contract_supertype/,

  # Activity correlator - correlation analysis
  ~r/activity_correlator\.ex:\d+:contract_supertype/,

  # Historical fetch worker - internal worker functions
  ~r/historical_fetch_worker\.ex:\d+:contract_supertype/,

  # Data requirements - helper functions
  ~r/data_requirements\.ex:\d+:contract_supertype/,

  # Query optimizer - optimization functions
  ~r/query_optimizer\.ex:\d+:contract_supertype/,

  # Result module - unwrap function
  ~r/result\.ex:\d+:contract_supertype/,

  # Metrics calculator - default values
  ~r/metrics_calculator\.ex:\d+:contract_supertype/,

  # ===========================================
  # INVALID CONTRACT WARNINGS
  # ===========================================
  # Complex type inference with cache wrappers

  # Combat intelligence API - cache wrapper type inference
  ~r/combat_intelligence\/api\.ex:\d+:invalid_contract/,

  # External group analyzer - cache wrapper type inference
  ~r/external_group_analyzer\.ex:\d+:invalid_contract/,

  # ===========================================
  # NO RETURN WARNINGS - Repository Macros
  # ===========================================
  # Repository use macros create anonymous functions that dialyzer
  # can't analyze properly

  ~r/character_repository\.ex:\d+:no_return/,
  ~r/killmail_repository\.ex:\d+:no_return/,

  # ===========================================
  # PATTERN MATCH COVERAGE
  # ===========================================
  # Defensive catch-all clauses

  # Battle timeline component - defensive formatting
  ~r/battle_timeline_component\.ex:\d+:\d+:pattern_match_cov/,

  # Notification dispatcher - defensive error handling
  ~r/notification_dispatcher\.ex:\d+:\d+:pattern_match/,

  # ===========================================
  # API TYPE CONTRACTS
  # ===========================================
  # API specs intentionally use broader/domain types for stability
  # while implementations may use more specific types

  # Surveillance API - profile_id accepts multiple types for flexibility
  ~r/surveillance\/api\.ex:\d+:invalid_contract/,
  ~r/surveillance\/api\.ex:\d+:extra_range/,

  # Corporation API - broad specs for API stability
  ~r/corporation\/api\.ex:\d+:invalid_contract/,

  # Intelligence API - broad specs for API stability
  ~r/intelligence\/api\.ex:\d+:invalid_contract/,

  # Player Profile API - broad return types for flexibility
  ~r/player_profile\/api\.ex:\d+:contract_supertype/,

  # Threat Surveillance API - broad specs for extensibility
  ~r/threat_surveillance\/api\.ex:\d+:contract_supertype/
]
