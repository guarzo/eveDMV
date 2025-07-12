# Sprint Ideas & Future Improvements

This document captures ideas for future sprints and improvements that have been identified during development.

---

## ✅ Moved to Sprint 10: Fleet Intelligence & User Experience Polish

**The following sections have been moved to Sprint 10 (July 12-26, 2025):**

### Character Profile Enhancements (MOVED TO SPRINT 10)
- Character portrait integration with EVE image server
- Corporation and alliance information display
- Real ISK destroyed/lost calculations
- Recent activity feed with real killmail data
- Profile statistics dashboard with real data

### Dynamic Ship Role Analysis System (MOVED TO SPRINT 10)
- Killmail-based role classification engine
- Scheduled analysis job for role pattern detection
- Real-time fleet analysis with dynamic roles
- Doctrine recognition and tactical assessment
- Ship specialization tracking for characters

### Recent Battles Integration (MOVED TO SPRINT 10)
- Recent battles section for character analysis pages
- Corporation battle participation tracking
- System battle activity for system intelligence pages
- Battle detection and context enhancement

See `/workspace/docs/sprints/current/SPRINT_10_FLEET_INTELLIGENCE_POLISH.md` for full implementation details.

---

## Dashboard Improvements

### User Dashboard Fixes
The logged-in user dashboard (`/dashboard`) needs several data accuracy fixes and feature improvements:

#### ISK Destroyed Section
- [x] ~~Calculate real ISK destroyed values from killmail data~~ **MOVED TO SPRINT 10**
- [ ] Show monthly/weekly/daily breakdowns
- [x] ~~Include both kills and losses~~ **MOVED TO SPRINT 10** 
- [x] ~~Add ISK efficiency ratio (ISK destroyed vs ISK lost)~~ **MOVED TO SPRINT 10**
- [ ] Show trending indicators

#### Fleet Engagements
- [ ] Query real fleet participation data from killmails
- [ ] Show actual fleet battles the user participated in
- [ ] Calculate fleet roles (DPS, Logi, Tackle, etc.)
- [ ] Display fleet performance metrics
- [ ] Link to detailed battle analysis

#### Recent Activity
- [x] ~~Display actual recent kills/losses from database~~ **MOVED TO SPRINT 10**
- [x] ~~Show real timestamps and system information~~ **MOVED TO SPRINT 10**
- [x] ~~Include ship types and values~~ **MOVED TO SPRINT 10**
- [ ] Add activity heatmap by hour/day
- [x] ~~Quick links to full killmail details~~ **MOVED TO SPRINT 10**

#### Real-Time Price Updates
- [ ] Fix price update subscription system
- [ ] Show live price changes for destroyed items
- [ ] Display market volatility indicators
- [ ] Track personal asset value changes
- [ ] Alert on significant price swings

## Profile Page Improvements

### Character Profile Enhancements
The user profile page needs to display comprehensive character information:

#### Character Information
- [x] ~~Display character portrait from EVE image server~~ **MOVED TO SPRINT 10**
- [x] ~~Show character name, ID, and creation date~~ **MOVED TO SPRINT 10**
- [x] ~~Add security status display~~ **MOVED TO SPRINT 10**
- [ ] Include character description/bio
- [ ] Show skill point count (if authorized)

#### Corporation & Alliance
- [x] ~~Display corporation name and ticker~~ **MOVED TO SPRINT 10**
- [x] ~~Show corporation logo~~ **MOVED TO SPRINT 10**
- [x] ~~Include alliance name and ticker (if applicable)~~ **MOVED TO SPRINT 10**
- [x] ~~Display alliance logo~~ **MOVED TO SPRINT 10**
- [ ] Show member count and founding date
- [x] ~~Link to corporation intelligence page~~ **MOVED TO SPRINT 10**

#### EVE SSO Integration
- [ ] Show authorized scopes with descriptions
- [ ] Display token expiration status
- [ ] Add "Refresh Token" button for expired tokens
- [ ] Show last token refresh time
- [ ] Allow scope management (add/remove scopes)

#### Data Export
- [ ] "Export My Data" feature for GDPR compliance
- [ ] Export formats: JSON, CSV, PDF report
- [ ] Include all killmails, statistics, and settings
- [ ] Add data deletion option
- [ ] Provide activity audit log

## Chain Intelligence Improvements

### Wormhole Chain Intelligence Page
The chain intelligence page (`/chain-intelligence`) needs significant improvements to display real wormhole chain data:

#### Chain Topology Display
- [ ] Integrate with Wanderer API for real chain data
- [ ] Display actual wormhole connections and systems
- [ ] Show chain depth and branch visualization
- [ ] Real-time updates when chain topology changes
- [ ] Visual representation of chain structure (graph/tree view)

#### Chain Inhabitants
- [ ] Query real character locations from Wanderer
- [ ] Show actual pilots currently in chain
- [ ] Display corporation/alliance affiliations
- [ ] Track entry/exit times and movements
- [ ] Highlight hostile/friendly/neutral standings

#### Recent Chain Activity
- [ ] Display real killmails from chain systems
- [ ] Show actual PvP events in the chain
- [ ] Track ship types and fleet compositions
- [ ] Monitor capital ship movements
- [ ] Alert on significant events (caps, large fleets)

#### Chain Statistics
- [ ] Calculate real chain-wide ISK destroyed
- [ ] Show actual kill/loss ratios for chain
- [ ] Display most dangerous systems based on data
- [ ] Track activity patterns by time of day
- [ ] Identify frequently used connections

#### Threat Assessment
- [ ] Analyze actual threat levels per system
- [ ] Use real killmail data for risk scoring
- [ ] Consider inhabitant threat scores
- [ ] Factor in recent activity patterns
- [ ] Provide data-driven recommendations

### Technical Requirements
```elixir
# Example: Real chain data query
def get_chain_topology(map_id) do
  WandererClient.get_map_systems(map_id)
  |> build_chain_graph()
  |> calculate_chain_metrics()
end

# Chain activity analysis
def analyze_chain_activity(chain_systems, time_window) do
  KillmailRaw
  |> filter_by_systems(chain_systems)
  |> filter_by_time(time_window)
  |> aggregate_chain_statistics()
end
```

### Integration Points
- Wanderer API for chain topology and inhabitants
- Killmail data for activity analysis
- Character intelligence for threat scoring
- Real-time updates via WebSocket/SSE
- Standing management integration

### Priority: HIGH
Chain intelligence is critical for wormhole operations and currently shows mostly placeholder data. This should be prioritized alongside surveillance features.

## Technical Implementation Notes

### Dashboard Data Queries
```elixir
# Example: Real ISK destroyed calculation
def calculate_isk_destroyed(character_id, period \\ :all_time) do
  KillmailRaw
  |> where([k], k.victim_character_id == ^character_id)
  |> filter_by_period(period)
  |> select([k], sum(k.total_value))
  |> Repo.one()
end
```

### Character Portrait URL
```elixir
def character_portrait_url(character_id, size \\ 256) do
  "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
end
```

### Export Data Structure
```json
{
  "character": {
    "id": 12345,
    "name": "Character Name",
    "corporation": "Corp Name",
    "alliance": "Alliance Name"
  },
  "statistics": {
    "total_kills": 150,
    "total_losses": 45,
    "isk_destroyed": 15000000000,
    "isk_lost": 3000000000
  },
  "killmails": [...],
  "settings": {...},
  "export_date": "2025-01-11T12:00:00Z"
}
```

## Priority Ranking

### High Priority
1. Fix ISK destroyed calculations (impacts trust in data)
2. Display character portrait and corp/alliance info
3. Fix real-time price updates
4. Implement data export for compliance

### Medium Priority
1. Fleet engagement analysis
2. Recent activity improvements
3. Token refresh functionality
4. Activity heatmaps

### Low Priority
1. Trending indicators
2. Market volatility alerts
3. Skill point display
4. Audit logging

## Estimated Effort

| Feature Group | Story Points | Complexity |
|--------------|--------------|------------|
| Dashboard ISK/Fleet/Activity | 8-10 | Medium |
| Character Profile Display | 5-6 | Low |
| EVE SSO Token Management | 4-5 | Medium |
| Data Export System | 6-8 | Medium |
| Real-time Price Fixes | 3-4 | Low |
| Chain Intelligence Improvements | 10-12 | High |
| Route Error Handling (404) | 2-3 | Low |

**Total Estimated Points**: 38-48 (1-2 full sprints)

## Route Error Handling

### Invalid Route Redirect
Currently, when users navigate to an invalid route, they get a generic error page. We should improve the user experience by redirecting to a helpful page.

#### Implementation Options
1. **Redirect to Dashboard** - Send authenticated users to `/dashboard`, others to `/`
2. **Custom 404 Page** - Create a helpful 404 page with navigation options
3. **Smart Redirect** - Analyze the URL and suggest similar valid routes

#### Technical Implementation
```elixir
# In router.ex - Add catch-all route at the end
scope "/", EveDmvWeb do
  pipe_through :browser
  
  # ... existing routes ...
  
  # Catch-all route for 404s
  get "/*path", PageController, :not_found
end

# In PageController
def not_found(conn, _params) do
  conn
  |> put_status(:not_found)
  |> put_flash(:error, "Page not found. Redirecting to home...")
  |> redirect(to: ~p"/")
end
```

#### Custom 404 Page Features
- [ ] Show "Page Not Found" message
- [ ] List popular pages (Dashboard, Kill Feed, Battle Analysis)
- [ ] Include search functionality
- [ ] Show recently visited pages
- [ ] Provide helpful navigation links

#### Smart Redirect Logic
```elixir
# Detect common mistakes and redirect appropriately
def smart_redirect(path) do
  cond do
    String.contains?(path, "character") and String.contains?(path, "intel") ->
      # User probably meant /character/:id/intelligence
      ~p"/character/#{extract_id(path)}/intelligence"
      
    String.contains?(path, "battle") ->
      # Redirect to battle analysis
      ~p"/battle"
      
    String.contains?(path, "kill") or String.contains?(path, "feed") ->
      # Redirect to kill feed
      ~p"/feed"
      
    true ->
      # Default to dashboard or home
      ~p"/"
  end
end
```

### Priority: LOW-MEDIUM
While not critical, this improves user experience and reduces confusion when users mistype URLs or use outdated bookmarks.

## Database Performance Optimizations

### N+1 Query Pattern Detection
Currently experiencing N+1 query warnings, particularly around materialized view existence checks. These need investigation and optimization.

#### Identified Issues
- [ ] **Materialized View Checks**: Multiple `pg_matviews` existence checks instead of batching
  ```sql
  SELECT EXISTS (
    SELECT 1 FROM pg_matviews 
    WHERE schemaname = 'public' AND matviewname = ?
  )
  ```
  Currently executing 5 times - should be batched or cached

#### Performance Investigation Tasks
- [ ] Identify source of repeated materialized view checks (likely Ash framework)
- [ ] Review query patterns in character analysis and intelligence features
- [ ] Implement query result caching for materialized view existence
- [ ] Add database query monitoring and alerting for N+1 patterns
- [ ] Optimize repeated ESI API calls with better caching strategies

#### Implementation Strategies
```elixir
# Cache materialized view existence checks
defmodule EveDmv.Cache.SchemaCache do
  @cache_table :schema_cache
  
  def materialized_view_exists?(view_name) do
    case :ets.lookup(@cache_table, {:matview, view_name}) do
      [{_, exists, _expires}] -> exists
      [] -> 
        exists = query_view_existence(view_name)
        cache_result({:matview, view_name}, exists)
        exists
    end
  end
end

# Batch materialized view checks
def check_multiple_views(view_names) do
  query = """
  SELECT matviewname, TRUE 
  FROM pg_matviews 
  WHERE schemaname = 'public' 
    AND matviewname = ANY($1)
  """
  
  Repo.query(query, [view_names])
  |> build_existence_map(view_names)
end
```

#### Monitoring & Alerting
- [ ] Set up query performance monitoring dashboard
- [ ] Alert on queries executing >10 times with same pattern
- [ ] Track query execution time trends
- [ ] Monitor cache hit/miss ratios
- [ ] Log slow queries for analysis

### Priority: MEDIUM
Database performance impacts user experience and system scalability. N+1 patterns can significantly degrade performance under load.

## Battle Sharing System

### Fix Sharing Feature
The battle sharing functionality in the battle analysis page is currently broken and has been temporarily disabled.

#### Issues to Resolve
- [ ] Fix battle report creation errors
- [ ] Resolve KeyError issues in battle data access
- [ ] Fix arithmetic errors in battle analysis calculations
- [ ] Test battle report sharing end-to-end
- [ ] Validate battle report data integrity

#### Implementation Tasks
- [ ] Debug and fix `create_battle_report_from_data` function
- [ ] Ensure all required fields are properly handled
- [ ] Add proper error handling for missing battle data
- [ ] Test with real battle data from the system
- [ ] Re-enable sharing UI once backend is stable

### Priority: MEDIUM
Battle sharing is a valuable feature for community engagement but not critical for core functionality.

## Dynamic Ship Role Analysis System

**✅ MOVED TO SPRINT 10** - See `/workspace/docs/sprints/current/SPRINT_10_FLEET_INTELLIGENCE_POLISH.md`

### ~~Killmail-Based Role Classification~~ 
~~Implement a sophisticated ship role analysis system that determines ship roles based on actual player fitting patterns from killmail data, rather than static ship classifications.~~

#### Core Features
- [ ] **Module Classification Engine**: Analyze fitted modules to determine ship roles
  - Tackle role detection (scramblers, webs, interdiction launchers)
  - Logistics role detection (remote reps, cap transfers, triage modules)
  - EWAR role detection (ECM, damps, painters, neuts)
  - DPS role detection (weapons, damage amplifiers)
  - Command role detection (command bursts, warfare links)
  - Exploration role detection (probe launchers, analyzers, covert ops)

- [ ] **Scheduled Analysis Job**: Daily/hourly background analysis of killmail data
  - Query recent killmails (last 7 days) for each ship type
  - Extract fitted modules from victim ships
  - Calculate role confidence scores based on module patterns
  - Update cached ship role classifications
  - Track meta changes over time

- [ ] **Real-Time Fleet Analysis**: Enhanced fleet composition analysis
  - Use dynamic role classification for fleet analysis
  - Provide confidence scores for role assignments
  - Generate tactical insights based on actual fitting patterns
  - Detect doctrine shifts and meta evolution

#### Technical Implementation

```elixir
# Core module classification system
defmodule EveDmv.Analytics.ModuleClassifier do
  @tackle_modules ["Warp Scrambler", "Warp Disruptor", "Stasis Webifier"]
  @logi_modules ["Remote Shield Booster", "Remote Armor Repairer"]
  @ewar_modules ["ECM", "Remote Sensor Dampener", "Target Painter"]
  
  def classify_ship_role(fitted_modules) do
    role_scores = calculate_role_scores(fitted_modules)
    determine_primary_role(role_scores)
  end
end

# Scheduled analysis worker
defmodule EveDmv.Workers.ShipRoleAnalysisWorker do
  use Oban.Worker, queue: :analytics
  
  def perform(%Oban.Job{}) do
    analyze_recent_killmails()
    |> update_ship_role_cache()
    |> generate_meta_trend_report()
  end
end

# Enhanced fleet analyzer
defmodule EveDmv.Analytics.FleetAnalyzer do
  def analyze_fleet_with_dynamic_roles(fleet_participants) do
    participants
    |> Enum.map(&get_dynamic_role/1)
    |> generate_tactical_insights()
  end
end
```

#### Database Schema Extensions
- [ ] **Ship Role Patterns Table**: Store aggregated role analysis results
  ```sql
  CREATE TABLE ship_role_patterns (
    ship_type_id INTEGER PRIMARY KEY,
    primary_role VARCHAR(50),
    role_distribution JSONB,
    confidence_score DECIMAL(3,2),
    sample_size INTEGER,
    last_analyzed TIMESTAMP,
    meta_trend VARCHAR(20)
  );
  ```

- [ ] **Role Analysis History**: Track role changes over time
  ```sql
  CREATE TABLE role_analysis_history (
    id SERIAL PRIMARY KEY,
    ship_type_id INTEGER,
    analysis_date DATE,
    role_distribution JSONB,
    meta_indicators JSONB
  );
  ```

#### Fleet Analysis Enhancements
- [ ] **Smart Role Detection**: 
  - If 70% of Lokis are fitted with webs → classify as `:tackle` 
  - If 60% of Stormbringers have damage modules → classify as `:dps`
  - Confidence thresholds prevent false classifications

- [ ] **Meta Trend Analysis**:
  - Detect when ship usage patterns change
  - Alert on doctrine shifts (e.g., "Loki usage shifted from DPS to tackle")
  - Track seasonal meta evolution

- [ ] **Tactical Insights Generation**:
  - "This Strategic Cruiser heavy fleet indicates high ISK investment and tactical flexibility"
  - "⚠️ No logistics support detected based on recent fitting patterns"
  - "EDENCOM ships present - arc damage effective against drone swarms"

#### Integration Points
- [ ] **Fleet Operations Analysis**: Use dynamic roles for fleet composition analysis
- [ ] **Battle Analysis**: Enhance battle reports with role-based insights
- [ ] **Character Intelligence**: Track individual pilot role preferences
- [ ] **Corporation Analysis**: Identify corp doctrine preferences and meta adaptation

#### Performance Considerations
- [ ] **Caching Strategy**: Cache role analysis results for 24-48 hours
- [ ] **Query Optimization**: Efficient killmail queries with proper indexing
- [ ] **Background Processing**: All analysis runs as background jobs
- [ ] **Graceful Fallbacks**: Fall back to static classification if insufficient data

#### Analytics Dashboard
- [ ] **Meta Trends Page**: Visualize ship role evolution over time
- [ ] **Doctrine Analysis**: Track popular fitting patterns and their effectiveness
- [ ] **Fleet Composition Insights**: Real-time analysis of fleet effectiveness based on actual meta

### Implementation Timeline
**Week 1**: Module classification engine and role scoring algorithms
**Week 2**: Scheduled analysis worker and database schema
**Week 3**: Integration with fleet analysis system and caching
**Week 4**: Analytics dashboard and meta trend visualization

### Priority: HIGH
This system would provide unprecedented insights into EVE Online fleet meta and player behavior, making EVE DMV the go-to platform for data-driven fleet analysis.

### Success Metrics
- 80%+ accuracy in role classification vs manual analysis
- Sub-second fleet analysis response times
- Detection of major meta shifts within 24-48 hours
- Positive feedback from fleet commanders on tactical insights

## Advanced Charts with LiveCharts

### Live_Charts Integration Investigation
Investigate using [live_charts](https://github.com/stax3/live_charts) for advanced charting capabilities in the application.

#### Research Tasks
- [ ] Evaluate live_charts library compatibility with Phoenix LiveView
- [ ] Test integration with real-time data streams (killmail pipeline)
- [ ] Compare performance vs current chart solutions
- [ ] Assess mobile responsiveness and accessibility
- [ ] Review customization options for EVE Online themed charts

#### Potential Use Cases
- [ ] **Fleet Composition Pie Charts**: Dynamic ship type distribution with hover details
- [ ] **ISK Destroyed Timeline**: Real-time line charts showing destruction over time
- [ ] **Battle Analysis Heatmaps**: System activity visualization
- [ ] **Chain Activity Graphs**: Wormhole chain activity patterns
- [ ] **Damage Type Analysis**: Radar charts for weapon effectiveness
- [ ] **Economic Trends**: Market price movements and volume charts

#### Technical Integration
```elixir
# Example integration in LiveView
defmodule EveDmvWeb.DashboardLive do
  use EveDmvWeb, :live_view
  alias LiveCharts.Chart

  def mount(_params, _session, socket) do
    chart_data = build_isk_destroyed_chart()
    {:ok, assign(socket, :chart_data, chart_data)}
  end

  def handle_info({:new_killmail, _killmail}, socket) do
    # Update chart data in real-time
    updated_chart = rebuild_chart_data()
    {:noreply, push_event(socket, "chart-update", updated_chart)}
  end
end
```

#### Chart Types to Investigate
- [ ] **Line Charts**: Time-series data (ISK over time, activity patterns)
- [ ] **Bar Charts**: Comparative data (ship types, corporations)
- [ ] **Pie Charts**: Distribution data (damage types, fleet composition)
- [ ] **Heatmaps**: Geographic/system activity data
- [ ] **Radar Charts**: Multi-dimensional analysis (pilot skills, ship capabilities)
- [ ] **Scatter Plots**: Correlation analysis (ISK vs activity, skill vs performance)

#### Performance Requirements
- [ ] Real-time updates without full page reloads
- [ ] Smooth animations for data transitions
- [ ] Efficient rendering with large datasets (1000+ data points)
- [ ] Mobile-optimized touch interactions
- [ ] Accessibility compliance (screen readers, keyboard navigation)

#### Implementation Phases
**Phase 1**: Basic integration and proof of concept
- Simple line chart for ISK destroyed over time
- Test real-time updates via LiveView

**Phase 2**: Advanced chart types
- Fleet composition pie charts
- Battle analysis heatmaps
- Interactive hover details and drill-down

**Phase 3**: Custom EVE Online theming
- Dark theme matching application design
- EVE-specific color schemes and iconography
- Custom tooltips with ship images and names

#### Priority: MEDIUM
Enhanced visualization would significantly improve user experience and data comprehension, but core functionality takes precedence.

#### Success Criteria
- Charts render smoothly with real-time data updates
- Mobile responsiveness maintained across all chart types
- Performance remains acceptable with large datasets
- User engagement increases with interactive visualizations

## EVE Ship Intelligence System Enhancement

### Integrate Ship Role Reference Data
Leverage the comprehensive ship information from `docs/reference/ship_info.md` to enhance our fleet analysis and character intelligence systems with real EVE Online tactical knowledge.

#### Ship Role Classification Database
- [ ] **Import Ship Reference Data**: Parse ship_info.md to create a comprehensive ship role database
  ```elixir
  defmodule EveDmv.StaticData.ShipRoles do
    @ship_roles %{
      # Battleships
      641 => %{name: "Megathron", category: :battleship, primary_role: :dps, 
              doctrine_fit: :sniper, range: :long, tank_type: :armor},
      642 => %{name: "Apocalypse", category: :battleship, primary_role: :sniper,
              doctrine_fit: :beam_laser, range: :extreme, tank_type: :armor},
      # Command Ships
      22474 => %{name: "Damnation", category: :command_ship, primary_role: :booster,
                 boost_type: :armor, survivability: :high, command_capacity: 3},
      # HACs
      12015 => %{name: "Muninn", category: :hac, primary_role: :dps,
                 doctrine_fit: :artillery, range: :long, mobility: :high}
    }
  end
  ```

#### Enhanced Fleet Analysis Features
- [ ] **Doctrine Recognition**: Automatically identify fleet doctrines based on ship compositions
  - "Armor BS Doctrine" (Megalathons + Guardians + Damnation)
  - "Muninn Fleet" (Muninns + Scimitars + Vulture + Sabres)
  - "Eagle Fleet" (Eagles + Basilisks + interdictors)
  
- [ ] **Tactical Assessment**: Provide real tactical insights based on ship roles
  - "⚠️ No logistics support detected - fleet vulnerable to attrition"
  - "🎯 Heavy tackle present (Devoter) - likely anti-capital preparation"
  - "⚡ Fast interceptor screen - high mobility doctrine"

#### Fleet Composition Intelligence
- [ ] **Role Distribution Analysis**: Calculate optimal vs actual fleet composition
  ```elixir
  def analyze_fleet_balance(fleet_ships) do
    roles = classify_ship_roles(fleet_ships)
    %{
      dps_ships: roles.dps / length(fleet_ships),
      logistics: roles.logi / length(fleet_ships), 
      tackle: roles.tackle / length(fleet_ships),
      electronic_warfare: roles.ewar / length(fleet_ships),
      recommendations: generate_balance_recommendations(roles)
    }
  end
  ```

- [ ] **Doctrine Effectiveness Scoring**: Rate fleet effectiveness based on ship synergies
  - Logistics ratio (should be ~20% for sustained combat)
  - Tank type consistency (mixed armor/shield = vulnerability)
  - Range coherence (all ships effective at same range)
  - Support ship coverage (tackle, EWAR, boosts)

#### Battle Analysis Enhancements  
- [ ] **Ship Role Impact Analysis**: Determine which roles were most effective in battles
  - "Interdictors were crucial - 80% of enemy losses occurred in bubbles"
  - "Logistics ships suffered 15% losses - insufficient escort"
  - "Command ships provided 25% effective HP bonus to fleet"

- [ ] **Counter-Doctrine Recommendations**: Suggest effective counters based on enemy fleet
  ```elixir
  def suggest_counter_doctrine(enemy_fleet) do
    dominant_ships = analyze_primary_ships(enemy_fleet)
    case dominant_ships do
      %{category: :battleship, range: :long} ->
        "Consider HAC doctrine for superior mobility and range control"
      %{primary_role: :sniper, tank_type: :shield} ->
        "Bombers effective against clustered shield snipers"
      %{heavy_tackle: true, capitals: true} ->
        "Bring ECM burst and neut ships to break tackle"
    end
  end
  ```

#### Character Intelligence Integration
- [ ] **Pilot Doctrine Preferences**: Track what doctrines characters fly most
  - "Primary Muninn pilot - prefers artillery HAC doctrines"
  - "Command specialist - frequently flies Damnation/Vulture"
  - "Interceptor pilot - high mobility tackle role"

- [ ] **Ship Specialization Analysis**: Identify pilot expertise and training focus
  ```elixir
  def analyze_pilot_specialization(character_killmails) do
    ship_usage = group_by_ship_category(character_killmails)
    %{
      primary_category: most_flown_category(ship_usage),
      specialization_score: calculate_focus_score(ship_usage),
      preferred_doctrines: identify_doctrine_patterns(ship_usage),
      skill_implications: infer_skill_training(ship_usage)
    }
  end
  ```

#### Database Schema Extensions
- [ ] **Ship Categories Table**: Store ship role classifications with metadata
  ```sql
  CREATE TABLE ship_categories (
    type_id INTEGER PRIMARY KEY,
    ship_name VARCHAR(100),
    hull_category ship_category_enum,
    primary_role ship_role_enum,
    tank_type tank_type_enum,
    optimal_range range_enum,
    doctrine_classification TEXT[],
    tactical_notes TEXT
  );
  ```

- [ ] **Fleet Doctrine Patterns**: Track common fleet compositions
  ```sql
  CREATE TABLE doctrine_patterns (
    id SERIAL PRIMARY KEY,
    doctrine_name VARCHAR(100),
    ship_composition JSONB,
    effective_range range_enum,
    primary_tank tank_type_enum,
    support_requirements JSONB,
    countered_by TEXT[]
  );
  ```

#### Real-Time Battle Intelligence
- [ ] **Live Doctrine Detection**: Identify enemy doctrines in real-time during battles
- [ ] **Tactical Alerts**: Warn about specific threats based on ship identification
  - "🚨 Sabre detected - bubble threat imminent"
  - "⚡ Rapier uncloaked - heavy webs incoming"
  - "🎯 Multiple HICs on grid - capital trap likely"

#### Advanced Fleet Metrics
- [ ] **ISK Efficiency by Role**: Calculate cost-effectiveness of different ship roles
- [ ] **Survival Rates by Category**: Track which ship types survive longest
- [ ] **Damage Application Analysis**: Measure effectiveness of different weapon systems
- [ ] **Support Ship Impact**: Quantify the value of logistics, EWAR, and booster ships

#### Implementation Strategy
**Phase 1**: Core ship role database and basic classification (1 week)
**Phase 2**: Fleet composition analysis and doctrine recognition (1-2 weeks)  
**Phase 3**: Battle analysis integration and tactical recommendations (1 week)
**Phase 4**: Character intelligence enhancement and specialization tracking (1 week)

#### Integration Points
- [ ] **Battle Analysis Page**: Enhanced fleet composition breakdown with role details
- [ ] **Character Intelligence**: Pilot specialization and doctrine preference analysis
- [ ] **Kill Feed**: Real-time doctrine identification and threat assessment
- [ ] **Chain Intelligence**: Wormhole fleet composition and threat analysis

#### Success Metrics
- Accurate doctrine identification (>90% for common fleet types)
- Useful tactical recommendations validated by experienced FCs
- Improved user engagement with enhanced analysis features
- Positive feedback from EVE players on tactical accuracy

### Priority: HIGH
This enhancement would provide unmatched tactical intelligence by combining real EVE knowledge with live data analysis, making EVE DMV essential for serious fleet commanders and intelligence analysts.

## User Profile Page Enhancements

### Recent Activity & Real-Time Updates Integration
Enhance the user profile page with comprehensive activity tracking and real-time data integration.

#### Recent Activity Section
- [ ] **Real Activity Feed**: Display actual recent kills/losses from database
  ```elixir
  def get_recent_activity(character_id, limit \\ 10) do
    KillmailRaw
    |> where([k], k.victim_character_id == ^character_id or 
                   fragment("? = ANY(?)", ^character_id, k.attackers_character_ids))
    |> order_by([k], desc: k.killmail_time)
    |> limit(^limit)
    |> preload([:victim_ship_type, :solar_system])
    |> Repo.all()
  end
  ```

- [ ] **Activity Timeline**: Show chronological activity with context
  - "Destroyed Muninn in J123456 (2 hours ago)"
  - "Lost Interceptor to Goonswarm Federation in 1DQ1-A (4 hours ago)"
  - "Participated in 50-pilot battle in Delve (1 day ago)"

- [ ] **Activity Filters**: Allow filtering by activity type
  - Kills only / Losses only / All activity
  - Ship category filters (Battleship, HAC, Frigate, etc.)
  - Time range filters (Last 24h, Week, Month)

#### ISK Destroyed & Fleet Engagement Updates
- [ ] **Real-Time ISK Calculations**: Connect to live price data and actual killmail values
  ```elixir
  def calculate_real_isk_destroyed(character_id, period \\ :last_30_days) do
    time_filter = case period do
      :last_24h -> Timex.shift(DateTime.utc_now(), days: -1)
      :last_7d -> Timex.shift(DateTime.utc_now(), days: -7)
      :last_30d -> Timex.shift(DateTime.utc_now(), days: -30)
      :all_time -> ~U[2003-05-06 00:00:00Z] # EVE launch date
    end
    
    KillmailRaw
    |> where([k], fragment("? = ANY(?)", ^character_id, k.attackers_character_ids))
    |> where([k], k.killmail_time >= ^time_filter)
    |> select([k], sum(k.total_value))
    |> Repo.one() || 0
  end
  ```

- [ ] **Fleet Engagement Analysis**: Query real fleet participation data
  - Identify multi-pilot killmails as fleet engagements
  - Calculate fleet size and composition from attackers
  - Track user's role in fleet (DPS, Logi, Tackle, Command)
  - Show fleet performance metrics (ISK efficiency, survival rate)

- [ ] **Real-Time Price Integration**: Decide on price update strategy
  **Option A**: EVE ESI Market Data
  - Query current Jita prices via ESI
  - Update ISK values hourly
  - Cache frequently destroyed ships
  
  **Option B**: Third-party Price Services
  - Integrate with EVE-Central or similar
  - Real-time price feeds
  - Historical price tracking
  
  **Option C**: Static Price Estimates**
  - Use average historical values
  - Periodic manual updates
  - Faster performance, less accuracy

#### Saved Battles & Fleets Section
- [ ] **Saved Battles Feature**: Allow users to bookmark interesting battles
  ```elixir
  defmodule EveDmv.UserContent.SavedBattle do
    use Ash.Resource,
      domain: EveDmv.Api,
      data_layer: AshPostgres.DataLayer
    
    attributes do
      uuid_primary_key :id
      attribute :user_id, :uuid, allow_nil?: false
      attribute :battle_id, :string, allow_nil?: false
      attribute :custom_name, :string
      attribute :notes, :string
      attribute :saved_at, :utc_datetime, default: &DateTime.utc_now/0
    end
  end
  ```

- [ ] **Saved Fleets Feature**: Bookmark fleet compositions for analysis
  ```elixir
  defmodule EveDmv.UserContent.SavedFleet do
    use Ash.Resource,
      domain: EveDmv.Api,
      data_layer: AshPostgres.DataLayer
    
    attributes do
      uuid_primary_key :id
      attribute :user_id, :uuid, allow_nil?: false
      attribute :fleet_name, :string, allow_nil?: false
      attribute :fleet_composition, :map # JSONB with ship types/counts
      attribute :doctrine_type, :string
      attribute :notes, :string
      attribute :created_at, :utc_datetime, default: &DateTime.utc_now/0
    end
  end
  ```

- [ ] **Quick Access Lists**: Easy access to saved content
  - Recent saved battles with thumbnails
  - Fleet comparison tools
  - Export/share saved battles
  - Battle replay functionality

#### Profile Statistics Dashboard
- [ ] **Real Statistics Grid**: Replace placeholder data with calculations
  - Total Kills/Losses with real counts
  - ISK Destroyed/Lost with accurate values
  - Favorite Ship (most flown ship type)
  - Deadliest System (most kills in)
  - Recent Performance Trend (improving/declining)

- [ ] **Activity Heatmap**: Visual activity patterns
  - Activity by hour of day
  - Activity by day of week
  - Peak activity periods
  - Seasonal patterns

### Priority: HIGH
Profile page is a primary user destination and should showcase real, meaningful data to build user engagement and trust.

## Navigation Bar Cleanup & User Experience

### Consistent Navigation Structure
Clean up the top navigation bar for better user experience and consistent logged-in state display.

#### Navigation Bar Issues to Address
- [ ] **Inconsistent Menu Items**: Standardize navigation items across pages
- [ ] **Logged-in State Visibility**: Always show user is authenticated
- [ ] **Mobile Responsiveness**: Ensure navigation works on all screen sizes
- [ ] **Active Page Indication**: Clearly show current page location

#### Proposed Navigation Structure
```elixir
# Consistent navigation items for all authenticated users
@navigation_items [
  %{name: "Kill Feed", path: "/feed", icon: "zap"},
  %{name: "Dashboard", path: "/dashboard", icon: "dashboard"},
  %{name: "Battle Analysis", path: "/battle", icon: "crosshairs"},
  %{name: "Intelligence", path: "/intelligence", icon: "eye"},
  %{name: "Chain Intel", path: "/chain-intelligence", icon: "git-branch"}
]

# User menu (always visible when logged in)
@user_menu_items [
  %{name: "Profile", path: "/profile", icon: "user"},
  %{name: "Settings", path: "/settings", icon: "settings"},
  %{name: "Sign Out", path: "/auth/logout", icon: "log-out"}
]
```

#### Implementation Tasks
- [ ] **Consistent User Indicator**: Always show logged-in user information
  ```heex
  <div class="flex items-center space-x-4">
    <!-- Character portrait (small) -->
    <img src={character_portrait_url(@current_user.character_id, 32)} 
         class="w-8 h-8 rounded-full border-2 border-blue-400" 
         alt={@current_user.character_name} />
    
    <!-- Character name with corporation ticker -->
    <div class="text-sm">
      <div class="text-white font-medium"><%= @current_user.character_name %></div>
      <div class="text-gray-400 text-xs">[<%= @current_user.corporation_ticker %>]</div>
    </div>
    
    <!-- User menu dropdown -->
    <div class="relative">
      <!-- Menu trigger and dropdown content -->
    </div>
  </div>
  ```

- [ ] **Active Page Highlighting**: Visual indication of current page
  ```heex
  <nav class="flex space-x-6">
    <%= for item <- @navigation_items do %>
      <.link navigate={item.path} 
             class={[
               "flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors",
               if(@current_page == item.path, 
                  do: "bg-blue-600 text-white", 
                  else: "text-gray-300 hover:text-white hover:bg-gray-700")
             ]}>
        <.icon name={item.icon} class="w-4 h-4 mr-2" />
        <%= item.name %>
      </.link>
    <% end %>
  </nav>
  ```

- [ ] **Mobile-First Navigation**: Collapsible menu for smaller screens
  - Hamburger menu for mobile
  - Slide-out navigation drawer
  - Touch-friendly menu items
  - Maintain user info visibility

- [ ] **Navigation Component Refactor**: Create reusable navigation component
  ```elixir
  defmodule EveDmvWeb.Components.Navigation do
    use EveDmvWeb, :live_component
    
    def render(assigns) do
      ~H"""
      <nav class="bg-gray-800 border-b border-gray-700">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-between h-16">
            <!-- Logo and main navigation -->
            <div class="flex items-center space-x-8">
              <.link navigate="/" class="text-xl font-bold text-white">
                EVE DMV
              </.link>
              <.main_navigation current_page={@current_page} />
            </div>
            
            <!-- User menu -->
            <.user_menu current_user={@current_user} />
          </div>
        </div>
      </nav>
      """
    end
  end
  ```

#### User Experience Improvements
- [ ] **Breadcrumb Navigation**: Show navigation path for deep pages
  - "Intelligence > Character > [Character Name]"
  - "Battle Analysis > Battle Details > [Battle ID]"

- [ ] **Quick Actions Menu**: Frequently used actions
  - "New Battle Analysis"
  - "Search Character"
  - "Recent Battles"

- [ ] **Notification Indicators**: Show pending items
  - New killmails since last visit
  - Battle analysis completion
  - System alerts or updates

#### Accessibility & Standards
- [ ] **ARIA Labels**: Proper accessibility attributes
- [ ] **Keyboard Navigation**: Full keyboard support
- [ ] **Screen Reader Support**: Proper semantic HTML
- [ ] **Color Contrast**: Meet WCAG guidelines
- [ ] **Focus Indicators**: Clear focus states for keyboard users

### Implementation Timeline
**Week 1**: Navigation structure cleanup and user indicator fixes
**Week 2**: Mobile responsiveness and component refactoring
**Week 3**: Accessibility improvements and testing

### Priority: MEDIUM-HIGH
Navigation is fundamental to user experience. Clean, consistent navigation builds user confidence and improves overall application usability.

## Application Health & Performance Dashboard

### System Monitoring & Diagnostics Page
Create a comprehensive health and performance monitoring dashboard for administrators and advanced users to track application performance, system health, and operational metrics.

#### Core Health Metrics
- [ ] **System Status Overview**: Real-time application health indicators
  ```elixir
  defmodule EveDmv.Monitoring.HealthCheck do
    def system_status do
      %{
        database: check_database_connection(),
        killmail_pipeline: check_pipeline_status(),
        sse_connection: check_wanderer_connection(),
        memory_usage: get_memory_metrics(),
        response_times: get_average_response_times(),
        error_rates: get_error_rates(),
        uptime: get_system_uptime()
      }
    end
    
    defp check_database_connection do
      case Ecto.Adapters.SQL.query(EveDmv.Repo, "SELECT 1", []) do
        {:ok, _} -> %{status: :healthy, latency: measure_db_latency()}
        {:error, reason} -> %{status: :unhealthy, error: reason}
      end
    end
  end
  ```

- [ ] **Performance Metrics Dashboard**: Key application performance indicators
  - Average response times by endpoint
  - Database query performance
  - Memory and CPU usage trends
  - Active user sessions
  - API rate limiting status

#### Killmail Pipeline Monitoring
- [ ] **Pipeline Health**: Monitor Broadway killmail processing pipeline
  ```elixir
  defmodule EveDmv.Monitoring.PipelineMetrics do
    def pipeline_status do
      %{
        producer_status: get_sse_producer_status(),
        processor_throughput: get_processing_rate(),
        batch_handler_performance: get_batch_metrics(),
        error_rate: get_pipeline_error_rate(),
        backlog_size: get_message_backlog(),
        last_successful_batch: get_last_batch_time()
      }
    end
    
    def get_processing_rate do
      # Calculate killmails processed per minute/hour
      recent_killmails = KillmailRaw
        |> where([k], k.inserted_at >= ^Timex.shift(DateTime.utc_now(), minutes: -5))
        |> Repo.aggregate(:count, :id)
      
      %{
        last_5_minutes: recent_killmails,
        rate_per_minute: recent_killmails / 5,
        rate_per_hour: recent_killmails * 12
      }
    end
  end
  ```

- [ ] **SSE Connection Monitoring**: Track Wanderer-Kills integration health
  - Connection status and uptime
  - Message receive rate
  - Connection error frequency
  - Reconnection attempts
  - Data quality metrics

#### Database Performance Monitoring
- [ ] **Database Health Metrics**: Monitor PostgreSQL performance
  ```elixir
  defmodule EveDmv.Monitoring.DatabaseMetrics do
    def database_performance do
      %{
        connection_pool: get_connection_pool_status(),
        query_performance: get_slow_queries(),
        table_sizes: get_table_sizes(),
        index_usage: get_index_efficiency(),
        partition_health: check_partition_status(),
        replication_lag: get_replication_metrics()
      }
    end
    
    def get_slow_queries do
      # Query pg_stat_statements for slow queries
      query = """
      SELECT query, calls, total_time, mean_time, rows
      FROM pg_stat_statements 
      WHERE mean_time > 100 
      ORDER BY mean_time DESC 
      LIMIT 10
      """
      
      case Ecto.Adapters.SQL.query(EveDmv.Repo, query, []) do
        {:ok, result} -> format_slow_queries(result)
        {:error, _} -> []
      end
    end
  end
  ```

- [ ] **Partition Management**: Monitor table partitioning health
  - Partition sizes and distribution
  - Automatic partition creation status
  - Cleanup job performance
  - Storage utilization by partition

#### Application Performance Tracking
- [ ] **Endpoint Performance**: Track Phoenix endpoint metrics
  ```elixir
  defmodule EveDmv.Monitoring.EndpointMetrics do
    def endpoint_performance do
      %{
        response_times: get_response_time_percentiles(),
        request_volume: get_request_rates(),
        error_rates: get_http_error_rates(),
        slowest_endpoints: get_slowest_endpoints(),
        user_sessions: get_active_sessions()
      }
    end
    
    # Integration with Telemetry for real-time metrics
    def handle_telemetry_event([:phoenix, :endpoint, :stop], measurements, metadata, _config) do
      duration = measurements.duration
      endpoint = metadata.route
      
      # Store metrics for dashboard
      record_endpoint_metric(endpoint, duration)
    end
  end
  ```

- [ ] **Memory and Resource Usage**: System resource monitoring
  - Erlang VM memory usage
  - Process count and mailbox sizes
  - Garbage collection frequency
  - ETS table sizes

#### Real-Time Monitoring Dashboard
- [ ] **Live Performance Charts**: Visual performance tracking
  ```heex
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
    <!-- System Status Cards -->
    <div class="bg-gray-800 p-6 rounded-lg">
      <h3 class="text-lg font-semibold text-white mb-4">System Health</h3>
      <div class="space-y-2">
        <div class="flex justify-between">
          <span class="text-gray-400">Database</span>
          <span class={status_color(@health.database.status)}>
            <%= @health.database.status %>
          </span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-400">Pipeline</span>
          <span class={status_color(@health.pipeline.status)}>
            <%= @health.pipeline.status %>
          </span>
        </div>
      </div>
    </div>
    
    <!-- Performance Metrics -->
    <div class="bg-gray-800 p-6 rounded-lg">
      <h3 class="text-lg font-semibold text-white mb-4">Performance</h3>
      <div class="space-y-2">
        <div class="flex justify-between">
          <span class="text-gray-400">Avg Response</span>
          <span class="text-white"><%= @metrics.avg_response_time %>ms</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-400">Memory Usage</span>
          <span class="text-white"><%= @metrics.memory_usage %>%</span>
        </div>
      </div>
    </div>
  </div>
  ```

- [ ] **Real-Time Updates**: Live dashboard with WebSocket updates
  - Auto-refreshing metrics every 30 seconds
  - Alert notifications for critical issues
  - Historical trend charts
  - Exportable performance reports

#### Error Tracking & Alerting
- [ ] **Error Monitoring**: Comprehensive error tracking system
  ```elixir
  defmodule EveDmv.Monitoring.ErrorTracker do
    def error_summary do
      %{
        recent_errors: get_recent_errors(),
        error_frequency: calculate_error_rates(),
        critical_errors: get_critical_errors(),
        error_trends: get_error_trends()
      }
    end
    
    def log_error(error, context \\ %{}) do
      error_data = %{
        message: Exception.message(error),
        stacktrace: Exception.format_stacktrace(__STACKTRACE__),
        context: context,
        timestamp: DateTime.utc_now(),
        severity: determine_severity(error)
      }
      
      # Store in database and trigger alerts if critical
      create_error_log(error_data)
      maybe_send_alert(error_data)
    end
  end
  ```

- [ ] **Alert System**: Configurable alerting for system issues
  - Database connection failures
  - Pipeline processing delays
  - High error rates
  - Performance degradation
  - Memory usage thresholds

#### Operational Insights
- [ ] **Usage Analytics**: Application usage patterns
  - Peak usage hours and days
  - Feature usage statistics
  - User engagement metrics
  - Geographic usage distribution

- [ ] **Capacity Planning**: Growth and scaling insights
  - Database growth rates
  - Processing capacity utilization
  - Projected scaling needs
  - Resource utilization trends

#### Administrative Tools
- [ ] **System Control Panel**: Administrative actions
  ```elixir
  defmodule EveDmvWeb.Admin.SystemControlLive do
    def render(assigns) do
      ~H"""
      <div class="space-y-6">
        <!-- Pipeline Controls -->
        <div class="bg-gray-800 p-6 rounded-lg">
          <h3 class="text-lg font-semibold text-white mb-4">Pipeline Control</h3>
          <div class="flex space-x-4">
            <button phx-click="restart_pipeline" class="btn btn-warning">
              Restart Pipeline
            </button>
            <button phx-click="flush_queue" class="btn btn-danger">
              Flush Queue
            </button>
            <button phx-click="toggle_pipeline" class="btn btn-secondary">
              <%= if @pipeline_enabled, do: "Disable", else: "Enable" %> Pipeline
            </button>
          </div>
        </div>
        
        <!-- Cache Management -->
        <div class="bg-gray-800 p-6 rounded-lg">
          <h3 class="text-lg font-semibold text-white mb-4">Cache Management</h3>
          <button phx-click="clear_all_caches" class="btn btn-warning">
            Clear All Caches
          </button>
        </div>
      </div>
      """
    end
  end
  ```

- [ ] **Maintenance Tools**: System maintenance utilities
  - Cache clearing controls
  - Pipeline restart functionality
  - Database maintenance triggers
  - Log file management

#### Security & Access Control
- [ ] **Admin-Only Access**: Restrict health dashboard to administrators
  ```elixir
  # Route protection
  scope "/admin", EveDmvWeb.Admin, as: :admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin]
    
    live "/health", HealthDashboardLive, :index
    live "/performance", PerformanceLive, :index
    live "/system", SystemControlLive, :index
  end
  ```

- [ ] **Audit Logging**: Track administrative actions
  - System control usage
  - Configuration changes
  - Access patterns
  - Security events

#### Implementation Strategy
**Phase 1**: Core health metrics and basic dashboard (1 week)
**Phase 2**: Pipeline monitoring and database metrics (1 week)
**Phase 3**: Real-time updates and error tracking (1 week)
**Phase 4**: Administrative tools and alerting (1 week)

#### Integration Points
- [ ] **Phoenix Telemetry**: Leverage built-in metrics collection
- [ ] **Prometheus/Grafana**: Optional external monitoring integration
- [ ] **Application Insights**: Performance trend analysis
- [ ] **Log Aggregation**: Centralized logging and analysis

#### Success Criteria
- Real-time visibility into application health
- Proactive identification of performance issues
- Reduced mean time to resolution for incidents
- Improved system reliability and uptime
- Data-driven capacity planning capabilities

### Priority: MEDIUM
While not user-facing, application health monitoring is crucial for maintaining service reliability and operational excellence, especially as the application scales.

## Dependencies

- EVE ESI API for character/corp/alliance data
- EVE Image Server for portraits and logos
- Proper ISK calculation algorithms
- GDPR-compliant data export framework
- WebSocket/PubSub fixes for real-time updates

## Success Criteria

- Dashboard shows only real data, no placeholders
- All calculations are accurate and verifiable
- Character information is complete and current
- Data export includes all user data
- Real-time updates work reliably
- Profile page provides comprehensive character overview