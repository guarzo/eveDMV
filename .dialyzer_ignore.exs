[
  # Common false positives that can be safely ignored

  # ===========================================
  # LIBRARY AND FRAMEWORK FALSE POSITIVES
  # ===========================================

  # Custom Credo checks have API compatibility issues with current Credo version
  # These checks are development-only and not part of the production codebase
  ~r"lib/credo_custom_checks/.*",

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

  # Character intelligence - incomplete type information
  ~r"character_intelligence.ex:.*:pattern_match",
  ~r"player_stats_engine.ex:1:pattern_match",

  # ===========================================
  # WORKSTREAM E FALSE POSITIVES
  # ===========================================

  # Phoenix LiveView component templates cause no_return false positives
  ~r"lib/eve_dmv_web/components/battle_timeline_component.ex:.*:no_return",
  ~r"lib/eve_dmv_web/components/battle_timeline_component.ex:.*:call",

  # Ship preferences analyzer - private functions are used but dialyzer doesn't detect it
  ~r"lib/eve_dmv/contexts/player_profile/analyzers/ship_preferences_analyzer.ex:.*:unused_fun",

  # Killmail processing API - Ash.read() can return errors but dialyzer doesn't track it properly
  ~r"lib/eve_dmv/contexts/killmail_processing/api.ex:.*:pattern_match.*\{:error, _reason\}",

  # Cond expressions with catch-all true clauses - legitimate Elixir patterns
  ~r"lib/eve_dmv/contexts/player_profile/analyzers/combat_stats_analyzer.ex:.*:pattern_match.*false"
  # REMOVED - unused filter per dialyzer output
  # ~r"threat_scoring_engine.ex:.*:pattern_match",

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
