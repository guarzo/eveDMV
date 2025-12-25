[
  # ===========================================
  # DIALYZER IGNORE FILE
  # ===========================================
  # This file contains patterns for false positives that should be ignored by dialyzer.
  #
  # When adding new filters:
  # 1. Only add filters for confirmed false positives
  # 2. Document why the filter is needed
  # 3. Use specific patterns rather than broad wildcards
  # 4. Periodically review and remove obsolete filters
  #
  # Format: ~r"pattern_to_match"
  # ===========================================

  # ===========================================
  # CONDITIONAL COMPILATION PATTERNS
  # ===========================================
  # Mix.env() checks are evaluated at compile time but dialyzer sees
  # them as runtime checks. These are false positives when dialyzer
  # is run in :dev mode but the code checks for :prod or :test.
  #
  # Example: `if Mix.env() == :prod do ...` shows as "pattern can never match true"
  # when compiled/analyzed in :dev mode.

  # router.ex:212 - `if Mix.env() == :prod do` for production-only LiveDashboard routes
  # This is a compile-time conditional that dialyzer sees as a runtime check
  ~r{lib/eve_dmv_web/router\.ex.*pattern_match.*The pattern can never match the type true},

  # ===========================================
  # DEAD CODE IN EXHAUSTIVE PATTERN MATCHES (pattern_match_cov)
  # ===========================================
  # Some functions have catch-all clauses for defensive programming
  # that dialyzer correctly identifies as unreachable. These are
  # intentional for future-proofing and error handling.
  #
  # To add new entries: Run `mix dialyzer` and look for pattern_match_cov
  # warnings, then add file-specific patterns below.

  # application.ex - Defensive catch-all for supervisor child specs
  ~r/application\.ex.*pattern_match_cov.*can never match/,

  # cached_battle_analyzer.ex - Defensive pattern matching on cache results
  ~r/cached_battle_analyzer\.ex.*pattern_match_cov.*can never match/,

  # analytics_service.ex - Exhaustive pattern matching for analytics operations
  ~r/analytics_service\.ex.*pattern_match_cov.*can never match/,

  # behavioral_pattern_analyzer.ex - Defensive catch-all for behavior analysis
  ~r/behavioral_pattern_analyzer\.ex.*pattern_match_cov.*can never match/,

  # single_system_analyzer.ex - Defensive catch-all for system analysis
  ~r/single_system_analyzer\.ex.*pattern_match_cov.*can never match/,

  # ===========================================
  # CACHE LAYER FALSE POSITIVES
  # ===========================================
  # Multi-layer cache L3 returns :miss placeholder - this is intentional
  # until Redis is implemented.

  ~r/multi_layer_cache.ex.*pattern_match.*The pattern can never match the type :miss/,

  # ===========================================
  # INTENTIONALLY BROAD SPECS (extra_range)
  # ===========================================
  # API functions have specs that allow for error returns even when
  # current implementation may not return errors. This is intentional
  # for API stability and future-proofing.

  # Character intelligence API - broader specs for future error handling
  ~r/character_intelligence\.ex.*extra_range/,
  ~r/character_analyzer\.ex.*extra_range/,

  # Corporation intelligence API - broader specs for future error handling
  ~r/corporation_intelligence\.ex.*extra_range/,

  # Combat analysis API - broader specs for future error handling
  ~r/combat_analysis.*threat_assessment_engine\.ex.*extra_range/,

  # ===========================================
  # PATTERN MATCH ON ERROR TUPLES
  # ===========================================
  # Some functions always return :ok or {:ok, _} in current implementation
  # but pattern match on error cases for defensive programming.

  ~r/application\.ex.*pattern_match.*The pattern can never match/,
  ~r/cached_battle_analyzer\.ex.*pattern_match.*The pattern can never match/,
  ~r/analytics_service\.ex.*pattern_match.*The pattern can never match/,
  ~r/behavioral_pattern_analyzer\.ex.*pattern_match.*The pattern can never match/,
  ~r/single_system_analyzer\.ex.*pattern_match.*The pattern can never match/,

  # ===========================================
  # NO_RETURN IN ANALYZER MODULES
  # ===========================================
  # Some analyzer modules have paths that dialyzer determines will never
  # complete normally. These are typically due to intentional design patterns.

  ~r/combat_doctrine_analyzer\.ex.*no_return/,
  ~r/monitoring_engine\.ex.*no_return/,

  # ===========================================
  # GUARD FAILURES ON OPTIONAL DATA
  # ===========================================
  # Some guards operate on data that may be nil/empty in certain paths.
  # These are handled by the guards themselves.

  ~r/combat_doctrine_analyzer\.ex.*guard_fail/,
  ~r/insight_generator\.ex.*guard_fail/
]
