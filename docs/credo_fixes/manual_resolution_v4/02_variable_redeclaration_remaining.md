# Remaining Variable Redeclaration Fixes (36 errors)

Based on current credo.txt, here are the remaining variable redeclaration errors.

## Error Pattern: "Variable 'X' was declared more than once"

### Files to Fix:

### 1. lib/eve_dmv/intelligence/alert_system.ex
**Lines 170:5, 229:5, 265:5** - Variable "alerts" redeclared (3 instances)

**Fix Pattern:**
```elixir
# BEFORE:
alerts = initial_alerts()
alerts = add_threat_alerts(alerts, data)
alerts = add_activity_alerts(alerts, data)
alerts = prioritize_alerts(alerts)

# AFTER:
initial_alerts = initial_alerts()
threat_alerts = add_threat_alerts(initial_alerts, data)
activity_alerts = add_activity_alerts(threat_alerts, data)
final_alerts = prioritize_alerts(activity_alerts)
```

### 2. lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/readiness_analyzer.ex
**Line 282:5** - Variable "recommendations"

**Fix Pattern:**
```elixir
# BEFORE:
recommendations = base_recommendations()
recommendations = add_readiness_recs(recommendations)
recommendations = add_asset_recs(recommendations)

# AFTER:
base_recommendations = base_recommendations()
readiness_recommendations = add_readiness_recs(base_recommendations)
final_recommendations = add_asset_recs(readiness_recommendations)
```

### 3. lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex
**Line 426:5** - Variable "gaps"

**Fix Pattern:**
```elixir
# BEFORE:
gaps = identify_initial_gaps()
gaps = analyze_coverage_gaps(gaps)
gaps = prioritize_gaps(gaps)

# AFTER:
initial_gaps = identify_initial_gaps()
coverage_gaps = analyze_coverage_gaps(initial_gaps)
prioritized_gaps = prioritize_gaps(coverage_gaps)
```

### 4. lib/eve_dmv/intelligence/analyzers/member_activity_analyzer.ex
**Lines 327:5, 669:5** - Variables "recommendations" and "risk_score"

**Fix recommendations:**
```elixir
# BEFORE:
recommendations = []
recommendations = recommendations ++ activity_recs()
recommendations = recommendations ++ retention_recs()

# AFTER:
initial_recommendations = []
activity_recommendations = initial_recommendations ++ activity_recs()
final_recommendations = activity_recommendations ++ retention_recs()
```

**Fix risk_score:**
```elixir
# BEFORE:
risk_score = base_score()
risk_score = adjust_for_activity(risk_score)
risk_score = normalize_score(risk_score)

# AFTER:
base_risk_score = base_score()
adjusted_risk_score = adjust_for_activity(base_risk_score)
final_risk_score = normalize_score(adjusted_risk_score)
```

### 5. lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex
**Lines 125:5, 222:5** - Variables "factors" and "actions"

**Fix factors:**
```elixir
# BEFORE:
factors = initial_factors()
factors = add_retention_factors(factors)
factors = weight_factors(factors)

# AFTER:
initial_factors = initial_factors()
retention_factors = add_retention_factors(initial_factors)
weighted_factors = weight_factors(retention_factors)
```

**Fix actions:**
```elixir
# BEFORE:
actions = base_actions()
actions = add_recruitment_actions(actions)
actions = prioritize_actions(actions)

# AFTER:
base_actions = base_actions()
recruitment_actions = add_recruitment_actions(base_actions)
prioritized_actions = prioritize_actions(recruitment_actions)
```

### 6. lib/eve_dmv/intelligence/analyzers/member_risk_assessment.ex
**Line 173:5** - Variable "indicators"

### 7. lib/eve_dmv/intelligence/generators/recruitment_insight_generator.ex
**Line 115:5** - Variable "areas"

### 8. lib/eve_dmv/intelligence/intelligence_scoring/behavioral_scoring.ex
**Line 77:5** - Variable "recommendations"

### 9. lib/eve_dmv/intelligence/intelligence_scoring/fleet_scoring.ex
**Lines 106:5, 227:5** - Variables "recommendations" and "optimizations"

### 10. lib/eve_dmv/intelligence/intelligence_scoring/intelligence_suitability.ex
**Lines 352:5, 425:5, 456:5** - Variables "training_recommendations", "recommendations", "risks"

### 11. lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex
**Lines 343:5, 361:5** - Variables "recommendations" and "risks"

### 12. lib/eve_dmv/intelligence/pattern_analysis.ex
**Line 425:5** - Variable "strategy_score"

### 13. lib/eve_dmv/intelligence/ship_database/doctrine_data.ex
**Line 195:5** - Variable "missing"

### 14. lib/eve_dmv/intelligence/ship_database/wormhole_utils.ex
**Line 179:5** - Variable "recommendations"

### 15. lib/eve_dmv/quality/metrics_collector/ci_cd_metrics.ex
**Line 76:5** - Variable "recommendations"

### 16. lib/eve_dmv/shared/ship_database_service.ex
**Line 686:5** - Variable "recommendations"

### 17. lib/eve_dmv/telemetry/performance_monitor/connection_pool_monitor.ex
**Line 288:5** - Variable "recommendations"

### 18. lib/eve_dmv/telemetry/performance_monitor/health_monitor.ex
**Line 443:5** - Variable "warnings"

## General Fix Strategy:

### For Each Variable Type:

#### Recommendations Variables:
Use progression: `initial_recommendations` → `enhanced_recommendations` → `final_recommendations`

#### Score Variables:
Use progression: `base_score` → `adjusted_score` → `final_score`

#### Factor Variables:
Use progression: `initial_factors` → `weighted_factors` → `normalized_factors`

#### Collection Variables (alerts, gaps, etc.):
Use progression: `initial_X` → `processed_X` → `final_X`

## Step-by-Step Instructions:

1. **Open the file** and go to the line number
2. **Find the function** containing the redeclared variable
3. **Identify the progression pattern** (accumulator, builder, scoring, etc.)
4. **Rename variables** to show clear progression
5. **Update ALL references** within the function to use new names
6. **Ensure return value** uses the final variable name

## Common Patterns:

### Accumulator Pattern:
```elixir
# BEFORE:
result = []
result = result ++ process_step_1()
result = result ++ process_step_2()
result

# AFTER:
initial_result = []
step1_result = initial_result ++ process_step_1()
final_result = step1_result ++ process_step_2()
final_result
```

### Builder Pattern:
```elixir
# BEFORE:
config = base_config()
config = apply_user_settings(config)
config = validate_config(config)

# AFTER:
base_config = base_config()
user_config = apply_user_settings(base_config)
validated_config = validate_config(user_config)
```

### Scoring Pattern:
```elixir
# BEFORE:
score = calculate_base()
score = apply_modifiers(score)
score = normalize(score)

# AFTER:
base_score = calculate_base()
modified_score = apply_modifiers(base_score)
final_score = normalize(modified_score)
```

## Verification:
After each fix:
1. **Read through the entire function** to ensure all references are updated
2. **Check logic flow** - each step should use the output of the previous step
3. **Verify return value** uses the correct final variable
4. **Run `mix compile`** to catch any missed references

## Progress Tracking:
- [ ] intelligence/alert_system.ex (3 fixes)
- [ ] intelligence/analyzers/fleet_asset_manager/readiness_analyzer.ex
- [ ] intelligence/analyzers/home_defense_analyzer.ex
- [ ] intelligence/analyzers/member_activity_analyzer.ex (2 fixes)
- [ ] intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex (2 fixes)
- [ ] intelligence/analyzers/member_risk_assessment.ex
- [ ] intelligence/generators/recruitment_insight_generator.ex
- [ ] intelligence/intelligence_scoring/behavioral_scoring.ex
- [ ] intelligence/intelligence_scoring/fleet_scoring.ex (2 fixes)
- [ ] intelligence/intelligence_scoring/intelligence_suitability.ex (3 fixes)
- [ ] intelligence/intelligence_scoring/recruitment_scoring.ex (2 fixes)
- [ ] intelligence/pattern_analysis.ex
- [ ] intelligence/ship_database/doctrine_data.ex
- [ ] intelligence/ship_database/wormhole_utils.ex
- [ ] quality/metrics_collector/ci_cd_metrics.ex
- [ ] shared/ship_database_service.ex
- [ ] telemetry/performance_monitor/connection_pool_monitor.ex
- [ ] telemetry/performance_monitor/health_monitor.ex

This should eliminate all 36 remaining variable redeclaration errors.