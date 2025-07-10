# Dialyzer ignore patterns
# Only include patterns for actual warnings from dependencies and known false positives

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
  {"lib/eve_dmv_web/live/surveillance_live/profile_service.ex", :pattern_match_cov},

  # Common Phoenix/LiveView patterns that Dialyzer struggles with
  ~r/.*live_view.*handle_params.*no_return/,
  ~r/.*live_view.*handle_event.*no_return/,
  ~r/.*live_view.*handle_info.*no_return/,

  # Ash framework patterns
  ~r/.*ash.*callback_not_exported/,
  ~r/.*ash.*behaviour_undefined/,

  # Phoenix patterns
  ~r/.*phoenix.*callback_not_exported/,
  ~r/.*plug.*callback_not_exported/,

  # Broadway patterns
  ~r/.*broadway.*callback_not_exported/,

  # Common dependency warnings we can't fix
  ~r/.*deps.*no_return/,
  ~r/.*deps.*unused_fun/
]
