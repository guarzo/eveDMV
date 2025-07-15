[
  # Common false positives that can be safely ignored

  # ===========================================
  # LIBRARY AND FRAMEWORK FALSE POSITIVES
  # ===========================================

  # ===========================================
  # KNOWN PROJECT-SPECIFIC FALSE POSITIVES
  # ===========================================

  # ===========================================
  # GENERATED CODE FALSE POSITIVES
  # ===========================================

  # ===========================================
  # TELEMETRY AND MONITORING FALSE POSITIVES
  # ===========================================

  # ===========================================
  # TYPE SPEC SUPERTYPE WARNINGS (TEMPORARY)
  # ===========================================

  # These indicate real issues but are being ignored temporarily
  # to establish a baseline - should be addressed in Sprint 12

  # Generic supertype warnings - need proper type specs
  ~r"Type specification.*is a supertype of the success typing.*"

  # ===========================================
  # PATTERN MATCHING WARNINGS (TEMPORARY)
  # ===========================================

  # These indicate potential logic issues but are common in
  # external API integration code

  # ===========================================
  # TEMPORARY UNUSED VARIABLE SUPPRESSION
  # ===========================================

  # Temporarily ignore unused variable warnings to focus on type errors
  # These should be fixed after dialyzer issues are resolved

  # ===========================================
  # DOCUMENTATION
  # ===========================================

  # This ignore file follows the Sprint 11 strategy:
  # 1. Ignore known false positives from libraries
  # 2. Ignore project-specific patterns that are unavoidable
  # 3. Temporarily ignore supertype warnings to establish baseline
  # 4. Focus on fixing critical type safety issues first
  # 
  # Target: Reduce from 871 errors to ≤85 errors
  # 
  # Review this file regularly and remove ignore patterns
  # as the underlying issues are fixed.
]
