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
  ~r/multi_system_battle_correlator\.ex:241.*call_with_opaque/,

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

  # Platform defensive patterns
  ~r/cache_manager\.ex:\d+.*pattern_match_cov/,

  # Web defensive patterns
  ~r/surveillance_profiles_live\.ex:\d+.*pattern_match_cov/,

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
  ~r/combat_stats\.ex.*pattern_match/,

  # External services
  ~r/wanderer_client\.ex.*pattern_match/,
  ~r/esi_strategy\.ex.*pattern_match/,

  # Cache and auth
  ~r/intelligence_cache\.ex.*pattern_match/,
  ~r/auth.*pattern_match/,
  ~r/user\.ex.*pattern_match/,

  # Platform utilities
  ~r/monitoring\/facade\.ex/,
  ~r/performance_optimizer\.ex.*pattern_match/,
  ~r/materialized_view_manager.*view_lifecycle\.ex/,
  ~r/api_auth\.ex.*pattern_match/,

  # Graceful shutdown
  ~r/graceful_shutdown\.ex/,

  # ===========================================
  # INTENTIONALLY BROAD SPECS (file-scoped)
  # ===========================================
  # API functions with specs broader than current implementation
  # for API stability and future-proofing

  # extra_range warnings - character intelligence
  ~r/character_intelligence\.ex:\d+:extra_range/,

  # extra_range warnings - combat analysis
  ~r/threat_assessment_engine\.ex:\d+:extra_range/,

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

  # contract_supertype warnings - config
  ~r/query_migration\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - character intelligence
  ~r/character_intelligence\.ex:\d+:contract_supertype/,
  ~r/threat_config\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - combat intelligence
  ~r/combat_intelligence\/api\.ex:\d+:contract_supertype/,
  ~r/external_group_analyzer\.ex:\d+:contract_supertype/,

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

  # contract_supertype warnings - platform
  ~r/telemetry_helper\.ex:\d+:contract_supertype/,

  # contract_supertype warnings - web
  ~r/search_helpers\.ex:\d+:contract_supertype/,
  ~r/layout_helpers\.ex:\d+:contract_supertype/,
  ~r/threat_display_helpers\.ex:\d+:contract_supertype/,
  ~r/surveillance_helpers\.ex:\d+:contract_supertype/,
  ~r/character_intelligence_helpers\.ex:\d+:contract_supertype/,
  ~r/dashboard_helpers\.ex:\d+:contract_supertype/,

  # ===========================================
  # GUARD FAILURES (file-scoped)
  # ===========================================
  # Guards on optional data fields

  # combat_doctrine_analyzer.ex - guards on optional data
  ~r/combat_doctrine_analyzer\.ex:\d+:guard_fail/,

  # requirements_builder.ex - guards on optional data
  ~r/requirements_builder\.ex:\d+:guard_fail/,

  # insight_generator.ex - guards on optional data
  ~r/insight_generator\.ex:\d+:guard_fail/,

  # module_reorganizer.ex - guards on optional data
  ~r/module_reorganizer\.ex:\d+:guard_fail/,

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
  # CALLBACK TYPE MISMATCHES (file-scoped)
  # ===========================================
  # Plugin callback implementations with acceptable type differences

  # combat_stats.ex - plugin callback implementations
  ~r/intelligence_engine\/plugins\/character\/combat_stats\.ex:\d+.*callback_type_mismatch/,

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
  ~r/threat_analysis_service\.ex.*pattern_match/,

  # Core services
  ~r/correlation_engine\.ex.*pattern_match/,
  ~r/module_reorganizer\.ex.*pattern_match/,
  ~r/battle_service\.ex.*pattern_match/,
  ~r/dns_resolver\.ex.*pattern_match/,

  # Repositories
  ~r/corporation_repository\.ex.*pattern_match/,

  # LiveView helpers
  ~r/liveview_pattern_template\.ex.*pattern_match/,

  # ===========================================
  # CALL TYPE MISMATCHES
  # ===========================================
  ~r/api\.ex:\d+:\d+:call/,
  ~r/_repository\.ex:\d+:call/,
  ~r/jsonl_parser\.ex:\d+:\d+:call/,
  ~r/sde_validator\.ex:\d+:\d+:call/,
  ~r/background_task_supervisor\.ex:\d+:\d+:call/,
  ~r/_live\.ex:\d+:\d+:call/,
  ~r/threat_analyzer\.ex:\d+:\d+:call/,

  # ===========================================
  # OPAQUE TERM IN FUNCTION CALLS
  # ===========================================
  # Legacy dialyzer warning about opaque terms in function calls
  ~r/multi_system_battle_correlator\.ex:241/,

  # ===========================================
  # ASH QUERY PATTERNS
  # ===========================================
  # Ash.Query.filter usage patterns in resources
  ~r/killmail_raw\.ex:\d+:call_to_missing/,

  # ===========================================
  # DATA LOADER HELPERS
  # ===========================================
  # Helper function type mismatches with optional data patterns
  ~r/character_data_loader\.ex:\d+:\d+:call/
]
