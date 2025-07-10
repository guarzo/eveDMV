defmodule EveDmv.Intelligence.Analyzers.WhFleetAnalyzer.DoctrineManager do
  @moduledoc """
  Handles doctrine creation, management, and counter-doctrine generation.

  This module provides functionality for creating fleet doctrines,
  generating counter-doctrines, and managing doctrine templates.
  """

  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.Analyzers.FleetPilotAnalyzer
  alias EveDmv.Intelligence.Fleet.DoctrineTemplateBuilder
  alias EveDmv.Intelligence.Wormhole.FleetComposition

  require Logger

  @doc """
  Create a new fleet composition doctrine for a corporation.

  ## Parameters
  - `corporation_id` - Corporation ID to create doctrine for
  - `doctrine_params` - Map containing doctrine parameters
  - `options` - Additional options (created_by, etc.)

  ## Returns
  - `{:ok, composition}` - Successfully created doctrine
  - `{:error, reason}` - Error creating doctrine
  """
  def create_fleet_doctrine(corporation_id, doctrine_params, options \\ []) do
    Logger.info("Creating new fleet doctrine for corporation #{corporation_id}")

    with {:ok, corp_info} <- get_corporation_info(corporation_id),
         {:ok, doctrine_template} <-
           DoctrineTemplateBuilder.build_doctrine_template(doctrine_params),
         {:ok, size_category} <-
           DoctrineTemplateBuilder.determine_size_category(doctrine_template) do
      composition_data = %{
        corporation_id: corporation_id,
        corporation_name: corp_info.corporation_name,
        alliance_id: corp_info.alliance_id,
        alliance_name: corp_info.alliance_name,
        doctrine_name: doctrine_params["name"],
        doctrine_description: doctrine_params["description"],
        fleet_size_category: size_category,
        minimum_pilots: DoctrineTemplateBuilder.calculate_minimum_pilots(doctrine_template),
        optimal_pilots: DoctrineTemplateBuilder.calculate_optimal_pilots(doctrine_template),
        maximum_pilots: DoctrineTemplateBuilder.calculate_maximum_pilots(doctrine_template),
        doctrine_template: doctrine_template,
        created_by: Keyword.get(options, :created_by)
      }

      case FleetComposition.create(composition_data) do
        {:ok, composition} ->
          # Return composition for immediate analysis by caller
          {:ok, composition}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to create fleet doctrine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate counter-doctrine recommendations against a specific threat.

  ## Parameters
  - `threat_analysis` - Analysis of the threat to counter
  - `corporation_id` - Corporation ID to create counter-doctrine for
  - `options` - Additional options

  ## Returns
  - `{:ok, composition}` - Successfully created counter-doctrine
  - `{:error, reason}` - Error creating counter-doctrine
  """
  def generate_counter_doctrine(threat_analysis, corporation_id, options \\ []) do
    Logger.info("Generating counter-doctrine for corporation #{corporation_id}")

    {:ok, available_pilots} = FleetPilotAnalyzer.get_available_pilots(corporation_id)
    counter_template = build_counter_template(threat_analysis, available_pilots)

    create_fleet_doctrine(
      corporation_id,
      %{
        "name" => "Counter: #{threat_analysis["threat_name"]}",
        "description" => "Optimized counter-doctrine for #{threat_analysis["threat_type"]}",
        "roles" => counter_template
      },
      options
    )
  end

  @doc """
  Get corporation information from ESI with fallback.

  ## Parameters
  - `corporation_id` - Corporation ID to lookup

  ## Returns
  - `{:ok, corp_info}` - Corporation information
  - `{:error, reason}` - Error getting corporation info
  """
  def get_corporation_info(corporation_id) do
    case EsiClient.get_corporation(corporation_id) do
      {:ok, corp_data} ->
        # Get alliance info if applicable
        alliance_info =
          if corp_data.alliance_id do
            case EsiClient.get_alliance(corp_data.alliance_id) do
              {:ok, alliance} ->
                %{alliance_id: alliance.alliance_id, alliance_name: alliance.name}

              _ ->
                %{alliance_id: nil, alliance_name: nil}
            end
          else
            %{alliance_id: nil, alliance_name: nil}
          end

        {:ok,
         %{
           corporation_name: corp_data.name,
           alliance_id: alliance_info.alliance_id,
           alliance_name: alliance_info.alliance_name
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch corporation info from ESI for #{corporation_id}: #{inspect(reason)}"
        )

        # Fallback to placeholder data
        {:ok,
         %{
           corporation_name: "Corporation #{corporation_id}",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  @doc """
  Extract ship types from a doctrine template.

  ## Parameters
  - `doctrine_template` - Doctrine template to extract ships from

  ## Returns
  - List of unique ship names
  """
  def extract_ship_types_from_doctrine(doctrine_template) do
    doctrine_template
    |> Enum.flat_map(fn {_role, config} ->
      config["preferred_ships"] || []
    end)
    |> Enum.uniq()
  end

  # Private helper functions

  defp build_counter_template(_threat_analysis, _available_pilots) do
    # Build a counter-doctrine template based on threat analysis
    # This would be more sophisticated in production
    %{
      "fleet_commander" => %{
        "required" => 1,
        "preferred_ships" => ["Command Ship"],
        "skills_required" => ["Leadership V"],
        "priority" => 1
      },
      "dps" => %{
        "required" => 4,
        "preferred_ships" => ["HAC", "T3 Cruiser"],
        "skills_required" => ["HAC IV"],
        "priority" => 2
      }
    }
  end
end
