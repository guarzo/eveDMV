defmodule EveDmv.Contexts.BattleAnalysis.Domain.Analyzers.ModuleClassifier do
  @moduledoc """
  Module classifier for ship role analysis.

  Classifies ship roles based on their fitted modules and combat behavior.
  """

  require Logger

  # Safe conversion of string to existing atom, fallback to :unknown
  defp safe_string_to_atom(string) when is_binary(string) do
    String.to_existing_atom(string)
  rescue
    ArgumentError -> :unknown
  end

  defp safe_string_to_atom(_), do: :unknown

  @doc """
  Classify ship role based on modules and behavior.
  """
  def classify_ship_role(ship_data) do
    ship_type_id = ship_data[:ship_type_id] || ship_data["ship_type_id"]

    if ship_type_id do
      # Use actual ship classification from database
      case EveDmv.StaticData.ShipTypes.get_ship_role(ship_type_id) do
        {:ok, role} ->
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

          %{
            primary_role: safe_string_to_atom(role),
            secondary_roles: determine_secondary_roles(ship_class, role),
            confidence: 0.9,
            analysis: %{
              dps_class: classify_dps_capability(ship_class),
              tank_type: classify_tank_capability(ship_class),
              mobility: classify_mobility_capability(ship_class),
              support_capability: classify_support_capability(role)
            }
          }

        {:error, _} ->
          # Fallback to class-based role classification
          ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
          fallback_role = classify_role_from_class(ship_class)

          %{
            primary_role: fallback_role,
            secondary_roles: [],
            confidence: 0.6,
            analysis: %{
              dps_class: classify_dps_capability(ship_class),
              tank_type: classify_tank_capability(ship_class),
              mobility: classify_mobility_capability(ship_class),
              support_capability: classify_support_capability(Atom.to_string(fallback_role))
            }
          }
      end
    else
      Logger.warning("Ship role classification failed - no ship_type_id provided")

      %{
        primary_role: :unknown,
        secondary_roles: [],
        confidence: 0.0,
        analysis: %{
          dps_class: :unknown,
          tank_type: :unknown,
          mobility: :unknown,
          support_capability: :none
        }
      }
    end
  end

  defp determine_secondary_roles(ship_class, primary_role) do
    case {ship_class, primary_role} do
      {:cruiser, "logistics"} -> [:support, :fleet_anchor]
      {:frigate, "tackle"} -> [:scout, :interceptor]
      {:destroyer, "dps"} -> [:tackle, :anti_frigate]
      {:battleship, "dps"} -> [:fleet_backbone, :alpha_strike]
      {:capital, _} -> [:fleet_anchor, :strategic_asset]
      _ -> []
    end
  end

  defp classify_role_from_class(ship_class) do
    case ship_class do
      :frigate -> :tackle
      :destroyer -> :dps
      :cruiser -> :dps
      :battlecruiser -> :dps
      :battleship -> :dps
      :capital -> :support
      :supercapital -> :dps
      :industrial -> :support
      :mining -> :support
      _ -> :unknown
    end
  end

  defp classify_dps_capability(ship_class) do
    case ship_class do
      :frigate -> :light
      :destroyer -> :medium
      :cruiser -> :medium
      :battlecruiser -> :heavy
      :battleship -> :heavy
      :capital -> :extreme
      :supercapital -> :extreme
      _ -> :unknown
    end
  end

  defp classify_tank_capability(ship_class) do
    case ship_class do
      :frigate -> :speed_tank
      :destroyer -> :speed_tank
      :cruiser -> :active_tank
      :battlecruiser -> :active_tank
      :battleship -> :buffer_tank
      :capital -> :capital_tank
      :supercapital -> :capital_tank
      _ -> :unknown
    end
  end

  defp classify_mobility_capability(ship_class) do
    case ship_class do
      :frigate -> :high
      :destroyer -> :high
      :cruiser -> :medium
      :battlecruiser -> :medium
      :battleship -> :low
      :capital -> :very_low
      :supercapital -> :very_low
      _ -> :unknown
    end
  end

  defp classify_support_capability(role) do
    case role do
      "logistics" -> :high
      "ewar" -> :high
      "tackle" -> :medium
      "dps" -> :low
      _ -> :none
    end
  end

  @doc """
  Get ship DPS classification.
  """
  def get_dps_class(ship_data) do
    ship_type_id = ship_data[:ship_type_id] || ship_data["ship_type_id"]

    if ship_type_id do
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
      classify_dps_capability(ship_class)
    else
      :unknown
    end
  end

  @doc """
  Get ship tank classification.
  """
  def get_tank_type(ship_data) do
    ship_type_id = ship_data[:ship_type_id] || ship_data["ship_type_id"]

    if ship_type_id do
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
      classify_tank_capability(ship_class)
    else
      :unknown
    end
  end

  @doc """
  Get ship mobility classification.
  """
  def get_mobility_class(ship_data) do
    ship_type_id = ship_data[:ship_type_id] || ship_data["ship_type_id"]

    if ship_type_id do
      ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)
      classify_mobility_capability(ship_class)
    else
      :unknown
    end
  end
end
