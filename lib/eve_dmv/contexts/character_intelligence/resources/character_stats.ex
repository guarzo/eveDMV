defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats do
  @moduledoc """
  Virtual resource for character statistics.

  Replaces CharacterQueries.get_character_stats/2 with Ash-native approach.
  Calculates statistics directly from the Participant resource without
  persisting to the database.

  ## Usage

      # Get stats for a character (default 90 days)
      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      # Get stats with custom date range
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)
      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_date)

      # Access calculated fields
      stats.kills       # Number of kills
      stats.deaths      # Number of deaths
      stats.kd_ratio    # Kill/Death ratio
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: :embedded

  alias EveDmv.Killmails.Participant

  require Ash.Query

  attributes do
    attribute :character_id, :integer do
      primary_key?(true)
      allow_nil?(false)
      description("The character ID these stats are for")
    end

    attribute :kills, :integer do
      default(0)
      description("Number of kills in the time period")
    end

    attribute :deaths, :integer do
      default(0)
      description("Number of deaths in the time period")
    end

    attribute :isk_destroyed, :decimal do
      default(Decimal.new("0"))
      description("Total ISK value destroyed")
    end

    attribute :isk_lost, :decimal do
      default(Decimal.new("0"))
      description("Total ISK value lost")
    end

    attribute :period_days, :integer do
      default(90)
      description("Number of days covered by these stats")
    end
  end

  calculations do
    calculate :kd_ratio, :float do
      description("Kill/Death ratio")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          if record.deaths > 0 do
            Float.round(record.kills / record.deaths, 2)
          else
            record.kills * 1.0
          end
        end)
      end)
    end

    calculate :isk_efficiency, :float do
      description("ISK efficiency as percentage (0-100)")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          total = Decimal.add(record.isk_destroyed, record.isk_lost)

          if Decimal.compare(total, Decimal.new("0")) == :gt do
            record.isk_destroyed
            |> Decimal.div(total)
            |> Decimal.mult(Decimal.new("100"))
            |> Decimal.to_float()
            |> Float.round(2)
          else
            0.0
          end
        end)
      end)
    end

    calculate :net_isk, :decimal do
      description("Net ISK (destroyed minus lost)")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          Decimal.sub(record.isk_destroyed, record.isk_lost)
        end)
      end)
    end
  end

  code_interface do
    domain(EveDmv.Api)
    define(:calculate_for_character, action: :calculate, args: [:character_id, :since_date])
  end

  actions do
    action :calculate, :struct do
      description("Calculate statistics for a character within a time period")
      constraints(instance_of: __MODULE__)

      argument :character_id, :integer do
        allow_nil?(false)
        description("The character ID to calculate stats for")
      end

      argument :since_date, :utc_datetime do
        allow_nil?(true)
        description("Start date for the stats period (defaults to 90 days ago)")
      end

      run(fn input, _context ->
        character_id = input.arguments.character_id
        since_date = input.arguments.since_date || default_since_date()
        stats = calculate_from_participants(character_id, since_date)
        {:ok, struct(__MODULE__, Map.put(stats, :character_id, character_id))}
      end)
    end
  end

  # Private helper functions

  defp calculate_from_participants(char_id, since_date) do
    require Ash.Query
    import Ash.Expr

    kills_query =
      Participant
      |> Ash.Query.filter(expr(character_id == ^char_id))
      |> Ash.Query.filter(expr(killmail_time >= ^since_date))
      |> Ash.Query.filter(expr(is_victim == false))

    deaths_query =
      Participant
      |> Ash.Query.filter(expr(character_id == ^char_id))
      |> Ash.Query.filter(expr(killmail_time >= ^since_date))
      |> Ash.Query.filter(expr(is_victim == true))

    # Run queries in parallel for better performance
    kills_task = Task.async(fn -> count_participants(kills_query) end)
    deaths_task = Task.async(fn -> count_participants(deaths_query) end)

    kills = Task.await(kills_task)
    deaths = Task.await(deaths_task)

    period_days = Date.diff(Date.utc_today(), DateTime.to_date(since_date))

    %{
      kills: kills,
      deaths: deaths,
      period_days: period_days,
      # ISK tracking requires joining with killmail_raw for total_value
      # This is a simplified implementation that returns zeros for now
      # Full ISK tracking will be added in a future enhancement
      isk_destroyed: Decimal.new("0"),
      isk_lost: Decimal.new("0")
    }
  end

  defp count_participants(query) do
    case Ash.count(query, domain: EveDmv.Api) do
      {:ok, count} -> count
      {:error, _} -> 0
    end
  end

  defp default_since_date do
    DateTime.utc_now()
    |> DateTime.add(-90, :day)
    |> DateTime.truncate(:second)
  end
end
