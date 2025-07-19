# Combat Log Analysis - Comprehensive Tactical Data Extraction

## Overview
Combat logs contain detailed tactical information about:
- Damage application patterns (hit quality, weapon effectiveness)
- Module usage patterns (EWAR, defensive modules, range issues)
- Tactical decision making (target selection, defensive reactions)
- Combat effectiveness metrics (application vs opportunity)

## Current Issues

### 1. Combat Log Parsing Problems
- Parser is categorizing all events as generic `:combat` instead of specific types
- Not extracting damage values from outgoing damage lines
- Missing key tactical patterns (range issues, defensive module usage)
- Not correlating module attempts with kill outcomes

### 2. Fitting Persistence Issue
- LiveView state not properly maintained when switching ships
- Selected ship data gets overwritten without preserving fitting

## Detailed Implementation Plan

### Phase 1: Fix Combat Log Parser (Priority: Critical)

#### 1.1 Update Damage Pattern Recognition
Current log shows outgoing damage format:
```
"84 to Hornet II[GI.N](Hornet II) - Scourge Rage Rocket - Hits"
"278 to Darin Raltin[GI.N](Porpoise) - Scourge Rage Rocket - Hits"
```

**New regex patterns needed:**
```elixir
# Outgoing damage: "84 to Hornet II[GI.N](Hornet II) - Scourge Rage Rocket - Hits"
~r/(\d+) to ([^[]+)\[([^\]]+)\]\(([^)]+)\) - ([^-]+) - (Hits|Penetrates|Smashes|Wrecks|Glances Off|Grazes)/

# Incoming damage: "15 from Kragden[GI.N](Covetor) - Hornet II - Glances Off"  
~r/(\d+) from ([^[]+)\[([^\]]+)\]\(([^)]+)\) - ([^-]+) - (Hits|Penetrates|Smashes|Wrecks|Glances Off|Grazes)/

# Miss patterns: "Hornet II belonging to Nitlar Nirad misses you completely"
~r/([^s]+) belonging to ([^s]+) misses you completely/

# Module attempts: "Warp scramble attempt from you to"
~r/(Warp scramble|Warp disruption) attempt from you to (.+)/

# Range failures: "Your target is too far away"
~r/Your target is too far away/

# Defensive modules: "Shield booster activated", "Armor repair activated"
~r/(Shield booster|Armor repair|Hull repair) activated/
```

#### 1.2 Extract Tactical Patterns

**Hit Quality Analysis:**
- Wrecking shots: Perfect application (100% damage)
- Smashes: Excellent application (~90%)
- Penetrates: Good application (~70%)
- Hits: Normal application (~50%)
- Glances/Grazes: Poor application (~20-30%)

**Module Effectiveness Tracking:**
- Tackle attempts vs successful tackles vs kills
- EWAR module usage patterns
- Defensive module activation timing
- Range management issues

#### 1.3 Enhanced Event Types
```elixir
%{
  type: :damage_dealt,
  timestamp: timestamp,
  damage: 278,
  target: "Darin Raltin",
  target_corp: "GI.N",
  target_ship: "Porpoise",
  weapon: "Scourge Rage Rocket",
  hit_quality: :normal,
  application_percentage: 50.0
}

%{
  type: :damage_received,
  timestamp: timestamp,
  damage: 151,
  attacker: "Darin Raltin",
  attacker_corp: "GI.N", 
  attacker_ship: "Porpoise",
  weapon: "Valkyrie II",
  hit_quality: :wrecking,
  application_percentage: 100.0
}

%{
  type: :tackle_attempt,
  timestamp: timestamp,
  module: "Warp Scrambler",
  target: "Alexander Ravager",
  target_ship: "Sabre",
  success: true,  # Determined by follow-up events
  target_escaped: false,  # Determined by correlation with kills
  target_killed: true
}

%{
  type: :defensive_action,
  timestamp: timestamp,
  module: "Shield Booster",
  reason: :under_fire,  # Triggered by recent damage
  effectiveness: :too_late  # Based on survival outcome
}

%{
  type: :range_failure,
  timestamp: timestamp,
  attempted_action: "Warp Scrambler",
  target: "Fleeing Ship",
  range_issue: true
}
```

### Phase 2: Advanced Combat Analysis (Priority: High)

#### 2.1 Tactical Decision Analysis
```elixir
def analyze_tactical_decisions(events, killmails) do
  %{
    target_prioritization: analyze_target_selection(events),
    defensive_reactions: analyze_defensive_timing(events),
    tackle_effectiveness: analyze_tackle_success_rate(events, killmails),
    range_management: analyze_range_discipline(events),
    survival_instincts: analyze_escape_attempts(events, killmails)
  }
end
```

#### 2.2 Hit Quality Metrics
```elixir
def analyze_damage_application(events) do
  damage_events = filter_damage_events(events)
  
  %{
    total_shots: length(damage_events),
    wrecking_shots: count_by_quality(damage_events, :wrecking),
    excellent_shots: count_by_quality(damage_events, :excellent),
    average_application: calculate_avg_application(damage_events),
    weapon_performance: group_by_weapon(damage_events),
    target_difficulty: analyze_target_sig_tracking(damage_events)
  }
end
```

#### 2.3 Module Usage Intelligence
```elixir
def analyze_module_usage(events, killmails) do
  %{
    tackle_stats: %{
      attempts: count_tackle_attempts(events),
      successful_tackles: count_successful_tackles(events),
      kills_from_tackles: correlate_tackles_with_kills(events, killmails),
      escaped_after_tackle: count_tackle_escapes(events, killmails)
    },
    defensive_stats: %{
      repair_activations: count_repair_activations(events),
      reaction_time: calculate_defensive_reaction_time(events),
      survival_correlation: correlate_defensive_use_with_survival(events, killmails)
    },
    range_discipline: %{
      range_failures: count_range_failures(events),
      optimal_range_shots: calculate_optimal_range_percentage(events),
      positioning_score: score_range_management(events)
    }
  }
end
```

### Phase 3: Fix Fitting Persistence (Priority: High)

#### 3.1 Root Cause Analysis
The issue is in the `analyze_ship_performance` event handler where `ship_data` doesn't include the existing fitting data when calling the analyzer.

#### 3.2 Fix Implementation
```elixir
def handle_event("analyze_ship_performance", %{"character_id" => char_id, "ship_type_id" => ship_id}, socket) do
  character_id = String.to_integer(char_id)
  ship_type_id = String.to_integer(ship_id)
  
  # CRITICAL: Check if this is the currently selected ship to preserve fitting
  current_fitting = if socket.assigns.selected_ship && 
                      socket.assigns.selected_ship.character_id == character_id &&
                      socket.assigns.selected_ship.ship_type_id == ship_type_id do
    socket.assigns.selected_ship.fitting_data
  else
    # Query database for existing fitting
    load_fitting_from_database(character_id, ship_type_id)
  end
  
  ship_data = %{
    character_id: character_id,
    ship_type_id: ship_type_id,
    character_name: get_character_name(character_id),
    fitting_data: current_fitting  # PRESERVE EXISTING FITTING
  }
  
  # ... rest of analysis
end
```

#### 3.3 State Management Fix
```elixir
# Ensure fitting data persists across ship selections
defp preserve_ship_state(socket, new_ship_data) do
  # If switching ships, save current fitting to database first
  if socket.assigns.selected_ship && 
     socket.assigns.selected_ship != new_ship_data &&
     socket.assigns.selected_ship.fitting_data do
    save_fitting_to_database(socket.assigns.selected_ship)
  end
  
  assign(socket, :selected_ship, new_ship_data)
end
```

### Phase 4: Enhanced UI Display (Priority: Medium)

#### 4.1 Combat Log Visualization
```heex
<div class="combat-analysis">
  <div class="damage-application">
    <h4>Damage Application</h4>
    <div class="hit-quality-breakdown">
      <%= for {quality, stats} <- @combat_analysis.hit_quality do %>
        <div class="quality-bar">
          <span><%= quality %></span>
          <div class="bar" style="width: <%= stats.percentage %>%"></div>
          <span><%= stats.count %> shots (<%= Float.round(stats.percentage, 1) %>%)</span>
        </div>
      <% end %>
    </div>
  </div>
  
  <div class="tactical-decisions">
    <h4>Tactical Performance</h4>
    <div class="tackle-effectiveness">
      <span>Tackle Success Rate: <%= @combat_analysis.tackle_success_rate %>%</span>
      <span>Kills from Tackles: <%= @combat_analysis.kills_from_tackles %></span>
    </div>
    <div class="defensive-reactions">
      <span>Defensive Reaction Time: <%= @combat_analysis.avg_reaction_time %>s</span>
      <span>Survival Rate: <%= @combat_analysis.survival_rate %>%</span>
    </div>
  </div>
</div>
```

#### 4.2 Real-time Combat Recommendations
```elixir
def generate_tactical_recommendations(combat_analysis) do
  recommendations = []
  
  # Hit quality recommendations
  if combat_analysis.average_application < 60 do
    recommendations = recommendations ++ ["Consider using tracking enhancers or webs to improve hit quality"]
  end
  
  # Tackle effectiveness
  if combat_analysis.tackle_success_rate < 70 do
    recommendations = recommendations ++ ["Work on tackle timing - many targets escaping"]
  end
  
  # Range discipline
  if combat_analysis.range_failures > 5 do
    recommendations = recommendations ++ ["Improve range management - too many out-of-range attempts"]
  end
  
  # Defensive reactions
  if combat_analysis.defensive_reaction_time > 3 do
    recommendations = recommendations ++ ["Activate defensive modules earlier when taking damage"]
  end
  
  recommendations
end
```

### Phase 5: Testing Strategy

#### 5.1 Parser Testing
1. Test with both sample combat logs (message.txt, message2.txt)
2. Verify each event type is correctly categorized
3. Validate damage extraction and hit quality parsing
4. Test tactical pattern recognition

#### 5.2 Fitting Persistence Testing
1. Load fitting for Ship A
2. Click on Ship B (should maintain Ship A's fitting)
3. Click back to Ship A (should restore fitting)
4. Import new fitting for Ship A (should update and persist)

#### 5.3 Integration Testing
1. Upload combat log with known patterns
2. Verify tactical analysis matches manual review
3. Test recommendations generation
4. Validate performance metrics

## Implementation Priority

### Week 1: Core Fixes
1. Fix combat log parser regex patterns ✓
2. Fix fitting persistence in LiveView ✓
3. Test with sample logs ✓

### Week 2: Enhanced Analysis
1. Implement tactical decision analysis
2. Add hit quality metrics
3. Module usage intelligence

### Week 3: UI & Recommendations
1. Enhanced combat log visualization
2. Real-time tactical recommendations
3. Performance correlation with killmails

## Success Metrics

1. **Parser Accuracy**: 95%+ of events correctly categorized
2. **Tactical Insights**: Meaningful recommendations for 80%+ of logs
3. **State Persistence**: 100% fitting retention across ship switches
4. **Performance**: Parse 1000+ events in <2 seconds

This comprehensive approach will transform the combat log analysis from basic parsing to strategic combat intelligence.