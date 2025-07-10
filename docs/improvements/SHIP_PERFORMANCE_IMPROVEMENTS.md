# Ship Performance Analysis - Improvement Roadmap

## Current State

The ship performance analyzer provides basic performance metrics by comparing actual combat results with simplified estimates. While functional for general analysis, it lacks the precision needed for detailed fitting optimization.

### Current Limitations

1. **Simplified DPS Calculations**
   - Uses hardcoded estimates based on ship class (e.g., Cruiser = 400 DPS)
   - Doesn't account for actual weapon modules, ammo types, or damage bonuses
   - No consideration for optimal range, tracking, or application

2. **Basic Tank Estimates**
   - Uses base hull HP with simple multipliers (shield × 1.2, armor × 1.1)
   - No resistance profiles or active tank calculations
   - Ignores module effects, rigs, and implants

3. **Missing Factors**
   - No skill calculations (all skills assumed at V)
   - No implant or booster effects
   - No fleet bonuses or command bursts
   - No wormhole effects or environmental modifiers

## Recommended Improvements

### 1. Integrate PyFA Calculation Engine
**Priority: High**

PyFA (Python Fitting Assistant) has a mature, open-source calculation engine that accurately models EVE's mechanics.

```python
# Example integration approach
from eos import Fit, Ship, Module

def calculate_real_stats(fitting_data):
    fit = Fit()
    fit.ship = Ship(fitting_data['ship_type_id'])
    
    for module in fitting_data['modules']:
        fit.modules.append(Module(module['type_id']))
    
    return {
        'dps': fit.totalDps,
        'ehp': fit.ehp,
        'cap_stable': fit.capStable,
        'speed': fit.maxSpeed
    }
```

**Benefits:**
- Accurate DPS calculations including all modifiers
- Proper tank calculations with resistance profiles
- Capacitor stability analysis
- Speed and signature calculations

### 2. Build Comprehensive Module Database
**Priority: High**

Import and maintain EVE's complete module statistics:

```elixir
defmodule EveDmv.Eve.ModuleStats do
  use Ash.Resource
  
  attributes do
    attribute :type_id, :integer, primary_key?: true
    attribute :damage_modifier, :float
    attribute :rate_of_fire, :float
    attribute :optimal_range, :float
    attribute :falloff, :float
    attribute :tracking_speed, :float
    attribute :cpu_usage, :float
    attribute :powergrid_usage, :float
    # ... all relevant attributes
  end
end
```

### 3. Implement Skill System
**Priority: Medium**

Track and apply character skills to calculations:

```elixir
defmodule EveDmv.Characters.SkillProfile do
  use Ash.Resource
  
  attributes do
    attribute :character_id, :integer
    attribute :skill_id, :integer
    attribute :level, :integer, constraints: [min: 0, max: 5]
    attribute :skill_points, :integer
  end
end

# Apply skill bonuses
def apply_skill_bonuses(base_stats, skill_profile) do
  # Example: Surgical Strike gives 3% damage per level
  damage_bonus = get_skill_level(skill_profile, :surgical_strike) * 0.03
  
  %{base_stats | damage: base_stats.damage * (1 + damage_bonus)}
end
```

### 4. Combat Log Integration
**Priority: High**

Parse actual combat logs for real application data:

```elixir
def analyze_combat_log(log_events, fitting) do
  %{
    actual_dps: calculate_actual_dps(log_events),
    hit_quality: analyze_hit_quality(log_events),
    missed_shots: count_misses(log_events),
    wrecking_hits: count_wrecking_shots(log_events),
    range_profile: analyze_engagement_ranges(log_events),
    tracking_issues: detect_tracking_problems(log_events, fitting)
  }
end
```

### 5. Environmental Factors
**Priority: Low**

Account for system effects and fleet support:

```elixir
defmodule EveDmv.Environment.SystemEffects do
  def apply_wormhole_effects(stats, wormhole_class) do
    case wormhole_class do
      :c1 -> %{stats | shield_hp: stats.shield_hp * 1.07}
      :c2 -> %{stats | armor_hp: stats.armor_hp * 1.08}
      :c3 -> %{stats | shield_hp: stats.shield_hp * 1.16}
      # ... etc
    end
  end
  
  def apply_command_bursts(stats, active_links) do
    # Apply command burst bonuses
  end
end
```

### 6. Advanced Metrics
**Priority: Medium**

Calculate meaningful performance indicators:

```elixir
def calculate_advanced_metrics(performance_data) do
  %{
    # Actual vs theoretical damage application
    application_efficiency: actual_damage / (theoretical_dps * time),
    
    # How well pilot managed transversal
    tracking_efficiency: successful_hits / total_shots,
    
    # Optimal range management
    range_efficiency: shots_in_optimal / total_shots,
    
    # Tank utilization
    repair_efficiency: damage_repaired / potential_repair,
    
    # Capacitor management
    cap_efficiency: time_cap_stable / total_time,
    
    # Target selection quality
    target_value_ratio: isk_destroyed / potential_targets_value
  }
end
```

### 7. Machine Learning Predictions
**Priority: Low (Future)**

Use historical data to predict performance:

```elixir
def predict_matchup(ship_a, ship_b, environment) do
  # Use ML model trained on historical battles
  features = extract_features(ship_a, ship_b, environment)
  
  model = load_trained_model()
  prediction = model.predict(features)
  
  %{
    win_probability: prediction.win_chance,
    expected_duration: prediction.fight_duration,
    likely_range: prediction.engagement_range
  }
end
```

## Implementation Plan

### Phase 1: Foundation (1-2 months)
1. Import complete SDE module database
2. Build proper fitting calculation engine
3. Implement basic skill system

### Phase 2: Accuracy (1 month)
1. Integrate PyFA calculations or build equivalent
2. Add resistance and stacking penalty calculations
3. Implement proper EHP calculations

### Phase 3: Combat Analysis (2 months)
1. Enhanced combat log parser
2. Hit quality analysis
3. Application efficiency metrics

### Phase 4: Advanced Features (Ongoing)
1. Environmental effects
2. Fleet composition analysis
3. ML-based predictions

## Testing Strategy

1. **Unit Tests**: Verify calculations match EVE's formulas
2. **Integration Tests**: Compare with PyFA/in-game values
3. **Regression Tests**: Ensure updates don't break existing analysis
4. **Performance Tests**: Handle large-scale fleet battles

## Success Metrics

- Calculated DPS within 1% of in-game values
- EHP calculations match PyFA exactly
- Combat log analysis processes 10k+ events/second
- 95% accuracy in performance predictions

## Resources Required

1. **EVE SDE Access**: Latest static data export
2. **PyFA Integration**: License compatible integration
3. **Compute Resources**: For ML model training
4. **Domain Expertise**: EVE mechanics specialists for validation