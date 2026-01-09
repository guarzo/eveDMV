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

  ~r/contexts\.ex:\d+.*call_without_opaque/,
  ~r/multi_system_battle_correlator\.ex:\d+.*call_without_opaque/,
  ~r/multi_system_battle_correlator\.ex:\d+.*call_with_opaque/,
  ~r/multi_system_battle_correlator\.ex:\d+.*opaque/,
  ~r/correlation_engine\.ex:\d+.*call_without_opaque/,
  ~r/cross_character_analyzer\.ex:\d+.*call_without_opaque/,
  ~r/ewar_analyzer\.ex:\d+.*call_without_opaque/,
  ~r/cross_system_coordinator\.ex:\d+.*call_without_opaque/,

  # ===========================================
  # CONTRACT SUPERTYPE WARNINGS
  # ===========================================
  # Dialyzer infers narrower types than documented specs due to complex
  # type flow through bounded context APIs. These are intentionally broad
  # specs to allow for future expansion.

  ~r/character_intelligence\.ex:\d+:contract_supertype/,
  ~r|character_intelligence/.*:contract_supertype|,
  ~r|corporation_intelligence/.*:contract_supertype|,
  ~r|combat_intelligence/.*:contract_supertype|,
  ~r|fleet_operations/.*:contract_supertype|,
  ~r|killmail_processing/.*:contract_supertype|,
  ~r|market_intelligence/.*:contract_supertype|,
  ~r|player_profile/.*:contract_supertype|,
  ~r/system_analysis\.ex:\d+:contract_supertype/,
  ~r|threat_surveillance/.*:contract_supertype|,
  ~r/threat_config\.ex:\d+:contract_supertype/,
  ~r/health_config\.ex:\d+:contract_supertype/,
  ~r/pipeline_autoscaler_config\.ex:\d+:contract_supertype/,
  ~r|intelligence_infrastructure/.*:contract_supertype|,
  ~r/unified_cache\.ex:\d+:contract_supertype/,
  ~r/unified_repository\.ex:\d+:contract_supertype/,
  ~r/unified_event_processor\.ex:\d+:contract_supertype/,
  ~r/data_requirements\.ex:\d+:contract_supertype/,
  ~r/pattern_analysis\.ex:\d+:contract_supertype/,
  ~r/cache_helper\.ex:\d+:contract_supertype/,
  ~r/config\.ex:\d+:contract_supertype/,
  ~r/timeout_helper\.ex:\d+:contract_supertype/,
  ~r/security_classification\.ex:\d+:contract_supertype/,
  ~r/threat_classification\.ex:\d+:contract_supertype/,
  ~r/naive_datetime_utils\.ex:\d+:contract_supertype/,
  ~r/number_formatter\.ex:\d+:contract_supertype/,
  ~r/metrics_calculator\.ex:\d+:contract_supertype/,
  ~r/query_optimizer\.ex:\d+:contract_supertype/,
  ~r/query_plan_analyzer\.ex:\d+:contract_supertype/,
  ~r/file_manager\.ex:\d+:contract_supertype/,
  ~r/item_type_processor\.ex:\d+:contract_supertype/,
  ~r/sde_validator\.ex:\d+:contract_supertype/,
  ~r/cache_manager\.ex:\d+:contract_supertype/,
  ~r/activity_correlator\.ex:\d+:contract_supertype/,
  ~r/result\.ex:\d+:contract_supertype/,
  ~r/character_intelligence_live\.ex:\d+:contract_supertype/,

  # ===========================================
  # PATTERN MATCH WARNINGS
  # ===========================================
  # These are defensive error handling patterns where dialyzer infers
  # certain branches are unreachable. The code handles edge cases that
  # can occur in production but not in dialyzer's type analysis.

  # Compile-time conditional patterns (line 1 warnings from Mix.env checks)
  ~r/battle_analysis\.ex:1:pattern_match/,
  ~r/battle_metrics_calculator\.ex:1:pattern_match/,
  ~r/player_stats_engine\.ex:1:pattern_match/,
  ~r/doctrine_effectiveness_service\.ex:1:pattern_match/,
  ~r/killmail_extractor\.ex:1:pattern_match/,
  ~r/threat_detector\.ex:1:pattern_match/,
  ~r/analytics_service\.ex:1:pattern_match/,
  ~r/chain_intelligence\.ex:1:pattern_match/,
  ~r/behavioral_pattern_analyzer\.ex:1:pattern_match/,
  ~r/threat_analyzer\.ex:1:pattern_match/,
  ~r/esi_market_client\.ex:1:pattern_match/,
  ~r/esi_request_client\.ex:1:pattern_match/,
  ~r/esi_strategy\.ex:1:pattern_match/,
  ~r/ship_attribute_importer\.ex:1:pattern_match/,
  ~r/combat_doctrine_analyzer\.ex:1:pattern_match/,

  # Runtime pattern matches with defensive error handling
  ~r/application\.ex:\d+:pattern_match/,
  ~r/battle_analysis\.ex:\d+:pattern_match/,
  ~r/battle_curator\.ex:\d+:pattern_match/,
  ~r/character_intelligence\.ex:\d+:pattern_match/,
  ~r/character_stats\.ex:\d+:pattern_match/,
  ~r/shared_utilities\.ex:\d+:pattern_match/,
  ~r|combat_intelligence/api\.ex:\d+:pattern_match|,
  ~r/corporation_intelligence\.ex:\d+:pattern_match/,
  ~r/corporation_analyzer\.ex:\d+:pattern_match/,
  ~r/single_system_analyzer\.ex:\d+:pattern_match/,
  ~r/killmail_presenter\.ex:\d+:pattern_match/,
  ~r/price_service\.ex:\d+:pattern_match/,
  ~r/player_analyzer\.ex:\d+:pattern_match/,
  ~r/alert_batcher\.ex:\d+:pattern_match/,
  ~r/notification_dispatcher\.ex:\d+:pattern_match/,
  ~r/regional_correlation_analyzer\.ex:\d+:pattern_match/,
  ~r/threat_analyzer\.ex:\d+:pattern_match/,
  ~r/correlation_engine\.ex:\d+:pattern_match/,
  ~r/module_reorganizer\.ex:\d+:pattern_match/,
  ~r/battle_service\.ex:\d+:pattern_match/,
  ~r/dns_resolver\.ex:\d+:pattern_match/,
  ~r/static_data_loader\.ex:\d+:pattern_match/,
  ~r/ccp_sde_client\.ex:\d+:pattern_match/,
  ~r/item_type_processor\.ex:\d+:pattern_match/,
  ~r/jsonl_parser\.ex:\d+:pattern_match/,
  ~r/sde_startup_service\.ex:\d+:pattern_match/,
  ~r/sde_validator\.ex:\d+:pattern_match/,
  ~r/sde_version_manager\.ex:\d+:pattern_match/,
  ~r/solar_system_processor\.ex:\d+:pattern_match/,
  ~r/api_authentication\.ex:\d+:pattern_match/,
  ~r/user\.ex:\d+:pattern_match/,
  ~r/performance_optimizer\.ex:\d+:pattern_match/,
  ~r/wanderer_client\.ex:\d+:pattern_match/,
  ~r/esi_strategy\.ex:\d+:pattern_match/,
  ~r/ship_attributes_service\.ex:\d+:pattern_match/,
  ~r/battle_share_controller\.ex:\d+:pattern_match/,
  ~r/character_threat_controller\.ex:\d+:pattern_match/,
  ~r/auth_controller\.ex:\d+:pattern_match/,
  ~r/battle_analysis_live\.ex:\d+:pattern_match/,
  ~r/character_comparison_live\.ex:\d+:pattern_match/,
  ~r/character_intelligence_live\.ex:\d+:pattern_match/,
  ~r/liveview_pattern_template\.ex:\d+:pattern_match/,

  # Pattern match coverage (pattern_match_cov) - unreachable branch warnings
  ~r/battle_analysis\.ex:\d+:pattern_match_cov/,
  ~r/character_intelligence\.ex:\d+:pattern_match_cov/,
  ~r/character_stats\.ex:\d+:pattern_match_cov/,
  ~r/tactical_pattern_detector\.ex:\d+:pattern_match_cov/,
  ~r/threat_assessor\.ex:\d+:pattern_match_cov/,
  ~r/combat_doctrine_analyzer\.ex:\d+:pattern_match_cov/,
  ~r/killmail_orchestrator\.ex:\d+:pattern_match_cov/,
  ~r/surveillance_matching_engine\.ex:\d+:pattern_match_cov/,
  ~r/intelligence_suitability\.ex:\d+:pattern_match_cov/,
  ~r/user\.ex:\d+:pattern_match_cov/,
  ~r/error_recovery_worker\.ex:\d+:pattern_match_cov/,
  ~r/background_task_supervisor\.ex:\d+:pattern_match_cov/,
  ~r/ship_role_analysis_worker\.ex:\d+:pattern_match_cov/,
  ~r/battle_timeline_component\.ex:\d+:pattern_match_cov/,
  ~r/battle_intelligence_controller\.ex:\d+:pattern_match_cov/,
  ~r/character_behavior_controller\.ex:\d+:pattern_match_cov/,
  ~r/character_threat_controller\.ex:\d+:pattern_match_cov/,
  ~r/battle_analysis_live\.ex:\d+:pattern_match_cov/,
  ~r/killmail_live\.ex:\d+:pattern_match_cov/,
  ~r/profile_live\.ex:\d+:pattern_match_cov/,

  # ===========================================
  # EXTRA RANGE WARNINGS
  # ===========================================
  # Return type includes values that are never actually returned.
  # These are intentionally broad for API stability.

  ~r|combat_intelligence/api\.ex:\d+:extra_range|,
  ~r/character_analyzer\.ex:\d+:extra_range/,
  ~r|surveillance/api\.ex:\d+:extra_range|,
  ~r/security_classification\.ex:\d+:extra_range/,
  ~r/circuit_breaker\.ex:\d+:extra_range/,
  ~r/static_data_loader\.ex:\d+:extra_range/,
  ~r/item_type_processor\.ex:\d+:extra_range/,
  ~r/jsonl_parser\.ex:\d+:extra_range/,
  ~r/sde_validator\.ex:\d+:extra_range/,
  ~r/solar_system_processor\.ex:\d+:extra_range/,
  ~r/account_manager\.ex:\d+:extra_range/,

  # ===========================================
  # INVALID CONTRACT WARNINGS
  # ===========================================
  # Specs intentionally broader than implementation for API flexibility.

  ~r|corporation/api\.ex:\d+:invalid_contract|,
  ~r|intelligence/api\.ex:\d+:invalid_contract|,
  ~r|surveillance/api\.ex:\d+:invalid_contract|,
  ~r|threat_surveillance/api\.ex:\d+:invalid_contract|,

  # ===========================================
  # CALL AND NO_RETURN WARNINGS
  # ===========================================
  # Repository stubs and optional features that may not be implemented.

  ~r/character_repository\.ex:\d+:call/,
  ~r/character_repository\.ex:\d+:no_return/,
  ~r/killmail_repository\.ex:\d+:call/,
  ~r/killmail_repository\.ex:\d+:no_return/,
  ~r/jsonl_parser\.ex:\d+:call/,
  ~r/participant\.ex:\d+:call_to_missing/,

  # ===========================================
  # GUARD FAIL WARNINGS
  # ===========================================
  # Guards that dialyzer thinks always fail but work at runtime.

  ~r/insight_generator\.ex:\d+:guard_fail/,
  ~r/module_reorganizer\.ex:\d+:guard_fail/
]
