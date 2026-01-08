[
  # ===========================================
  # DIALYZER IGNORE FILE
  # ===========================================
  # This file contains patterns for known false positives only.
  # Real issues have been fixed in the codebase.
  #
  # Categories:
  # 1. MapSet opaque type warnings (Dialyzer limitation)
  # 2. Repository-specific suppressions (if needed)
  # 3. Compile-time conditionals (Mix.env checks)
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
  ~r/cross_system_coordinator\.ex:\d+.*call_without_opaque/

  # ===========================================
  # REPOSITORY-SPECIFIC SUPPRESSIONS
  # ===========================================
  # Previously used broad patterns (~r/_repository\.ex:\d+:call/ and
  # ~r/_repository\.ex:\d+:no_return/) have been removed as they were too
  # broad. If repository warnings resurface, add targeted suppressions for
  # specific repository files below.
  #
  # Known repository files in the codebase:
  # - unified_repository.ex (main consolidated repository)
  # - killmail_repository.ex (platform/database and platform/database/repositories)
  # - character_repository.ex (platform/database and platform/database/repositories)
  # - corporation_repository.ex (platform/database)
  # - surveillance_repository.ex (platform/database)
  # - fleet_repository.ex (contexts/fleet_operations/infrastructure)
  # - profile_repository.ex (contexts/surveillance/infrastructure)
  # - player_repository.ex (contexts/player_profile/infrastructure)
  #
  # No active repository suppressions needed at this time.

  # ===========================================
  # COMPILE-TIME CONDITIONALS
  # ===========================================
  # No compile-time conditional suppressions currently needed.
  # If pattern_match warnings appear at line 1 from Mix.env checks,
  # add targeted suppressions for specific files here, e.g.:
  # ~r/specific_file\.ex:1:pattern_match/
]
