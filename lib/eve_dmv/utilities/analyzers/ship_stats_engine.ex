# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Analytics.ShipStatsEngine do
  @moduledoc """
  Engine for calculating ship performance statistics.
  """

  alias EveDmv.Analytics.ShipStats
  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Eve.ItemType
  alias EveDmv.Killmails.Participant

  require Logger
  require Ash.Query

  @default_days 90
  @default_min_usage 10

  @doc """
  Calculate and update ship statistics for all ship types.

  ## Options

    * `:days`      - days to look back (default: #{@default_days})
    * `:min_usage` - minimum activity count (default: #{@default_min_usage})
  """
  @dialyzer {:nowarn_function, calculate_ship_stats: 1}
  def calculate_ship_stats(opts \\ []) do
    days = Keyword.get(opts, :days, @default_days)
    min_usage = Keyword.get(opts, :min_usage, @default_min_usage)
    now = DateTime.utc_now()
    start_date = DateTimeUtils.add(now, -days * 86_400, :second)

    Logger.info("Starting ship statistics for last #{days} days")

    case participants_ids(:ship_type_id, min_usage) do
      {:error, reason} ->
        Logger.error("Failed to calculate ship stats: #{inspect(reason)}")
        {:error, reason}

      {:ok, ids} ->
        ids
        |> Enum.with_index(1)
        |> Task.async_stream(
          fn {ship_id, idx} ->
            if rem(idx, 50) == 1, do: Logger.debug("Processing ship #{idx}")
            process_ship(ship_id, start_date, now)
          end,
          max_concurrency: System.schedulers_online(),
          ordered: false
        )
        |> Stream.run()

        update_ship_rankings()
        Logger.info("Ship statistics calculation completed")
        :ok
    end
  end

  # Fetch up to `limit` unique non-nil ship type IDs from recent participants
  defp participants_ids(field, limit) do
    case Ash.read(Participant, domain: Api) do
      {:ok, parts} ->
        parts
        |> Enum.map(&Map.get(&1, field))
        |> Enum.filter(& &1)
        |> Enum.uniq()
        |> Enum.take(limit)

      {:error, reason} ->
        Logger.error("Failed to fetch participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Process one ship's metrics and upsert into Ash
  defp process_ship(ship_type_id, start_date, end_date) do
    with {:ok, ship_type} <-
           Ash.get(ItemType, ship_type_id, domain: Api, load: [:is_capital_ship]),
         {:ok, metrics} <-
           calculate_ship_metrics(ship_type_id, start_date, end_date),
         %{ship_name: _} <- metrics do
      attrs =
        metrics
        |> Map.put(:ship_type_id, ship_type_id)
        |> Map.put(:ship_category, determine_ship_category(ship_type))
        |> Map.put(:tech_level, ship_type.tech_level || 1)
        |> Map.put(:meta_level, ship_type.meta_level || 0)
        |> Map.put(:is_capital, ship_type.is_capital_ship == true)
        |> Map.put(:stats_period_start, start_date)
        |> Map.put(:stats_period_end, end_date)

      upsert(ShipStats, [ship_type_id: ship_type_id], attrs)
    else
      {:error, reason} ->
        Logger.warning("Failed to process ship #{ship_type_id}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Error processing ship #{ship_type_id}: #{inspect(error)}")
      {:error, error}
  end

  # Generic upsert helper (create or update based on filters)
  defp upsert(schema, filters, attrs) do
    case Ash.get(schema, filters, domain: Api) do
      {:ok, existing} -> Ash.update(existing, attrs, domain: Api)
      _ -> Ash.create(schema, attrs, domain: Api)
    end
  end

  # Calculate ship metrics from participant data
  defp calculate_ship_metrics(ship_type_id, _start_date, _end_date) do
    case Ash.read(Participant,
           filter: %{ship_type_id: ship_type_id},
           limit: 1_000,
           domain: Api
         ) do
      {:ok, [_ | _] = parts} ->
        # Enrich participants with gang_size information
        enriched_parts = enrich_participants_with_gang_size(parts)
        {:ok, build_ship_metrics(enriched_parts)}

      {:ok, []} ->
        {:error, "No participants found for ship type #{ship_type_id}"}

      {:error, reason} ->
        Logger.error("Failed to fetch ship metrics: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Enrich participants with gang_size information from killmail data
  defp enrich_participants_with_gang_size(participants) do
    # Group participants by killmail to batch lookup attacker counts
    killmail_groups = Enum.group_by(participants, &{&1.killmail_id, &1.killmail_time})

    # Get attacker counts for each unique killmail
    attacker_counts = get_attacker_counts_for_killmails(Map.keys(killmail_groups))

    # Add gang_size to each participant based on their killmail's attacker count
    Enum.flat_map(killmail_groups, fn {killmail_key, parts} ->
      gang_size = Map.get(attacker_counts, killmail_key, 1)
      Enum.map(parts, &Map.put(&1, :gang_size, gang_size))
    end)
  end

  # Get attacker counts for a list of killmails (excluding victims)
  defp get_attacker_counts_for_killmails(killmail_keys) do
    killmail_keys
    |> Enum.map(fn {killmail_id, killmail_time} ->
      case Ash.read(Participant,
             filter: %{
               killmail_id: killmail_id,
               killmail_time: killmail_time,
               is_victim: false
             },
             domain: Api
           ) do
        {:ok, attackers} ->
          {{killmail_id, killmail_time}, length(attackers)}

        {:error, _} ->
          {{killmail_id, killmail_time}, 1}
      end
    end)
    |> Map.new()
  end

  # Build ship-level metrics map
  defp build_ship_metrics(ps) do
    if Enum.empty?(ps) do
      %{ship_name: "Unknown"}
    else
      ship_name = List.first(ps).ship_name || "Unknown"
      {kills, losses} = Enum.split_with(ps, fn p -> not (p.is_victim || false) end)

      basic_metrics = calculate_basic_metrics(kills, losses, ps)
      isk_metrics = calculate_isk_metrics(kills, losses)
      combat_metrics = calculate_combat_metrics(kills, losses)
      time_metrics = calculate_time_metrics()

      basic_metrics
      |> Map.merge(isk_metrics)
      |> Map.merge(combat_metrics)
      |> Map.merge(time_metrics)
      |> Map.put(:ship_name, ship_name)
    end
  end

  defp calculate_basic_metrics(kills, losses, ps) do
    %{
      total_kills: Kernel.length(kills),
      total_losses: Kernel.length(losses),
      pilots_flown: ps |> Stream.map(& &1.character_id) |> Enum.uniq() |> Kernel.length(),
      solo_kills: Enum.count(kills, &((&1.gang_size || 1) == 1))
    }
  end

  defp calculate_isk_metrics(kills, losses) do
    total_isk_out = sum_ship_values(kills)
    total_isk_in = sum_ship_values(losses)

    %{
      total_isk_destroyed: total_isk_out,
      total_isk_lost: total_isk_in
    }
  end

  defp calculate_combat_metrics(kills, losses) do
    total_kills = length(kills)
    total_losses = length(losses)

    avg_damage_dealt = calculate_average_damage(kills, total_kills)
    avg_gang_kill = calculate_average_gang_size(kills, total_kills)
    avg_gang_loss = calculate_average_gang_size(losses, total_losses)
    solo_pct = calculate_solo_percentage(kills, total_kills)

    %{
      avg_damage_dealt: Decimal.from_float(avg_damage_dealt),
      avg_gang_size_when_killing: Decimal.from_float(avg_gang_kill),
      avg_gang_size_when_dying: Decimal.from_float(avg_gang_loss),
      solo_kill_percentage: Decimal.from_float(solo_pct)
    }
  end

  defp calculate_time_metrics do
    now = DateTime.utc_now()
    first = DateTimeUtils.add(now, -30 * 86_400, :second)

    %{
      peak_activity_hour: 18,
      first_seen: first,
      last_seen: now
    }
  end

  @spec determine_ship_category(ItemType.t()) :: String.t()
  defp determine_ship_category(%ItemType{is_capital_ship: is_cap, group_name: group_name}) do
    if is_cap do
      "capital"
    else
      categorize_by_group(group_name || "")
    end
  end

  defp categorize_by_group(group) do
    cond do
      group =~ ~r/battlecruiser/i -> "battlecruiser"
      group =~ ~r/battleship/i -> "battleship"
      group =~ ~r/cruiser/i -> "cruiser"
      group =~ ~r/destroyer/i -> "destroyer"
      group =~ ~r/frigate/i -> "frigate"
      group =~ ~r/industrial/i -> "industrial"
      true -> "special"
    end
  end

  # Calculate the sum of ship values from a list of participants
  defp sum_ship_values(participants) do
    participants
    |> Enum.map(fn p -> p.ship_value || 0.0 end)
    |> Enum.sum()
  end

  # Calculate average damage from participants
  defp calculate_average_damage(participants, count) when count > 0 do
    total_damage =
      participants
      |> Enum.map(fn p -> p.damage_done || 0.0 end)
      |> Enum.sum()

    total_damage / count
  end

  defp calculate_average_damage(_, 0), do: 0.0

  # Calculate average gang size from participants
  defp calculate_average_gang_size(participants, count) when count > 0 do
    total_gang_size =
      participants
      |> Enum.map(fn p -> p.gang_size || 1 end)
      |> Enum.sum()

    total_gang_size / count
  end

  defp calculate_average_gang_size(_, 0), do: 0.0

  # Calculate solo kill percentage
  defp calculate_solo_percentage(participants, count) when count > 0 do
    solo_count = Enum.count(participants, fn p -> (p.gang_size || 1) == 1 end)
    solo_count / count * 100
  end

  defp calculate_solo_percentage(_, 0), do: 0.0

  # Update ship rankings based on current statistics
  defp update_ship_rankings do
    Logger.info("Updating ship rankings...")

    case Ash.read(ShipStats, domain: EveDmv.Api) do
      {:ok, ships} ->
        # Calculate usage rank (by total activity)
        ships_by_usage = Enum.sort_by(ships, &(&1.total_kills + &1.total_losses), :desc)
        update_usage_ranks(ships_by_usage)

        # Calculate effectiveness rank (by K/D ratio)
        ships_by_effectiveness = Enum.sort_by(ships, &(&1.kill_death_ratio || 0), :desc)
        update_effectiveness_ranks(ships_by_effectiveness)

        Logger.info("Ship rankings updated successfully")
        :ok

      {:error, reason} ->
        Logger.error("Failed to update ship rankings: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Update usage ranks for ships
  defp update_usage_ranks(ships) do
    ships
    |> Enum.with_index(1)
    |> Enum.each(fn {ship, rank} ->
      case Ash.update(ship, %{usage_rank: rank}, domain: EveDmv.Api) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to update usage rank for ship #{ship.ship_type_id}: #{inspect(reason)}"
          )
      end
    end)
  end

  # Update effectiveness ranks for ships
  defp update_effectiveness_ranks(ships) do
    ships
    |> Enum.with_index(1)
    |> Enum.each(fn {ship, rank} ->
      case Ash.update(ship, %{effectiveness_rank: rank}, domain: EveDmv.Api) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "Failed to update effectiveness rank for ship #{ship.ship_type_id}: #{inspect(reason)}"
          )
      end
    end)
  end
end
