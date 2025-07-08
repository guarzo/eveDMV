defmodule EveDmv.Surveillance.Matching.KillmailFieldExtractor do
  @moduledoc """
  Killmail field extraction and classification module.

  This module provides utilities for extracting and transforming field values
  from killmail data structures for use in surveillance profile matching.
  """

  @doc """
  Extract field values from killmail data.

  Handles nested field access with proper fallbacks and data transformation.
  """
  def get_field(killmail, field) do
    case String.split(field, "_", parts: 2) do
      ["victim", victim_field] -> get_victim_field(killmail, victim_field)
      ["solar", "system" | _] -> get_system_field(killmail, field)
      _ -> get_top_level_field(killmail, field)
    end
  end

  @doc """
  Extract victim-specific fields from killmail data.
  """
  def get_victim_field(killmail, field) do
    case field do
      "character_id" -> get_in(killmail, ["victim", "character_id"])
      "corporation_id" -> get_in(killmail, ["victim", "corporation_id"])
      "alliance_id" -> get_in(killmail, ["victim", "alliance_id"])
      "ship_type_id" -> get_in(killmail, ["victim", "ship_type_id"])
      "character_name" -> get_in(killmail, ["victim", "character_name"])
      "corporation_name" -> get_in(killmail, ["victim", "corporation_name"])
      "alliance_name" -> get_in(killmail, ["victim", "alliance_name"])
      "ship_name" -> get_in(killmail, ["victim", "ship_name"])
      "ship_category" -> classify_ship(get_in(killmail, ["victim", "ship_type_id"]))
      _ -> nil
    end
  end

  @doc """
  Extract system-related fields from killmail data.
  """
  def get_system_field(killmail, field) do
    case field do
      "solar_system_id" -> killmail["solar_system_id"] || killmail["system_id"]
      "solar_system_name" -> killmail["solar_system_name"]
      _ -> nil
    end
  end

  @doc """
  Extract top-level killmail fields.
  """
  def get_top_level_field(killmail, field) do
    cond do
      field == "killmail_id" ->
        killmail["killmail_id"]

      field in ["total_value", "ship_value", "fitted_value"] ->
        get_value_fields(killmail, field)

      field in ["module_tags", "noteworthy_modules"] ->
        get_array_fields(killmail, field)

      field == "attacker_count" ->
        killmail["attacker_count"] || length(killmail["attackers"] || [])

      field == "final_blow_character_id" ->
        get_final_blow_character_id(killmail)

      field == "kill_category" ->
        classify_kill(killmail)

      true ->
        nil
    end
  end

  @doc """
  Extract value fields with proper fallbacks to zkb data.
  """
  def get_value_fields(killmail, field) do
    case field do
      "total_value" -> get_value_field(killmail, ["total_value", ["zkb", "totalValue"]])
      "ship_value" -> get_value_field(killmail, ["ship_value", ["zkb", "destroyedValue"]])
      "fitted_value" -> get_value_field(killmail, ["fitted_value", ["zkb", "fittedValue"]])
    end
  end

  @doc """
  Extract array fields with empty list fallback.
  """
  def get_array_fields(killmail, field) do
    killmail[field] || []
  end

  @doc """
  Get value field with fallback path support.
  """
  def get_value_field(killmail, [primary_field, fallback_path]) do
    killmail[primary_field] || get_in(killmail, fallback_path) || 0
  end

  @doc """
  Get the character ID of the pilot who delivered the final blow.
  """
  def get_final_blow_character_id(killmail) do
    attackers = killmail["attackers"] || []

    case Enum.find(attackers, &(&1["final_blow"] == true)) do
      %{"character_id" => character_id} -> character_id
      _ -> nil
    end
  end

  @doc """
  Classify a ship based on its type ID.

  Returns ship category string for filtering purposes.
  """
  def classify_ship(ship_type_id) when is_nil(ship_type_id), do: "unknown"

  def classify_ship(ship_type_id) do
    # Simplified ship classification - in production this would use
    # a proper ship database lookup
    cond do
      ship_type_id in 588..659 -> "frigate"
      ship_type_id in 540..563 -> "destroyer"
      ship_type_id in 617..648 -> "cruiser"
      ship_type_id in 419..440 -> "battlecruiser"
      ship_type_id in 641..659 -> "battleship"
      ship_type_id in 547..659 -> "industrial"
      ship_type_id >= 23_757 -> "capital"
      true -> "other"
    end
  end

  @doc """
  Classify a kill based on its characteristics.

  Returns kill category string for filtering purposes.
  """
  def classify_kill(killmail) do
    attackers = killmail["attackers"] || []
    victim = killmail["victim"] || %{}

    attacker_count = length(attackers)
    ship_type_id = victim["ship_type_id"]
    total_value = get_value_field(killmail, ["total_value", ["zkb", "totalValue"]])

    cond do
      attacker_count == 1 -> "solo"
      attacker_count <= 5 -> "small_gang"
      attacker_count <= 20 -> "medium_gang"
      attacker_count > 20 -> "fleet"
      ship_type_id && ship_type_id >= 23_757 -> "capital"
      total_value > 1_000_000_000 -> "expensive"
      true -> "standard"
    end
  end

  @doc """
  Extract indexable values from a killmail for building search indexes.

  Returns a map of field types to their extracted values.
  """
  def extract_indexable_values(killmail) do
    %{
      systems:
        Enum.filter([
          killmail["solar_system_id"] || killmail["system_id"]
        ], &(&1 != nil)),
      ships:
        Enum.filter([
          get_in(killmail, ["victim", "ship_type_id"])
        ], &(&1 != nil)),
      isk_values:
        Enum.filter([
          get_value_field(killmail, ["total_value", ["zkb", "totalValue"]])
        ], &(&1 != nil && &1 > 0)),
      tags:
        [
          get_array_fields(killmail, "module_tags"),
          get_array_fields(killmail, "noteworthy_modules")
        ]
        |> List.flatten()
        |> Enum.uniq()
    }
  end

  @doc """
  Determine if a field should be used for indexing optimization.

  Returns true if the field can benefit from inverted index lookup.
  """
  def indexable_field?(field) do
    field in [
      "solar_system_id",
      "victim_ship_type_id",
      "total_value",
      "ship_value",
      "fitted_value",
      "module_tags",
      "noteworthy_modules"
    ]
  end

  @doc """
  Get the index type for a given field.

  Returns the ETS table atom that should be used for indexing this field.
  """
  def get_index_type(field) do
    cond do
      field in ["solar_system_id"] -> :index_by_system
      field in ["victim_ship_type_id"] -> :index_by_ship
      field in ["total_value", "ship_value", "fitted_value"] -> :index_by_isk
      field in ["module_tags", "noteworthy_modules"] -> :index_by_tag
      true -> nil
    end
  end
end
