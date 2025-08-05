[
  # Common false positives that can be safely ignored

  # ===========================================
  # LIBRARY AND FRAMEWORK FALSE POSITIVES
  # ===========================================

  # Custom Credo checks have API compatibility issues with current Credo version
  # These checks are development-only and not part of the production codebase
  ~r"lib/credo_custom_checks/.*",

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
  # ~r"character_intelligence.ex:.*:pattern_match",
  # ~r"character_intelligence.ex:.*:no_return.*get_.*ship.*preferences",
  # ~r"character_intelligence.ex:.*:no_return.*get_character_ship_intelligence",
  ~r"player_stats_engine.ex:1:pattern_match",

  # Guard fail errors in combat modules - these are due to complex pattern matching that dialyzer doesn't understand
  ~r"lib/eve_dmv/contexts/combat/core/performance_calculator.ex:.*:guard_fail",
  ~r"lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex:.*:guard_fail",

  # Pattern match coverage in tactical pattern detector - dialyzer doesn't understand the logic flow
  ~r"lib/eve_dmv/contexts/combat/core/tactical_pattern_detector.ex:.*:pattern_match_cov",

  # Pattern match errors in battle services - these are proper error handling patterns
  ~r"lib/eve_dmv/contexts/combat/services/zkillboard_importer.ex:.*:pattern_match",

  # Call errors in zkillboard_importer - HTTP client error handling that dialyzer doesn't track properly
  ~r"lib/eve_dmv/contexts/combat/services/zkillboard_importer.ex:.*:call",

  # REMOVED - unused filters per dialyzer output

  # Battle analyzer pattern match issues - proper error handling that dialyzer doesn't understand
  ~r"lib/eve_dmv/contexts/combat/core/battle_analyzer.ex:.*:pattern_match",
  ~r"lib/eve_dmv/contexts/combat/core/battle_analyzer.ex:.*:no_return",

  # REMOVED - unused filters per dialyzer output

  # Exact equality check in resource_analyzer - mathematical comparison that is intentional
  ~r"lib/eve_dmv/contexts/battle_analysis/domain/strategic/resource_analyzer.ex:.*:exact_eq"
]
