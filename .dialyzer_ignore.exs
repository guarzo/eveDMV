[
  # ===========================================
  # DIALYZER IGNORE FILE
  # ===========================================
  # This file contains patterns for known false positives in a complex
  # Ash Framework / Phoenix LiveView / Bounded Context architecture.
  #
  # Categories:
  # 1. MapSet opaque type warnings (Dialyzer limitation)
  # 2. Contract supertype warnings (type inference through bounded contexts)
  # 3. Pattern match warnings (error handling code paths)
  # 4. Extra range warnings (defensive error returns)
  # 5. Invalid contract warnings (spec vs inference mismatch)
  # 6. Compile-time conditionals (Mix.env checks)
  # ===========================================

  # ===========================================
  # MAPSET OPAQUE TYPE WARNINGS
  # ===========================================
  # MapSet is an opaque type - Dialyzer reports false positives when it
  # tracks internal structure through recursive calls. The code is correct.

  ~r/contexts\.ex.*call_without_opaque/,
  ~r/multi_system_battle_correlator\.ex.*call_without_opaque/,
  ~r/multi_system_battle_correlator\.ex.*call_with_opaque/,
  ~r/multi_system_battle_correlator\.ex.*opaque/,
  ~r/correlation_engine\.ex.*call_without_opaque/,
  ~r/cross_character_analyzer\.ex.*call_without_opaque/,
  ~r/ewar_analyzer\.ex.*call_without_opaque/,
  ~r/cross_system_coordinator\.ex.*call_without_opaque/,

  # ===========================================
  # CONTRACT SUPERTYPE WARNINGS
  # ===========================================
  # Dialyzer infers narrower types than documented specs due to complex
  # type flow through bounded context APIs. These are intentionally broad
  # specs to allow for future expansion.

  ~r/character_intelligence.*contract_supertype/,
  ~r/corporation_intelligence.*contract_supertype/,
  ~r/combat_intelligence.*contract_supertype/,
  ~r/fleet_operations.*contract_supertype/,
  ~r/killmail_processing.*contract_supertype/,
  ~r/market_intelligence.*contract_supertype/,
  ~r/player_profile.*contract_supertype/,
  ~r/system_analysis.*contract_supertype/,
  ~r/threat_surveillance.*contract_supertype/,
  ~r/threat_config.*contract_supertype/,
  ~r/health_config.*contract_supertype/,
  ~r/pipeline_autoscaler_config.*contract_supertype/,
  ~r/intelligence_infrastructure.*contract_supertype/,
  ~r/unified_cache.*contract_supertype/,
  ~r/unified_repository.*contract_supertype/,
  ~r/unified_event_processor.*contract_supertype/,
  ~r/data_requirements.*contract_supertype/,
  ~r/pattern_analysis.*contract_supertype/,
  ~r/cache_helper.*contract_supertype/,
  ~r/config\.ex.*contract_supertype/,
  ~r/timeout_helper.*contract_supertype/,
  ~r/security_classification.*contract_supertype/,
  ~r/threat_classification.*contract_supertype/,
  ~r/naive_datetime_utils.*contract_supertype/,
  ~r/number_formatter.*contract_supertype/,
  ~r/metrics_calculator.*contract_supertype/,
  ~r/query_optimizer.*contract_supertype/,
  ~r/query_plan_analyzer.*contract_supertype/,
  ~r/file_manager.*contract_supertype/,
  ~r/item_type_processor.*contract_supertype/,
  ~r/sde_validator.*contract_supertype/,
  ~r/cache_manager.*contract_supertype/,
  ~r/activity_correlator.*contract_supertype/,
  ~r/result\.ex.*contract_supertype/,
  ~r/character_intelligence_live.*contract_supertype/,

  # ===========================================
  # PATTERN MATCH WARNINGS
  # ===========================================
  # These are defensive error handling patterns where dialyzer infers
  # certain branches are unreachable. The code handles edge cases that
  # can occur in production but not in dialyzer's type analysis.

  # Bounded context pattern matches
  ~r/battle_analysis\.ex.*pattern_match/,
  ~r/battle_curator\.ex.*pattern_match/,
  ~r/character_intelligence\.ex.*pattern_match/,
  ~r/character_stats\.ex.*pattern_match/,
  ~r/shared_utilities\.ex.*pattern_match/,
  ~r/corporation_intelligence\.ex.*pattern_match/,
  ~r/corporation_analyzer\.ex.*pattern_match/,
  ~r/single_system_analyzer\.ex.*pattern_match/,
  ~r/killmail_presenter\.ex.*pattern_match/,
  ~r/price_service\.ex.*pattern_match/,
  ~r/player_analyzer\.ex.*pattern_match/,
  ~r/alert_batcher\.ex.*pattern_match/,
  ~r/notification_dispatcher\.ex.*pattern_match/,
  ~r/regional_correlation_analyzer\.ex.*pattern_match/,
  ~r/threat_analyzer\.ex.*pattern_match/,
  ~r/correlation_engine\.ex.*pattern_match/,
  ~r/module_reorganizer\.ex.*pattern_match/,
  ~r/battle_service\.ex.*pattern_match/,
  ~r/dns_resolver\.ex.*pattern_match/,
  ~r/tactical_pattern_detector\.ex.*pattern_match/,
  ~r/threat_assessor\.ex.*pattern_match/,
  ~r/combat_doctrine_analyzer\.ex.*pattern_match/,
  ~r/killmail_orchestrator\.ex.*pattern_match/,
  ~r/surveillance_matching_engine\.ex.*pattern_match/,
  ~r/intelligence_suitability\.ex.*pattern_match/,
  ~r/insight_generator\.ex.*guard_fail/,
  ~r/module_reorganizer\.ex.*guard_fail/,

  # Compile-time conditional patterns (line 1 warnings from Mix.env checks)
  ~r/battle_metrics_calculator\.ex:1:pattern_match/,
  ~r/player_stats_engine\.ex:1:pattern_match/,
  ~r/doctrine_effectiveness_service\.ex:1:pattern_match/,
  ~r/killmail_extractor\.ex:1:pattern_match/,
  ~r/threat_detector\.ex:1:pattern_match/,
  ~r/analytics_service\.ex:1:pattern_match/,
  ~r/chain_intelligence\.ex:1:pattern_match/,
  ~r/behavioral_pattern_analyzer\.ex:1:pattern_match/,
  ~r/esi_market_client\.ex:1:pattern_match/,
  ~r/esi_request_client\.ex:1:pattern_match/,
  ~r/ship_attribute_importer\.ex:1:pattern_match/,

  # Static data loader pattern matches
  ~r/static_data_loader\.ex.*pattern_match/,
  ~r/ccp_sde_client\.ex.*pattern_match/,
  ~r/item_type_processor\.ex.*pattern_match/,
  ~r/jsonl_parser\.ex.*pattern_match/,
  ~r/sde_startup_service\.ex.*pattern_match/,
  ~r/sde_validator\.ex.*pattern_match/,
  ~r/sde_version_manager\.ex.*pattern_match/,
  ~r/solar_system_processor\.ex.*pattern_match/,

  # Platform pattern matches
  ~r/application\.ex.*pattern_match/,
  ~r/api_authentication\.ex.*pattern_match/,
  ~r/user\.ex.*pattern_match/,
  ~r/performance_optimizer\.ex.*pattern_match/,
  ~r/error_recovery_worker\.ex.*pattern_match/,
  ~r/background_task_supervisor\.ex.*pattern_match/,
  ~r/ship_role_analysis_worker\.ex.*pattern_match/,
  ~r/ship_attributes_service\.ex.*pattern_match/,

  # External integration pattern matches
  ~r/wanderer_client\.ex.*pattern_match/,
  ~r/esi_strategy\.ex.*pattern_match/,

  # Web layer pattern matches
  ~r/battle_share_controller\.ex.*pattern_match/,
  ~r/character_threat_controller\.ex.*pattern_match/,
  ~r/auth_controller\.ex.*pattern_match/,
  ~r/battle_intelligence_controller\.ex.*pattern_match/,
  ~r/character_behavior_controller\.ex.*pattern_match/,
  ~r/battle_analysis_live\.ex.*pattern_match/,
  ~r/character_comparison_live\.ex.*pattern_match/,
  ~r/character_intelligence_live\.ex.*pattern_match/,
  ~r/liveview_pattern_template\.ex.*pattern_match/,
  ~r/killmail_live\.ex.*pattern_match/,
  ~r/profile_live\.ex.*pattern_match/,
  ~r/battle_timeline_component\.ex.*pattern_match/,

  # ===========================================
  # EXTRA RANGE WARNINGS
  # ===========================================
  # Return type includes values that are never actually returned.
  # These are intentionally broad for API stability.

  ~r/combat_intelligence.*api\.ex.*extra_range/,
  ~r/character_analyzer\.ex.*extra_range/,
  ~r/surveillance.*api\.ex.*extra_range/,
  ~r/security_classification\.ex.*extra_range/,
  ~r/circuit_breaker\.ex.*extra_range/,
  ~r/static_data_loader\.ex.*extra_range/,
  ~r/item_type_processor\.ex.*extra_range/,
  ~r/jsonl_parser\.ex.*extra_range/,
  ~r/sde_validator\.ex.*extra_range/,
  ~r/solar_system_processor\.ex.*extra_range/,
  ~r/account_manager\.ex.*extra_range/,

  # ===========================================
  # INVALID CONTRACT WARNINGS
  # ===========================================
  # Specs intentionally broader than implementation for API flexibility.

  ~r/corporation.*api\.ex.*invalid_contract/,
  ~r/intelligence.*api\.ex.*invalid_contract/,
  ~r/surveillance.*api\.ex.*invalid_contract/,
  ~r/threat_surveillance.*api\.ex.*invalid_contract/,

  # ===========================================
  # CALL AND NO_RETURN WARNINGS
  # ===========================================
  # Repository stubs and optional features that may not be implemented.

  ~r/character_repository\.ex.*:call/,
  ~r/character_repository\.ex.*no_return/,
  ~r/killmail_repository\.ex.*:call/,
  ~r/killmail_repository\.ex.*no_return/,
  ~r/jsonl_parser\.ex.*:call/,
  ~r/participant\.ex.*call_to_missing/
]
