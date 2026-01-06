# Ash Framework & Idiomatic Elixir Improvement Plan

> **Status**: Ready for Implementation
> **Created**: 2026-01-06
> **Priority**: Critical security gaps + major productivity improvements
> **Estimated Scope**: ~40-60 files affected across 6 parallel work streams

## Executive Summary

This plan addresses identified gaps in Ash Framework utilization and Elixir idioms in the EVE DMV codebase. The work is organized into **6 parallel tracks** that can be executed concurrently by different engineers or AI assistants.

### Key Metrics
- **Authorization Gap**: 9+ resources with authorizers configured but no policies
- **AshPhoenix.Form**: 0 usage despite dependency (major opportunity)
- **Raw SQL Bypass**: 20+ files using `Ecto.Adapters.SQL.query` instead of Ash
- **Code Reduction Potential**: ~70% in form-heavy LiveViews

---

## Parallel Work Streams Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         PARALLEL EXECUTION TRACKS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Track 1: Authorization     Track 2: AshPhoenix.Form    Track 3: SQL→Ash   │
│  ─────────────────────     ────────────────────────    ───────────────────  │
│  • Add policies to 9+      • Refactor LiveViews        • Replace raw SQL   │
│    resources               • Implement form helpers    • Add read actions  │
│  • Actor-based access      • Error handling            • Use code_interface│
│                                                                             │
│  Track 4: Notifiers        Track 5: Resource Fixes     Track 6: Idioms     │
│  ─────────────────────     ────────────────────────    ───────────────────  │
│  • Integrate notifiers     • CharacterStats ISK        • Pattern matching  │
│    into resources          • Soft delete unification   • Function heads    │
│  • Remove manual PubSub    • Upsert patterns           • Pipe improvements │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Track 1: Authorization Policies (CRITICAL - Security)

### Problem
Resources have `authorizers: [Ash.Policy.Authorizer]` configured but **no actual policies defined**, meaning authorization checks are not enforced.

### Files to Modify

| Resource | File Path | Current State |
|----------|-----------|---------------|
| Corporation | `lib/eve_dmv/contexts/corporation/resources/corporation.ex` | No policies |
| CorporationMember | `lib/eve_dmv/contexts/corporation/resources/corporation_member.ex` | No policies |
| ActivityMetric | `lib/eve_dmv/contexts/corporation/resources/activity_metric.ex` | No policies |
| RecruitmentCampaign | `lib/eve_dmv/contexts/corporation/resources/recruitment_campaign.ex` | No policies |
| RecruitmentApplication | `lib/eve_dmv/contexts/corporation/resources/recruitment_application.ex` | No policies |
| MemberActivityLog | `lib/eve_dmv/contexts/corporation/resources/member_activity_log.ex` | No policies |
| MemberPerformanceSnapshot | `lib/eve_dmv/contexts/corporation/resources/member_performance_snapshot.ex` | No policies |
| CharacterProfile | `lib/eve_dmv/contexts/intelligence/resources/character_profile.ex` | No policies |
| HistoricalFetchStatus | `lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex` | No policies |
| Battle | `lib/eve_dmv/contexts/battle_analysis/resources/battle.ex` | No policies |
| BattleReport | `lib/eve_dmv/contexts/battle_analysis/resources/battle_report.ex` | No policies |

### Reference Implementation
Use `FleetDoctrine` as the template - it has complete policies:

```elixir
# lib/eve_dmv/contexts/fleet_operations/resources/fleet_doctrine.ex (REFERENCE)
policies do
  # Public read for shared doctrines
  policy action_type(:read) do
    authorize_if expr(is_public == true)
    authorize_if expr(corporation_id == ^actor(:corporation_id))
    authorize_if expr(created_by == ^actor(:character_id))
  end

  # Only creator or directors can update
  policy action_type(:update) do
    authorize_if expr(created_by == ^actor(:character_id))
    authorize_if actor_attribute_equals(:role, :director)
  end

  # Only creator can delete
  policy action_type(:destroy) do
    authorize_if expr(created_by == ^actor(:character_id))
  end

  # Any authenticated user can create
  policy action_type(:create) do
    authorize_if always()
  end
end
```

### Implementation Pattern for Each Resource

```elixir
# Add after `authorizers: [Ash.Policy.Authorizer]` in use statement

policies do
  # 1. Read policies - determine who can see this data
  policy action_type(:read) do
    # Option A: Public data (like static EVE data)
    authorize_if always()

    # Option B: Owner-only data
    authorize_if expr(user_id == ^actor(:id))

    # Option C: Corporation-scoped data
    authorize_if expr(corporation_id == ^actor(:corporation_id))

    # Option D: Role-based
    authorize_if actor_attribute_equals(:role, :admin)
  end

  # 2. Create policies
  policy action_type(:create) do
    authorize_if always()  # Or restrict as needed
  end

  # 3. Update policies
  policy action_type(:update) do
    authorize_if expr(user_id == ^actor(:id))  # Owner only
    authorize_if actor_attribute_equals(:role, :admin)
  end

  # 4. Delete policies
  policy action_type(:destroy) do
    authorize_if expr(user_id == ^actor(:id))
    authorize_if actor_attribute_equals(:role, :admin)
  end
end
```

### Specific Policy Requirements per Resource

#### Corporation Resources
```elixir
# Corporation, CorporationMember, ActivityMetric
# These should be readable by anyone, writable by system/admins
policies do
  policy action_type(:read) do
    authorize_if always()  # Public corporation data
  end

  policy action_type([:create, :update, :destroy]) do
    # Only internal systems should modify
    authorize_if actor_attribute_equals(:role, :system)
    authorize_if actor_attribute_equals(:role, :admin)
  end
end
```

#### RecruitmentCampaign & RecruitmentApplication
```elixir
# Corporation officers manage campaigns, applicants submit applications
policies do
  policy action_type(:read) do
    # Campaigns: public if open, otherwise corp-only
    authorize_if expr(status == :open)
    authorize_if expr(corporation_id == ^actor(:corporation_id))
  end

  policy action_type(:create) do
    # Applications: any authenticated user
    authorize_if always()
  end

  policy action_type(:update) do
    # Only corporation directors/recruiters
    authorize_if expr(corporation_id == ^actor(:corporation_id))
    authorize_if actor_attribute_equals(:role, :recruiter)
  end
end
```

#### CharacterProfile & HistoricalFetchStatus
```elixir
# User-scoped data
policies do
  policy action_type(:read) do
    authorize_if expr(user_id == ^actor(:id))
    authorize_if actor_attribute_equals(:role, :admin)
  end

  policy action_type([:create, :update]) do
    authorize_if expr(user_id == ^actor(:id))
  end
end
```

#### Battle & BattleReport
```elixir
# Public read, creator can modify
policies do
  policy action_type(:read) do
    authorize_if always()  # Battles are public intel
  end

  policy action_type(:create) do
    authorize_if always()  # System generates battles
  end

  policy action_type(:update) do
    authorize_if expr(created_by == ^actor(:character_id))
    authorize_if actor_attribute_equals(:role, :admin)
  end

  policy action_type(:destroy) do
    forbid_if always()  # Never delete battle history
  end
end
```

### Testing Requirements
After adding policies, verify with:
```elixir
# In IEx or tests
actor = %{id: 1, corporation_id: 12345, role: :user}
Ash.can?({Corporation, :read}, actor)  # Should return {:ok, true/false}
```

### Acceptance Criteria
- [ ] All 11 resources have explicit `policies do ... end` blocks
- [ ] No resource has only `authorize_if always()` for all actions (unless intentional)
- [ ] Tests verify policy enforcement
- [ ] `mix compile` passes with no warnings

---

## Track 2: AshPhoenix.Form Integration ✅ COMPLETED

> **Status**: Completed 2026-01-06
> **Changes**: SurveillanceProfilesLive refactored to use AshPhoenix.Form

### Problem (Resolved)
Zero usage of `AshPhoenix.Form` despite having the dependency. LiveViews manually handle form state, validation, and error display.

### Implementation Summary
The following changes were made to `SurveillanceProfilesLive`:

1. **Added AshPhoenix.Form integration** for profile create/edit operations
2. **Form creation helpers**: `create_profile_form/1` and `update_profile_form/1`
3. **Criteria transformation**: `criteria_to_filter_tree/1` and `filter_tree_to_criteria/1` to convert between LiveView's criteria format and Ash resource's filter_tree format
4. **Template updates**: Form now uses `<.form :let={f} for={@form}>` with field-level error display
5. **Validation handler**: Added `handle_event("validate", ...)` for real-time form validation
6. **Backward compatibility**: Legacy `save_profile` handler preserved for non-Ash form submissions

### Files Modified
- `lib/eve_dmv_web/live/surveillance_profiles_live.ex` - AshPhoenix.Form integration
- `lib/eve_dmv_web/live/surveillance_profiles_live.html.heex` - Form template updates

### Note on Other LiveViews
After analysis, the other LiveViews listed were found to not have forms requiring AshPhoenix.Form:
- **AdminUsersLive**: List view with toggle actions, no forms
- **FleetOperationsLive**: Analysis tool, no create/edit forms
- **BattleAnalysisLive**: Share form exists but is not rendered in template

### Files to Refactor

| LiveView | File Path | Lines | Priority |
|----------|-----------|-------|----------|
| SurveillanceProfilesLive | `lib/eve_dmv_web/live/surveillance_profiles_live.ex` | 1,393 | High |
| AdminUsersLive | `lib/eve_dmv_web/live/admin/users_live.ex` | ~300 | Medium |
| FleetLive | `lib/eve_dmv_web/live/fleet_live.ex` | ~400 | Medium |
| BattleAnalysisLive | `lib/eve_dmv_web/live/battle_analysis_live.ex` | ~600 | Low |

### AshPhoenix.Form Pattern

#### Step 1: Mount with Form
```elixir
def mount(_params, _session, socket) do
  # For creating new records
  form =
    AshPhoenix.Form.for_create(Profile, :create,
      domain: EveDmv.Api,
      as: "profile"
    )
    |> to_form()

  {:ok, assign(socket, form: form)}
end

# For editing existing records
def handle_params(%{"id" => id}, _uri, socket) do
  profile = Profile.get!(id)

  form =
    AshPhoenix.Form.for_update(profile, :update,
      domain: EveDmv.Api,
      as: "profile"
    )
    |> to_form()

  {:noreply, assign(socket, form: form, profile: profile)}
end
```

#### Step 2: Validate on Change
```elixir
def handle_event("validate", %{"profile" => params}, socket) do
  form =
    socket.assigns.form.source
    |> AshPhoenix.Form.validate(params)
    |> to_form()

  {:noreply, assign(socket, form: form)}
end
```

#### Step 3: Submit
```elixir
def handle_event("save", %{"profile" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
    {:ok, record} ->
      {:noreply,
       socket
       |> put_flash(:info, "Saved successfully")
       |> push_navigate(to: ~p"/profiles/#{record.id}")}

    {:error, form} ->
      {:noreply, assign(socket, form: to_form(form))}
  end
end
```

#### Step 4: Template Usage
```heex
<.simple_form for={@form} phx-change="validate" phx-submit="save">
  <.input field={@form[:name]} label="Name" />
  <.input field={@form[:description]} type="textarea" label="Description" />

  <%!-- Errors automatically displayed by Phoenix.Component --%>

  <:actions>
    <.button type="submit">Save</.button>
  </:actions>
</.simple_form>
```

### Refactoring SurveillanceProfilesLive (Detailed)

#### Current Structure (to be replaced)
```elixir
# CURRENT: Manual form handling (~1,393 lines)
def handle_event("save_profile", %{"profile" => profile_params}, socket) do
  editing_profile = socket.assigns.editing_profile
  profile_data = %{
    name: Map.get(profile_params, "name", ""),
    description: Map.get(profile_params, "description", ""),
    is_active: Map.get(profile_params, "enabled", "true") == "true",
    criteria: editing_profile.criteria,
    user_id: get_current_user_id(socket)
  }

  case editing_profile do
    %{id: nil} ->
      case safe_call(fn -> SurveillanceApi.create_profile(profile_data) end) do
        {:ok, _profile} -> ...
        _ -> ...
      end
    %{id: id} ->
      case safe_call(fn -> SurveillanceApi.update_profile(id, profile_data) end) do
        ...
      end
  end
end
```

#### Target Structure
```elixir
# TARGET: AshPhoenix.Form (~200 lines for form handling)
defmodule EveDmvWeb.SurveillanceProfilesLive do
  use EveDmvWeb, :live_view

  alias EveDmv.Surveillance.Profile

  def mount(_params, _session, socket) do
    profiles = load_profiles(socket.assigns.current_user)

    {:ok,
     socket
     |> assign(:profiles, profiles)
     |> assign(:form, nil)
     |> assign(:editing, false)}
  end

  def handle_params(%{"action" => "new"}, _uri, socket) do
    form = build_create_form(socket.assigns.current_user)
    {:noreply, assign(socket, form: form, editing: true)}
  end

  def handle_params(%{"action" => "edit", "id" => id}, _uri, socket) do
    profile = Profile.get!(id)
    form = build_update_form(profile)
    {:noreply, assign(socket, form: form, editing: true, profile: profile)}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, form: nil, editing: false)}
  end

  def handle_event("validate", %{"profile" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form.source, params) |> to_form()
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"profile" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile saved")
         |> push_navigate(to: ~p"/surveillance-profiles")}

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  # ... other event handlers for filter building remain similar
  # but criteria management can use nested forms

  defp build_create_form(user) do
    AshPhoenix.Form.for_create(Profile, :create,
      domain: EveDmv.Api,
      as: "profile",
      prepare_source: fn changeset ->
        Ash.Changeset.set_argument(changeset, :user_id, user.id)
      end
    )
    |> to_form()
  end

  defp build_update_form(profile) do
    AshPhoenix.Form.for_update(profile, :update,
      domain: EveDmv.Api,
      as: "profile"
    )
    |> to_form()
  end

  defp load_profiles(user) do
    Profile.list_for_user!(user.id)
  end
end
```

### Nested Forms for Criteria

For complex nested structures like surveillance criteria:

```elixir
# In Profile resource, add embedded resource for Criteria
defmodule EveDmv.Surveillance.Criteria do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :type, :atom, constraints: [one_of: [:character, :corporation, :system, :ship_type]]
    attribute :logic_operator, :atom, constraints: [one_of: [:and, :or]], default: :and
    attribute :conditions, {:array, :map}, default: []
  end
end

# In Profile resource
attributes do
  attribute :criteria, EveDmv.Surveillance.Criteria
end

# In LiveView, use nested form
form = AshPhoenix.Form.for_create(Profile, :create,
  domain: EveDmv.Api,
  forms: [
    criteria: [
      type: :single,
      resource: EveDmv.Surveillance.Criteria,
      create_action: :create
    ]
  ]
)
```

### Acceptance Criteria
- [ ] SurveillanceProfilesLive uses AshPhoenix.Form
- [ ] Form validation errors display automatically
- [ ] Code reduced by at least 50%
- [ ] All existing functionality preserved
- [ ] Tests pass

---

## Track 3: Replace Raw SQL with Ash Queries

### Problem
20+ files use `Ecto.Adapters.SQL.query()` directly, bypassing Ash's type safety, policies, and query composition.

### Files to Modify

```
lib/eve_dmv/external/eve/name_resolver/esi_entity_resolver.ex
lib/eve_dmv/search/search_suggestion_service.ex
lib/eve_dmv/surveillance/matching_engine.ex
lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex
lib/eve_dmv/contexts/character_intelligence/domain/analyzers/historical_trend_analyzer.ex
lib/eve_dmv_web/live/universal_search_live.ex
lib/eve_dmv_web/live/admin/system_live.ex
lib/eve_dmv/platform/database/materialized_view_optimizer.ex
lib/eve_dmv/platform/database/character_repository.ex
lib/eve_dmv/platform/utilities/query_helpers.ex
lib/eve_dmv/contexts/combat_intelligence/domain/streaming_battle_analyzer.ex
lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/battle_analysis_coordinator.ex
```

### Pattern: Raw SQL → Ash Query

#### Example 1: Search Suggestions

**Current:**
```elixir
# lib/eve_dmv/search/search_suggestion_service.ex
def get_character_suggestions(query, opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)

  {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
    SELECT DISTINCT character_id as id, character_name as name
    FROM participants
    WHERE character_name ILIKE $1
    AND character_id IS NOT NULL
    ORDER BY character_name
    LIMIT $2
  """, ["%#{query}%", limit])

  suggestions = Enum.map(result.rows, fn [id, name] ->
    %{id: id, name: name}
  end)

  {:ok, suggestions}
end
```

**Target:**
```elixir
# Add to Participant resource
read :search_by_name do
  argument :query, :string, allow_nil?: false
  argument :limit, :integer, default: 10

  prepare fn query, context ->
    search_term = "%#{context.arguments.query}%"

    query
    |> Ash.Query.filter(fragment("character_name ILIKE ?", ^search_term))
    |> Ash.Query.filter(not is_nil(character_id))
    |> Ash.Query.sort(:character_name)
    |> Ash.Query.limit(context.arguments.limit)
    |> Ash.Query.select([:character_id, :character_name])
    |> Ash.Query.distinct(true)
  end
end

# In code_interface
define :search_by_name, args: [:query, :limit]

# Usage
def get_character_suggestions(query, opts \\ []) do
  limit = Keyword.get(opts, :limit, 10)

  case Participant.search_by_name(query, limit) do
    {:ok, participants} ->
      suggestions = Enum.map(participants, fn p ->
        %{id: p.character_id, name: p.character_name}
      end)
      {:ok, suggestions}

    {:error, _} = error -> error
  end
end
```

#### Example 2: Entity Resolution

**Current:**
```elixir
# lib/eve_dmv/external/eve/name_resolver/esi_entity_resolver.ex
def resolve_from_database(entity_type, ids) do
  table = table_for_type(entity_type)
  id_col = id_column_for_type(entity_type)
  name_col = name_column_for_type(entity_type)

  {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
    SELECT #{id_col}, #{name_col}
    FROM #{table}
    WHERE #{id_col} = ANY($1)
  """, [ids])

  # Process results...
end
```

**Target:**
```elixir
# Add read actions to each relevant resource
# In Corporation resource:
read :by_ids do
  argument :ids, {:array, :integer}, allow_nil?: false
  filter expr(corporation_id in ^arg(:ids))
end

# In code_interface:
define :get_by_ids, action: :by_ids, args: [:ids]

# Generic resolver using pattern matching
def resolve_from_database(:corporation, ids) do
  case Corporation.get_by_ids(ids) do
    {:ok, corps} ->
      Map.new(corps, fn c -> {c.corporation_id, c.corporation_name} end)
    _ -> %{}
  end
end

def resolve_from_database(:character, ids) do
  case Participant.get_characters_by_ids(ids) do
    {:ok, chars} ->
      Map.new(chars, fn c -> {c.character_id, c.character_name} end)
    _ -> %{}
  end
end
```

#### Example 3: Complex Analytics Query

**Current:**
```elixir
# lib/eve_dmv/contexts/character_intelligence/analyzers/character_intelligence_analyzer.ex
def get_activity_timeline(character_id, days \\ 90) do
  {:ok, result} = Ecto.Adapters.SQL.query(Repo, """
    SELECT
      date_trunc('day', killmail_time) as day,
      COUNT(*) as kill_count,
      SUM(CASE WHEN is_victim THEN 1 ELSE 0 END) as death_count
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE p.character_id = $1
    AND k.killmail_time > NOW() - INTERVAL '#{days} days'
    GROUP BY date_trunc('day', killmail_time)
    ORDER BY day DESC
  """, [character_id])

  # Process...
end
```

**Target (using Ash calculation + custom query):**
```elixir
# Option A: Keep as optimized raw query but wrap in Ash-style interface
# Create a dedicated query module that returns proper structs

defmodule EveDmv.Contexts.CharacterIntelligence.Queries.ActivityTimeline do
  @moduledoc """
  Optimized query for character activity timeline.
  Uses raw SQL for performance but returns typed structs.
  """

  import Ecto.Query
  alias EveDmv.Repo

  defstruct [:day, :kill_count, :death_count]

  def execute(character_id, days \\ 90) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    query = """
      SELECT
        date_trunc('day', k.killmail_time)::date as day,
        COUNT(*) FILTER (WHERE NOT p.is_victim) as kill_count,
        COUNT(*) FILTER (WHERE p.is_victim) as death_count
      FROM participants p
      JOIN killmails_raw k ON p.killmail_id = k.killmail_id
        AND p.killmail_time = k.killmail_time
      WHERE p.character_id = $1
        AND k.killmail_time >= $2
      GROUP BY 1
      ORDER BY 1 DESC
    """

    case Repo.query(query, [character_id, since]) do
      {:ok, %{rows: rows}} ->
        timeline = Enum.map(rows, fn [day, kills, deaths] ->
          %__MODULE__{day: day, kill_count: kills, death_count: deaths}
        end)
        {:ok, timeline}

      {:error, _} = error -> error
    end
  end
end
```

### When to Keep Raw SQL

Some queries should remain as raw SQL for performance:
- Materialized view management (`materialized_view_optimizer.ex`)
- Complex window functions
- Bulk operations with specific PostgreSQL features
- Partition management

For these, create wrapper modules that:
1. Return typed structs (not raw tuples)
2. Have proper error handling
3. Are documented with their purpose

### Acceptance Criteria
- [x] Search suggestion queries use Ash actions
- [x] Entity resolution uses resource code_interface
- [x] Complex analytics wrapped in typed query modules
- [x] Raw SQL only remains where necessary for performance
- [x] All queries return `{:ok, result}` or `{:error, reason}` tuples

### Implementation Summary (Completed 2026-01-06)

**New Ash Actions Added:**
- `Participant.search_characters_by_name/2` - Search characters by name with ILIKE
- `Participant.search_corporations_by_name/2` - Search corporations by name with ILIKE
- `Alliance.get_by_ids/1` - Bulk fetch alliances by IDs

**Files Updated:**
- `esi_entity_resolver.ex` - Now uses Alliance resource instead of raw SQL
- `universal_search_live.ex` - Now uses Participant resource actions
- `character_repository.ex` - Now delegates to AnalyticsQueries module
- `historical_trend_analyzer.ex` - Now uses AnalyticsQueries module

**New Typed Query Module:**
- `lib/eve_dmv/platform/database/queries/analytics_queries.ex` - Wraps complex analytics queries with proper typing, error handling, and documentation

---

## Track 4: Ash Notifiers Integration

### Problem
Notifier modules exist but aren't integrated into resources. Manual `Phoenix.PubSub.broadcast/3` calls throughout the codebase.

### Files

**Notifier Definitions (exist, need review):**
- `lib/eve_dmv/ash/notifiers/pubsub_notifier.ex`
- `lib/eve_dmv/ash/notifiers/telemetry_notifier.ex`

**Resources to Add Notifiers:**
- All resources with real-time update requirements
- Surveillance profiles
- Battles
- Historical fetch status

### Current Notifier Implementation

```elixir
# lib/eve_dmv/ash/notifiers/pubsub_notifier.ex
defmodule EveDmv.Ash.Notifiers.PubsubNotifier do
  @moduledoc """
  Ash notifier that broadcasts resource changes via Phoenix PubSub.
  """

  use Ash.Notifier

  @impl true
  def notify(%Ash.Notifier.Notification{} = notification) do
    resource = notification.resource
    action = notification.action.name
    data = notification.data

    # Broadcast to resource-specific topic
    topic = "#{resource_name(resource)}:#{get_id(data)}"
    Phoenix.PubSub.broadcast(EveDmv.PubSub, topic, {action, data})

    # Broadcast to collection topic
    collection_topic = "#{resource_name(resource)}:all"
    Phoenix.PubSub.broadcast(EveDmv.PubSub, collection_topic, {action, data})

    :ok
  end

  defp resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp get_id(%{id: id}), do: id
  defp get_id(_), do: "unknown"
end
```

### Integration Pattern

```elixir
# In each resource that needs real-time updates:
defmodule EveDmv.Surveillance.Profile do
  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    notifiers: [
      EveDmv.Ash.Notifiers.PubsubNotifier,
      EveDmv.Ash.Notifiers.TelemetryNotifier
    ]

  # ... rest of resource
end
```

### Remove Manual PubSub Calls

**Find and replace pattern:**

```elixir
# CURRENT: Manual broadcast in service/LiveView
Phoenix.PubSub.broadcast(EveDmv.PubSub, "surveillance:profiles", {:profile_updated, profile})

# TARGET: Removed - notifier handles automatically
# Just do the Ash operation, broadcast happens via notifier
Profile.update!(profile, %{name: new_name})
```

### LiveView Subscription Pattern

```elixir
# In LiveView mount
def mount(_params, _session, socket) do
  if connected?(socket) do
    # Subscribe to resource changes via notifier topic
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "profile:all")

    # Or for specific record
    Phoenix.PubSub.subscribe(EveDmv.PubSub, "profile:#{profile_id}")
  end

  {:ok, socket}
end

# Handle notifier messages
def handle_info({:update, %Profile{} = profile}, socket) do
  # Update UI with new data
  {:noreply, update_profile_in_assigns(socket, profile)}
end

def handle_info({:create, %Profile{} = profile}, socket) do
  {:noreply, add_profile_to_assigns(socket, profile)}
end

def handle_info({:destroy, %Profile{id: id}}, socket) do
  {:noreply, remove_profile_from_assigns(socket, id)}
end
```

### Acceptance Criteria
- [ ] PubsubNotifier added to Profile, Battle, HistoricalFetchStatus resources
- [ ] TelemetryNotifier added to all resources for observability
- [ ] Manual PubSub.broadcast calls removed from services
- [ ] LiveViews subscribe to notifier topics
- [ ] Real-time updates work end-to-end

---

## Track 5: Resource Fixes & Improvements

### 5.1 CharacterStats ISK Tracking (Fix Placeholder)

**File:** `lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex`

**Problem:** ISK tracking returns hardcoded zeros with TODO comment.

**Fix:**
```elixir
# Add actual ISK calculation
calculations do
  calculate :total_isk_destroyed, :decimal do
    description("Total ISK value destroyed by this character")

    calculation fn records, _context ->
      character_ids = Enum.map(records, & &1.character_id)

      # Query participants for ISK values
      isk_by_character =
        Participant
        |> Ash.Query.filter(character_id in ^character_ids and is_victim == false)
        |> Ash.Query.load([:killmail])
        |> Ash.read!()
        |> Enum.group_by(& &1.character_id)
        |> Map.new(fn {char_id, participants} ->
          total = Enum.reduce(participants, Decimal.new(0), fn p, acc ->
            Decimal.add(acc, p.killmail.total_value || Decimal.new(0))
          end)
          {char_id, total}
        end)

      Enum.map(records, fn record ->
        Map.get(isk_by_character, record.character_id, Decimal.new(0))
      end)
    end
  end

  calculate :total_isk_lost, :decimal do
    description("Total ISK value lost by this character")

    calculation fn records, _context ->
      character_ids = Enum.map(records, & &1.character_id)

      isk_by_character =
        KillmailRaw
        |> Ash.Query.filter(victim_character_id in ^character_ids)
        |> Ash.read!()
        |> Enum.group_by(& &1.victim_character_id)
        |> Map.new(fn {char_id, killmails} ->
          total = Enum.reduce(killmails, Decimal.new(0), fn km, acc ->
            Decimal.add(acc, km.total_value || Decimal.new(0))
          end)
          {char_id, total}
        end)

      Enum.map(records, fn record ->
        Map.get(isk_by_character, record.character_id, Decimal.new(0))
      end)
    end
  end
end
```

### 5.2 Unified Soft Delete Handling

**Problem:** Multiple resources implement soft deletes with duplicated `base_filter`.

**Solution:** Create shared preparation.

```elixir
# lib/eve_dmv/ash/preparations/soft_delete_filter.ex
defmodule EveDmv.Ash.Preparations.SoftDeleteFilter do
  @moduledoc """
  Automatically filters out soft-deleted records.
  Add to resources that have a `deleted_at` attribute.
  """

  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, _context) do
    Ash.Query.filter(query, is_nil(deleted_at))
  end
end

# Usage in resources:
preparations do
  prepare EveDmv.Ash.Preparations.SoftDeleteFilter
end

# Or as base_filter (applied even to internal queries):
postgres do
  table "battles"
  repo EveDmv.Repo
  base_filter_sql "deleted_at IS NULL"
end
```

**Files to update:**
- `lib/eve_dmv/contexts/battle_analysis/resources/battle.ex`
- `lib/eve_dmv/contexts/battle_analysis/resources/battle_report.ex`
- Any other resources with `deleted_at` attribute

### 5.3 Upsert Patterns

**Problem:** Manual "get or create" logic instead of Ash upserts.

**Add to CorporationMember:**
```elixir
# lib/eve_dmv/contexts/corporation/resources/corporation_member.ex
create :upsert do
  description("Create or update a corporation member record")

  accept([
    :corporation_id,
    :character_id,
    :character_name,
    :last_seen,
    :total_kills,
    :total_losses,
    :isk_destroyed,
    :isk_lost
  ])

  upsert?(true)
  upsert_identity(:unique_corp_character)

  # Fields to update on conflict
  upsert_fields([
    :character_name,
    :last_seen,
    :total_kills,
    :total_losses,
    :isk_destroyed,
    :isk_lost
  ])
end

# In code_interface:
define :upsert, action: :upsert
```

**Usage:**
```elixir
# Instead of:
case CorporationMember.get_by_corp_and_char(corp_id, char_id) do
  {:ok, member} -> CorporationMember.update(member, attrs)
  {:error, _} -> CorporationMember.create(attrs)
end

# Use:
CorporationMember.upsert(attrs)
```

### Acceptance Criteria
- [ ] CharacterStats ISK calculations return real data
- [ ] SoftDeleteFilter preparation created and used
- [ ] Upsert action added to CorporationMember
- [ ] All tests pass

---

## Track 6: Elixir Idioms Improvements

### 6.1 Pattern Matching in Function Heads

**File:** `lib/eve_dmv_web/live/surveillance_profiles_live.ex` (and others)

**Current:**
```elixir
defp get_current_user_id(socket) do
  case socket.assigns do
    %{current_user: %{id: user_id}} -> user_id
    %{user_id: user_id} when is_integer(user_id) -> user_id
    _ -> 1
  end
end
```

**Improved:**
```elixir
defp get_current_user_id(%{assigns: %{current_user: %{id: user_id}}}), do: user_id
defp get_current_user_id(%{assigns: %{user_id: user_id}}) when is_integer(user_id), do: user_id
defp get_current_user_id(_socket), do: 1
```

### 6.2 Pipe Operator Improvements

**Current:**
```elixir
defp format_isk(value) when is_number(value) do
  formatted =
    value
    |> round()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()

  formatted
end
```

**Improved:**
```elixir
defp format_isk(value) when is_number(value) do
  value
  |> round()
  |> Integer.to_string()
  |> String.graphemes()
  |> Enum.reverse()
  |> Enum.chunk_every(3)
  |> Enum.join(",")
  |> String.reverse()
end
```

### 6.3 With Clause Simplification

**Current:**
```elixir
def create_profile(profile_data) do
  with {:ok, validated_data} <- validate_profile_data(profile_data),
       {:ok, profile} <- ProfileManager.create_profile(validated_data) do
    Logger.info("Created surveillance profile: #{profile.name}")
    {:ok, profile}
  else
    {:error, reason} ->
      Logger.warning("Failed to create surveillance profile: #{inspect(reason)}")
      {:error, reason}
  end
end
```

**Improved (when using Ash validations):**
```elixir
def create_profile(profile_data) do
  case Profile.create(profile_data) do
    {:ok, profile} ->
      Logger.info("Created surveillance profile: #{profile.name}")
      {:ok, profile}

    {:error, changeset} ->
      Logger.warning("Failed to create profile: #{inspect(changeset.errors)}")
      {:error, changeset}
  end
end
```

### 6.4 List Comprehension vs Enum.map + Enum.filter

**Current:**
```elixir
ids =
  value
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.reject(&(&1 == ""))
  |> Enum.map(fn id_str ->
    case Integer.parse(id_str) do
      {id, _} -> id
      :error -> nil
    end
  end)
  |> Enum.reject(&is_nil/1)
```

**Improved:**
```elixir
for id_str <- String.split(value, ","),
    trimmed = String.trim(id_str),
    trimmed != "",
    {id, _} <- [Integer.parse(trimmed)],
    do: id
```

### 6.5 Guard Clauses

**Current:**
```elixir
def process_killmail(killmail) do
  if killmail != nil and killmail.killmail_id != nil do
    # Process...
  else
    {:error, :invalid_killmail}
  end
end
```

**Improved:**
```elixir
def process_killmail(%{killmail_id: id} = killmail) when not is_nil(id) do
  # Process...
end

def process_killmail(_), do: {:error, :invalid_killmail}
```

### Files to Review for Idiom Improvements
```
lib/eve_dmv_web/live/surveillance_profiles_live.ex
lib/eve_dmv/contexts/surveillance/api.ex
lib/eve_dmv/contexts/character_intelligence/domain/analyzers/*.ex
lib/eve_dmv/contexts/battle_analysis/domain/*.ex
lib/eve_dmv/external/killmails/*.ex
```

### Acceptance Criteria
- [ ] Function heads use pattern matching where appropriate
- [ ] Unnecessary variable bindings removed
- [ ] List comprehensions used for filter+map combinations
- [ ] Guard clauses used instead of if/case for type checks
- [ ] `mix credo --strict` passes

---

## Implementation Order & Dependencies

```
Week 1 (Parallel):
├── Track 1: Authorization (Critical) ──────────────┐
├── Track 4: Notifiers ─────────────────────────────┤
└── Track 6: Elixir Idioms ─────────────────────────┘
                                                    │
Week 2 (Parallel, depends on Track 1 for some):     │
├── Track 2: AshPhoenix.Form ───────────────────────┤
├── Track 3: SQL → Ash (can start immediately) ─────┤
└── Track 5: Resource Fixes ────────────────────────┘
```

### No Dependencies (Can Start Immediately)
- Track 1: Authorization policies
- Track 3: SQL → Ash queries
- Track 4: Notifiers integration
- Track 6: Elixir idioms

### Has Dependencies
- Track 2: AshPhoenix.Form - benefits from Track 1 (policies) being done first
- Track 5.1: CharacterStats - no deps
- Track 5.2: Soft delete - no deps
- Track 5.3: Upserts - no deps

---

## Testing Strategy

### Unit Tests
Each track should include tests:

```elixir
# Track 1: Policy tests
describe "Corporation policies" do
  test "allows read for any actor" do
    actor = %{id: 1, role: :user}
    assert {:ok, true} = Ash.can?({Corporation, :read}, actor)
  end

  test "denies update for non-admin" do
    actor = %{id: 1, role: :user}
    assert {:ok, false} = Ash.can?({Corporation, :update}, actor)
  end
end

# Track 2: Form tests
describe "SurveillanceProfilesLive" do
  test "creates profile via AshPhoenix.Form" do
    {:ok, view, _html} = live(conn, ~p"/surveillance-profiles?action=new")

    view
    |> form("#profile-form", profile: %{name: "Test Profile"})
    |> render_submit()

    assert_redirected(view, ~p"/surveillance-profiles")
  end
end

# Track 3: Query tests
describe "Participant.search_by_name/2" do
  test "returns matching characters" do
    insert(:participant, character_name: "Test Pilot")

    assert {:ok, [%{name: "Test Pilot"}]} =
      Participant.search_by_name("Test", 10)
  end
end
```

### Integration Tests
- End-to-end LiveView form submission
- Policy enforcement in controllers
- Real-time updates via notifiers

---

## Success Metrics

| Metric | Current | Target |
|--------|---------|--------|
| Resources with policies | 1/11 (9%) | 11/11 (100%) |
| AshPhoenix.Form usage | 0 files | 4+ LiveViews |
| Raw SQL queries | 20+ files | <5 files (justified) |
| LiveView LOC (profiles) | 1,393 | <400 |
| Credo strict issues | TBD | 0 |

---

## Rollback Plan

If issues arise:
1. Each track is independent - can be reverted separately
2. Feature flags can gate new behavior
3. Keep old implementations commented until verified
4. Database migrations are additive (no destructive changes)

---

## Questions for Stakeholders

Before implementation, clarify:

1. **Authorization Model**: Should corporation data be:
   - Fully public (current implicit behavior)?
   - Corporation-member only?
   - Role-based within corporation?

2. **Soft Delete Policy**: Should soft-deleted records be:
   - Never shown (current)?
   - Shown to admins?
   - Permanently deleted after X days?

3. **Real-time Requirements**: Which entities need instant updates?
   - Surveillance profiles: Yes
   - Battles: Yes
   - Corporation data: Maybe?

---

## Appendix: File Inventory

### All Ash Resources
```
lib/eve_dmv/contexts/corporation/resources/corporation.ex
lib/eve_dmv/contexts/corporation/resources/corporation_member.ex
lib/eve_dmv/contexts/corporation/resources/activity_metric.ex
lib/eve_dmv/contexts/corporation/resources/alliance.ex
lib/eve_dmv/contexts/corporation/resources/member_activity_log.ex
lib/eve_dmv/contexts/corporation/resources/member_performance_snapshot.ex
lib/eve_dmv/contexts/corporation/resources/recruitment_application.ex
lib/eve_dmv/contexts/corporation/resources/recruitment_campaign.ex
lib/eve_dmv/contexts/battle_analysis/resources/battle.ex
lib/eve_dmv/contexts/battle_analysis/resources/battle_report.ex
lib/eve_dmv/contexts/character_intelligence/resources/character_stats.ex
lib/eve_dmv/contexts/fleet_operations/resources/fleet_doctrine.ex
lib/eve_dmv/contexts/intelligence/resources/character_profile.ex
lib/eve_dmv/contexts/killmail_processing/resources/historical_fetch_status.ex
lib/eve_dmv/external/killmails/killmail_raw.ex
lib/eve_dmv/external/killmails/participant.ex
lib/eve_dmv/surveillance/profile.ex
lib/eve_dmv/users/user.ex
lib/eve_dmv/users/account.ex
lib/eve_dmv/users/token.ex
lib/eve_dmv/security/api_authentication.ex
lib/eve_dmv/eve/item_type.ex
lib/eve_dmv/eve/solar_system.ex
lib/eve_dmv/static_data/ship_attributes.ex
```

### All LiveViews
```
lib/eve_dmv_web/live/surveillance_profiles_live.ex
lib/eve_dmv_web/live/surveillance_live.ex
lib/eve_dmv_web/live/battle_analysis_live.ex
lib/eve_dmv_web/live/character_analysis/character_analysis_live.ex
lib/eve_dmv_web/live/corporation_live.ex
lib/eve_dmv_web/live/fleet_live.ex
lib/eve_dmv_web/live/system_live.ex
lib/eve_dmv_web/live/universal_search_live.ex
lib/eve_dmv_web/live/killmail_live.ex
lib/eve_dmv_web/live/kill_feed_live.ex
lib/eve_dmv_web/live/admin/users_live.ex
lib/eve_dmv_web/live/admin/performance_live.ex
lib/eve_dmv_web/live/admin/system_live.ex
```
