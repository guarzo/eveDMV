defmodule EveDmv.Contexts.KillmailProcessing.Domain.KillmailPresenter do
  @moduledoc """
  Formats killmail data for display in the web interface.

  Transforms enriched killmail records into a simplified structure
  optimized for LiveView rendering and API responses.
  """

  @doc """
  Formats a killmail for display in the kill feed.

  Transforms an enriched killmail into a simplified map structure
  suitable for the LiveView kill feed display.

  ## Parameters
  - `killmail` - An enriched killmail struct or map

  ## Returns
  A map with display-ready killmail data including:
  - `:id` - Killmail ID
  - `:killmail_time` - When the kill occurred
  - `:solar_system_id` - System where kill occurred
  - `:victim` - Victim information map
  - `:total_value` - ISK value of the kill
  - `:participant_count` - Number of participants
  - `:location` - Location information map
  """
  @spec format_for_display(map()) :: map()
  def format_for_display(killmail) do
    %{
      id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      solar_system_id: killmail.solar_system_id,
      victim: %{
        character_id: killmail.victim_character_id,
        corporation_id: killmail.victim_corporation_id,
        alliance_id: killmail.victim_alliance_id,
        ship_type_id: killmail.victim_ship_type_id
      },
      total_value: Map.get(killmail, :total_value, 0),
      participant_count: Map.get(killmail, :participant_count, 0),
      location: %{
        solar_system_id: killmail.solar_system_id,
        region_id: Map.get(killmail, :region_id),
        constellation_id: Map.get(killmail, :constellation_id)
      }
    }
  end
end
