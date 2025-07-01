# Team Gamma - Intelligence & Business Logic Implementation Plan

> **AI Assistant Instructions for Intelligence & Business Logic Team**
> 
> You are Team Gamma, responsible for implementing real intelligence functionality and replacing stub implementations. You **depend on Teams Alpha and Beta** completing their foundational work.

## 🎯 **Your Mission**

Replace placeholder implementations with real intelligence analysis, refactor oversized modules, extract business logic from LiveViews, and build the core intelligence features that provide actual value to users.

## ⚠️ **Critical Instructions**

### **Quality Requirements**
After **EVERY SINGLE TASK**, you must run:
```bash
mix format
mix credo --strict
mix dialyzer
mix test --warnings-as-errors
git add -A && git commit -m "descriptive message"
```

### **No Stubs or Placeholders**
- **NEVER** create placeholder implementations
- **NEVER** use TODO comments in production code  
- **NEVER** return hardcoded data - implement real functionality using killmail data
- **NEVER** add "# Placeholder implementation" comments
- If you can't implement something fully, split into smaller tasks

### **Dependencies**
- **WAIT** for Team Alpha security fixes (Week 1)
- **WAIT** for Team Beta database optimizations (Week 3)  
- **YOU MERGE THIRD** every Friday (after Alpha and Beta)
- **COORDINATE** with Team Delta for testing as you implement

## 📋 **Phase 1 Tasks (Weeks 1-4) - FOUNDATION CLEANUP**

### **Week 1: WAIT FOR TEAM ALPHA** ⏸️
**IMPORTANT**: Do not start until Team Alpha completes security fixes

#### Task 1.1: Configure Unique Development Ports
**IMPORTANT**: Configure unique ports for Team Gamma devcontainer to avoid conflicts with other teams.

**File**: `.devcontainer/devcontainer.json` (Gamma worktree)
```json
{
  "name": "EVE DMV Gamma Team Dev Container",
  "dockerComposeFile": "../docker-compose.yml",
  "service": "app",
  "workspaceFolder": "/workspace",
  "shutdownAction": "stopCompose",
  "forwardPorts": [4013, 5436, 6383],
  "portsAttributes": {
    "4013": {
      "label": "Phoenix Server (Gamma)",
      "onAutoForward": "notify"
    },
    "5436": {
      "label": "PostgreSQL (Gamma)"
    },
    "6383": {
      "label": "Redis (Gamma)"
    }
  }
}
```

**File**: `docker-compose.yml` (Gamma worktree)
```yaml
services:
  db:
    image: postgres:17-alpine
    container_name: eve_tracker_db_gamma
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: eve_tracker_gamma
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data_gamma:/var/lib/postgresql/data
    ports:
      - "5436:5432"

  redis:
    image: redis:7-alpine
    container_name: eve_tracker_redis_gamma
    volumes:
      - redis_data_gamma:/data
    ports:
      - "6383:6379"

  app:
    container_name: eve_tracker_app_gamma
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db/eve_tracker_gamma
      - REDIS_URL=redis://redis:6379
      - PHX_HOST=localhost
      - PHX_PORT=4013
    ports:
      - "4013:4013"

volumes:
  postgres_data_gamma:
  redis_data_gamma:
  mix_deps_gamma:
  mix_build_gamma:
```

**File**: `config/dev.exs` (Gamma worktree)
```elixir
config :eve_dmv, EveDmvWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4013],
  # ... rest of config
```

#### Task 1.2: File Organization While Waiting
**Safe tasks with no dependencies**:

Remove duplicate function definitions:
**File**: `lib/eve_dmv/intelligence/wh_fleet_analyzer.ex`

Remove duplicate `get_ship_data/1` function (lines 214-227):
```elixir
# Find and remove the duplicate definition
# Keep only one implementation
```

Fix formatting issues:
**File**: `lib/eve_dmv/intelligence/member_activity_analyzer.ex`

Run `mix format` and fix any formatting issues (lines 1318-1327).

### **Week 2: WAIT FOR TEAM BETA** ⏸️
**IMPORTANT**: Wait for database schema stabilization

#### Task 2.1: Extract Business Logic from LiveViews
**File**: `lib/eve_dmv_web/live/kill_feed_live.ex`

Create context module `lib/eve_dmv/killmails/display_service.ex`:
```elixir
defmodule EveDmv.Killmails.DisplayService do
  @moduledoc """
  Business logic for killmail display and formatting
  """
  
  alias EveDmv.Eve.NameResolver
  
  def preload_killmail_names(killmails) do
    # Move the complex N+1 prevention logic here
    character_ids = extract_character_ids(killmails)
    corporation_ids = extract_corporation_ids(killmails)
    ship_type_ids = extract_ship_type_ids(killmails)
    system_ids = extract_system_ids(killmails)
    
    # Bulk load all names
    NameResolver.character_names(character_ids)
    NameResolver.corporation_names(corporation_ids)
    NameResolver.ship_names(ship_type_ids)
    NameResolver.system_names(system_ids)
    
    killmails
  end
  
  def build_killmail_from_enriched(enriched) do
    # Move the 40+ line transformation logic here
    %{
      killmail_id: enriched.killmail_id,
      killmail_time: enriched.killmail_time,
      victim: build_victim_info(enriched),
      attackers: build_attacker_info(enriched.participants),
      location: build_location_info(enriched),
      ship_destroyed: build_ship_info(enriched)
    }
  end
  
  def calculate_system_stats(killmails) do
    # Move system statistics calculation here
    # Return actual analysis instead of hardcoded values
  end
end
```

Update `KillFeedLive` to use the service:
```elixir
defmodule EveDmvWeb.Live.KillFeedLive do
  alias EveDmv.Killmails.DisplayService
  
  def handle_info({:new_killmail, enriched}, socket) do
    killmail = DisplayService.build_killmail_from_enriched(enriched)
    # ... rest of logic
  end
end
```

#### Task 2.2: Create Presentation Formatters
Create `lib/eve_dmv/presentation/formatters.ex`:
```elixir
defmodule EveDmv.Presentation.Formatters do
  @moduledoc """
  Formatting utilities for UI presentation
  """
  
  def format_isk(decimal_value) when is_struct(decimal_value, Decimal) do
    # Move ISK formatting logic here from templates
    decimal_value
    |> Decimal.to_float()
    |> format_isk()
  end
  
  def format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 2)}B ISK"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 2)}M ISK"
      value >= 1_000 -> "#{Float.round(value / 1_000, 2)}K ISK"
      true -> "#{Float.round(value, 2)} ISK"
    end
  end
  
  def format_time_ago(minutes) when is_integer(minutes) do
    # Move time formatting logic here
    cond do
      minutes < 60 -> "#{minutes} minutes ago"
      minutes < 1440 -> "#{div(minutes, 60)} hours ago"
      true -> "#{div(minutes, 1440)} days ago"
    end
  end
end
```

### **Week 3: START INTELLIGENCE REFACTORING** 🧠
**PREREQUISITE**: Team Beta has completed database work

#### Task 3.1: Split Character Analyzer 
**File**: `lib/eve_dmv/intelligence/character_analyzer.ex` (1,533 lines)

Break into focused modules:

**Core Analysis** (`lib/eve_dmv/intelligence/character_analyzer.ex`):
```elixir
defmodule EveDmv.Intelligence.CharacterAnalyzer do
  @moduledoc """
  Core character analysis coordination
  """
  
  alias EveDmv.Intelligence.{CharacterMetrics, CharacterFormatters}
  
  @spec analyze_character(integer()) :: {:ok, CharacterStats.t()} | {:error, term()}
  def analyze_character(character_id) do
    with {:ok, basic_info} <- get_character_info(character_id),
         {:ok, killmail_data} <- get_recent_killmails(character_id),
         {:ok, metrics} <- CharacterMetrics.calculate_all_metrics(character_id, killmail_data),
         {:ok, character_stats} <- save_character_stats(basic_info, metrics) do
      {:ok, character_stats}
    else
      {:error, reason} = error ->
        Logger.error("Failed to analyze character #{character_id}: #{inspect(reason)}")
        error
    end
  end
  
  # Keep only core orchestration logic here (200-300 lines max)
end
```

**Metrics Module** (`lib/eve_dmv/intelligence/character_metrics.ex`):
```elixir
defmodule EveDmv.Intelligence.CharacterMetrics do
  @moduledoc """
  Character analysis calculations and scoring
  """
  
  def calculate_all_metrics(character_id, killmail_data) do
    %{
      combat_metrics: calculate_combat_metrics(killmail_data),
      ship_usage: analyze_ship_usage(character_id, killmail_data),
      geographic_patterns: analyze_geographic_patterns(killmail_data),
      temporal_patterns: analyze_temporal_patterns(killmail_data),
      dangerous_rating: calculate_dangerous_rating(killmail_data),
      associate_analysis: analyze_associates(character_id, killmail_data)
    }
  end
  
  # Move all calculation logic here (250 lines max)
end
```

**Formatters Module** (`lib/eve_dmv/intelligence/character_formatters.ex`):
```elixir
defmodule EveDmv.Intelligence.CharacterFormatters do
  @moduledoc """
  Character analysis display formatting
  """
  
  def format_analysis_summary(character_stats) do
    # Move summary generation logic here
  end
  
  def format_ship_usage_display(ship_usage_data) do
    # Move ship usage formatting here
  end
  
  # Move all formatting logic here (200 lines max)
end
```

#### Task 3.2: Extract Ship Data Module
**File**: `lib/eve_dmv/intelligence/wh_fleet_analyzer.ex`

Extract hardcoded ship data (lines 1324-1466) to:
**File**: `lib/eve_dmv/intelligence/ship_database.ex`:
```elixir
defmodule EveDmv.Intelligence.ShipDatabase do
  @moduledoc """
  Static ship data and classifications for fleet analysis
  """
  
  def get_ship_class(ship_type_id) do
    # Move ship classification logic here
    ship_classes()[ship_type_id] || :unknown
  end
  
  def get_ship_mass(ship_type_id) do
    # Move ship mass data here
    ship_masses()[ship_type_id] || 0
  end
  
  def get_wormhole_restrictions(ship_class) do
    # Move wormhole restrictions here
  end
  
  # All static data as private functions
  defp ship_classes do
    %{
      # Move all the hardcoded ship data here
    }
  end
end
```

### **Week 4: Continue Module Splitting** 📦

#### Task 4.1: Create Team Coordination Scripts
Create shell scripts for managing multi-team git workflow with worktrees.

**File**: `scripts/merge_team_branch.sh`
```bash
#!/bin/bash
set -e

# Script to merge a team's branch into gamma (integration branch)
# Usage: ./scripts/merge_team_branch.sh [team_name]
# Example: ./scripts/merge_team_branch.sh alpha

TEAM_NAME="${1}"

if [ -z "$TEAM_NAME" ]; then
    echo "Usage: $0 [team_name]"
    echo "Available teams: alpha, beta, delta"
    exit 1
fi

# Validate team name
if [[ ! "$TEAM_NAME" =~ ^(alpha|beta|delta)$ ]]; then
    echo "Error: Invalid team name. Must be one of: alpha, beta, delta"
    exit 1
fi

# Get worktree paths dynamically
GAMMA_PATH=$(git worktree list | grep "\[gamma\]" | awk '{print $1}')
TEAM_PATH=$(git worktree list | grep "\[${TEAM_NAME}\]" | awk '{print $1}')

if [ -z "$GAMMA_PATH" ]; then
    echo "Error: Gamma worktree not found"
    exit 1
fi

if [ -z "$TEAM_PATH" ]; then
    echo "Error: ${TEAM_NAME} worktree not found"
    exit 1
fi

echo "🔄 Merging ${TEAM_NAME} branch into gamma..."
echo "Gamma path: $GAMMA_PATH"
echo "Team path: $TEAM_PATH"

# Switch to gamma worktree
cd "$GAMMA_PATH"

# Ensure we're on gamma branch
git checkout gamma

# Fetch latest changes
git fetch origin

# Ensure gamma is up to date
git pull origin gamma

# Switch to team worktree to get latest changes
cd "$TEAM_PATH"
git checkout "$TEAM_NAME"
git pull origin "$TEAM_NAME"

# Get the latest commit hash from team branch
TEAM_COMMIT=$(git rev-parse HEAD)

# Switch back to gamma
cd "$GAMMA_PATH"

# Merge team branch into gamma
echo "📝 Merging commit $TEAM_COMMIT from $TEAM_NAME into gamma"
git merge --no-ff "$TEAM_NAME" -m "Merge team $TEAM_NAME into gamma

Weekly integration merge from $TEAM_NAME team.
Commit: $TEAM_COMMIT

🤖 Generated merge via team coordination script"

# Run quality checks after merge
echo "🔍 Running quality checks after merge..."
mix format
mix credo --strict

# Check if tests pass
echo "🧪 Running tests..."
if mix test --warnings-as-errors; then
    echo "✅ All tests pass after merge"
else
    echo "❌ Tests failed after merge - manual intervention required"
    exit 1
fi

echo "✅ Successfully merged $TEAM_NAME into gamma"
echo "📋 Next steps:"
echo "  1. Review the merged changes"
echo "  2. Run ./scripts/rebase_gamma_to_teams.sh to update other teams"
echo "  3. Push gamma branch: git push origin gamma"
```

**File**: `scripts/rebase_gamma_to_teams.sh`
```bash
#!/bin/bash
set -e

# Script to rebase gamma changes to all team branches
# Usage: ./scripts/rebase_gamma_to_teams.sh
# This updates all team branches with the latest gamma integration

echo "🔄 Rebasing gamma changes to all team branches..."

# Get gamma worktree path
GAMMA_PATH=$(git worktree list | grep "\[gamma\]" | awk '{print $1}')

if [ -z "$GAMMA_PATH" ]; then
    echo "Error: Gamma worktree not found"
    exit 1
fi

# Get all team worktrees dynamically (exclude main branches)
TEAM_WORKTREES=$(git worktree list | grep -E "\[(alpha|beta|delta)\]" | awk '{print $1 ":" $NF}' | sed 's/\[//g' | sed 's/\]//g')

if [ -z "$TEAM_WORKTREES" ]; then
    echo "Warning: No team worktrees found"
    exit 0
fi

# Ensure gamma is up to date
cd "$GAMMA_PATH"
git checkout gamma
git fetch origin
git pull origin gamma

GAMMA_COMMIT=$(git rev-parse HEAD)
echo "📍 Rebasing from gamma commit: $GAMMA_COMMIT"

# Rebase each team branch
echo "$TEAM_WORKTREES" | while IFS=':' read -r WORKTREE_PATH BRANCH_NAME; do
    echo ""
    echo "🔄 Processing team: $BRANCH_NAME"
    echo "   Path: $WORKTREE_PATH"
    
    # Switch to team worktree
    cd "$WORKTREE_PATH"
    
    # Ensure we're on the correct branch
    git checkout "$BRANCH_NAME"
    
    # Fetch latest changes
    git fetch origin
    
    # Check if branch has uncommitted changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠️  Warning: $BRANCH_NAME has uncommitted changes - skipping rebase"
        echo "   Please commit or stash changes in $WORKTREE_PATH"
        continue
    fi
    
    # Get current commit before rebase
    BEFORE_COMMIT=$(git rev-parse HEAD)
    
    # Perform rebase
    echo "📝 Rebasing $BRANCH_NAME onto gamma..."
    if git rebase gamma; then
        AFTER_COMMIT=$(git rev-parse HEAD)
        
        if [ "$BEFORE_COMMIT" != "$AFTER_COMMIT" ]; then
            echo "✅ Successfully rebased $BRANCH_NAME"
            echo "   Before: $BEFORE_COMMIT"
            echo "   After:  $AFTER_COMMIT"
            
            # Run quality checks after rebase
            echo "🔍 Running quick quality check..."
            if command -v mix >/dev/null 2>&1; then
                mix format --check-formatted || {
                    echo "⚠️  Formatting issues detected in $BRANCH_NAME - please run 'mix format'"
                }
            fi
        else
            echo "ℹ️  $BRANCH_NAME already up to date with gamma"
        fi
    else
        echo "❌ Rebase failed for $BRANCH_NAME - manual intervention required"
        echo "   Path: $WORKTREE_PATH"
        echo "   Please resolve conflicts manually and run 'git rebase --continue'"
        
        # Abort the failed rebase
        git rebase --abort
        continue
    fi
done

echo ""
echo "✅ Rebase operation completed"
echo "📋 Summary:"
git worktree list
echo ""
echo "📝 Next steps for each team:"
echo "  1. Review rebased changes in their worktree"
echo "  2. Run quality checks: mix format && mix credo && mix test"
echo "  3. Push updated branches: git push origin [branch-name]"
echo ""
echo "⚠️  Note: Teams should verify their changes still work after rebase"
```

**File**: `scripts/setup_team_worktrees.sh` (bonus utility)
```bash
#!/bin/bash
set -e

# Script to set up team worktrees for the first time
# Usage: ./scripts/setup_team_worktrees.sh

BASE_DIR="$(dirname "$(pwd)")"
TEAMS=("alpha" "beta" "gamma" "delta")

echo "🏗️  Setting up team worktrees..."
echo "Base directory: $BASE_DIR"

for TEAM in "${TEAMS[@]}"; do
    WORKTREE_PATH="$BASE_DIR/$TEAM"
    
    if [ -d "$WORKTREE_PATH" ]; then
        echo "⚠️  Worktree already exists: $WORKTREE_PATH"
        continue
    fi
    
    echo "📁 Creating worktree for team $TEAM at $WORKTREE_PATH"
    
    # Create branch if it doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$TEAM"; then
        echo "🌿 Creating branch: $TEAM"
        git branch "$TEAM"
    fi
    
    # Create worktree
    git worktree add "$WORKTREE_PATH" "$TEAM"
    
    echo "✅ Created worktree for $TEAM"
done

echo ""
echo "✅ All team worktrees set up successfully"
echo "📋 Worktree list:"
git worktree list
echo ""
echo "📝 Teams can now work in their respective directories:"
for TEAM in "${TEAMS[@]}"; do
    echo "  Team $TEAM: $BASE_DIR/$TEAM"
done
```

Make all scripts executable:
```bash
chmod +x scripts/merge_team_branch.sh
chmod +x scripts/rebase_gamma_to_teams.sh
chmod +x scripts/setup_team_worktrees.sh
```

#### Task 4.2: Split WH Fleet Analyzer
**File**: `lib/eve_dmv/intelligence/wh_fleet_analyzer.ex` (1,596 lines)

Break into focused modules:

**Fleet Composition** (`lib/eve_dmv/intelligence/fleet_composition.ex`):
```elixir
defmodule EveDmv.Intelligence.FleetComposition do
  @moduledoc """
  Fleet composition analysis and optimization
  """
  
  def analyze_composition(composition_id) do
    # Move composition analysis logic here
    # Real implementation using killmail data
  end
  
  def optimize_pilot_assignments(available_pilots, doctrine_requirements) do
    # Move optimization logic here
    # Real implementation based on pilot history
  end
end
```

**Mass Calculator** (`lib/eve_dmv/intelligence/mass_calculator.ex`):
```elixir
defmodule EveDmv.Intelligence.MassCalculator do
  @moduledoc """
  Wormhole mass calculations and restrictions
  """
  
  def calculate_fleet_mass(ship_compositions) do
    # Move mass calculation logic here
    # Use real ship data from ShipDatabase
  end
  
  def check_wormhole_restrictions(fleet_mass, wormhole_class) do
    # Real wormhole restriction checking
  end
end
```

#### Task 4.2: Split Member Activity Analyzer
**File**: `lib/eve_dmv/intelligence/member_activity_analyzer.ex` (1,335 lines)

Break into:
- **Activity Analyzer** (core logic)
- **Activity Metrics** (calculations)  
- **Activity Formatters** (display)

**END OF PHASE 1** - Foundation cleanup complete

## 📋 **Phase 2 Tasks (Weeks 5-8) - STUB REPLACEMENT**

### **Week 5: Replace Home Defense Stubs** 🏠

#### Task 5.1: Implement Real Rolling Participation Analysis
**File**: `lib/eve_dmv/intelligence/home_defense_analyzer.ex`

Replace `analyze_rolling_participation/3` (lines 218-239):
```elixir
defp analyze_rolling_participation(corporation_id, start_date, end_date) do
  # Get actual rolling operations from killmail data
  rolling_systems = get_rolling_systems(corporation_id, start_date, end_date)
  
  participation = %{
    "total_rolling_ops" => length(rolling_systems),
    "member_participation" => calculate_member_rolling_participation(rolling_systems),
    "rolling_efficiency" => calculate_rolling_efficiency(rolling_systems),
    "success_rate" => calculate_rolling_success_rate(rolling_systems)
  }
  
  {:ok, participation}
end

defp get_rolling_systems(corporation_id, start_date, end_date) do
  # Query killmails in wormhole systems where corporation members were active
  # Look for patterns indicating rolling operations:
  # - Multiple jumps through same connection
  # - Ships typically used for rolling (heavy ships, carriers)
  # - Time patterns suggesting coordinated rolling
  
  query = from km in KillmailEnriched,
    join: p in assoc(km, :participants),
    where: p.corporation_id == ^corporation_id,
    where: km.killmail_time >= ^start_date,
    where: km.killmail_time <= ^end_date,
    where: fragment("? IN (SELECT system_id FROM solar_systems WHERE security_class = 'J')", km.system_id)
  
  Repo.all(query)
  |> group_by_system_and_time()
  |> identify_rolling_patterns()
end
```

#### Task 5.2: Implement Battle History Queries
Replace `get_home_system_battles/3` (lines 390-395):
```elixir
defp get_home_system_battles(corporation_id, start_date, end_date) do
  # Find corporation's home system(s) from activity patterns
  home_systems = identify_home_systems(corporation_id)
  
  # Get battles in home systems
  Enum.flat_map(home_systems, fn system_id ->
    query = from km in KillmailEnriched,
      where: km.system_id == ^system_id,
      where: km.killmail_time >= ^start_date,
      where: km.killmail_time <= ^end_date,
      where: exists(from p in assoc(km, :participants), 
                   where: p.corporation_id == ^corporation_id)
    
    Repo.all(query)
  end)
end

defp identify_home_systems(corporation_id) do
  # Analyze where corporation members are most active
  # Look for systems with high activity density
  # Consider docking/undocking patterns if available
end
```

#### Task 5.3: Implement Response Time Analysis
Replace `calculate_response_times/1` (lines 397-406):
```elixir
defp calculate_response_times(battles) do
  response_times = Enum.map(battles, fn battle ->
    # Calculate time from first hostile contact to first defender response
    calculate_battle_response_time(battle)
  end)
  |> Enum.reject(&is_nil/1)
  
  if Enum.empty?(response_times) do
    %{
      "avg_response_time" => 0,
      "fastest_response" => 0,
      "slowest_response" => 0,
      "response_rate" => 0.0
    }
  else
    %{
      "avg_response_time" => Enum.sum(response_times) / length(response_times),
      "fastest_response" => Enum.min(response_times),
      "slowest_response" => Enum.max(response_times),
      "response_rate" => length(response_times) / length(battles)
    }
  end
end
```

### **Week 6: Replace Member Activity Stubs** 👥

#### Task 6.1: Implement Real Killmail Queries
Replace `get_character_killmails/3` (lines 359-361):
```elixir
defp get_character_killmails(character_id, start_date, end_date) do
  query = from km in KillmailEnriched,
    left_join: p in assoc(km, :participants),
    where: km.victim_character_id == ^character_id or p.character_id == ^character_id,
    where: km.killmail_time >= ^start_date,
    where: km.killmail_time <= ^end_date,
    preload: [participants: p]
  
  Repo.all(query)
end
```

#### Task 6.2: Implement Activity Participation Counting
Replace all `count_*_participation/3` functions (lines 388-391):
```elixir
defp count_home_defense_participation(character_id, start_date, end_date) do
  # Count killmails in home system defense
  home_systems = get_character_home_systems(character_id)
  
  query = from km in KillmailEnriched,
    join: p in assoc(km, :participants),
    where: p.character_id == ^character_id,
    where: km.system_id in ^home_systems,
    where: km.killmail_time >= ^start_date,
    where: km.killmail_time <= ^end_date
  
  Repo.aggregate(query, :count)
end

defp count_chain_operations(character_id, start_date, end_date) do
  # Count participation in chain operations (activities in multiple connected systems)
  # Look for patterns indicating chain mapping, scouting, or combat
end

defp count_fleet_operations(character_id, start_date, end_date) do
  # Count participation in organized fleet activities
  # Look for killmails with multiple corporation members involved
end
```

#### Task 6.3: Implement Timezone Pattern Analysis
Replace `analyze_timezone_patterns/2` (lines 295-303):
```elixir
defp analyze_timezone_patterns(character_id, activity_data) do
  # Analyze activity by hour to determine timezone patterns
  hourly_activity = activity_data
  |> Enum.group_by(fn activity -> 
    activity.killmail_time 
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_time()
    |> Time.truncate(:hour)
  end)
  |> Map.new(fn {hour, activities} -> {hour, length(activities)} end)
  
  peak_hours = find_peak_activity_hours(hourly_activity)
  primary_timezone = infer_primary_timezone(peak_hours)
  
  %{
    "hourly_distribution" => hourly_activity,
    "peak_hours" => peak_hours,
    "primary_timezone" => primary_timezone,
    "activity_span" => calculate_activity_span(hourly_activity)
  }
end
```

### **Week 7: Replace WH Vetting Stubs** 🔍

#### Task 7.1: Implement WH Class Extraction
Replace `extract_wh_classes/1` (lines 361-365):
```elixir
defp extract_wh_classes(character_id) do
  # Get wormhole classes from systems where character has been active
  query = from km in KillmailEnriched,
    join: p in assoc(km, :participants),
    join: sys in SolarSystem, on: sys.system_id == km.system_id,
    where: p.character_id == ^character_id,
    where: sys.security_class == "J",
    select: sys.wormhole_class_id,
    distinct: true
  
  Repo.all(query)
  |> Enum.reject(&is_nil/1)
  |> Enum.sort()
end
```

#### Task 7.2: Implement Home Hole Identification
Replace `identify_home_holes/1` (lines 367-371):
```elixir
defp identify_home_holes(character_id) do
  # Identify likely home holes based on activity patterns
  activity_by_system = get_character_activity_by_system(character_id)
  
  # Look for systems with:
  # - High activity frequency
  # - Consistent activity over time
  # - Defensive patterns (more losses in system = likely home)
  
  activity_by_system
  |> Enum.filter(fn {system_id, activity} ->
    is_wormhole_system?(system_id) and 
    activity.frequency > 10 and
    activity.defensive_ratio > 0.3
  end)
  |> Enum.map(fn {system_id, _activity} -> system_id end)
end
```

#### Task 7.3: Implement Rolling Pattern Analysis
Replace `analyze_rolling_patterns/1` (lines 373-380):
```elixir
defp analyze_rolling_patterns(character_id) do
  # Look for rolling activity patterns in killmail data
  rolling_indicators = get_rolling_indicators(character_id)
  
  %{
    "times_rolled" => count_rolling_operations(rolling_indicators),
    "times_helped_roll" => count_rolling_assistance(rolling_indicators),
    "rolling_competency" => calculate_rolling_competency(rolling_indicators),
    "preferred_ships" => get_preferred_rolling_ships(rolling_indicators)
  }
end

defp get_rolling_indicators(character_id) do
  # Look for specific patterns that indicate rolling:
  # - Heavy ships in WH systems
  # - Multiple system transitions
  # - Activity spikes followed by quiet periods
end
```

### **Week 8: Replace Fleet Analyzer Stubs** 🚀

#### Task 8.1: Implement Counter-Doctrine Analysis
Replace `generate_counter_doctrine_analysis/1` (lines 805-819):
```elixir
def generate_counter_doctrine_analysis(target_composition) do
  # Analyze enemy composition and suggest counters based on:
  # - Ship type effectiveness matrices
  # - Range/engagement profiles
  # - Historical success rates from killmail data
  
  enemy_ships = extract_ship_types(target_composition)
  counter_strategies = Enum.map(enemy_ships, fn ship_type ->
    get_effective_counters(ship_type)
  end)
  
  %{
    "primary_threats" => identify_primary_threats(enemy_ships),
    "recommended_counters" => consolidate_counter_strategies(counter_strategies),
    "engagement_range" => recommend_engagement_range(enemy_ships),
    "success_probability" => calculate_success_probability(target_composition)
  }
end
```

#### Task 8.2: Implement Ship Cost Estimation
Replace `estimate_ship_cost/1` (lines 453-460):
```elixir
defp estimate_ship_cost(ship_type_id) do
  # Use market API integration instead of hardcoded values
  case EveDmv.Market.PriceService.get_item_price(ship_type_id) do
    {:ok, price_data} -> 
      price_data.average_price || price_data.adjusted_price || 50_000_000
    {:error, _reason} ->
      # Fallback to static ship value estimates based on ship class
      get_fallback_ship_cost(ship_type_id)
  end
end
```

**END OF PHASE 2** - Core stub replacements complete

## 📋 **Phase 3 Tasks (Weeks 9-12) - ADVANCED FEATURES**

### **Week 9: Advanced Intelligence Features** 🧠

#### Task 9.1: Implement Character Search Integration
**File**: `lib/eve_dmv_web/live/wh_vetting_live.ex`

Replace `search_characters/1` (lines 158-166):
```elixir
defp search_characters(search_term) do
  # Real ESI character search integration
  case EveDmv.Eve.EsiCharacterClient.search_characters(search_term) do
    {:ok, character_results} ->
      # Process and format results
      Enum.map(character_results, fn character ->
        %{
          character_id: character.character_id,
          character_name: character.name,
          corporation_id: character.corporation_id,
          alliance_id: character.alliance_id
        }
      end)
    
    {:error, _reason} ->
      []
  end
end
```

#### Task 9.2: Implement Eviction Group Analysis
Replace `find_eviction_group_connections/2` (lines 391-394):
```elixir
defp find_eviction_group_connections(character_id, known_eviction_groups) do
  # Analyze shared killmails and activity patterns
  character_associates = get_frequent_associates(character_id)
  
  Enum.filter(known_eviction_groups, fn group ->
    overlap = calculate_associate_overlap(character_associates, group.members)
    overlap > 0.3  # 30% overlap threshold
  end)
end
```

### **Week 10: Intelligence Integration** 🔗

#### Task 10.1: Cross-Module Intelligence Correlation
Implement correlation between different intelligence modules.

#### Task 10.2: Intelligence Caching and Performance
Optimize intelligence calculations with proper caching.

### **Week 11: UI Intelligence Features** 💻

#### Task 11.1: Advanced LiveView Intelligence
Implement advanced UI features for intelligence display.

#### Task 11.2: Real-time Intelligence Updates
Implement real-time updates for intelligence data.

### **Week 12: Intelligence Testing** 🧪

#### Task 12.1: Intelligence Feature Testing
Work with Team Delta to create comprehensive tests.

#### Task 12.2: Performance Testing
Test intelligence features under load.

## 📋 **Phase 4 Tasks (Weeks 13-16) - POLISH & COMPLETION**

### **Week 13-16: Final Intelligence Implementation**
- Complete any remaining stub replacements
- Optimize intelligence algorithms
- Implement advanced analytics
- Polish user experience

## 🚨 **Emergency Procedures**

### **If You Break Intelligence Features**
1. **IMMEDIATELY** revert to previous working state
2. **NOTIFY** teams if your changes affect UI/database
3. **FIX** the issue in a separate branch
4. **TEST** thoroughly before re-committing

### **If You Need Database Schema Changes**
1. **COORDINATE** with Team Beta first
2. **WAIT** for their approval and implementation
3. **UPDATE** your code to use new schema
4. **TEST** with the new schema

### **If Intelligence Calculations Are Wrong**
1. **DOCUMENT** the incorrect behavior
2. **IDENTIFY** the root cause in the algorithm
3. **FIX** the calculation logic
4. **VALIDATE** with test data

## ✅ **Success Criteria**

By the end of 16 weeks, you must achieve:
- [ ] **Zero stub implementations** remain in intelligence modules
- [ ] **All large files** split into focused modules under 500 lines
- [ ] **Business logic** extracted from all LiveViews
- [ ] **Intelligence features** provide real value from killmail data
- [ ] **Character analysis** works accurately with real data
- [ ] **Fleet analysis** provides actionable insights
- [ ] **Vetting system** identifies real patterns and risks

Remember: **You are building the core value proposition of the application. The intelligence features you implement must provide real, actionable insights to users based on actual EVE Online data.**