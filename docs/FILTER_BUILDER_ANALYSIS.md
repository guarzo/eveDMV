# Filter Builder UI Analysis & AshPhoenix.Form Recommendations

> **Analysis Date**: 2026-01-06
> **Author**: Claude Code
> **Status**: Ready for Review

## Executive Summary

After deep analysis of the filter builder implementation, I've identified several opportunities to simplify the architecture using AshPhoenix.Form's native features. However, the current implementation has significant complexity that makes a full migration challenging. This document presents three approaches with trade-offs.

**Recommendation**: Approach B (Embedded FilterRule Resource) provides the best balance of improved Ash integration while preserving the sophisticated UI functionality that users depend on.

---

## Current Architecture Analysis

### Data Structure Overview

The filter system uses two parallel data formats:

```elixir
# LiveView internal format (criteria)
%{
  type: :custom_criteria,
  logic_operator: :and | :or,
  conditions: [%{type: :character, field: "character_ids", ...}, ...]
}

# Ash Profile resource format (filter_tree)
%{
  "condition" => "and" | "or",
  "rules" => [%{"type" => "character", "field" => "character_ids", ...}, ...]
}
```

### Complexity Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| Condition Types | 9 | character, corporation, alliance, system, ship_type, range, temporal, proximity, nested |
| Max Nesting Depth | 5 levels | Recursive nested conditions |
| Form Event Handlers | 14 | add_filter, remove_filter, update_filter_field, update_range_filter, etc. |
| Transformation Functions | 12 | criteria_to_filter_tree, filter_tree_to_criteria, and helpers |
| LiveView Lines | ~1,500 | Complex state management |
| Autocomplete Entities | 5 | Characters, corps, alliances, systems, ships |

### Current Pain Points

1. **Dual Data Formats**: Constant transformation between LiveView and Ash formats
2. **Manual Form State**: No use of AshPhoenix.Form's validation/state management
3. **Complex Event Handlers**: 14 different handlers for form manipulation
4. **Scattered Validation**: Validation spread across LiveView, Ash resource, and matching engine
5. **Nested Condition Complexity**: Recursive structures require manual handling

---

## AshPhoenix.Form Capabilities Review

Based on [AshPhoenix documentation](https://hexdocs.pm/ash_phoenix/nested-forms.html):

### Relevant Features

1. **Nested Forms**: Automatic discovery for embedded resources
2. **Union Types**: [Support for polymorphic types](https://hexdocs.pm/ash_phoenix/union-forms.html) with `_union_type` parameter
3. **Dynamic Add/Remove**: `add_form/3` and `remove_form/3` functions
4. **Checkbox-Based Management**: `_add_<field>` and `_drop_<field>[]` for declarative manipulation
5. **Auto Validation**: Automatic validation through Ash resource constraints

### Key Functions

```elixir
# Add a new nested form
AshPhoenix.Form.add_form(form, path, params: %{...})

# Remove a nested form by path
AshPhoenix.Form.remove_form(form, path)

# Template usage
<.inputs_for :let={condition} field={@form[:conditions]}>
  <.input field={condition[:type]} />
</.inputs_for>
```

---

## Proposed Approaches

### Approach A: Full AshPhoenix.Form with Union Types

**Create embedded Ash resources with union types for polymorphic conditions:**

```elixir
# lib/eve_dmv/surveillance/filter_condition.ex
defmodule EveDmv.Surveillance.FilterCondition do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      constraints one_of: [:entity, :range, :temporal, :proximity, :nested]
    end

    # Union type for condition data
    attribute :data, EveDmv.Surveillance.ConditionData
  end
end

# Union type definition
defmodule EveDmv.Surveillance.ConditionData do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        entity: [
          type: EveDmv.Surveillance.EntityCondition,
          tag: :type,
          tag_value: :entity
        ],
        range: [
          type: EveDmv.Surveillance.RangeCondition,
          tag: :type,
          tag_value: :range
        ],
        # ... other condition types
      ]
    ]
end
```

**LiveView Integration:**

```elixir
def handle_event("add-condition", %{"type" => type}, socket) do
  form = AshPhoenix.Form.add_form(
    socket.assigns.form,
    [:conditions],
    params: %{"_union_type" => type}
  )
  {:noreply, assign(socket, :form, to_form(form))}
end

def handle_event("remove-condition", %{"path" => path}, socket) do
  form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
  {:noreply, assign(socket, :form, to_form(form))}
end
```

**Template:**

```heex
<.inputs_for :let={condition} field={@form[:conditions]}>
  <.input field={condition[:_union_type]} type="select" options={condition_types()} />

  <%= case condition.params["_union_type"] do %>
    <% "entity" -> %>
      <.entity_condition_fields condition={condition} />
    <% "range" -> %>
      <.range_condition_fields condition={condition} />
    <% _ -> %>
      <p>Unknown condition type</p>
  <% end %>
</.inputs_for>
```

#### Trade-offs

| Pros | Cons |
|------|------|
| Full Ash validation integration | Complex union type with 9+ variants |
| Automatic form state management | Nested conditions require recursive union types |
| Type-safe condition representation | ~2-3 weeks implementation effort |
| Eliminates dual data formats | May break existing preview/autocomplete features |
| Cleaner LiveView code | Union forms require careful path handling |

#### Estimated Effort: High (2-3 weeks)

---

### Approach B: Embedded FilterRule Resource (Recommended)

**Create a simplified embedded resource for filter rules without union types:**

```elixir
# lib/eve_dmv/surveillance/filter_rule.ex
defmodule EveDmv.Surveillance.FilterRule do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [
        :character, :corporation, :alliance, :system, :ship_type,
        :range, :temporal, :proximity, :nested
      ]
    end

    attribute :field, :string

    attribute :operator, :atom do
      constraints one_of: [:in, :not_in, :between, :gt, :lt, :gte, :lte, :eq]
    end

    # Flexible value storage (validated at action level)
    attribute :value, :map, default: %{}

    # Entity IDs (for entity-type conditions)
    attribute :entity_ids, {:array, :integer}, default: []

    # Nested conditions (for nested type only)
    attribute :nested_logic, :atom, constraints: [one_of: [:and, :or]]
    attribute :nested_rules, {:array, __MODULE__}, default: []
  end

  validations do
    validate present(:type)
    validate present(:field), where: [type: [not_in: [:nested]]]
  end
end

# Update Profile resource to use embedded rules
defmodule EveDmv.Surveillance.Profile do
  # ... existing code ...

  attributes do
    # Replace filter_tree with structured rules
    attribute :filter_logic, :atom do
      default :and
      constraints one_of: [:and, :or]
    end

    attribute :filter_rules, {:array, EveDmv.Surveillance.FilterRule} do
      default []
    end
  end
end
```

**LiveView Integration:**

```elixir
# Use AshPhoenix.Form for profile + rules management
def create_profile_form(user_id) do
  Profile
  |> AshPhoenix.Form.for_create(:create,
    as: "form",
    actor: %{id: user_id},
    forms: [
      filter_rules: [
        type: :list,
        resource: EveDmv.Surveillance.FilterRule,
        create_action: :create
      ]
    ]
  )
  |> to_form()
end

# Add condition using AshPhoenix.Form
def handle_event("add-condition", %{"type" => type}, socket) do
  default_params = get_default_params_for_type(type)

  form = AshPhoenix.Form.add_form(
    socket.assigns.form.source,
    [:filter_rules],
    params: default_params
  )

  {:noreply, assign(socket, :form, to_form(form))}
end

# Remove condition
def handle_event("remove-condition", %{"index" => index}, socket) do
  form = AshPhoenix.Form.remove_form(
    socket.assigns.form.source,
    [:filter_rules, String.to_integer(index)]
  )

  {:noreply, assign(socket, :form, to_form(form))}
end
```

**Template (mostly preserves existing UI):**

```heex
<.form :let={f} for={@form} phx-submit="save" phx-change="validate">
  <.input field={f[:name]} label="Profile Name" />
  <.input field={f[:description]} type="textarea" label="Description" />

  <div class="filter-builder">
    <.input field={f[:filter_logic]} type="select"
            options={[{"ALL (AND)", :and}, {"ANY (OR)", :or}]} />

    <.inputs_for :let={rule} field={f[:filter_rules]}>
      <div class="condition-card">
        <.input field={rule[:type]} type="hidden" />

        <%!-- Render type-specific inputs using existing component --%>
        <.render_condition_inputs condition={rule} index={rule.index} />

        <button type="button" phx-click="remove-condition"
                phx-value-index={rule.index}>Remove</button>
      </div>
    </.inputs_for>

    <.condition_type_dropdown on_select="add-condition" />
  </div>
</.form>
```

#### Trade-offs

| Pros | Cons |
|------|------|
| Preserves existing UI components | Still requires some transformation for nested rules |
| Uses AshPhoenix add_form/remove_form | Need to migrate from filter_tree to filter_rules |
| Structured embedded resource with validation | One-time migration of existing profiles |
| Reduces event handlers from 14 to ~5 | Matching engine needs updating |
| Incremental migration possible | |

#### Estimated Effort: Medium (1-2 weeks)

---

### Approach C: Simplified Filter Model

**Reduce complexity by limiting filter types and eliminating deep nesting:**

```elixir
# Simplified filter with only essential types
defmodule EveDmv.Surveillance.SimpleFilter do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :entity_type, :atom do
      constraints one_of: [:character, :corporation, :alliance, :system, :ship]
    end

    attribute :entity_ids, {:array, :integer}, default: []

    attribute :min_isk_value, :integer
    attribute :max_isk_value, :integer

    attribute :active_hours_start, :integer  # 0-23
    attribute :active_hours_end, :integer    # 0-23
  end
end

# Profile uses simple AND logic across filters
defmodule EveDmv.Surveillance.Profile do
  attributes do
    # Multiple simple filters, all ANDed together
    attribute :entity_filters, {:array, EveDmv.Surveillance.SimpleFilter}
    attribute :isk_min, :integer
    attribute :isk_max, :integer
    attribute :active_hours, {:array, :integer}  # Hours 0-23
  end
end
```

**Simplified Template:**

```heex
<.form for={@form} phx-submit="save" phx-change="validate">
  <.input field={@form[:name]} label="Profile Name" />

  <fieldset>
    <legend>Entity Filters (Match ALL)</legend>

    <.inputs_for :let={filter} field={@form[:entity_filters]}>
      <div class="entity-filter">
        <.input field={filter[:entity_type]} type="select"
                options={entity_types()} label="Type" />
        <.entity_id_input field={filter[:entity_ids]}
                          entity_type={filter[:entity_type].value} />
        <.remove_button path={filter.name} />
      </div>
    </.inputs_for>

    <.add_button field={:entity_filters} />
  </fieldset>

  <fieldset>
    <legend>Value Filters</legend>
    <.input field={@form[:isk_min]} type="number" label="Min ISK" />
    <.input field={@form[:isk_max]} type="number" label="Max ISK" />
  </fieldset>

  <fieldset>
    <legend>Time Filters</legend>
    <.multi_select field={@form[:active_hours]}
                   options={0..23 |> Enum.map(&{"#{&1}:00", &1})}
                   label="Active Hours" />
  </fieldset>
</.form>
```

#### Trade-offs

| Pros | Cons |
|------|------|
| Dramatically simplified codebase | **Loses OR logic capability** |
| Full AshPhoenix.Form integration | **Loses nested conditions** |
| Easy to understand and maintain | **Loses proximity filters** |
| Fast implementation (3-5 days) | User workflow changes required |
| Clean UI/UX | May not meet power user needs |

#### Estimated Effort: Low (3-5 days)

---

## Feature Preservation Matrix

| Feature | Approach A | Approach B | Approach C |
|---------|------------|------------|------------|
| Entity filters (character/corp/etc) | ✅ | ✅ | ✅ |
| Range filters (ISK, participants) | ✅ | ✅ | ⚠️ Simplified |
| Temporal filters | ✅ | ✅ | ⚠️ Simplified |
| Proximity/Chain filters | ✅ | ✅ | ❌ |
| OR logic | ✅ | ✅ | ❌ |
| Nested conditions | ✅ | ✅ | ❌ |
| Deep nesting (5 levels) | ⚠️ Complex | ⚠️ Complex | ❌ |
| Autocomplete suggestions | ⚠️ Needs work | ✅ Preserved | ✅ |
| Real-time preview | ⚠️ Needs work | ✅ Preserved | ✅ |
| Form validation | ✅ Native Ash | ✅ Native Ash | ✅ Native Ash |
| Add/Remove buttons | ✅ Native | ✅ Native | ✅ Native |

---

## Recommendation: Approach B

### Why Approach B?

1. **Preserves Functionality**: All 9 condition types remain available
2. **Improves Architecture**: Uses AshPhoenix.Form's `add_form`/`remove_form` natively
3. **Reduces Complexity**: Eliminates many custom event handlers
4. **Incremental Migration**: Can be done in phases without breaking changes
5. **Validation Benefits**: Structured embedded resource with Ash validations
6. **Keeps Working UI**: Existing autocomplete, preview, and rendering components preserved

### Implementation Phases

#### Phase 1: Create Embedded FilterRule Resource (2-3 days)
```elixir
# 1. Define FilterRule embedded resource
# 2. Update Profile to use filter_rules array
# 3. Create migration for existing profiles
# 4. Update matching engine to use new structure
```

#### Phase 2: AshPhoenix.Form Integration (3-4 days)
```elixir
# 1. Update create_profile_form/1 with forms: config
# 2. Replace add_filter with AshPhoenix.Form.add_form
# 3. Replace remove_filter with AshPhoenix.Form.remove_form
# 4. Update validate handler to use AshPhoenix.Form.validate
```

#### Phase 3: Template Updates (2-3 days)
```heex
# 1. Use inputs_for for condition rendering
# 2. Preserve existing condition type components
# 3. Update add/remove buttons to use form paths
# 4. Test all condition types
```

#### Phase 4: Cleanup & Testing (1-2 days)
```elixir
# 1. Remove obsolete transformation functions
# 2. Remove redundant event handlers
# 3. Update tests for new architecture
# 4. Performance testing with complex filters
```

---

## Detailed Implementation for Approach B

### Step 1: FilterRule Embedded Resource

```elixir
# lib/eve_dmv/surveillance/filter_rule.ex
defmodule EveDmv.Surveillance.FilterRule do
  @moduledoc """
  Embedded resource representing a single filter condition.

  Supports all condition types: entity (character, corp, alliance, system, ship),
  range, temporal, proximity, and nested.
  """

  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :type, :atom do
      allow_nil? false
      constraints one_of: [
        # Entity types
        :character, :corporation, :alliance, :system, :ship_type,
        # Advanced types
        :range, :temporal, :proximity,
        # Nesting
        :nested
      ]
      description "The condition type"
    end

    attribute :field, :string do
      description "Field to filter on (e.g., 'isk_value', 'time_of_day')"
    end

    attribute :operator, :atom do
      constraints one_of: [
        :in, :not_in,           # Entity matching
        :between, :gt, :lt,     # Range comparison
        :gte, :lte, :eq,        # Equality
        :within                 # Proximity
      ]
      default :in
    end

    # For entity-type conditions (character, corp, alliance, system, ship)
    attribute :entity_ids, {:array, :integer} do
      default []
      description "List of entity IDs to match"
    end

    # For range conditions
    attribute :range_min, :integer
    attribute :range_max, :integer
    attribute :range_value, :integer  # For single-value comparisons

    # For temporal conditions
    attribute :hour_start, :integer, constraints: [min: 0, max: 23]
    attribute :hour_end, :integer, constraints: [min: 0, max: 23]
    attribute :days_of_week, {:array, :integer}  # 0-6 for Sun-Sat

    # For proximity conditions
    attribute :proximity_type, :atom, constraints: [one_of: [:chain, :jumps]]
    attribute :max_jumps, :integer, default: 5
    attribute :reference_systems, {:array, :integer}, default: []

    # For nested conditions
    attribute :nested_logic, :atom do
      constraints one_of: [:and, :or]
      default :and
    end

    # Self-referential for nesting
    attribute :nested_rules, {:array, __MODULE__} do
      default []
    end
  end

  validations do
    # Field required for non-nested conditions
    validate present(:field), where: [type: [not_in: [:nested]]]

    # Entity IDs required for entity types
    validate present(:entity_ids),
      where: [type: [in: [:character, :corporation, :alliance, :system, :ship_type]]]

    # Range values required for range type
    validate fn changeset, _context ->
      if Ash.Changeset.get_attribute(changeset, :type) == :range do
        operator = Ash.Changeset.get_attribute(changeset, :operator)

        case operator do
          :between ->
            if Ash.Changeset.get_attribute(changeset, :range_min) &&
               Ash.Changeset.get_attribute(changeset, :range_max) do
              :ok
            else
              {:error, field: :range_min, message: "Range min and max required for 'between' operator"}
            end
          _ ->
            if Ash.Changeset.get_attribute(changeset, :range_value) do
              :ok
            else
              {:error, field: :range_value, message: "Value required for range comparison"}
            end
        end
      else
        :ok
      end
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*
    end

    update :update do
      primary? true
      accept :*
    end
  end
end
```

### Step 2: Updated Profile Resource

```elixir
# lib/eve_dmv/surveillance/profile.ex (updated attributes section)
attributes do
  uuid_primary_key(:id)

  attribute :name, :string do
    allow_nil?(false)
    constraints(max_length: 100, min_length: 1)
  end

  attribute :description, :string do
    constraints(max_length: 500)
  end

  attribute :user_id, :uuid, allow_nil?: false
  attribute :is_active, :boolean, default: true

  # New structured filter attributes
  attribute :filter_logic, :atom do
    allow_nil? false
    default :and
    constraints one_of: [:and, :or]
    description "Top-level logic operator for combining rules"
  end

  attribute :filter_rules, {:array, EveDmv.Surveillance.FilterRule} do
    default []
    description "Array of filter conditions"
  end

  # Keep filter_tree for backward compatibility during migration
  attribute :filter_tree, :map do
    description "Deprecated: Use filter_rules instead"
  end

  # ... rest of attributes
end
```

### Step 3: LiveView Form Setup

```elixir
# In SurveillanceProfilesLive

defp create_profile_form(user_id) do
  Profile
  |> AshPhoenix.Form.for_create(:create,
    as: "form",
    actor: %{id: user_id},
    forms: [
      filter_rules: [
        type: :list,
        resource: EveDmv.Surveillance.FilterRule,
        create_action: :create,
        update_action: :update
      ]
    ]
  )
  |> to_form()
end

# Simplified event handlers
def handle_event("add-condition", %{"type" => type}, socket) do
  params = default_params_for_condition_type(type)

  form =
    socket.assigns.form.source
    |> AshPhoenix.Form.add_form([:filter_rules], params: params)
    |> to_form()

  {:noreply, assign(socket, :form, form)}
end

def handle_event("remove-condition", %{"index" => index}, socket) do
  form =
    socket.assigns.form.source
    |> AshPhoenix.Form.remove_form([:filter_rules, String.to_integer(index)])
    |> to_form()

  {:noreply, assign(socket, :form, form)}
end

def handle_event("validate", %{"form" => params}, socket) do
  form =
    socket.assigns.form.source
    |> AshPhoenix.Form.validate(params)
    |> to_form()

  {:noreply, assign(socket, :form, form)}
end

def handle_event("save", %{"form" => params}, socket) do
  case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
    {:ok, profile} ->
      {:noreply,
       socket
       |> put_flash(:info, "Profile saved successfully")
       |> push_navigate(to: ~p"/surveillance-profiles")}

    {:error, form} ->
      {:noreply, assign(socket, :form, to_form(form))}
  end
end

defp default_params_for_condition_type(type) do
  base = %{"type" => type}

  case type do
    type when type in ["character", "corporation", "alliance", "system", "ship_type"] ->
      Map.merge(base, %{
        "field" => "#{type}_ids",
        "operator" => "in",
        "entity_ids" => []
      })

    "range" ->
      Map.merge(base, %{
        "field" => "isk_value",
        "operator" => "between",
        "range_min" => 10_000_000,
        "range_max" => 1_000_000_000
      })

    "temporal" ->
      Map.merge(base, %{
        "field" => "time_of_day",
        "operator" => "between",
        "hour_start" => 18,
        "hour_end" => 23
      })

    "proximity" ->
      Map.merge(base, %{
        "field" => "chain_proximity",
        "operator" => "within",
        "proximity_type" => "chain",
        "max_jumps" => 5
      })

    "nested" ->
      Map.merge(base, %{
        "nested_logic" => "and",
        "nested_rules" => []
      })

    _ ->
      base
  end
end
```

### Step 4: Simplified Template

```heex
<.form :let={f} for={@form} phx-submit="save" phx-change="validate">
  <%!-- Profile metadata --%>
  <div class="grid grid-cols-2 gap-4 mb-6">
    <div>
      <.input field={f[:name]} label="Profile Name" required />
    </div>
    <div>
      <.input field={f[:is_active]} type="select" label="Status"
              options={[{"Active", true}, {"Inactive", false}]} />
    </div>
  </div>

  <.input field={f[:description]} type="textarea" label="Description" />

  <%!-- Filter Logic --%>
  <div class="filter-builder mt-6">
    <div class="flex justify-between items-center mb-4">
      <h3 class="text-lg font-medium">Filters</h3>
      <div class="flex items-center gap-4">
        <.input field={f[:filter_logic]} type="select" label="Logic"
                options={[{"ALL (AND)", :and}, {"ANY (OR)", :or}]} />
        <.condition_type_dropdown />
      </div>
    </div>

    <%!-- Render each condition --%>
    <.inputs_for :let={rule} field={f[:filter_rules]}>
      <div class="condition-card p-4 mb-4 border rounded-lg">
        <input type="hidden" name={rule[:type].name} value={rule[:type].value} />

        <div class="flex justify-between items-start mb-3">
          <span class="text-sm font-medium">
            <%= humanize_condition_type(rule[:type].value) %>
          </span>
          <button type="button"
                  phx-click="remove-condition"
                  phx-value-index={rule.index}
                  class="text-red-400 hover:text-red-300">
            Remove
          </button>
        </div>

        <%!-- Type-specific inputs --%>
        <%= render_condition_inputs(rule) %>
      </div>
    </.inputs_for>

    <%= if Enum.empty?(f[:filter_rules].value || []) do %>
      <div class="text-center py-8 text-gray-500">
        No filters added yet. Use the dropdown to add filters.
      </div>
    <% end %>
  </div>

  <%!-- Actions --%>
  <div class="flex justify-end gap-3 mt-6">
    <.button type="button" phx-click="cancel">Cancel</.button>
    <.button type="submit">Save Profile</.button>
  </div>
</.form>

<%!-- Condition type dropdown component --%>
<script>
// Existing autocomplete JavaScript can be preserved
</script>
```

---

## Migration Strategy

### Database Migration

```elixir
defmodule EveDmv.Repo.Migrations.AddFilterRulesToProfiles do
  use Ecto.Migration

  def change do
    alter table(:surveillance_profiles) do
      add :filter_logic, :string, default: "and"
      add :filter_rules, :map, default: []
    end

    # Migrate existing filter_tree data in a separate data migration
  end
end
```

### Data Migration Script

```elixir
# priv/repo/migrations/migrate_filter_trees.exs
defmodule EveDmv.DataMigrations.MigrateFilterTrees do
  def run do
    EveDmv.Surveillance.Profile
    |> Ash.Query.filter(not is_nil(filter_tree))
    |> Ash.read!()
    |> Enum.each(fn profile ->
      rules = convert_filter_tree_to_rules(profile.filter_tree)
      logic = Map.get(profile.filter_tree, "condition", "and")

      profile
      |> Ash.Changeset.for_update(:update, %{
        filter_logic: String.to_atom(logic),
        filter_rules: rules
      })
      |> Ash.update!()
    end)
  end

  defp convert_filter_tree_to_rules(%{"rules" => rules}) do
    Enum.map(rules, &convert_rule/1)
  end

  defp convert_rule(rule) do
    # Conversion logic here...
  end
end
```

---

## Conclusion

Approach B provides the optimal balance of:
- **Improved Ash integration** through embedded FilterRule resource and AshPhoenix.Form
- **Preserved functionality** for all 9 condition types including nested conditions
- **Reduced complexity** by eliminating ~9 event handlers
- **Incremental migration** allowing phased implementation

The estimated effort of 1-2 weeks is reasonable given the complexity of the existing system and the benefits gained in maintainability and type safety.

---

## References

- [AshPhoenix Nested Forms](https://hexdocs.pm/ash_phoenix/nested-forms.html)
- [AshPhoenix Union Forms](https://hexdocs.pm/ash_phoenix/union-forms.html)
- [AshPhoenix.Form API](https://hexdocs.pm/ash_phoenix/AshPhoenix.Form.html)
