defmodule WandererClient do
  @moduledoc "Wrapper for Wanderer client operations with additional utility functions"

  alias EveDmv.Intelligence.WandererClient, as: RealClient

  defdelegate get_chain_topology(map_id), to: RealClient

  @doc """
  @doc """
  Check if a system is present in any monitored chain.

  ## Parameters
  - system_id: The solar system ID to check

  ## Returns
  - {:ok, map_info} if system is found in a chain
  - {:error, :not_found} if system is not in any monitored chains
  - {:error, reason} for other errors
  """
  def check_system_in_chain(system_id) when is_integer(system_id) do
    # Get all active monitored maps from the WandererClient
    case RealClient.connection_status() do
      %{monitored_maps: monitored_maps} when is_list(monitored_maps) ->
        check_system_in_maps(system_id, monitored_maps)

      _ ->
        {:error, :no_monitored_maps}
    end
  end

  def check_system_in_chain(system_id) when is_binary(system_id) do
    case Integer.parse(system_id) do
      {parsed_id, ""} -> check_system_in_chain(parsed_id)
      _ -> {:error, :invalid_system_id}
    end
  end

  def check_system_in_chain(_), do: {:error, :invalid_system_id}

  defp check_system_in_maps(_system_id, []), do: {:error, :not_found}

  defp check_system_in_maps(system_id, [map_id | remaining_maps]) do
    case RealClient.get_chain_topology(map_id) do
      {:ok, %{"systems" => systems}} when is_list(systems) ->
        if system_in_topology?(system_id, systems) do
          {:ok, %{map_id: map_id, system_id: system_id, found_in_chain: true}}
        else
          check_system_in_maps(system_id, remaining_maps)
        end

      {:error, _reason} ->
        # If this map fails, try the next one
        check_system_in_maps(system_id, remaining_maps)

      _ ->
        check_system_in_maps(system_id, remaining_maps)
    end
  end

  defp system_in_topology?(system_id, systems) when is_list(systems) do
    Enum.any?(systems, fn system ->
      case system do
        %{"solar_system_id" => ^system_id} -> true
        %{"id" => ^system_id} -> true
        %{"system_id" => ^system_id} -> true
        _ -> false
      end
    end)
  end
end
