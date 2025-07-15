# Sprint 10: Fleet Intelligence & User Experience Polish

**Duration**: 2 weeks (July 12-26, 2025)  
**Total Story Points**: 42 (targeting 40-45 range)  
**Sprint Goal**: Implement Fleet Intelligence system with ship role analysis, enhance character profiles with real data, and add recent battles sections across analyzer pages

## 📋 Sprint Overview

### Primary Objectives
1. **Fleet Intelligence System**: Build dynamic ship role classification and fleet composition analysis
2. **Character Profile Polish**: Complete character profiles with real data and enhanced UI
3. **Battle History Integration**: Add recent battles sections to character/corporation/system pages

### Success Criteria
- Fleet analysis provides accurate doctrine identification (>90% for common fleets)
- Character profiles display real statistics and proper EVE integration
- Battle history sections show relevant recent activity across all analyzer pages
- All features integrate seamlessly with existing surveillance and intelligence systems

---

## 🚢 Ship Role Classification & Fleet Intelligence (20 points)

### SHIP-1: Core Ship Role Classification Engine (5 points)
**Goal**: Build sophisticated module classification system using real killmail data

**Implementation Tasks**:
- [ ] Create `EveDmv.Analytics.ModuleClassifier` module
- [ ] Define module classification patterns for roles:
  - Tackle: Scramblers, disruptors, webs, interdiction
  - Logistics: Remote reps, cap transfers, triage modules  
  - EWAR: ECM, damps, painters, neuts
  - DPS: Weapons, damage amplifiers
  - Command: Command bursts, warfare links
- [ ] Build confidence scoring algorithm for role assignments
- [ ] **Import ship reference data from `docs/reference/ship_info.md`**:
  - Parse ship tactical information and common roles
  - Create ship baseline classifications with Type IDs
  - Extract doctrine patterns (Mach fleets, Ferox fleets, etc.)
  - Use as foundation for both fallback and validation
- [ ] Create fallback system using ship type defaults from imported reference data

**Database Schema**:
```sql
CREATE TABLE ship_role_patterns (
  ship_type_id INTEGER PRIMARY KEY,
  ship_name VARCHAR(100),
  primary_role VARCHAR(50),
  role_distribution JSONB,
  confidence_score DECIMAL(3,2),
  sample_size INTEGER,
  last_analyzed TIMESTAMP,
  meta_trend VARCHAR(20),
  -- Reference data from ship_info.md
  reference_role VARCHAR(50),
  typical_doctrines TEXT[],
  tactical_notes TEXT
);

CREATE TABLE doctrine_patterns (
  id SERIAL PRIMARY KEY,
  doctrine_name VARCHAR(100),
  ship_composition JSONB, -- Type IDs and typical counts
  tank_type VARCHAR(20), -- shield/armor/hull
  engagement_range VARCHAR(20), -- close/medium/long/extreme
  tactical_role VARCHAR(50), -- brawler/sniper/kiter/alpha
  reference_source VARCHAR(50) -- ship_info.md, detected, etc.
);

CREATE TABLE role_analysis_history (
  id SERIAL PRIMARY KEY,
  ship_type_id INTEGER,
  analysis_date DATE,
  role_distribution JSONB,
  meta_indicators JSONB
);
```

**Success Criteria**:
- Module classification accuracy >85% against manual review
- Role confidence scores properly weighted by sample size
- Graceful fallback for ships with insufficient data

### SHIP-1b: Ship Reference Data Import (2 points)
**Goal**: Parse and import comprehensive ship reference data from `docs/reference/ship_info.md`

**Implementation Tasks**:
- [ ] Create `EveDmv.StaticData.ShipReferenceImporter` module
- [ ] Parse ship_info.md to extract:
  - Ship Type IDs and names (Megathron 641, Apocalypse 642, etc.)
  - Primary tactical roles (sniper, brawler, support, EWAR)
  - Common doctrine classifications
  - Tank types (armor/shield) and engagement ranges
  - Special capabilities and tactical notes
- [ ] Populate `ship_role_patterns` table with reference baseline data
- [ ] Create `doctrine_patterns` table with known fleet compositions
- [ ] Build validation system to compare detected roles vs reference data

**Data Structure Example**:
```elixir
%{
  641 => %{
    name: "Megathron",
    type_id: 641,
    reference_role: "sniper_dps",
    typical_doctrines: ["armor_bs_sniper", "railgun_alpha"],
    tank_type: "armor",
    engagement_range: "long",
    tactical_notes: "Gallente battleship for long-range alpha volleys, backbone of nullsec armor fleets"
  },
  17738 => %{
    name: "Machariel", 
    type_id: 17738,
    reference_role: "mobile_dps",
    typical_doctrines: ["mach_speed_fleet", "shield_artillery"],
    tank_type: "shield",
    engagement_range: "medium_long",
    tactical_notes: "Fast battleship for hit-and-run tactics, dictates engagement range"
  }
}
```

**Success Criteria**:
- All ships from ship_info.md successfully imported with Type IDs
- Reference data provides baseline for 100+ commonly used fleet ships
- Doctrine patterns capture major fleet compositions accurately

### SHIP-2: Dynamic Ship Role Analysis Worker (3 points)
**Goal**: Implement scheduled analysis job for continuous role pattern detection

**Implementation Tasks**:
- [ ] Create `EveDmv.Workers.ShipRoleAnalysisWorker` using Oban
- [ ] Build killmail analysis pipeline:
  - Query recent killmails (last 7 days) by ship type
  - Extract fitted modules from victim ships
  - Calculate role confidence scores
  - Update cached ship role classifications
- [ ] Implement meta trend detection (role usage changes over time)
- [ ] Add performance monitoring and error handling

**Technical Requirements**:
```elixir
defmodule EveDmv.Workers.ShipRoleAnalysisWorker do
  use Oban.Worker, queue: :analytics
  
  def perform(%Oban.Job{}) do
    analyze_recent_killmails()
    |> update_ship_role_cache()
    |> generate_meta_trend_report()
    |> schedule_next_analysis()
  end
end
```

**Success Criteria**:
- Analysis completes within 10 minutes for full dataset
- Role patterns updated daily with new killmail data
- Meta trend detection identifies doctrine shifts within 48 hours

### SHIP-3: Fleet Composition Intelligence (6 points)
**Goal**: Build doctrine recognition and tactical assessment system

**Implementation Tasks**:
- [ ] Create `EveDmv.Analytics.FleetAnalyzer` module
- [ ] Implement doctrine recognition patterns using `ship_info.md` reference data:
  - **Battleship Doctrines**: Megathron armor fleets, Apocalypse snipers, Machariel speed fleets
  - **Battlecruiser Doctrines**: Ferox railgun fleets, Drake missile fleets, Hurricane artillery
  - **HAC Doctrines**: Muninn fleets, Eagle fleets, Cerberus/Ishtar compositions
  - **Command Ship Integration**: Damnation (armor), Vulture (shield), Claymore support
  - **Specialized Support**: Scorpion ECM, Armageddon neuting, Bhaalgorn tackle
  - **Triglavian Compositions**: Leshak spider-tank fleets with ramping damage
- [ ] Build tactical assessment engine:
  - Logistics ratio analysis (optimal ~20%)
  - Tank type consistency checking
  - Range coherence analysis
  - Support ship coverage evaluation
- [ ] Generate actionable tactical insights and recommendations

**Fleet Analysis Features**:
```elixir
def analyze_fleet_composition(fleet_ships) do
  %{
    doctrine_classification: identify_doctrine(fleet_ships),
    tactical_assessment: assess_fleet_strengths(fleet_ships),
    role_distribution: calculate_role_balance(fleet_ships),
    recommendations: generate_recommendations(fleet_ships),
    threat_level: calculate_threat_score(fleet_ships)
  }
end
```

**Success Criteria**:
- Accurate doctrine identification for 20+ common fleet types
- Tactical recommendations validated by experienced fleet commanders
- Fleet analysis completes in <1 second for 100-ship fleets

### SHIP-4: Fleet Optimizer Integration (4 points)
**Goal**: Connect ship intelligence to existing fleet analysis and battle systems

**Implementation Tasks**:
- [ ] Integrate ship role data with battle analysis system
- [ ] Enhance fleet composition displays with role information
- [ ] Add ship specialization tracking to character intelligence
- [ ] Connect doctrine analysis to surveillance profiles
- [ ] Build fleet meta trend dashboard

**Integration Points**:
- Battle Analysis: Enhanced fleet composition breakdown with roles
- Character Intelligence: Pilot specialization and doctrine preferences  
- Surveillance Profiles: Fleet doctrine-based filtering
- Corporation Analysis: Doctrine preference tracking

**Success Criteria**:
- Ship intelligence data visible across all relevant pages
- Character specialization scores accurately reflect pilot history
- Fleet composition analysis provides actionable intelligence

---

## 👤 Character Profile Polish (12 points)

### PROFILE-1: Character Profile Enhancement (6 points)
**Goal**: Complete character profiles with proper EVE integration and visual improvements

**Implementation Tasks**:
- [ ] Add character portrait integration using EVE image server
- [ ] Display corporation and alliance information with logos
- [ ] Show character creation date, security status, and basic info
- [ ] Add corporation ticker and alliance ticker display
- [ ] Implement proper character header layout with EVE styling

**UI Enhancements**:
```heex
<div class="character-header bg-gray-800 rounded-lg p-6 mb-6">
  <div class="flex items-center space-x-6">
    <!-- Character Portrait -->
    <img src={character_portrait_url(@character.id, 128)} 
         class="w-32 h-32 rounded-lg border-2 border-blue-400" 
         alt={@character.name} />
    
    <!-- Character Info -->
    <div class="flex-1">
      <h1 class="text-3xl font-bold text-white"><%= @character.name %></h1>
      <div class="text-gray-400 mt-2">
        <div class="flex items-center space-x-4">
          <span>[<%= @character.corporation.ticker %>] <%= @character.corporation.name %></span>
          <%= if @character.alliance do %>
            <span>&lt;<%= @character.alliance.ticker %>&gt; <%= @character.alliance.name %></span>
          <% end %>
        </div>
        <div class="mt-1 text-sm">
          <span>Security Status: <%= format_security_status(@character.security_status) %></span>
          <span class="ml-4">Created: <%= format_date(@character.birthday) %></span>
        </div>
      </div>
    </div>
  </div>
</div>
```

**Success Criteria**:
- Character portraits load reliably from EVE image server
- Corporation and alliance information displays correctly
- Character header visually matches EVE Online styling

### PROFILE-2: Real ISK Calculations (4 points)
**Goal**: Replace placeholder statistics with real calculations from killmail data

**Implementation Tasks**:
- [ ] Implement real ISK destroyed calculations by character
- [ ] Calculate ISK lost with accurate values
- [ ] Add ISK efficiency ratio (destroyed vs lost)
- [ ] Build performance trending (improving/declining over time)
- [ ] Add time period filtering (24h, 7d, 30d, all time)

**Statistical Calculations**:
```elixir
defmodule EveDmv.Analytics.CharacterStats do
  def calculate_character_statistics(character_id, period \\ :last_30_days) do
    %{
      isk_destroyed: calculate_isk_destroyed(character_id, period),
      isk_lost: calculate_isk_lost(character_id, period),
      kill_count: count_kills(character_id, period),
      loss_count: count_losses(character_id, period),
      efficiency_ratio: calculate_efficiency_ratio(character_id, period),
      favorite_ship: get_most_flown_ship(character_id, period),
      deadliest_system: get_most_active_system(character_id, period),
      performance_trend: calculate_performance_trend(character_id)
    }
  end
end
```

**Success Criteria**:
- All statistics reflect real data from killmail database
- ISK calculations accurate within 5% of zkillboard values
- Performance trends show meaningful patterns over time

### PROFILE-3: Recent Activity Feed (2 points)
**Goal**: Display real recent activity with proper formatting and filtering

**Implementation Tasks**:
- [ ] Query recent kills/losses from killmail database
- [ ] Format activity timeline with context and details
- [ ] Add activity type filtering (kills/losses/all)
- [ ] Implement ship category and time range filters
- [ ] Link activity items to detailed killmail pages

**Activity Display**:
```heex
<div class="recent-activity space-y-4">
  <%= for activity <- @recent_activity do %>
    <div class="activity-item bg-gray-700 rounded-lg p-4 flex items-center space-x-4">
      <div class="activity-icon">
        <%= if activity.type == :kill do %>
          <div class="w-3 h-3 bg-green-500 rounded-full"></div>
        <% else %>
          <div class="w-3 h-3 bg-red-500 rounded-full"></div>
        <% end %>
      </div>
      <div class="flex-1">
        <div class="text-white">
          <%= activity_description(activity) %>
        </div>
        <div class="text-gray-400 text-sm">
          <%= format_relative_time(activity.timestamp) %> in <%= activity.system_name %>
        </div>
      </div>
      <div class="text-right">
        <div class="text-white font-semibold">
          <%= format_isk(activity.isk_value) %>
        </div>
      </div>
    </div>
  <% end %>
</div>
```

**Success Criteria**:
- Activity feed shows actual recent kills/losses
- Filtering works correctly for all activity types
- Activity descriptions are clear and informative

---

## ⚔️ Battle History Integration (8 points)

### BATTLES-1: Character Battle History (3 points)
**Goal**: Add recent battles section to character analysis pages

**Implementation Tasks**:
- [ ] Identify multi-participant killmails as "battles" for characters
- [ ] Create battle summary cards with key information
- [ ] Add battle filtering by size, ISK value, and timeframe
- [ ] Link to detailed battle analysis pages
- [ ] Show character's role in each battle

**Battle Detection Logic**:
```elixir
defmodule EveDmv.Analytics.BattleDetector do
  def detect_character_battles(character_id, limit \\ 10) do
    # Find killmails with multiple participants involving this character
    KillmailRaw
    |> where([k], fragment("? = ANY(?)", ^character_id, k.attackers_character_ids) or 
                   k.victim_character_id == ^character_id)
    |> where([k], fragment("array_length(?, 1) >= ?", k.attackers_character_ids, 5))
    |> order_by([k], desc: k.killmail_time)
    |> limit(^limit)
    |> group_battles_by_proximity()
    |> enhance_with_battle_context()
  end
end
```

### BATTLES-2: Corporation Battle History (3 points)
**Goal**: Add battle participation tracking to corporation intelligence pages

**Implementation Tasks**:
- [ ] Detect corporation-wide battle participation
- [ ] Calculate corporation performance in battles
- [ ] Show fleet composition preferences and effectiveness
- [ ] Track corporation alliance participation in large battles
- [ ] Add corporation battle statistics and trends

**Corporation Battle Analysis**:
- Total battles participated in
- Average fleet size contribution
- Battle performance metrics (ISK efficiency)
- Preferred fleet doctrines and compositions
- Alliance coordination patterns

### BATTLES-3: System Battle Activity (2 points)
**Goal**: Add recent battle activity to system intelligence pages

**Implementation Tasks**:
- [ ] Track multi-ship engagements in systems
- [ ] Show battle frequency and intensity patterns
- [ ] Identify dangerous systems based on battle activity
- [ ] Display recent major engagements with details
- [ ] Add system battle heatmap visualization

**System Battle Metrics**:
- Battles per day/week in system
- Average battle size and ISK destroyed
- Peak activity times and patterns
- Threat level assessment based on recent activity

---

## 🔗 Integration & Testing (2 points)

### INTEGRATION-1: Ship Intelligence Integration (1 point)
**Goal**: Connect ship role analysis to existing character and corporation intelligence

**Implementation Tasks**:
- [ ] Add ship specialization data to character intelligence summaries
- [ ] Show preferred doctrines and ship categories in character profiles
- [ ] Display corporation doctrine preferences based on member activity
- [ ] Connect ship intelligence to surveillance profile filtering

### TEST-1: Comprehensive Testing (1 point)
**Goal**: End-to-end testing of all new features and integrations

**Implementation Tasks**:
- [ ] Test ship role classification accuracy with sample data
- [ ] Verify character profile enhancements work correctly
- [ ] Test battle history sections across all pages
- [ ] Performance testing for fleet analysis with large datasets
- [ ] Integration testing between ship intelligence and existing features

---

## 📊 Success Metrics

### Fleet Intelligence
- 90%+ accuracy in doctrine identification for common fleet types
- <1 second response time for fleet composition analysis
- Ship role confidence scores >0.8 for ships with 10+ killmail samples

### Character Profile Polish
- Character portraits load successfully >95% of the time
- ISK calculations accurate within 5% variance from zkillboard
- Recent activity feed displays real data for all users

### Battle History Integration
- Battle detection identifies 80%+ of multi-ship engagements
- Battle history sections load in <2 seconds
- Battle participation data accurate for characters and corporations

### Overall Integration
- All features work seamlessly together
- No performance degradation on existing pages
- User engagement increases with enhanced data visibility

---

## 🎯 Post-Sprint 10 Setup

### What We'll Have Achieved
1. **Complete Fleet Intelligence System**: Ship role classification, doctrine recognition, tactical analysis
2. **Polished Character Profiles**: Real data, EVE integration, professional presentation
3. **Enhanced Battle Context**: Battle history across all intelligence pages
4. **Stronger Analytics Foundation**: Ship intelligence supports future predictive features

### Natural Next Steps (Sprint 11 Candidates)
1. **Chain Intelligence Enhancement**: Wormhole-specific fleet analysis and threat assessment
2. **Price Integration**: Real-time market data for accurate ISK calculations
3. **Advanced Battle Correlation**: Multi-system battle tracking and strategic analysis
4. **Mobile Optimization**: Responsive design for field commanders

---

## 📈 Technical Architecture

### Database Extensions
- Ship role patterns and analysis history tables
- Battle participation tracking enhancements
- Character statistics caching for performance

### Performance Considerations
- Ship role analysis runs as background jobs
- Character statistics cached with 15-minute TTL
- Battle detection optimized with proper indexing
- Fleet analysis uses precomputed role data

### Integration Points
- Ship intelligence connects to surveillance profiles
- Character enhancements integrate with existing intelligence
- Battle history links to existing battle analysis system
- All features maintain dark theme and UI consistency

This sprint combines high-value new features with important polish, setting up a strong foundation for advanced analytics in future sprints.