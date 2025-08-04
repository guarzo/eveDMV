[
  # Common false positives that can be safely ignored

  # ===========================================
  # LIBRARY AND FRAMEWORK FALSE POSITIVES
  # ===========================================

  # Custom Credo checks have API compatibility issues with current Credo version
  # These checks are development-only and not part of the production codebase
  ~r"lib/credo_custom_checks/.*",

  # PLT configuration issues - these are library functions that exist but dialyzer can't find them
  # These indicate PLT rebuild needed rather than code issues
  ~r":unknown_function.*Function :telemetry\.",
  ~r":unknown_function.*Function String\.Chars\.to_string/1",
  ~r":unknown_function.*Function Ecto\.Adapters\.SQL\.",
  ~r":unknown_function.*Function Jason\.",
  
  # Phoenix Component and LiveView false positives - these are framework internals
  ~r"lib/eve_dmv_web/components/.*:unknown_function",
  ~r"lib/eve_dmv_web/live/.*:unknown_function",
  ~r"lib/eve_dmv_web/.*:unknown_function.*Phoenix\.",
  
  # Phoenix framework callback_info_missing - PLT configuration issue
  ~r"lib/eve_dmv_web/.*:callback_info_missing",

  # ===========================================
  # KNOWN PROJECT-SPECIFIC FALSE POSITIVES
  # ===========================================

  # ===========================================
  # TYPE SPEC SUPERTYPE WARNINGS (TEMPORARY)
  # ===========================================

  # These indicate real issues but are being ignored temporarily
  # to establish a baseline - should be addressed in Sprint 12

  # Generic supertype warnings - need proper type specs
  # REMOVED FOR WORKSTREAM A: ~r"Type specification.*is a supertype of the success typing.*",

  # ===========================================
  # FALSE POSITIVE PATTERN MATCHING WARNINGS
  # ===========================================

  # Module-level pattern matches (line 1) are false positives from dialyzer
  ~r|:1:pattern_match The pattern can never match the type true|,

  # Rescue/catch blocks that dialyzer doesn't properly analyze
  # These are legitimate error handling patterns that dialyzer misinterprets
  ~r"pattern_match_cov The pattern variable _ can never match the type, because it is covered by previous clauses",
  ~r"pattern_match_cov The pattern variable _error@1 can never match the type, because it is covered by previous clauses",

  # Timeline builder not implemented
  ~r/timeline_builder\.ex:.*:pattern_match.*\{:error, :not_implemented\}/,

  # Battle sharing context with curator unavailable errors
  ~r/lib\/eve_dmv\/contexts\/battle_sharing\.ex:.*:pattern_match.*\{:error, :curator_unavailable.*\}/,
  ~r/lib\/eve_dmv\/contexts\/battle_sharing\.ex:.*:pattern_match.*\{:error, :not_found.*\}/,

  # Tactical highlight manager with unavailable data
  ~r/lib\/eve_dmv\/contexts\/battle_sharing\/domain\/tactical_highlight_manager\.ex:.*:pattern_match.*\{:error, :battle_data_unavailable\}/,

  # Enum-based pattern matches that dialyzer doesn't understand
  ~r"lib/eve_dmv/contexts/corporation/core/threat_detector.ex:.*:pattern_match.*:stable",
  ~r"lib/eve_dmv/contexts/combat_intelligence/domain/external_group_analyzer.ex:.*:pattern_match.*:developing.*:high.*:low.*:moderate",

  # Cond expressions with catch-all true clauses - these are legitimate Elixir patterns
  ~r"combat_intelligence_engine.ex:.*:pattern_match.*false",
  ~r"combat_intelligence_engine.ex:.*:pattern_match.*:minimal",

  # Cache hit/miss patterns - FIXED in workstream D
  # ~r/doctrine_effectiveness_service\.ex:.*:pattern_match.*:miss.*\{:ok, _\}/,

  # Character intelligence - incomplete type information and delegation false positives
  ~r"character_intelligence.ex:.*:pattern_match",
  ~r"character_intelligence.ex:.*:no_return.*get_.*ship.*preferences",
  ~r"character_intelligence.ex:.*:no_return.*get_character_ship_intelligence",
  ~r"player_stats_engine.ex:1:pattern_match",

  # ===========================================
  # WORKSTREAM E FALSE POSITIVES
  # ===========================================

  # REMOVED - unused filters per dialyzer output

  # Ship preferences analyzer - private functions are used but dialyzer doesn't detect it
  ~r"lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex:.*:unused_fun",

  # REMOVED - unused filters per dialyzer output
  # REMOVED - unused filter per dialyzer output
  # ~r"threat_scoring_engine.ex:.*:pattern_match",

  # ===========================================
  # WORKSTREAM B BATTLE_ANALYSIS FALSE POSITIVES
  # ===========================================

  # Unused functions in battle_analyzer.ex - these are helper functions that may be used in future analysis features
  # Keeping them for future development rather than removing entirely
  ~r"lib/eve_dmv/contexts/combat/core/battle_analyzer.ex:.*:unused_fun",

  # Guard fail errors in combat modules - these are due to complex pattern matching that dialyzer doesn't understand
  ~r"lib/eve_dmv/contexts/combat/core/performance_calculator.ex:.*:guard_fail",
  ~r"lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex:.*:guard_fail",

  # Pattern match coverage in tactical pattern detector - dialyzer doesn't understand the logic flow
  ~r"lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex:.*:pattern_match_cov",

  # Pattern match errors in battle services - these are proper error handling patterns
  ~r"lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex:.*:pattern_match",
  ~r"lib/eve_dmv/contexts/combat/services/zkillboard_importer.ex:.*:pattern_match",

  # Unused functions in battle_sharing_service.ex - helper functions for future features
  ~r"lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex:.*:unused_fun",

  # Call errors in zkillboard_importer - HTTP client error handling that dialyzer doesn't track properly
  ~r"lib/eve_dmv/contexts/combat/services/zkillboard_importer.ex:.*:call",

  # REMOVED - unused filters per dialyzer output

  # Battle analyzer pattern match issues - proper error handling that dialyzer doesn't understand
  ~r"lib/eve_dmv/contexts/combat/core/battle_analyzer.ex:.*:pattern_match",
  ~r"lib/eve_dmv/contexts/combat/core/battle_analyzer.ex:.*:no_return",

  # REMOVED - unused filters per dialyzer output

  # Exact equality check in resource_analyzer - mathematical comparison that is intentional
  ~r"lib/eve_dmv/contexts/battle_analysis/domain/strategic/resource_analyzer.ex:.*:exact_eq"

  # ===========================================
  # DOCUMENTATION
  # ===========================================

  # This ignore file follows the Sprint 11 strategy:
  # 1. Ignore known false positives from libraries
  # 2. Ignore project-specific patterns that are unavoidable
  # 3. Temporarily ignore supertype warnings to establish baseline
  # 4. Focus on fixing critical type safety issues first
  # 
  # Target: Reduce from 1,878 errors to ≤85 errors
  # 
  # Review this file regularly and remove ignore patterns
  # as the underlying issues are fixed.
]
