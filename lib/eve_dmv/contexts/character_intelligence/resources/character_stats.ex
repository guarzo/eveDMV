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
    isk_destroyed_task = Task.async(fn -> calculate_isk_destroyed(char_id, since_date) end)
    isk_lost_task = Task.async(fn -> calculate_isk_lost(char_id, since_date) end)

    kills = Task.await(kills_task)
    deaths = Task.await(deaths_task)
    isk_destroyed = Task.await(isk_destroyed_task)
    isk_lost = Task.await(isk_lost_task)

    period_days = Date.diff(Date.utc_today(), DateTime.to_date(since_date))

    %{
      kills: kills,
      deaths: deaths,
      period_days: period_days,
      isk_destroyed: isk_destroyed,
      isk_lost: isk_lost
    }
  end

  # Calculate total ISK destroyed by character (as attacker)
  # Queries KillmailRaw using Ash exists() through the participants relationship
  # Includes OpenTelemetry instrumentation for performance monitoring
  defp calculate_isk_destroyed(char_id, since_date) do
    alias EveDmv.Telemetry.OtelSpans

    OtelSpans.with_span(
      "character_stats.calculate_isk_destroyed",
      %{character_id: char_id, since_date: DateTime.to_iso8601(since_date)},
      fn ->
        import Ash.Expr
        alias EveDmv.Killmails.KillmailRaw

        # Query killmails where this character was an attacker using Ash relationships
        query =
          KillmailRaw
          |> Ash.Query.filter(expr(killmail_time >= ^since_date))
          |> Ash.Query.filter(
            expr(exists(participants, character_id == ^char_id and is_victim == false))
          )

        case Ash.sum(query, :total_value, domain: EveDmv.Api) do
          {:ok, nil} ->
            Decimal.new("0")

          {:ok, value} ->
            case ensure_decimal(value) do
              {:ok, decimal} -> decimal
              {:error, _reason} -> Decimal.new("0")
            end

          {:error, _} ->
            Decimal.new("0")
        end
      end
    )
  end

  # Calculate total ISK lost by character (as victim)
  # Queries KillmailRaw directly using victim_character_id
  # Includes OpenTelemetry instrumentation for performance monitoring
  defp calculate_isk_lost(char_id, since_date) do
    alias EveDmv.Telemetry.OtelSpans

    OtelSpans.with_span(
      "character_stats.calculate_isk_lost",
      %{character_id: char_id, since_date: DateTime.to_iso8601(since_date)},
      fn ->
        import Ash.Expr
        alias EveDmv.Killmails.KillmailRaw

        query =
          KillmailRaw
          |> Ash.Query.filter(expr(victim_character_id == ^char_id))
          |> Ash.Query.filter(expr(killmail_time >= ^since_date))

        case Ash.sum(query, :total_value, domain: EveDmv.Api) do
          {:ok, nil} ->
            Decimal.new("0")

          {:ok, value} ->
            case ensure_decimal(value) do
              {:ok, decimal} -> decimal
              {:error, _reason} -> Decimal.new("0")
            end

          {:error, _} ->
            Decimal.new("0")
        end
      end
    )
  end

  @spec ensure_decimal(Decimal.t() | number() | String.t()) ::
          {:ok, Decimal.t()} | {:error, String.t()}
  defp ensure_decimal(%Decimal{} = value), do: {:ok, value}
  defp ensure_decimal(value) when is_float(value), do: {:ok, Decimal.from_float(value)}
  defp ensure_decimal(value) when is_integer(value), do: {:ok, Decimal.new(value)}

  defp ensure_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _rest} -> {:ok, decimal}
      :error -> {:error, "cannot parse #{inspect(value)} as Decimal"}
    end
  end

  defp ensure_decimal(value), do: {:error, "unsupported type: #{inspect(value)}"}

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
