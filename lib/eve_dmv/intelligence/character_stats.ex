defmodule EveDmv.Intelligence.CharacterStats do
  @moduledoc """
  Aggregated character statistics for hunter intelligence.

  This resource tracks patterns and statistics about a character's PvP behavior,
  focusing on information useful for hunters making engagement decisions.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("character_stats")
    repo(EveDmv.Repo)

    custom_indexes do
      # GIN indexes for JSONB map columns
      index([:ship_usage], name: "character_stats_ship_usage_gin_idx", using: "gin")

      index([:frequent_associates],
        name: "character_stats_frequent_associates_gin_idx",
        using: "gin"
      )

      index([:active_systems], name: "character_stats_active_systems_gin_idx", using: "gin")
      index([:target_profile], name: "character_stats_target_profile_gin_idx", using: "gin")

      index([:identified_weaknesses],
        name: "character_stats_identified_weaknesses_gin_idx",
        using: "gin"
      )
    end
  end

  attributes do
    integer_primary_key(:id)

    # Character identification
    attribute(:character_id, :integer, allow_nil?: false, public?: true)
    attribute(:character_name, :string, allow_nil?: false, public?: true)
    attribute(:corporation_id, :integer, public?: true)
    attribute(:corporation_name, :string, public?: true)
    attribute(:alliance_id, :integer, public?: true)
    attribute(:alliance_name, :string, public?: true)

    # Activity metrics (last 90 days)
    attribute(:total_kills, :integer, default: 0, public?: true)
    attribute(:total_losses, :integer, default: 0, public?: true)
    attribute(:solo_kills, :integer, default: 0, public?: true)
    attribute(:solo_losses, :integer, default: 0, public?: true)

    # Ship preferences (JSONB)
    attribute(:ship_usage, :map, default: %{}, public?: true)
    # Format: %{
    #   "587" => %{
    #     "ship_name" => "Rifter",
    #     "times_used" => 45,
    #     "kills" => 38,
    #     "losses" => 7,
    #     "avg_gang_size" => 2.3,
    #     "common_fits" => [...]
    #   }
    # }

    # Gang composition (JSONB)
    attribute(:frequent_associates, :map, default: %{}, public?: true)
    # Format: %{
    #   "95465499" => %{
    #     "name" => "Wingman Name",
    #     "corp_id" => 98388312,
    #     "times_together" => 34,
    #     "ships_flown" => ["Deacon", "Guardian"]
    #   }
    # }

    # Geographic patterns (JSONB)
    attribute(:active_systems, :map, default: %{}, public?: true)
    # Format: %{
    #   "30000142" => %{
    #     "system_name" => "Jita",
    #     "region_name" => "The Forge",
    #     "security" => 0.9,
    #     "kills" => 45,
    #     "losses" => 2,
    #     "last_seen" => ~U[2024-01-15 18:30:00Z]
    #   }
    # }

    # Target preferences (JSONB)
    attribute(:target_profile, :map, default: %{}, public?: true)
    # Format: %{
    #   "ship_categories" => %{
    #     "frigates" => %{"killed" => 123, "success_rate" => 0.89},
    #     "cruisers" => %{"killed" => 67, "success_rate" => 0.72}
    #   },
    #   "avg_victim_gang_size" => 2.1,
    #   "preferred_engagement_range" => "0-20km"
    # }

    # Behavioral patterns
    # 0-10 scale
    attribute(:aggression_index, :float, default: 0.0, public?: true)
    attribute(:avg_gang_size, :float, default: 1.0, public?: true)
    # e.g., "18:00-22:00 EVE"
    attribute(:prime_timezone, :string, public?: true)
    attribute(:home_system_id, :integer, public?: true)
    attribute(:home_system_name, :string, public?: true)

    # Risk indicators
    attribute(:uses_cynos, :boolean, default: false, public?: true)
    attribute(:flies_capitals, :boolean, default: false, public?: true)
    attribute(:has_logi_support, :boolean, default: false, public?: true)
    # 0.0-1.0 probability of awoxing (attacking own team)
    attribute(:awox_probability, :float, default: 0.0, public?: true)
    # low/medium/high
    attribute(:batphone_probability, :string, default: "low", public?: true)

    # Performance indicators
    # Percentage
    attribute(:isk_efficiency, :float, default: 50.0, public?: true)
    attribute(:kill_death_ratio, :float, default: 1.0, public?: true)
    # 1-5 stars
    attribute(:dangerous_rating, :integer, default: 3, public?: true)

    # Weaknesses (JSONB)
    attribute(:identified_weaknesses, :map, default: %{}, public?: true)
    # Format: %{
    #   "behavioral" => ["predictable_routes", "overconfident"],
    #   "technical" => ["weak_to_neuts", "poor_range_control"],
    #   "common_mistakes" => ["forgets_drones", "cap_management"]
    # }

    # Metadata
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
    attribute(:last_calculated_at, :utc_datetime_usec, public?: true)
    # 0-100%
    attribute(:data_completeness, :integer, default: 0, public?: true)
  end

  relationships do
    # No direct relationships - we aggregate from other tables
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name
      ])
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      # Accept all stats fields for updates
      accept([
        :total_kills,
        :total_losses,
        :solo_kills,
        :solo_losses,
        :ship_usage,
        :frequent_associates,
        :active_systems,
        :target_profile,
        :aggression_index,
        :avg_gang_size,
        :prime_timezone,
        :home_system_id,
        :home_system_name,
        :uses_cynos,
        :flies_capitals,
        :has_logi_support,
        :batphone_probability,
        :isk_efficiency,
        :kill_death_ratio,
        :dangerous_rating,
        :identified_weaknesses,
        :last_calculated_at,
        :data_completeness
      ])

      validate(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :batphone_probability) do
          value when value in ["low", "medium", "high"] ->
            :ok

          _ ->
            {:error, field: :batphone_probability, message: "must be one of: low, medium, high"}
        end
      end)
    end

    update :refresh_stats do
      description("Refresh character statistics from recent killmails")
      require_atomic?(false)

      # This is called by a background job to refresh character stats
      change(fn changeset, _context ->
        character_id = Ash.Changeset.get_attribute(changeset, :character_id)

        if character_id do
          # Use the CharacterAnalyzer to recalculate stats
          case EveDmv.Intelligence.CharacterAnalyzer.analyze_character(character_id) do
            {:ok, updated_stats} ->
              # Update changeset with fresh statistics
              changeset
              |> Ash.Changeset.change_attribute(:total_kills, updated_stats.total_kills)
              |> Ash.Changeset.change_attribute(:total_losses, updated_stats.total_losses)
              |> Ash.Changeset.change_attribute(:solo_kills, updated_stats.solo_kills)
              |> Ash.Changeset.change_attribute(:solo_losses, updated_stats.solo_losses)
              |> Ash.Changeset.change_attribute(:ship_usage, updated_stats.ship_usage)
              |> Ash.Changeset.change_attribute(
                :frequent_associates,
                updated_stats.frequent_associates
              )
              |> Ash.Changeset.change_attribute(:active_systems, updated_stats.active_systems)
              |> Ash.Changeset.change_attribute(:target_profile, updated_stats.target_profile)
              |> Ash.Changeset.change_attribute(:aggression_index, updated_stats.aggression_index)
              |> Ash.Changeset.change_attribute(:avg_gang_size, updated_stats.avg_gang_size)
              |> Ash.Changeset.change_attribute(:prime_timezone, updated_stats.prime_timezone)
              |> Ash.Changeset.change_attribute(:home_system_id, updated_stats.home_system_id)
              |> Ash.Changeset.change_attribute(:home_system_name, updated_stats.home_system_name)
              |> Ash.Changeset.change_attribute(:uses_cynos, updated_stats.uses_cynos)
              |> Ash.Changeset.change_attribute(:flies_capitals, updated_stats.flies_capitals)
              |> Ash.Changeset.change_attribute(:has_logi_support, updated_stats.has_logi_support)
              |> Ash.Changeset.change_attribute(
                :batphone_probability,
                updated_stats.batphone_probability
              )
              |> Ash.Changeset.change_attribute(:isk_efficiency, updated_stats.isk_efficiency)
              |> Ash.Changeset.change_attribute(:kill_death_ratio, updated_stats.kill_death_ratio)
              |> Ash.Changeset.change_attribute(:dangerous_rating, updated_stats.dangerous_rating)
              |> Ash.Changeset.change_attribute(
                :identified_weaknesses,
                updated_stats.identified_weaknesses
              )
              |> Ash.Changeset.change_attribute(
                :data_completeness,
                updated_stats.data_completeness
              )
              |> Ash.Changeset.change_attribute(:last_calculated_at, DateTime.utc_now())

            {:error, _reason} ->
              # If analysis fails, just update the timestamp
              changeset
              |> Ash.Changeset.change_attribute(:last_calculated_at, DateTime.utc_now())
          end
        else
          changeset
          |> Ash.Changeset.change_attribute(:last_calculated_at, DateTime.utc_now())
        end
      end)
    end

    read :by_character do
      description("Find stats for a specific character")

      argument(:character_id, :integer, allow_nil?: false)

      filter(expr(character_id == ^arg(:character_id)))
    end

    read :get_by_character_id do
      description("Get stats for a specific character ID")

      argument(:character_id, :integer, allow_nil?: false)

      filter(expr(character_id == ^arg(:character_id)))
    end

    read :dangerous_characters do
      description("Find highly dangerous characters")

      filter(expr(dangerous_rating >= 4))

      prepare(build(sort: [dangerous_rating: :desc]))
    end
  end

  code_interface do
    define(:get_by_character, action: :by_character, args: [:character_id])
    define(:get_by_character_id, action: :get_by_character_id, args: [:character_id])
    define(:list_dangerous, action: :dangerous_characters)
    define(:refresh, action: :refresh_stats)
  end

  calculations do
    calculate :danger_level, :string do
      description("Human-readable danger level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.dangerous_rating do
            5 -> "Extreme"
            4 -> "High"
            3 -> "Medium"
            2 -> "Low"
            _ -> "Minimal"
          end
        end)
      end)
    end

    calculate :activity_level, :string do
      description("Recent activity level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          total_recent = record.total_kills + record.total_losses

          cond do
            total_recent > 100 -> "Very Active"
            total_recent > 50 -> "Active"
            total_recent > 20 -> "Moderate"
            total_recent > 5 -> "Low"
            true -> "Inactive"
          end
        end)
      end)
    end
  end

  preparations do
    prepare(build(load: [:danger_level, :activity_level]))
  end
end
