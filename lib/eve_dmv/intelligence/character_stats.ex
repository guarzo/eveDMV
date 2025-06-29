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
    attribute(:aggression_index, :float, default: 5.0, public?: true)
    attribute(:avg_gang_size, :float, default: 1.0, public?: true)
    # e.g., "18:00-22:00 EVE"
    attribute(:prime_timezone, :string, public?: true)
    attribute(:home_system_id, :integer, public?: true)
    attribute(:home_system_name, :string, public?: true)

    # Risk indicators
    attribute(:uses_cynos, :boolean, default: false, public?: true)
    attribute(:flies_capitals, :boolean, default: false, public?: true)
    attribute(:has_logi_support, :boolean, default: false, public?: true)
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
    end

    update :refresh_stats do
      description("Refresh character statistics from recent killmails")
      require_atomic?(false)

      # This would be called by a background job
      change(fn changeset, _context ->
        # In a real implementation, this would:
        # 1. Query recent killmails
        # 2. Aggregate statistics
        # 3. Update the record

        changeset
        |> Ash.Changeset.change_attribute(:last_calculated_at, DateTime.utc_now())
      end)
    end

    read :by_character do
      description("Find stats for a specific character")

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
