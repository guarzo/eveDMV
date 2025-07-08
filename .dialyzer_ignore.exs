# Dialyzer ignore patterns
# Only include patterns for actual warnings from dependencies

[
  # PlayerStatsEngine pattern match issue - Dialyzer incorrectly infers boolean
  # calculation always returns true due to Ash's calculated field behavior
  {"lib/eve_dmv/analytics/player_stats_engine.ex", :pattern_match},

  # API Auth plug correctly halts on authentication failure - this is expected behavior
  # for Plug authentication middleware
  {"lib/eve_dmv_web/plugs/api_auth.ex", :no_return},

  # format_api_error_message is used in the error path which always halts,
  # so Dialyzer sees it as unused even though it's called
  {"lib/eve_dmv_web/plugs/api_auth.ex", :unused_fun},

  # Ash framework always returns exception maps for errors, so fallback patterns
  # in error formatting are unreachable but kept for defensive programming
  {"lib/eve_dmv_web/live/surveillance_live/profile_service.ex", :pattern_match_cov}
]
