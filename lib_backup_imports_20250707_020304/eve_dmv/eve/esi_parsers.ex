defmodule EveDmv.Eve.EsiParsers do
  alias EveDmv.Utils.ParsingUtils

  require Logger
  @moduledoc """
  Response parsing utilities for EVE ESI API responses.

  This module handles parsing and transforming raw ESI API responses
  into normalized data structures used by the application.
  """



  @doc """
  Parse character information response from ESI.
  """
  @spec parse_character_response(integer(), map()) :: map()
  def parse_character_response(character_id, data) do
    %{
      character_id: character_id,
      name: Map.get(data, "name"),
      corporation_id: Map.get(data, "corporation_id"),
      alliance_id: Map.get(data, "alliance_id"),
      birthday: parse_datetime(Map.get(data, "birthday")),
      gender: Map.get(data, "gender"),
      race_id: Map.get(data, "race_id"),
      bloodline_id: Map.get(data, "bloodline_id"),
      security_status: Map.get(data, "security_status", 0.0)
    }
  end

  @doc """
  Parse corporation information response from ESI.
  """
  @spec parse_corporation_response(integer(), map()) :: map()
  def parse_corporation_response(corporation_id, data) do
    %{
      corporation_id: corporation_id,
      name: Map.get(data, "name"),
      ticker: Map.get(data, "ticker"),
      description: Map.get(data, "description"),
      member_count: Map.get(data, "member_count", 0),
      ceo_id: Map.get(data, "ceo_id"),
      alliance_id: Map.get(data, "alliance_id"),
      date_founded: parse_datetime(Map.get(data, "date_founded")),
      creator_id: Map.get(data, "creator_id"),
      home_station_id: Map.get(data, "home_station_id"),
      tax_rate: Map.get(data, "tax_rate", 0.0),
      url: Map.get(data, "url")
    }
  end

  @doc """
  Parse alliance information response from ESI.
  """
  @spec parse_alliance_response(integer(), map()) :: map()
  def parse_alliance_response(alliance_id, data) do
    %{
      alliance_id: alliance_id,
      name: Map.get(data, "name"),
      ticker: Map.get(data, "ticker"),
      creator_id: Map.get(data, "creator_id"),
      creator_corporation_id: Map.get(data, "creator_corporation_id"),
      executor_corporation_id: Map.get(data, "executor_corporation_id"),
      date_founded: parse_datetime(Map.get(data, "date_founded"))
    }
  end

  @doc """
  Parse solar system information response from ESI.
  """
  @spec parse_system_response(integer(), map()) :: map()
  def parse_system_response(system_id, data) do
    %{
      system_id: system_id,
      name: Map.get(data, "name"),
      constellation_id: Map.get(data, "constellation_id"),
      security_status: Map.get(data, "security_status", 0.0),
      security_class: Map.get(data, "security_class"),
      star_id: Map.get(data, "star_id"),
      stargates: Map.get(data, "stargates", []),
      stations: Map.get(data, "stations", []),
      position: Map.get(data, "position")
    }
  end

  @doc """
  Parse type information response from ESI.
  """
  @spec parse_type_response(integer(), map()) :: map()
  def parse_type_response(type_id, data) do
    %{
      type_id: type_id,
      name: Map.get(data, "name"),
      description: Map.get(data, "description"),
      group_id: Map.get(data, "group_id"),
      category_id: Map.get(data, "category_id"),
      mass: Map.get(data, "mass"),
      volume: Map.get(data, "volume"),
      capacity: Map.get(data, "capacity"),
      portion_size: Map.get(data, "portion_size"),
      radius: Map.get(data, "radius"),
      published: Map.get(data, "published", false),
      market_group_id: Map.get(data, "market_group_id"),
      dogma_attributes: Map.get(data, "dogma_attributes", []),
      dogma_effects: Map.get(data, "dogma_effects", [])
    }
  end

  @doc """
  Parse group information response from ESI.
  """
  @spec parse_group_response(integer(), map()) :: map()
  def parse_group_response(group_id, data) do
    %{
      group_id: group_id,
      name: Map.get(data, "name"),
      category_id: Map.get(data, "category_id"),
      published: Map.get(data, "published", false),
      types: Map.get(data, "types", [])
    }
  end

  @doc """
  Parse category information response from ESI.
  """
  @spec parse_category_response(integer(), map()) :: map()
  def parse_category_response(category_id, data) do
    %{
      category_id: category_id,
      name: Map.get(data, "name"),
      published: Map.get(data, "published", false),
      groups: Map.get(data, "groups", [])
    }
  end

  @doc """
  Parse employment history entry from ESI.
  """
  @spec parse_employment_history_entry(map()) :: %{
          corporation_id: any(),
          start_date: DateTime.t() | nil,
          is_deleted: any(),
          record_id: any()
        }
  def parse_employment_history_entry(data) do
    %{
      corporation_id: Map.get(data, "corporation_id"),
      start_date: parse_datetime(Map.get(data, "start_date")),
      is_deleted: Map.get(data, "is_deleted", false),
      record_id: Map.get(data, "record_id")
    }
  end

  @doc """
  Parse skills response from ESI.
  """
  @spec parse_skills_response(map()) :: %{skills: [any()], total_sp: any(), unallocated_sp: any()}
  def parse_skills_response(data) do
    %{
      total_sp: Map.get(data, "total_sp", 0),
      unallocated_sp: Map.get(data, "unallocated_sp", 0),
      skills: Enum.map(Map.get(data, "skills", []), &parse_skill_entry/1)
    }
  end

  @doc """
  Parse individual skill entry from ESI.
  """
  @spec parse_skill_entry(map()) :: %{
          skill_id: any(),
          skillpoints_in_skill: any(),
          trained_skill_level: any(),
          active_skill_level: any()
        }
  def parse_skill_entry(data) do
    %{
      skill_id: Map.get(data, "skill_id"),
      skillpoints_in_skill: Map.get(data, "skillpoints_in_skill", 0),
      trained_skill_level: Map.get(data, "trained_skill_level", 0),
      active_skill_level: Map.get(data, "active_skill_level", 0)
    }
  end

  @doc """
  Parse asset entry from ESI.
  """
  @spec parse_asset_entry(map()) :: %{
          item_id: any(),
          type_id: any(),
          quantity: any(),
          location_id: any(),
          location_flag: any(),
          location_type: any(),
          is_blueprint_copy: any(),
          is_singleton: any()
        }
  def parse_asset_entry(data) do
    %{
      item_id: Map.get(data, "item_id"),
      type_id: Map.get(data, "type_id"),
      quantity: Map.get(data, "quantity", 1),
      location_id: Map.get(data, "location_id"),
      location_flag: Map.get(data, "location_flag"),
      location_type: Map.get(data, "location_type"),
      is_blueprint_copy: Map.get(data, "is_blueprint_copy"),
      is_singleton: Map.get(data, "is_singleton", false)
    }
  end

  @doc """
  Parse market order from ESI.
  """
  @spec parse_market_order(map()) :: %{
          order_id: any(),
          type_id: any(),
          location_id: any(),
          volume_total: any(),
          volume_remain: any(),
          min_volume: any(),
          price: any(),
          is_buy_order: any(),
          duration: any(),
          issued: DateTime.t() | nil,
          range: any()
        }
  def parse_market_order(data) do
    %{
      order_id: Map.get(data, "order_id"),
      type_id: Map.get(data, "type_id"),
      location_id: Map.get(data, "location_id"),
      volume_total: Map.get(data, "volume_total", 0),
      volume_remain: Map.get(data, "volume_remain", 0),
      min_volume: Map.get(data, "min_volume", 1),
      price: Map.get(data, "price", 0.0),
      is_buy_order: Map.get(data, "is_buy_order", false),
      duration: Map.get(data, "duration", 0),
      issued: parse_datetime(Map.get(data, "issued")),
      range: Map.get(data, "range")
    }
  end

  @doc """
  Parse market history entry from ESI.
  """
  @spec parse_market_history(map()) :: %{
          date: Date.t(),
          order_count: any(),
          volume: any(),
          highest: any(),
          average: any(),
          lowest: any()
        }
  def parse_market_history(data) do
    %{
      date: parse_date(Map.get(data, "date")),
      order_count: Map.get(data, "order_count", 0),
      volume: Map.get(data, "volume", 0),
      highest: Map.get(data, "highest", 0.0),
      average: Map.get(data, "average", 0.0),
      lowest: Map.get(data, "lowest", 0.0)
    }
  end

  # Helper functions

  defp parse_datetime(datetime_string), do: ParsingUtils.parse_datetime(datetime_string)

  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} ->
        date

      {:error, _reason} ->
        Logger.warning("Failed to parse date: #{date_string}")
        nil
    end
  end

  defp parse_date(_), do: nil
end
