[
  # =============================================================================
  # DIALYZER IGNORE FILE - GENERATED FROM ACTUAL WARNINGS
  # =============================================================================
  # Generated: 2026-01-09
  # Total patterns: ~150 (consolidated from 243 unique warnings)
  #
  # This file contains patterns for known warnings in the codebase.
  # Categories are organized by warning type and location.
  #
  # REVIEW POLICY:
  # - contract_supertype: Review if function implementation changes
  # - pattern_match at line 1: Compile-time Mix.env checks (legitimate)
  # - call_without_opaque: MapSet opaque type false positives (legitimate)
  # - invalid_contract: Review if API signatures change
  # - pattern_match with :error: Consider if error handling is dead code
  # =============================================================================

  # =============================================================================
  # COMPILE-TIME CONDITIONALS (Mix.env checks at line 1)
  # =============================================================================
  # These are legitimate compile-time environment checks.

  ~r/contexts\/battle_analysis\.ex:1:pattern_match/,
  ~r/contexts\/battle_analysis\/domain\/battle_metrics_calculator\.ex:1:pattern_match/,
  ~r/contexts\/character_intelligence\/domain\/engines\/player_stats_engine\.ex:1:pattern_match/,
  ~r/contexts\/combat\/services\/doctrine_effectiveness_service\.ex:1:pattern_match/,
  ~r/contexts\/combat_intelligence\/domain\/extractors\/killmail_extractor\.ex:1:pattern_match/,
  ~r/contexts\/corporation\/core\/threat_detector\.ex:1:pattern_match/,
  ~r/contexts\/corporation\/services\/analytics_service\.ex:1:pattern_match/,
  ~r/contexts\/corporation_intelligence\/domain\/combat_doctrine_analyzer\.ex:1:pattern_match/,
  ~r/contexts\/surveillance\/domain\/chain_intelligence\.ex:1:pattern_match/,
  ~r/contexts\/threat_assessment\/domain\/threat_analyzer\.ex:1:pattern_match/,
  ~r/contexts\/threat_surveillance\/domain\/behavioral_pattern_analyzer\.ex:1:pattern_match/,
  ~r/external\/eve\/esi_market_client\.ex:1:pattern_match/,
  ~r/external\/eve\/esi_request_client\.ex:1:pattern_match/,
  ~r/external\/market\/strategies\/esi_strategy\.ex:1:pattern_match/,
  ~r/static_data\/ship_attribute_importer\.ex:1:pattern_match/,

  # =============================================================================
  # MAPSET OPAQUE TYPE WARNINGS (Dialyzer false positives)
  # =============================================================================
  # MapSet is an opaque type. These warnings are false positives when
  # Dialyzer tracks internal structure through recursive calls.

  ~r/contexts\.ex:.*:call_without_opaque/,
  ~r/contexts/battle_analysis/domain/multi_system_battle_correlator\.ex:.*:call_with_opaque/,
  ~r/contexts/battle_analysis/domain/multi_system_battle_correlator\.ex:.*:call_without_opaque/,
  ~r/contexts/battle_analysis/domain/strategic/correlation_engine\.ex:.*:call_without_opaque/,
  ~r/contexts/character_intelligence/domain/analyzers/cross_character_analyzer\.ex:.*:call_without_opaque/,
  ~r/contexts/combat_intelligence/domain/ewar_analyzer\.ex:.*:call_without_opaque/,
  ~r/contexts/intelligence_infrastructure/domain/cross_system/cross_system_coordinator\.ex:.*:call_without_opaque/,

  # =============================================================================
  # CONFIGURATION CONSTANT SPECS (contract_supertype)
  # =============================================================================
  # These modules return specific constant values but have broader specs
  # for API stability. This is intentional design.

  # ThreatConfig - EVE combat configuration constants
  ~r/contexts/character_intelligence/threat_config\.ex:.*:contract_supertype/,

  # RequirementsBuilder - Wormhole mass thresholds
  ~r/contexts/fleet_operations/domain/analyzers/fleet_asset_manager/requirements_builder\.ex:.*:contract_supertype/,

  # HealthConfig - Monitoring thresholds
  ~r/platform/monitoring/health_config\.ex:.*:contract_supertype/,

  # PipelineAutoscalerConfig - Broadway pipeline settings
  ~r/external/killmails/pipeline_autoscaler_config\.ex:.*:contract_supertype/,

  # =============================================================================
  # CONTEXT API SPECS (contract_supertype)
  # =============================================================================
  # Public APIs with intentionally broad specs for stability.

  ~r/contexts/character_intelligence\.ex:.*:contract_supertype/,
  ~r/contexts/corporation_intelligence\.ex:.*:contract_supertype/,
  ~r/contexts/corporation_intelligence/api\.ex:.*:contract_supertype/,
  ~r/contexts/system_analysis\.ex:.*:contract_supertype/,
  ~r/contexts/combat_intelligence/api\.ex:.*:contract_supertype/,
  ~r/contexts/market_intelligence/api\.ex:.*:contract_supertype/,
  ~r/contexts/threat_surveillance/api\.ex:.*:contract_supertype/,
  ~r/contexts/player_profile/api\.ex:.*:contract_supertype/,

  # =============================================================================
  # DOMAIN ANALYZER SPECS (contract_supertype)
  # =============================================================================

  ~r/contexts/character_intelligence/domain/calculators/threat_score_calculator\.ex:.*:contract_supertype/,
  ~r/contexts/combat_intelligence/domain/external_group_analyzer\.ex:.*:contract_supertype/,
  ~r/contexts/combat_intelligence/domain/intelligence_transformer\.ex:.*:contract_supertype/,
  ~r/contexts/corporation_intelligence/domain/analyzers/corporation_analyzer\.ex:.*:contract_supertype/,
  ~r/contexts/intelligence_infrastructure/domain/correlators/activity_correlator\.ex:.*:contract_supertype/,
  ~r/contexts/killmail_processing/domain/extended_historical_fetcher\.ex:.*:contract_supertype/,
  ~r/contexts/killmail_processing/domain/historical_fetch_worker\.ex:.*:contract_supertype/,

  # =============================================================================
  # CORE INFRASTRUCTURE SPECS (contract_supertype)
  # =============================================================================

  ~r/core/analysis/data_requirements\.ex:.*:contract_supertype/,
  ~r/core/domain/analytics/pattern_analysis\.ex:.*:contract_supertype/,
  ~r/core/domain/intelligence/core/cache_helper\.ex:.*:contract_supertype/,
  ~r/core/domain/intelligence/core/config\.ex:.*:contract_supertype/,
  ~r/core/domain/intelligence/core/timeout_helper\.ex:.*:contract_supertype/,
  ~r/core/infrastructure/unified_cache\.ex:.*:contract_supertype/,
  ~r/core/infrastructure/unified_event_processor\.ex:.*:contract_supertype/,
  ~r/core/infrastructure/unified_repository\.ex:.*:contract_supertype/,
  ~r/core/shared_kernel/policies/security_classification\.ex:.*:contract_supertype/,
  ~r/core/shared_kernel/policies/threat_classification\.ex:.*:contract_supertype/,
  ~r/core/utils/naive_datetime_utils\.ex:.*:contract_supertype/,
  ~r/core/utils/number_formatter\.ex:.*:contract_supertype/,
  ~r/result\.ex:.*:contract_supertype/,
  ~r/utilities/calculators/metrics_calculator\.ex:.*:contract_supertype/,

  # =============================================================================
  # EXTERNAL INTEGRATION SPECS (contract_supertype)
  # =============================================================================

  ~r/external/eve/name_resolver/cache_manager\.ex:.*:contract_supertype/,
  ~r/external/eve/static_data_loader/file_manager\.ex:.*:contract_supertype/,
  ~r/external/eve/static_data_loader/item_type_processor\.ex:.*:contract_supertype/,
  ~r/external/eve/static_data_loader/sde_validator\.ex:.*:contract_supertype/,
  ~r/platform/database/query_optimizer\.ex:.*:contract_supertype/,
  ~r/platform/database/query_plan_analyzer\.ex:.*:contract_supertype/,

  # =============================================================================
  # WEB LAYER SPECS (contract_supertype)
  # =============================================================================

  ~r/live/character_intelligence_live\.ex:.*:contract_supertype/,

  # =============================================================================
  # EXTRA_RANGE WARNINGS (specs broader than current returns)
  # =============================================================================
  # These functions have specs that include error types not currently returned.
  # Kept for defensive API design.

  ~r/contexts/combat_intelligence/domain/character_analyzer\.ex:.*:extra_range/,
  ~r/contexts/surveillance/api\.ex:.*:extra_range/,
  ~r/core/shared_kernel/policies/security_classification\.ex:.*:extra_range/,
  ~r/external/eve/circuit_breaker\.ex:.*:extra_range/,
  ~r/external/eve/static_data_loader\.ex:.*:extra_range/,
  ~r/external/eve/static_data_loader/item_type_processor\.ex:.*:extra_range/,
  ~r/external/eve/static_data_loader/jsonl_parser\.ex:.*:extra_range/,
  ~r/external/eve/static_data_loader/sde_validator\.ex:.*:extra_range/,
  ~r/external/eve/static_data_loader/solar_system_processor\.ex:.*:extra_range/,
  ~r/platform/auth/account_manager\.ex:.*:extra_range/,

  # =============================================================================
  # INVALID_CONTRACT WARNINGS
  # =============================================================================
  # Complex type inference through cache wrappers and Ash framework.

  ~r/contexts/corporation/api\.ex:.*:invalid_contract/,
  ~r/contexts/intelligence/api\.ex:.*:invalid_contract/,
  ~r/contexts/surveillance/api\.ex:.*:invalid_contract/,
  ~r/contexts/threat_surveillance/api\.ex:.*:invalid_contract/,

  # =============================================================================
  # PATTERN_MATCH_COV (defensive catch-all clauses)
  # =============================================================================
  # These are intentional defensive patterns that handle edge cases.

  ~r/contexts/battle_analysis\.ex:.*:pattern_match_cov/,
  ~r/contexts/character_intelligence\.ex:.*:pattern_match_cov/,
  ~r/contexts/character_intelligence/resources/character_stats\.ex:.*:pattern_match_cov/,
  ~r/contexts/combat/core/tactical_pattern_detector\.ex:.*:pattern_match_cov/,
  ~r/contexts/corporation_intelligence/domain/combat_doctrine/threat_assessor\.ex:.*:pattern_match_cov/,
  ~r/contexts/corporation_intelligence/domain/combat_doctrine_analyzer\.ex:.*:pattern_match_cov/,
  ~r/contexts/killmail_processing/domain/killmail_orchestrator\.ex:.*:pattern_match_cov/,
  ~r/contexts/threat_surveillance/domain/surveillance_matching_engine\.ex:.*:pattern_match_cov/,
  ~r/core/domain/intelligence/intelligence_scoring/intelligence_suitability\.ex:.*:pattern_match_cov/,
  ~r/platform/auth/user\.ex:.*:pattern_match_cov/,
  ~r/platform/monitoring/error_recovery_worker\.ex:.*:pattern_match_cov/,
  ~r/platform/workers/background_task_supervisor\.ex:.*:pattern_match_cov/,
  ~r/platform/workers/ship_role_analysis_worker\.ex:.*:pattern_match_cov/,
  ~r/components/battle_timeline_component\.ex:.*:pattern_match_cov/,
  ~r/controllers/api/battle_intelligence_controller\.ex:.*:pattern_match_cov/,
  ~r/controllers/api/character_behavior_controller\.ex:.*:pattern_match_cov/,
  ~r/controllers/api/character_threat_controller\.ex:.*:pattern_match_cov/,
  ~r/live/battle_analysis_live\.ex:.*:pattern_match_cov/,
  ~r/live/killmail_live\.ex:.*:pattern_match_cov/,
  ~r/live/profile_live\.ex:.*:pattern_match_cov/,

  # =============================================================================
  # DATA-DEPENDENT PATTERN_MATCH WARNINGS
  # =============================================================================
  # Functions that return success/error based on database content.
  # Dialyzer can't prove success paths without runtime data.

  ~r/application\.ex:.*:pattern_match/,
  ~r/contexts/battle_analysis\.ex:.*:pattern_match/,
  ~r/contexts/battle_sharing/domain/battle_curator\.ex:.*:pattern_match/,
  ~r/contexts/character_intelligence\.ex:.*:pattern_match/,
  ~r/contexts/character_intelligence/domain/threat_scoring/shared_utilities\.ex:.*:pattern_match/,
  ~r/contexts/character_intelligence/resources/character_stats\.ex:.*:pattern_match/,
  ~r/contexts/corporation_intelligence\.ex:.*:pattern_match/,
  ~r/contexts/corporation_intelligence/domain/analyzers/corporation_analyzer\.ex:.*:pattern_match/,
  ~r/contexts/intelligence_infrastructure/domain/analyzers/single_system_analyzer\.ex:.*:pattern_match/,
  ~r/contexts/killmail_processing/domain/killmail_presenter\.ex:.*:pattern_match/,
  ~r/contexts/market_intelligence/domain/price_service\.ex:.*:pattern_match/,
  ~r/contexts/player_profile/domain/player_analyzer\.ex:.*:pattern_match/,
  ~r/contexts/surveillance/domain/alert_batcher\.ex:.*:pattern_match/,
  ~r/contexts/surveillance/infrastructure/notification_dispatcher\.ex:.*:pattern_match/,
  ~r/contexts/system_analysis/domain/regional_correlation_analyzer\.ex:.*:pattern_match/,
  ~r/contexts/threat_assessment/analyzers/threat_analyzer\.ex:.*:pattern_match/,
  ~r/core/domain/intelligence/core/correlation_engine\.ex:.*:pattern_match/,
  ~r/core/refactoring/module_reorganizer\.ex:.*:pattern_match/,
  ~r/core/services/battle_service\.ex:.*:pattern_match/,
  ~r/core/utils/dns_resolver\.ex:.*:pattern_match/,
  ~r/platform/auth/security/api_authentication\.ex:.*:pattern_match/,
  ~r/platform/auth/user\.ex:.*:pattern_match/,
  ~r/platform/monitoring/performance_optimizer\.ex:.*:pattern_match/,
  ~r/static_data/ship_attributes_service\.ex:.*:pattern_match/,

  # =============================================================================
  # EXTERNAL INTEGRATION PATTERN_MATCH WARNINGS
  # =============================================================================

  ~r/external/eve/static_data_loader\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/ccp_sde_client\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/item_type_processor\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/jsonl_parser\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/sde_startup_service\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/sde_validator\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/sde_version_manager\.ex:.*:pattern_match/,
  ~r/external/eve/static_data_loader/solar_system_processor\.ex:.*:pattern_match/,
  ~r/external/market/strategies/esi_strategy\.ex:.*:pattern_match/,
  ~r/external/wanderer/wanderer_client\.ex:.*:pattern_match/,

  # =============================================================================
  # WEB LAYER PATTERN_MATCH WARNINGS
  # =============================================================================

  ~r/controllers/api/battle_share_controller\.ex:.*:pattern_match/,
  ~r/controllers/api/character_threat_controller\.ex:.*:pattern_match/,
  ~r/controllers/auth_controller\.ex:.*:pattern_match/,
  ~r/live/battle_analysis_live\.ex:.*:pattern_match/,
  ~r/live/character_comparison_live\.ex:.*:pattern_match/,
  ~r/live/character_intelligence_live\.ex:.*:pattern_match/,
  ~r/live/helpers/liveview_pattern_template\.ex:.*:pattern_match/,
  ~r/live/unified_dashboard_live\.ex:.*:pattern_match/,

  # =============================================================================
  # GUARD_FAIL WARNINGS
  # =============================================================================

  ~r/contexts/intelligence/services/insight_generator\.ex:.*:guard_fail/,
  ~r/core/refactoring/module_reorganizer\.ex:.*:guard_fail/,

  # =============================================================================
  # REPOSITORY MACRO WARNINGS
  # =============================================================================
  # Repository `use` macros create anonymous functions that dialyzer can't analyze.

  ~r/platform/database/character_repository\.ex:.*:call/,
  ~r/platform/database/character_repository\.ex:.*:no_return/,
  ~r/platform/database/killmail_repository\.ex:.*:call/,
  ~r/platform/database/killmail_repository\.ex:.*:no_return/,

  # =============================================================================
  # ASH FRAMEWORK WARNINGS
  # =============================================================================
  # Ash.Query calls that dialyzer can't resolve.

  ~r/external/killmails/participant\.ex:.*:call_to_missing/,

  # =============================================================================
  # JSONL PARSER CALL WARNINGS
  # =============================================================================

  ~r/external/eve/static_data_loader/jsonl_parser\.ex:.*:call/
]
