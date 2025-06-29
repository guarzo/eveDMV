# Dialyzer ignore patterns
# Only include patterns for actual warnings from dependencies

[
  # Analytics engine pattern match issue - Dialyzer incorrectly infers boolean 
  # calculation always returns true due to Ash's calculated field behavior
  {"lib/eve_dmv/analytics/analytics_engine.ex", :pattern_match}
]
