[
  # ===========================================
  # DIALYZER IGNORE FILE
  # ===========================================
  # This file contains patterns for known false positives only.
  # Real issues have been fixed in the codebase.
  #
  # Categories:
  # 1. MapSet opaque type warnings (Dialyzer limitation)
  # 2. Ash Framework metaprogramming (complex macros)
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
  ~r/cross_system_coordinator\.ex:\d+.*call_without_opaque/,

  # ===========================================
  # ASH FRAMEWORK METAPROGRAMMING
  # ===========================================
  # Ash uses extensive macros that Dialyzer can't analyze properly.
  # These are false positives from generated code.

  ~r/_repository\.ex:\d+:call/,
  ~r/_repository\.ex:\d+:no_return/,

  # ===========================================
  # COMPILE-TIME CONDITIONALS
  # ===========================================
  # Pattern matches at line 1 are from compile-time Mix.env checks.
  # Always true/false at compile time but code is valid.

  ~r/\.ex:1:pattern_match/
]
