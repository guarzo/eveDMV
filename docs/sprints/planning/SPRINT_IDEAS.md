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
- [ ] Show monthly/weekly/daily breakdowns
- [ ] Show trending indicators

#### Fleet Engagements
- [ ] Calculate fleet roles (DPS, Logi, Tackle, etc.)
- [ ] Display fleet performance metrics
- [ ] Link to detailed battle analysis

#### Recent Activity
- [ ] Add activity heatmap by hour/day

#### Real-Time Price Updates
- [ ] Show live price changes for destroyed items
- [ ] Display market volatility indicators
- [ ] Track personal asset value changes
- [ ] Alert on significant price swings

## Profile Page Improvements

### Character Profile Enhancements
The user profile page needs to display comprehensive character information:

#### Character Information
- [ ] Show skill point count (if authorized)

#### Corporation & Alliance
- [ ] Show member count and founding date

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
1. Implement data export for compliance

### Medium Priority
1. Token refresh functionality
2. Activity heatmaps

### Low Priority
1. Trending indicators
2. Market volatility alerts
3. Skill point display
4. Audit logging

## Estimated Effort

| Feature Group | Story Points | Complexity |
|--------------|--------------|------------|
| EVE SSO Token Management | 4-5 | Medium |
| Data Export System | 6-8 | Medium |
| Chain Intelligence Improvements | 10-12 | High |
| Route Error Handling (404) | 2-3 | Low |
| Activity Heatmaps | 3-4 | Low |
| Mobile Navigation | 5-6 | Medium |

**Total Estimated Points**: 30-38 (1-2 full sprints)

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
- [ ] **Mobile Responsiveness**: Ensure navigation works on all screen sizes

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

## Favorites System Implementation

### User Favorites Feature
Implement a comprehensive favorites/bookmarking system allowing users to mark battles, characters, and corporations as favorites for quick access.

#### Core Features

#### User Interface Components
- [ ] **Star/Bookmark Buttons**: Add to relevant pages
  ```heex
  <!-- Character Analysis Page -->
  <div class="flex items-center space-x-4">
    <h1 class="text-2xl font-bold text-white"><%= @character.name %></h1>
    <button 
      phx-click="toggle_favorite" 
      phx-value-type="character"
      phx-value-id={@character.id}
      phx-value-name={@character.name}
      class={[
        "flex items-center px-3 py-1 rounded text-sm transition-colors",
        if(@is_favorited, 
           do: "bg-yellow-600 text-white hover:bg-yellow-700", 
           else: "bg-gray-600 text-gray-300 hover:bg-gray-500")
      ]}
    >
      <svg class="w-4 h-4 mr-1" fill={if @is_favorited, do: "currentColor", else: "none"} 
           stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
      </svg>
      <%= if @is_favorited, do: "Favorited", else: "Add to Favorites" %>
    </button>
  </div>
  ```

- [ ] **Dashboard Integration**: Replace placeholder with real data
  ```heex
  <!-- Replace empty favorites section -->
  <div>
    <h4 class="text-gray-300 text-sm font-medium mb-2">Recent Favorites</h4>
    <%= if @user_favorites != [] do %>
      <div class="space-y-2">
        <%= for favorite <- @user_favorites do %>
          <div class="flex items-center justify-between bg-gray-900 rounded p-2">
            <div class="flex items-center space-x-2">
              <span class="text-xs text-gray-500 capitalize"><%= favorite.entity_type %></span>
              <span class="text-white text-sm"><%= favorite.entity_name %></span>
            </div>
            <.link navigate={get_entity_url(favorite)} 
                   class="text-blue-400 hover:text-blue-300 text-xs">
              View
            </.link>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="bg-gray-900 rounded p-3 text-center">
        <p class="text-gray-500 text-xs">No favorites yet</p>
        <p class="text-gray-600 text-xs mt-1">Star pilots and corps from analysis pages</p>
      </div>
    <% end %>
  </div>
  ```

#### Implementation Timeline
**Week 1**: Database schema, Ash resource, basic add/remove functionality
**Week 2**: UI components, dashboard integration, favorites management page
**Week 3**: Advanced features, testing, polish

#### Priority: HIGH
The favorites system is already designed into the dashboard UI but not functional. Users expect to be able to bookmark interesting entities for quick access.

### Success Criteria
- Users can favorite/unfavorite characters, corporations, and battles
- Dashboard shows real favorited items instead of placeholder text
- Dedicated favorites management page provides full control
- Favorites persist across sessions and are tied to user accounts
- Performance remains fast even with large numbers of favorites

## Chain Intelligence Polish & Enhancement

### Chain Intelligence Page Improvements
Polish the wormhole chain intelligence page (`/chain-intelligence`) with better user experience, map management, and real-time monitoring capabilities.

#### Map Selection & Management
- [ ] **Map Dropdown Selector**: Replace sidebar list with searchable dropdown
  ```heex
  <!-- Replace current sidebar with dropdown selector -->
  <div class="bg-gray-800 rounded-lg border border-gray-700 p-4 mb-6">
    <div class="flex items-center justify-between mb-4">
      <h2 class="text-lg font-semibold text-purple-400">Select Chain Map</h2>
      <button 
        phx-click="show_add_map_modal"
        class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm"
      >
        ➕ Add Map
      </button>
    </div>
    
    <!-- Map Selector Dropdown -->
    <div class="relative">
      <button 
        phx-click="toggle_map_dropdown"
        class="w-full flex items-center justify-between bg-gray-700 border border-gray-600 rounded-lg px-4 py-3 text-left hover:border-purple-500 transition-colors"
      >
        <div class="flex items-center space-x-3">
          <%= if @selected_chain do %>
            <div class="w-3 h-3 bg-green-400 rounded-full"></div>
            <div>
              <div class="text-white font-medium">
                <%= get_map_display_name(@selected_chain, @monitored_chains) %>
              </div>
              <div class="text-xs text-gray-400">
                <%= get_map_details(@selected_chain, @monitored_chains) %>
              </div>
            </div>
          <% else %>
            <div class="w-3 h-3 bg-gray-500 rounded-full"></div>
            <div class="text-gray-400">Select a map to monitor...</div>
          <% end %>
        </div>
        <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
        </svg>
      </button>
      
      <!-- Dropdown Menu -->
      <%= if @show_map_dropdown do %>
        <div class="absolute top-full left-0 right-0 mt-1 bg-gray-700 border border-gray-600 rounded-lg shadow-lg z-50 max-h-80 overflow-y-auto">
          <!-- Search Filter -->
          <div class="p-3 border-b border-gray-600">
            <input 
              type="text"
              phx-keyup="filter_maps"
              phx-value-target="map_dropdown"
              placeholder="Search maps..."
              class="w-full bg-gray-800 border border-gray-600 rounded px-3 py-2 text-white placeholder-gray-400 focus:border-purple-500 focus:outline-none"
            />
          </div>
          
          <!-- Map List -->
          <div class="py-2">
            <%= for map <- @filtered_maps do %>
              <button 
                phx-click="select_map"
                phx-value-map_id={map.map_id}
                class="w-full px-4 py-3 text-left hover:bg-gray-600 transition-colors flex items-center justify-between"
              >
                <div class="flex items-center space-x-3">
                  <div class={[
                    "w-3 h-3 rounded-full",
                    if(map.monitoring_enabled, do: "bg-green-400", else: "bg-gray-500")
                  ]}></div>
                  <div>
                    <div class="text-white font-medium">
                      <%= map.custom_name || map.map_name || "Map #{String.slice(map.map_id, 0, 8)}" %>
                    </div>
                    <div class="text-xs text-gray-400">
                      <%= map.system_count %> systems • <%= map.connection_count %> connections
                    </div>
                  </div>
                </div>
                <div class="text-xs text-gray-500">
                  <%= time_since(map.last_activity_at) %>
                </div>
              </button>
            <% end %>
            
            <%= if Enum.empty?(@filtered_maps) do %>
              <div class="px-4 py-6 text-center text-gray-400">
                No maps found matching your search
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  </div>
  ```

- [ ] **Add Map Configuration Modal**: Comprehensive map setup wizard
  ```heex
  <%= if @show_add_map_modal do %>
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-gray-800 rounded-lg border border-gray-700 p-6 w-full max-w-2xl mx-4">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-semibold text-purple-400">Add Chain Map</h2>
          <button phx-click="hide_add_map_modal" class="text-gray-400 hover:text-white">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <form phx-submit="add_map_configuration">
          <!-- Map ID -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Wanderer Map ID *
            </label>
            <input
              type="text"
              name="map_id"
              value={@new_map_form["map_id"]}
              placeholder="Enter Wanderer map ID..."
              class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white placeholder-gray-400 focus:border-purple-500 focus:outline-none"
              required
            />
            <p class="text-xs text-gray-500 mt-1">
              Get this from your Wanderer map URL (e.g., the ID in https://wanderer.eveonline.com/map/12345)
            </p>
          </div>

          <!-- Custom Name -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Custom Map Name
            </label>
            <input
              type="text"
              name="custom_name"
              value={@new_map_form["custom_name"]}
              placeholder="e.g., Home Chain, Staging Area, etc."
              class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white placeholder-gray-400 focus:border-purple-500 focus:outline-none"
            />
          </div>

          <!-- Corporation Access -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Corporation Access
            </label>
            <select 
              name="corporation_access"
              class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white focus:border-purple-500 focus:outline-none"
            >
              <option value="personal">Personal Access Only</option>
              <option value="corp" selected>Share with Corporation</option>
              <option value="alliance">Share with Alliance</option>
            </select>
            <p class="text-xs text-gray-500 mt-1">
              Who can view and monitor this chain map
            </p>
          </div>

          <!-- Monitoring Settings -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Monitoring Settings
            </label>
            <div class="space-y-2">
              <label class="flex items-center">
                <input 
                  type="checkbox" 
                  name="auto_threat_detection"
                  checked={@new_map_form["auto_threat_detection"]}
                  class="rounded bg-gray-700 border-gray-600 text-purple-600 focus:ring-purple-500"
                />
                <span class="ml-2 text-sm text-gray-300">Auto threat detection</span>
              </label>
              <label class="flex items-center">
                <input 
                  type="checkbox" 
                  name="hostile_alerts"
                  checked={@new_map_form["hostile_alerts"]}
                  class="rounded bg-gray-700 border-gray-600 text-purple-600 focus:ring-purple-500"
                />
                <span class="ml-2 text-sm text-gray-300">Hostile activity alerts</span>
              </label>
              <label class="flex items-center">
                <input 
                  type="checkbox" 
                  name="capital_ship_alerts"
                  checked={@new_map_form["capital_ship_alerts"]}
                  class="rounded bg-gray-700 border-gray-600 text-purple-600 focus:ring-purple-500"
                />
                <span class="ml-2 text-sm text-gray-300">Capital ship movement alerts</span>
              </label>
            </div>
          </div>

          <!-- API Configuration -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-300 mb-2">
              Wanderer API Configuration
            </label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs text-gray-400 mb-1">API Endpoint</label>
                <input
                  type="url"
                  name="api_endpoint"
                  value={@new_map_form["api_endpoint"] || "http://host.docker.internal:4004"}
                  class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Update Interval (seconds)</label>
                <input
                  type="number"
                  name="update_interval"
                  value={@new_map_form["update_interval"] || "30"}
                  min="10"
                  max="300"
                  class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded text-white text-sm focus:border-purple-500 focus:outline-none"
                />
              </div>
            </div>
          </div>

          <!-- Form Actions -->
          <div class="flex justify-end space-x-3">
            <button
              type="button"
              phx-click="hide_add_map_modal"
              class="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded text-sm transition-colors"
            >
              Cancel
            </button>
            <button
              type="button"
              phx-click="test_map_connection"
              class="px-4 py-2 bg-yellow-600 hover:bg-yellow-700 rounded text-sm transition-colors"
            >
              Test Connection
            </button>
            <button
              type="submit"
              class="px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded text-sm font-medium transition-colors"
            >
              Add Map
            </button>
          </div>
        </form>
      </div>
    </div>
  <% end %>
  ```

#### Enhanced Map Management Features
- [ ] **Map Configuration Storage**: Database schema for map settings
  ```sql
  CREATE TABLE chain_map_configurations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    map_id VARCHAR(100) NOT NULL,
    custom_name VARCHAR(200),
    corporation_access VARCHAR(20) DEFAULT 'personal' CHECK (corporation_access IN ('personal', 'corp', 'alliance')),
    
    -- Monitoring settings
    auto_threat_detection BOOLEAN DEFAULT true,
    hostile_alerts BOOLEAN DEFAULT true,
    capital_ship_alerts BOOLEAN DEFAULT true,
    monitoring_enabled BOOLEAN DEFAULT true,
    
    -- API configuration
    api_endpoint VARCHAR(500) DEFAULT 'http://host.docker.internal:4004',
    update_interval INTEGER DEFAULT 30,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    sync_error_count INTEGER DEFAULT 0,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(user_id, map_id)
  );
  
  CREATE INDEX idx_chain_map_configs_user ON chain_map_configurations(user_id);
  CREATE INDEX idx_chain_map_configs_enabled ON chain_map_configurations(monitoring_enabled);
  ```

- [ ] **Connection Testing**: Validate Wanderer API connectivity
  ```elixir
  defmodule EveDmv.ChainIntelligence.MapValidator do
    def test_map_connection(map_id, api_endpoint) do
      case WandererClient.get_map_info(map_id, api_endpoint) do
        {:ok, map_data} ->
          {:ok, %{
            map_name: map_data.name,
            system_count: length(map_data.systems),
            connection_count: length(map_data.connections),
            last_activity: map_data.last_activity
          }}
          
        {:error, :not_found} ->
          {:error, "Map not found. Check the map ID and ensure it's publicly accessible."}
          
        {:error, :unauthorized} ->
          {:error, "Access denied. You may need permission to view this map."}
          
        {:error, reason} ->
          {:error, "Connection failed: #{inspect(reason)}"}
      end
    end
    
    def validate_api_endpoint(endpoint) do
      case HTTPoison.get("#{endpoint}/api/health") do
        {:ok, %{status_code: 200}} -> :ok
        {:ok, %{status_code: code}} -> {:error, "API returned status #{code}"}
        {:error, reason} -> {:error, "Cannot reach API: #{inspect(reason)}"}
      end
    end
  end
  ```

#### User Experience Improvements
- [ ] **Map Status Indicators**: Visual status for each configured map
  ```heex
  <div class="flex items-center space-x-2">
    <!-- Connection Status -->
    <div class={[
      "w-3 h-3 rounded-full",
      case @map.status do
        :connected -> "bg-green-400"
        :connecting -> "bg-yellow-400 animate-pulse"
        :error -> "bg-red-400"
        :disabled -> "bg-gray-500"
      end
    ]}></div>
    
    <!-- Map Info -->
    <div>
      <div class="text-white font-medium"><%= @map.display_name %></div>
      <div class="text-xs text-gray-400">
        <%= case @map.status do %>
          <% :connected -> %>
            <%= @map.system_count %> systems • Last sync: <%= time_since(@map.last_sync_at) %>
          <% :connecting -> %>
            Connecting to Wanderer API...
          <% :error -> %>
            Connection error (<%= @map.sync_error_count %> failures)
          <% :disabled -> %>
            Monitoring disabled
        <% end %>
      </div>
    </div>
  </div>
  ```

- [ ] **Quick Actions Menu**: Context menu for map management
  ```heex
  <div class="relative">
    <button 
      phx-click="toggle_map_menu"
      phx-value-map_id={@map.map_id}
      class="p-1 text-gray-400 hover:text-white rounded"
    >
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z"/>
      </svg>
    </button>
    
    <%= if @show_menu == @map.map_id do %>
      <div class="absolute right-0 mt-2 w-48 bg-gray-700 border border-gray-600 rounded-lg shadow-lg z-40">
        <button 
          phx-click="edit_map_config"
          phx-value-map_id={@map.map_id}
          class="w-full px-4 py-2 text-left text-sm text-gray-300 hover:bg-gray-600 hover:text-white"
        >
          ⚙️ Edit Configuration
        </button>
        <button 
          phx-click="refresh_map_data"
          phx-value-map_id={@map.map_id}
          class="w-full px-4 py-2 text-left text-sm text-gray-300 hover:bg-gray-600 hover:text-white"
        >
          🔄 Force Refresh
        </button>
        <button 
          phx-click="toggle_monitoring"
          phx-value-map_id={@map.map_id}
          class="w-full px-4 py-2 text-left text-sm text-gray-300 hover:bg-gray-600 hover:text-white"
        >
          <%= if @map.monitoring_enabled, do: "⏸️ Pause Monitoring", else: "▶️ Resume Monitoring" %>
        </button>
        <div class="border-t border-gray-600"></div>
        <button 
          phx-click="remove_map"
          phx-value-map_id={@map.map_id}
          class="w-full px-4 py-2 text-left text-sm text-red-400 hover:bg-gray-600 hover:text-red-300"
        >
          🗑️ Remove Map
        </button>
      </div>
    <% end %>
  </div>
  ```

#### Advanced Features
- [ ] **Map Sharing & Permissions**: Corporation and alliance map sharing
  ```elixir
  defmodule EveDmv.ChainIntelligence.MapSharing do
    def share_map_with_corp(map_config, corporation_id) do
      # Create shared access record
      create_map_access(%{
        map_config_id: map_config.id,
        corporation_id: corporation_id,
        access_level: :view,
        granted_by: map_config.user_id
      })
    end
    
    def get_accessible_maps(user) do
      # Get maps user owns + maps shared with their corp/alliance
      own_maps = get_user_maps(user.id)
      corp_maps = get_corporation_maps(user.eve_corporation_id)
      alliance_maps = get_alliance_maps(user.eve_alliance_id)
      
      combine_and_deduplicate([own_maps, corp_maps, alliance_maps])
    end
  end
  ```

- [ ] **Real-time Status Updates**: Live map status monitoring
  ```elixir
  defmodule EveDmv.ChainIntelligence.MapMonitor do
    use GenServer
    
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end
    
    def init(_opts) do
      # Schedule periodic map checks
      Process.send_after(self(), :check_all_maps, 30_000)
      {:ok, %{}}
    end
    
    def handle_info(:check_all_maps, state) do
      # Check all enabled maps for updates
      enabled_maps = get_all_enabled_maps()
      
      for map <- enabled_maps do
        Task.start(fn -> check_map_status(map) end)
      end
      
      # Schedule next check
      Process.send_after(self(), :check_all_maps, 30_000)
      {:noreply, state}
    end
    
    defp check_map_status(map) do
      case WandererClient.get_map_systems(map.map_id, map.api_endpoint) do
        {:ok, data} ->
          # Update map status and broadcast changes
          update_map_status(map, :connected, data)
          broadcast_map_update(map.id, :status_changed, data)
          
        {:error, reason} ->
          increment_error_count(map)
          broadcast_map_update(map.id, :connection_error, reason)
      end
    end
  end
  ```

#### Technical Implementation
- [ ] **Enhanced Database Schema**: Store map configurations and status
- [ ] **Map Configuration CRUD**: Full management interface
- [ ] **Connection Health Monitoring**: Track API reliability
- [ ] **Real-time Status Updates**: WebSocket updates for map status changes
- [ ] **Error Handling & Retry Logic**: Robust error handling for API failures

#### Implementation Timeline
**Week 1**: Database schema, basic map configuration CRUD
**Week 2**: Map dropdown UI, add map modal, connection testing
**Week 3**: Status monitoring, real-time updates, error handling
**Week 4**: Advanced features (sharing, permissions), polish and testing

#### Integration Points
- [ ] **Wanderer API Client**: Enhanced integration with configuration support
- [ ] **Real-time Updates**: WebSocket/SSE integration for live status
- [ ] **User Permissions**: Corporation/alliance access control
- [ ] **Notification System**: Alerts for map status changes

#### Success Criteria
- Users can easily add and configure new Wanderer maps
- Map status is clearly visible and updates in real-time
- Connection issues are handled gracefully with clear error messages
- Map sharing works correctly for corporation/alliance members
- Configuration changes take effect immediately

### Priority: HIGH
Chain intelligence is a core feature for wormhole operations. Better map management significantly improves user experience and operational efficiency.

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

