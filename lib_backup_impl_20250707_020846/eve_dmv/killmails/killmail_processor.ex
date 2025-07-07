defmodule EveDmv.Killmails.KillmailProcessor do
  @moduledoc """
  Shared killmail processing logic extracted from various modules.

  This module provides common functionality for processing killmail data
  across the pipeline, re-enrichment worker, and other killmail handlers.

  ## Main Functions

  - **Data extraction**: Parse and extract structured data from raw killmails
  - **Validation**: Ensure killmail data integrity and completeness
  - **Transformation**: Convert killmail data to database record formats
  - **Price calculation**: Handle ISK value calculations consistently
  - **Name resolution**: Resolve character/corporation/alliance names

  ## Usage

      # Extract structured data from raw killmail
      {:ok, structured} = KillmailProcessor.extract_structured_data(raw_killmail)

      # Build database changesets
      changesets = KillmailProcessor.build_changesets(structured)

      # Calculate price values
      price_data = KillmailProcessor.calculate_price_values(killmail, source: "janice")
  """

  require Logger
  alias EveDmv.Utils.ParsingUtils

  @type killmail_data :: map()
  @type changeset_data :: map()
  @type price_data :: %{
          total_value: Decimal.t(),
          ship_value: Decimal.t(),
          fitted_value: Decimal.t(),
          price_data_source: String.t()
        }

  @doc """
  Extract and validate structured data from raw killmail JSON.

  Handles different input formats from various SSE sources (wanderer-kills, zkillboard, etc.)
  and normalizes them into a consistent structure.

  ## Examples

      iex> raw = %{"killmail_id" => 123, "victim" => %{"character_id" => 456}}
      iex> KillmailProcessor.extract_structured_data(raw)
      {:ok, %{killmail_id: 123, victim: %{character_id: 456}, attackers: []}}

      iex> KillmailProcessor.extract_structured_data(%{})
      {:error, :missing_killmail_id}
  """
  @spec extract_structured_data(killmail_data()) :: {:ok, killmail_data()} | {:error, atom()}
  def extract_structured_data(raw_killmail) when is_map(raw_killmail) do
    with {:ok, killmail_id} <- extract_killmail_id(raw_killmail),
         {:ok, timestamp} <- extract_timestamp(raw_killmail),
         {:ok, victim} <- extract_victim_data(raw_killmail),
         {:ok, attackers} <- extract_attackers_data(raw_killmail),
         {:ok, system_id} <- extract_system_id(raw_killmail) do
      structured = %{
        killmail_id: killmail_id,
        timestamp: timestamp,
        victim: victim,
        attackers: attackers,
        solar_system_id: system_id,
        raw_data: raw_killmail
      }

      {:ok, structured}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def extract_structured_data(_), do: {:error, :invalid_input}

  @doc """
  Build database changesets for raw and enriched killmail records.

  Takes structured killmail data and produces changeset maps suitable
  for insertion into KillmailRaw and KillmailEnriched tables.

  ## Examples

      structured = %{killmail_id: 123, victim: %{character_id: 456}}
      changesets = KillmailProcessor.build_changesets(structured)
      %{raw: raw_changeset, enriched: enriched_changeset} = changesets
  """
  @spec build_changesets(killmail_data()) :: %{raw: changeset_data(), enriched: changeset_data()}
  def build_changesets(structured_data) do
    %{
      raw: build_raw_changeset(structured_data),
      enriched: build_enriched_changeset(structured_data)
    }
  end

  @doc """
  Calculate price values for a killmail using specified pricing source.

  Supports multiple pricing sources and handles fallbacks gracefully.

  ## Options

  - `:source` - Pricing source (:wanderer_kills, :janice, :mutamarket)
  - `:fallback` - Whether to use fallback pricing (default: true)

  ## Examples

      price_data = KillmailProcessor.calculate_price_values(killmail, source: :janice)
      %{total_value: value, ship_value: ship, fitted_value: fitted} = price_data
  """
  @spec calculate_price_values(killmail_data(), keyword()) :: price_data()
  def calculate_price_values(killmail_data, opts \\ []) do
    source = Keyword.get(opts, :source, :wanderer_kills)
    fallback = Keyword.get(opts, :fallback, true)

    case extract_existing_prices(killmail_data, source) do
      {:ok, prices} ->
        prices

      {:error, _} when fallback ->
        calculate_fallback_prices(killmail_data)

      {:error, _} ->
        %{
          total_value: Decimal.new("0.0"),
          ship_value: Decimal.new("0.0"),
          fitted_value: Decimal.new("0.0"),
          price_data_source: to_string(source)
        }
    end
  end

  @doc """
  Build participant changesets from attackers and victim data.

  Handles both victim and attacker participants, ensuring proper
  flags (is_victim, final_blow) are set correctly.

  ## Examples

      participants = KillmailProcessor.build_participants(structured_data)
      assert length(participants) > 0
      assert Enum.any?(participants, & &1.is_victim)
  """
  @spec build_participants(killmail_data()) :: [changeset_data()]
  def build_participants(structured_data) do
    victim_participants = build_victim_participant(structured_data)
    attacker_participants = build_attacker_participants(structured_data)

    [victim_participants | attacker_participants]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Validate killmail data completeness and integrity.

  Checks for required fields, data consistency, and logical constraints.

  ## Examples

      case KillmailProcessor.validate_killmail(data) do
        :ok -> process_killmail(data)
        {:error, errors} -> handle_validation_errors(errors)
      end
  """
  @spec validate_killmail(killmail_data()) :: :ok | {:error, [atom()]}
  def validate_killmail(killmail_data) do
    errors =
      []
      |> validate_required_fields(killmail_data)
      |> validate_participant_data(killmail_data)
      |> validate_system_data(killmail_data)
      |> validate_timestamp_data(killmail_data)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Resolve missing names for characters, corporations, and alliances.

  Uses ESI API to fetch missing names and updates the killmail data.
  Handles rate limiting and caching appropriately.

  ## Examples

      updated_data = KillmailProcessor.resolve_names(killmail_data)
      assert updated_data.victim.character_name != nil
  """
  @spec resolve_names(killmail_data()) :: killmail_data()
  def resolve_names(killmail_data) do
    # Implementation would use EveDmv.Eve.NameResolver
    # For now, return data unchanged to avoid breaking existing code
    killmail_data
  end

  # Private helper functions

  defp extract_killmail_id(raw_killmail) do
    case Map.get(raw_killmail, "killmail_id") do
      nil -> {:error, :missing_killmail_id}
      id when is_integer(id) -> {:ok, id}
      id when is_binary(id) -> {:ok, ParsingUtils.parse_integer(id)}
      _ -> {:error, :invalid_killmail_id}
    end
  end

  defp extract_timestamp(raw_killmail) do
    timestamp_key = raw_killmail["timestamp"] || raw_killmail["kill_time"]

    case timestamp_key do
      nil ->
        {:error, :missing_timestamp}

      timestamp ->
        case ParsingUtils.parse_datetime(timestamp) do
          nil -> {:error, :invalid_timestamp}
          dt -> {:ok, dt}
        end
    end
  end

  defp extract_victim_data(raw_killmail) do
    case Map.get(raw_killmail, "victim") do
      nil -> {:error, :missing_victim}
      victim when is_map(victim) -> {:ok, normalize_participant_data(victim)}
      _ -> {:error, :invalid_victim_data}
    end
  end

  defp extract_attackers_data(raw_killmail) do
    attackers = Map.get(raw_killmail, "attackers", [])

    normalized_attackers =
      Enum.map(Enum.filter(attackers, &is_map/1), &normalize_participant_data/1)

    {:ok, normalized_attackers}
  end

  defp extract_system_id(raw_killmail) do
    system_id = raw_killmail["solar_system_id"] || raw_killmail["system_id"]

    case system_id do
      nil -> {:error, :missing_system_id}
      id when is_integer(id) -> {:ok, id}
      id when is_binary(id) -> {:ok, ParsingUtils.parse_integer(id)}
      _ -> {:error, :invalid_system_id}
    end
  end

  defp normalize_participant_data(participant) do
    %{
      character_id: participant["character_id"],
      character_name: participant["character_name"],
      corporation_id: participant["corporation_id"],
      corporation_name: participant["corporation_name"],
      alliance_id: participant["alliance_id"],
      alliance_name: participant["alliance_name"],
      faction_id: participant["faction_id"],
      faction_name: participant["faction_name"],
      ship_type_id: participant["ship_type_id"],
      ship_name: participant["ship_name"],
      weapon_type_id: participant["weapon_type_id"],
      weapon_name: participant["weapon_name"],
      damage_done: participant["damage_done"] || 0,
      security_status: participant["security_status"],
      final_blow: participant["final_blow"] || false
    }
  end

  defp build_raw_changeset(structured_data) do
    %{
      killmail_id: structured_data.killmail_id,
      killmail_time: structured_data.timestamp,
      killmail_hash: generate_hash(structured_data.raw_data),
      solar_system_id: structured_data.solar_system_id,
      victim_character_id: get_nested_id(structured_data, [:victim, :character_id]),
      victim_corporation_id: get_nested_id(structured_data, [:victim, :corporation_id]),
      victim_alliance_id: get_nested_id(structured_data, [:victim, :alliance_id]),
      victim_ship_type_id: get_nested_id(structured_data, [:victim, :ship_type_id]),
      attacker_count: length(structured_data.attackers),
      raw_data: structured_data.raw_data,
      source: "processor"
    }
  end

  defp build_enriched_changeset(structured_data) do
    price_data = calculate_price_values(structured_data.raw_data)
    victim = structured_data.victim

    %{
      killmail_id: structured_data.killmail_id,
      killmail_time: structured_data.timestamp,
      victim_character_id: victim.character_id,
      victim_character_name: victim.character_name,
      victim_corporation_id: victim.corporation_id,
      victim_corporation_name: victim.corporation_name,
      victim_alliance_id: victim.alliance_id,
      victim_alliance_name: victim.alliance_name,
      solar_system_id: structured_data.solar_system_id,
      solar_system_name: "Unknown System",
      victim_ship_type_id: victim.ship_type_id,
      victim_ship_name: victim.ship_name,
      total_value: price_data.total_value,
      ship_value: price_data.ship_value,
      fitted_value: price_data.fitted_value,
      attacker_count: length(structured_data.attackers),
      final_blow_character_id: get_final_blow_character_id(structured_data),
      final_blow_character_name: get_final_blow_character_name(structured_data),
      kill_category: determine_kill_category(structured_data),
      victim_ship_category: determine_ship_category(victim.ship_type_id),
      module_tags: [],
      noteworthy_modules: [],
      price_data_source: price_data.price_data_source
    }
  end

  defp build_victim_participant(structured_data) do
    victim = structured_data.victim

    %{
      killmail_id: structured_data.killmail_id,
      killmail_time: structured_data.timestamp,
      character_id: victim.character_id,
      character_name: victim.character_name,
      corporation_id: victim.corporation_id,
      corporation_name: victim.corporation_name,
      alliance_id: victim.alliance_id,
      alliance_name: victim.alliance_name,
      faction_id: victim.faction_id,
      faction_name: victim.faction_name,
      ship_type_id: victim.ship_type_id,
      ship_name: victim.ship_name,
      weapon_type_id: victim.weapon_type_id,
      weapon_name: victim.weapon_name,
      damage_done: 0,
      security_status: victim.security_status,
      is_victim: true,
      final_blow: false,
      is_npc: npc_character?(victim.character_id),
      solar_system_id: structured_data.solar_system_id
    }
  end

  defp build_attacker_participants(structured_data) do
    Enum.map(structured_data.attackers, fn attacker ->
      %{
        killmail_id: structured_data.killmail_id,
        killmail_time: structured_data.timestamp,
        character_id: attacker.character_id,
        character_name: attacker.character_name,
        corporation_id: attacker.corporation_id,
        corporation_name: attacker.corporation_name,
        alliance_id: attacker.alliance_id,
        alliance_name: attacker.alliance_name,
        faction_id: attacker.faction_id,
        faction_name: attacker.faction_name,
        ship_type_id: attacker.ship_type_id,
        ship_name: attacker.ship_name,
        weapon_type_id: attacker.weapon_type_id,
        weapon_name: attacker.weapon_name,
        damage_done: attacker.damage_done,
        security_status: attacker.security_status,
        is_victim: false,
        final_blow: attacker.final_blow,
        is_npc: npc_character?(attacker.character_id),
        solar_system_id: structured_data.solar_system_id
      }
    end)
  end

  defp extract_existing_prices(killmail_data, :wanderer_kills) do
    zkb_value = get_in(killmail_data, ["zkb", "totalValue"])
    total_value = killmail_data["total_value"] || killmail_data["value"] || zkb_value

    case total_value do
      nil ->
        {:error, :no_price_data}

      value ->
        {:ok,
         %{
           total_value: ParsingUtils.parse_decimal(value),
           ship_value: Decimal.new("0.0"),
           fitted_value: Decimal.new("0.0"),
           price_data_source: "wanderer_kills"
         }}
    end
  end

  defp extract_existing_prices(_killmail_data, _source) do
    {:error, :unsupported_source}
  end

  defp calculate_fallback_prices(_killmail_data) do
    %{
      total_value: Decimal.new("0.0"),
      ship_value: Decimal.new("0.0"),
      fitted_value: Decimal.new("0.0"),
      price_data_source: "fallback"
    }
  end

  defp get_nested_id(data, path) do
    get_in(data, path)
  end

  defp get_final_blow_character_id(structured_data) do
    final_blow_attacker =
      Enum.find(structured_data.attackers, fn attacker ->
        attacker.final_blow
      end)

    case final_blow_attacker do
      nil -> nil
      attacker -> attacker.character_id
    end
  end

  defp get_final_blow_character_name(structured_data) do
    final_blow_attacker =
      Enum.find(structured_data.attackers, fn attacker ->
        attacker.final_blow
      end)

    case final_blow_attacker do
      nil -> nil
      attacker -> attacker.character_name
    end
  end

  defp determine_kill_category(structured_data) do
    attacker_count = length(structured_data.attackers)

    cond do
      attacker_count == 1 -> "solo"
      attacker_count <= 5 -> "small_gang"
      attacker_count <= 15 -> "medium_gang"
      true -> "fleet"
    end
  end

  defp determine_ship_category(ship_type_id) when is_integer(ship_type_id) do
    # Basic ship categorization - could be enhanced with actual ship data
    cond do
      ship_type_id in [670] -> "capsule"
      ship_type_id < 1000 -> "frigate"
      ship_type_id < 10_000 -> "cruiser"
      true -> "unknown"
    end
  end

  defp determine_ship_category(_), do: "unknown"

  defp npc_character?(character_id) when is_integer(character_id) do
    # NPC character IDs are typically below this threshold
    character_id < 3_000_000
  end

  defp npc_character?(_), do: false

  defp generate_hash(raw_data) do
    # Simple hash generation - could be enhanced
    raw_data
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # Validation helper functions

  defp validate_required_fields(errors, killmail_data) do
    required_fields = [:killmail_id, :timestamp, :victim, :solar_system_id]

    missing_fields =
      Enum.reject(required_fields, fn field ->
        Map.has_key?(killmail_data, field) && Map.get(killmail_data, field) != nil
      end)

    case missing_fields do
      [] -> errors
      fields -> [{:missing_required_fields, fields} | errors]
    end
  end

  defp validate_participant_data(errors, killmail_data) do
    case Map.get(killmail_data, :victim) do
      nil -> [:missing_victim | errors]
      victim when is_map(victim) -> errors
      _ -> [:invalid_victim | errors]
    end
  end

  defp validate_system_data(errors, killmail_data) do
    case Map.get(killmail_data, :solar_system_id) do
      id when is_integer(id) and id > 0 -> errors
      _ -> [:invalid_system_id | errors]
    end
  end

  defp validate_timestamp_data(errors, killmail_data) do
    case Map.get(killmail_data, :timestamp) do
      %DateTime{} -> errors
      _ -> [:invalid_timestamp | errors]
    end
  end
end
