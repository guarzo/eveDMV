# Dialyzer ignore patterns
# Only include patterns for actual warnings from dependencies

[
  # PlayerStatsEngine pattern match issue - Dialyzer incorrectly infers boolean
  # calculation always returns true due to Ash's calculated field behavior
  {"lib/eve_dmv/analytics/player_stats_engine.ex", :pattern_match}
]
