# Sprint Ideas & Future Improvements

This document captures ideas for future sprints and improvements that have been identified during development.

## Dashboard Improvements

### User Dashboard Fixes
The logged-in user dashboard (`/dashboard`) needs several data accuracy fixes and feature improvements:

#### ISK Destroyed Section
- [ ] Calculate real ISK destroyed values from killmail data
- [ ] Show monthly/weekly/daily breakdowns
- [ ] Include both kills and losses
- [ ] Add ISK efficiency ratio (ISK destroyed vs ISK lost)
- [ ] Show trending indicators

#### Fleet Engagements
- [ ] Query real fleet participation data from killmails
- [ ] Show actual fleet battles the user participated in
- [ ] Calculate fleet roles (DPS, Logi, Tackle, etc.)
- [ ] Display fleet performance metrics
- [ ] Link to detailed battle analysis

#### Recent Activity
- [ ] Display actual recent kills/losses from database
- [ ] Show real timestamps and system information
- [ ] Include ship types and values
- [ ] Add activity heatmap by hour/day
- [ ] Quick links to full killmail details

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
- [ ] Display character portrait from EVE image server
- [ ] Show character name, ID, and creation date
- [ ] Add security status display
- [ ] Include character description/bio
- [ ] Show skill point count (if authorized)

#### Corporation & Alliance
- [ ] Display corporation name and ticker
- [ ] Show corporation logo
- [ ] Include alliance name and ticker (if applicable)
- [ ] Display alliance logo
- [ ] Show member count and founding date
- [ ] Link to corporation intelligence page

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

### Killmail-Based Role Classification
Implement a sophisticated ship role analysis system that determines ship roles based on actual player fitting patterns from killmail data, rather than static ship classifications.

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