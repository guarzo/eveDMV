# Manual Resolution: Variable Redeclaration Fixes (7 errors)

## Error Pattern: "Variable 'X' was declared more than once"

This error occurs when the same variable name is reused in a function, making the code harder to follow.

## Files to Fix:

### 1. lib/eve_dmv/contexts/corporation_analysis/analyzers/participation_analyzer.ex
**Line 608:5** - Variable "areas" redeclared

**Fix approach:**
```elixir
# BEFORE (Pattern):
areas = initial_calculation()
areas = enhance_areas(areas)  
areas = finalize_areas(areas)

# AFTER (Fixed):
initial_areas = initial_calculation()
enhanced_areas = enhance_areas(initial_areas)
final_areas = finalize_areas(enhanced_areas)
```

### 2. lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex
**Line 320:5** - Variable "recommendations" redeclared
**Line 416:5** - Variable "factors" redeclared

**Recommendations variable fix:**
```elixir
# BEFORE:
recommendations = []
recommendations = recommendations ++ get_basic_recs()
recommendations = recommendations ++ get_advanced_recs()

# AFTER:
initial_recommendations = []
basic_recommendations = initial_recommendations ++ get_basic_recs()
final_recommendations = basic_recommendations ++ get_advanced_recs()
```

**Factors variable fix:**
```elixir
# BEFORE:
factors = base_factors()
factors = apply_modifiers(factors)
factors = normalize_factors(factors)

# AFTER:
base_factors = base_factors()
modified_factors = apply_modifiers(base_factors)
normalized_factors = normalize_factors(modified_factors)
```

### 3. lib/eve_dmv/contexts/player_profile/formatters/character_display_formatter.ex
**Line 330:5** - Variable "recommendations" redeclared
**Line 354:5** - Variable "recommendations" redeclared

**Fix both recommendations variables:**
```elixir
# Look for patterns like:
recommendations = start_value
recommendations = add_more(recommendations)
recommendations = finalize(recommendations)

# Change to descriptive progression:
initial_recommendations = start_value
enhanced_recommendations = add_more(initial_recommendations)
final_recommendations = finalize(enhanced_recommendations)
```

### 4. lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex
**Line 613:5** - Variable "patterns" redeclared
**Line 697:5** - Variable "confidence_factors" redeclared  
**Line 718:5** - Variable "quality_score" redeclared

**Patterns variable fix:**
```elixir
# BEFORE:
patterns = detect_base_patterns()
patterns = enhance_patterns(patterns)
patterns = validate_patterns(patterns)

# AFTER:
base_patterns = detect_base_patterns()
enhanced_patterns = enhance_patterns(base_patterns)
validated_patterns = validate_patterns(enhanced_patterns)
```

**Confidence factors fix:**
```elixir
# BEFORE:
confidence_factors = initial_factors()
confidence_factors = add_analysis_factors(confidence_factors)
confidence_factors = weight_factors(confidence_factors)

# AFTER:
initial_confidence_factors = initial_factors()
analysis_confidence_factors = add_analysis_factors(initial_confidence_factors)
weighted_confidence_factors = weight_factors(analysis_confidence_factors)
```

**Quality score fix:**
```elixir
# BEFORE:
quality_score = base_score()
quality_score = adjust_score(quality_score)
quality_score = normalize_score(quality_score)

# AFTER:
base_quality_score = base_score()
adjusted_quality_score = adjust_score(base_quality_score)
final_quality_score = normalize_score(adjusted_quality_score)
```

## Step-by-Step Instructions:

1. **Open the file** and go to the line number
2. **Find the function** containing the redeclared variable
3. **Identify the pattern** - usually accumulator or builder pattern
4. **Rename variables** to show progression:
   - First assignment: `initial_X`, `base_X`, or `raw_X`
   - Middle assignments: `enhanced_X`, `processed_X`, `modified_X`
   - Final assignment: `final_X`, `result_X`, or keep original name

5. **Update all references** within the function to use new names
6. **Ensure the return value** uses the final variable name

## Common Variable Naming Patterns:

### For Recommendations:
- `initial_recommendations` → `enhanced_recommendations` → `final_recommendations`

### For Factors/Scores:
- `base_factors` → `weighted_factors` → `normalized_factors`
- `raw_score` → `adjusted_score` → `final_score`

### For Data Processing:
- `raw_data` → `processed_data` → `validated_data`
- `base_analysis` → `enhanced_analysis` → `complete_analysis`

### For Collections:
- `initial_items` → `filtered_items` → `sorted_items`
- `base_results` → `enhanced_results` → `final_results`

## Verification Steps:

After each fix:
1. **Read through the entire function** to ensure all variable references are updated
2. **Check that the logic flow is preserved** - each step should use the output of the previous step
3. **Verify the return value** uses the correct final variable
4. **Run `mix compile`** to catch any missed references
5. **The variable names should tell a story** of the data transformation

## Progress Tracking:
- [ ] contexts/corporation_analysis/analyzers/participation_analyzer.ex (areas)
- [ ] contexts/player_profile/domain/player_analyzer.ex (recommendations + factors)  
- [ ] contexts/player_profile/formatters/character_display_formatter.ex (2x recommendations)
- [ ] contexts/threat_assessment/analyzers/threat_analyzer.ex (patterns + confidence_factors + quality_score)

This should eliminate all 7 variable redeclaration errors and make the code much more readable.