defmodule EveDmvWeb.FleetOperationsLive do
  @moduledoc """
  LiveView for fleet operations analysis and management.

  Provides comprehensive fleet composition analysis, effectiveness metrics,
  doctrine compliance checking, and fleet optimization recommendations.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Contexts.FleetOperations.Analyzers.CompositionAnalyzer
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Intelligence.Analyzers.WhFleetAnalyzer

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Fleet Operations")
      |> assign(:current_page, :fleet_operations)
      |> assign(:loading, false)
      |> assign(:fleet_data, nil)
      |> assign(:analysis_results, nil)
      |> assign(:analysis_type, "composition")

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket =
      case params do
        %{"battle_id" => battle_id, "side" => side} ->
          # Load fleet data for specific side
          socket
          |> assign(:loading, true)
          |> assign(:selected_side, side)
          |> then(fn socket ->
            send(self(), {:load_battle_side_data, battle_id, side})
            socket
          end)

        %{"battle_id" => battle_id, "window" => window_timestamp} ->
          # Load fleet data from battle analysis
          socket
          |> assign(:loading, true)
          |> then(fn socket ->
            send(self(), {:load_battle_fleet_data, battle_id, window_timestamp})
            socket
          end)

        %{"battle_id" => battle_id} ->
          # Load fleet data from battle (latest window)
          socket
          |> assign(:loading, true)
          |> then(fn socket ->
            send(self(), {:load_battle_fleet_data, battle_id, nil})
            socket
          end)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("analyze_fleet", %{"type" => type}, socket) do
    case socket.assigns.fleet_data do
      nil ->
        {:noreply, put_flash(socket, :error, "No fleet data available for analysis")}

      fleet_data ->
        socket =
          socket
          |> assign(:loading, true)
          |> assign(:analysis_type, type)

        send(self(), {:run_analysis, type, fleet_data})
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:run_analysis, type, fleet_data}, socket) do
    results =
      case type do
        "composition" ->
          analyze_fleet_composition(fleet_data)

        "effectiveness" ->
          analyze_fleet_effectiveness(fleet_data)

        "performance" ->
          analyze_pilot_performance(fleet_data)

        _ ->
          %{error: "Unknown analysis type"}
      end

    socket =
      socket
      |> assign(:loading, false)
      |> assign(:analysis_results, results)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:load_battle_side_data, battle_id, side}, socket) do
    case load_fleet_side_from_battle(battle_id, side) do
      {:ok, fleet_data} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:fleet_data, fleet_data)
          |> assign(:analysis_results, nil)
          |> put_flash(:info, "Loaded #{side} fleet data from battle #{battle_id}")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to load #{side} fleet data: #{reason}")

        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:load_battle_fleet_data, battle_id, window_timestamp}, socket) do
    case load_fleet_from_battle(battle_id, window_timestamp) do
      {:ok, fleet_data} ->
        socket =
          socket
          |> assign(:loading, false)
          |> assign(:fleet_data, fleet_data)
          |> assign(:analysis_results, nil)
          |> put_flash(:info, "Loaded fleet data from battle #{battle_id}")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:loading, false)
          |> put_flash(:error, "Failed to load battle fleet data: #{reason}")

        {:noreply, socket}
    end
  end

  # Analysis functions

  defp analyze_fleet_composition(fleet_data) do
    try do
      # CompositionAnalyzer expects fleet_id as integer and base_data structure
      # Convert string to integer
      fleet_id_hash = :erlang.phash2(fleet_data.fleet_id)

      # Fix the fleet participants key mapping
      fleet_participants_fixed = %{
        fleet_id_hash => Map.get(fleet_data.fleet_participants, fleet_data.fleet_id, [])
      }

      base_data = %{
        fleet_data: %{fleet_id_hash => fleet_data.fleet_data},
        fleet_participants: fleet_participants_fixed
      }

      case CompositionAnalyzer.analyze(fleet_id_hash, base_data) do
        {:ok, analysis} ->
          %{
            type: "composition",
            success: true,
            data: analysis,
            summary: generate_composition_summary(analysis)
          }

        {:error, reason} ->
          %{type: "composition", success: false, error: inspect(reason)}

        %EveDmv.Error{} = error ->
          %{type: "composition", success: false, error: error.message}
      end
    rescue
      error ->
        %{type: "composition", success: false, error: "Analysis failed: #{inspect(error)}"}
    end
  end

  defp analyze_fleet_effectiveness(fleet_data) do
    try do
      participant_data = Map.get(fleet_data, :fleet_participants, %{})
      participants = Map.get(participant_data, fleet_data.fleet_id, [])

      fleet_analysis = WhFleetAnalyzer.analyze_fleet_composition_from_members(participants)
      effectiveness = WhFleetAnalyzer.calculate_fleet_effectiveness(fleet_analysis)

      improvements =
        WhFleetAnalyzer.recommend_fleet_improvements(%{
          effectiveness_metrics: effectiveness,
          role_distribution: fleet_analysis.role_distribution,
          doctrine_compliance: fleet_analysis.doctrine_compliance
        })

      %{
        type: "effectiveness",
        success: true,
        data: %{
          fleet_analysis: fleet_analysis,
          effectiveness: effectiveness,
          improvements: improvements
        },
        summary: generate_effectiveness_summary(effectiveness)
      }
    rescue
      error ->
        %{type: "effectiveness", success: false, error: "Analysis failed: #{inspect(error)}"}
    end
  end

  defp analyze_pilot_performance(fleet_data) do
    try do
      participant_data = Map.get(fleet_data, :fleet_participants, %{})
      participants = Map.get(participant_data, fleet_data.fleet_id, [])

      # Calculate real pilot performance metrics from battle data
      performance_metrics = calculate_pilot_performance_metrics(participants)

      %{
        type: "performance",
        success: true,
        data: performance_metrics,
        summary: generate_performance_summary(performance_metrics)
      }
    rescue
      error ->
        %{type: "performance", success: false, error: "Analysis failed: #{inspect(error)}"}
    end
  end

  # Calculate pilot performance metrics from battle data
  defp calculate_pilot_performance_metrics(participants) do
    if Enum.empty?(participants) do
      %{
        total_pilots: 0,
        top_performers: [],
        damage_leaders: [],
        survival_rate: 0,
        ship_distribution: %{},
        performance_stats: %{}
      }
    else
      # Extract performance data from participants
      total_pilots = length(participants)

      # Calculate damage dealt (if available in participant data)
      damage_leaders =
        participants
        |> Enum.filter(&Map.has_key?(&1, :damage_dealt))
        |> Enum.sort_by(&Map.get(&1, :damage_dealt, 0), :desc)
        |> Enum.take(5)

      # Calculate ship distribution
      ship_distribution =
        participants
        |> Enum.group_by(&Map.get(&1, :ship_name, "Unknown"))
        |> Enum.map(fn {ship, pilots} -> {ship, length(pilots)} end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(5)
        |> Enum.into(%{})

      # Calculate survival rate (participants who weren't victims)
      survivors = Enum.count(participants, &(!Map.get(&1, :is_victim, false)))
      survival_rate = if total_pilots > 0, do: round(survivors / total_pilots * 100), else: 0

      # Identify top performers (based on multiple factors)
      top_performers =
        participants
        |> Enum.map(&calculate_pilot_score/1)
        |> Enum.sort_by(&Map.get(&1, :score, 0), :desc)
        |> Enum.take(5)

      # Performance statistics
      performance_stats = %{
        average_ship_value: calculate_average_ship_value(participants),
        most_common_ship: get_most_common_ship(ship_distribution),
        fleet_coordination: calculate_fleet_coordination_score(participants),
        engagement_intensity: calculate_engagement_intensity(participants)
      }

      %{
        total_pilots: total_pilots,
        top_performers: top_performers,
        damage_leaders: damage_leaders,
        survival_rate: survival_rate,
        ship_distribution: ship_distribution,
        performance_stats: performance_stats
      }
    end
  end

  # Summary generators

  defp generate_composition_summary(analysis) do
    overview = analysis.fleet_overview
    composition = analysis.ship_composition

    [
      "Fleet Size: #{overview.total_participants} pilots",
      "Fleet Type: #{String.capitalize(to_string(overview.fleet_type))}",
      "Ship Diversity: #{composition.unique_ship_types} unique types",
      "Fleet Value: #{format_isk(overview.total_fleet_value)}"
    ]
  end

  defp generate_effectiveness_summary(effectiveness) do
    [
      "Overall Effectiveness: #{effectiveness.overall_effectiveness}%",
      "DPS Rating: #{effectiveness.dps_rating}%",
      "Survivability: #{effectiveness.survivability_rating}%",
      "Flexibility: #{effectiveness.flexibility_rating}%"
    ]
  end

  defp generate_performance_summary(performance) do
    [
      "Total Pilots: #{performance.total_pilots}",
      "Survival Rate: #{performance.survival_rate}%",
      "Top Ship: #{performance.performance_stats.most_common_ship}",
      "Fleet Coordination: #{performance.performance_stats.fleet_coordination}/100"
    ]
  end

  # Real fleet data loading

  defp load_fleet_side_from_battle(battle_id, side) do
    # Battles are generated dynamically, so we need to regenerate them to find the specific battle
    end_time = DateTime.utc_now()
    # Look back 48 hours
    start_time = DateTime.add(end_time, -48, :hour)

    case BattleAnalysis.detect_battles(start_time, end_time) do
      {:ok, battles} ->
        case Enum.find(battles, fn battle ->
               Map.get(battle, :battle_id) == battle_id
             end) do
          nil ->
            {:error, "Battle #{battle_id} not found in recent battles"}

          battle ->
            case extract_side_participants(battle, side) do
              {:ok, side_participants} ->
                friendly_fleet_id = generate_friendly_fleet_id(battle, nil)

                fleet_data = %{
                  fleet_id: "#{friendly_fleet_id}_#{side}",
                  fleet_name: "#{String.capitalize(String.replace(side, "_", " "))} Fleet",
                  start_time: DateTime.to_iso8601(get_battle_start_time(battle.killmails)),
                  end_time: DateTime.to_iso8601(get_battle_end_time(battle.killmails)),
                  engagement_status: "Battle Analysis - #{String.capitalize(side)}"
                }

                fleet_participants = Enum.map(side_participants, &convert_pilot_to_fleet_member/1)

                {:ok,
                 %{
                   fleet_id: "#{friendly_fleet_id}_#{side}",
                   fleet_data: fleet_data,
                   fleet_participants: %{
                     "#{friendly_fleet_id}_#{side}" => fleet_participants
                   }
                 }}

              {:error, reason} ->
                {:error, reason}
            end
        end

      {:error, reason} ->
        {:error, "Failed to detect battles: #{reason}"}
    end
  end

  defp load_fleet_from_battle(battle_id, window_timestamp) do
    # Battles are generated dynamically, so we need to regenerate them to find the specific battle
    # This is not ideal for performance, but battles aren't persisted yet
    end_time = DateTime.utc_now()
    # Look back 48 hours
    start_time = DateTime.add(end_time, -48, :hour)

    case BattleAnalysis.detect_battles(start_time, end_time) do
      {:ok, battles} ->
        case Enum.find(battles, fn battle ->
               Map.get(battle, :battle_id) == battle_id
             end) do
          nil ->
            {:error, "Battle #{battle_id} not found in recent battles"}

          battle ->
            extract_fleet_from_battle_timeline(battle, window_timestamp)
        end

      {:error, reason} ->
        {:error, "Failed to detect battles: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "Failed to load battle data: #{inspect(error)}"}
  end

  defp extract_fleet_from_battle_timeline(battle, _window_timestamp) do
    # Extract fleet data directly from battle killmails
    killmails = Map.get(battle, :killmails, [])

    if Enum.empty?(killmails) do
      {:error, "No killmails found in battle"}
    else
      # Group participants by alliance/corporation to identify fleets
      participants = extract_participants_from_killmails(killmails)
      fleet_sides = group_participants_into_sides(participants)

      case fleet_sides do
        [] ->
          {:error, "No fleet sides found"}

        sides ->
          # Get the largest side as the main fleet
          main_fleet =
            Enum.max_by(sides, fn side ->
              length(Map.get(side, :pilots, []))
            end)

          # Generate a user-friendly fleet ID
          friendly_fleet_id = generate_friendly_fleet_id(battle, main_fleet)

          fleet_data = %{
            fleet_id: friendly_fleet_id,
            fleet_name: "Battle Fleet - #{Map.get(main_fleet, :group_id)}",
            start_time: DateTime.to_iso8601(get_battle_start_time(killmails)),
            end_time: DateTime.to_iso8601(get_battle_end_time(killmails)),
            engagement_status: "Battle Analysis"
          }

          fleet_participants =
            Enum.map(Map.get(main_fleet, :pilots, []), &convert_pilot_to_fleet_member/1)

          {:ok,
           %{
             fleet_id: friendly_fleet_id,
             fleet_data: fleet_data,
             fleet_participants: %{
               friendly_fleet_id => fleet_participants
             }
           }}
      end
    end
  end

  defp extract_participants_from_killmails(killmails) do
    Enum.flat_map(killmails, fn km ->
      victim = extract_victim_data(km)
      attackers = extract_attacker_data(km)
      [victim | attackers]
    end)
    |> Enum.filter(&(&1 != nil))
  end

  defp extract_victim_data(killmail) do
    raw_data = Map.get(killmail, :raw_data, %{})
    victim = Map.get(raw_data, "victim", %{})

    %{
      character_id: Map.get(victim, "character_id"),
      character_name: Map.get(victim, "character_name"),
      corporation_id: Map.get(victim, "corporation_id"),
      alliance_id: Map.get(victim, "alliance_id"),
      ship_type_id: Map.get(victim, "ship_type_id"),
      role: :victim
    }
  end

  defp extract_attacker_data(killmail) do
    raw_data = Map.get(killmail, :raw_data, %{})
    attackers = Map.get(raw_data, "attackers", [])

    Enum.map(attackers, fn attacker ->
      %{
        character_id: Map.get(attacker, "character_id"),
        character_name: Map.get(attacker, "character_name"),
        corporation_id: Map.get(attacker, "corporation_id"),
        alliance_id: Map.get(attacker, "alliance_id"),
        ship_type_id: Map.get(attacker, "ship_type_id"),
        role: :attacker,
        final_blow: Map.get(attacker, "final_blow", false)
      }
    end)
  end

  defp group_participants_into_sides(participants) do
    # Group by alliance (or corporation if no alliance)
    groups =
      Enum.group_by(participants, fn p ->
        Map.get(p, :alliance_id) || Map.get(p, :corporation_id) || "unknown"
      end)

    Enum.map(groups, fn {group_id, pilots} ->
      %{
        group_id: group_id,
        pilots: pilots,
        ship_count: length(pilots),
        unique_ship_types:
          pilots |> Enum.map(&Map.get(&1, :ship_type_id)) |> Enum.uniq() |> length()
      }
    end)
    # Only include sides with multiple ships
    |> Enum.filter(fn side -> side.ship_count > 1 end)
  end

  defp get_battle_start_time(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :killmail_time))
    |> Enum.min(DateTime, fn -> DateTime.utc_now() end)
  end

  defp get_battle_end_time(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :killmail_time))
    |> Enum.max(DateTime, fn -> DateTime.utc_now() end)
  end

  # Helper functions

  defp format_isk(amount) when is_number(amount) do
    cond do
      amount >= 1_000_000_000 -> "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
      amount >= 1_000_000 -> "#{Float.round(amount / 1_000_000, 1)}M ISK"
      amount >= 1_000 -> "#{Float.round(amount / 1_000, 1)}K ISK"
      true -> "#{round(amount)} ISK"
    end
  end

  defp format_isk(_), do: "0 ISK"

  # Helper functions for formatting numbers
  defp format_number(number) when is_number(number) do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{round(number)}"
    end
  end

  defp format_number(_), do: "0"

  defp format_ehp(ehp) when is_number(ehp) do
    cond do
      ehp >= 1_000_000_000 -> "#{Float.round(ehp / 1_000_000_000, 1)}B"
      ehp >= 1_000_000 -> "#{Float.round(ehp / 1_000_000, 1)}M"
      ehp >= 1_000 -> "#{Float.round(ehp / 1_000, 1)}K"
      true -> "#{round(ehp)}"
    end
  end

  defp format_ehp(_), do: "0"

  # Analysis rendering functions

  defp render_composition_analysis(data) do
    fleet_overview = Map.get(data || %{}, :fleet_overview, %{})
    ship_composition = Map.get(data || %{}, :ship_composition, %{})
    role_distribution = Map.get(data || %{}, :role_distribution, %{})

    _ship_breakdown = Map.get(ship_composition, :ship_breakdown, %{})
    ship_class_breakdown = Map.get(ship_composition, :ship_class_breakdown, %{})
    most_common_ships = Map.get(ship_composition, :most_common_ships, [])
    role_breakdown = Map.get(role_distribution, :role_breakdown, %{})

    # Format ship types within this class
    # Color code roles
    """
    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">Fleet Composition Analysis</h3>
      <div class="space-y-6">
        
        <!-- Fleet Summary -->
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
            <div class="text-sm text-gray-600 dark:text-gray-300">Total Ships</div>
            <div class="text-xl font-bold text-blue-600">#{Map.get(fleet_overview, :total_participants, 0)}</div>
          </div>
          <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
            <div class="text-sm text-gray-600 dark:text-gray-300">Ship Types</div>
            <div class="text-xl font-bold text-green-600">#{Map.get(ship_composition, :unique_ship_types, 0)}</div>
          </div>
          <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
            <div class="text-sm text-gray-600 dark:text-gray-300">Ship Classes</div>
            <div class="text-xl font-bold text-purple-600">#{Map.get(ship_composition, :unique_ship_classes, 0)}</div>
          </div>
        </div>
        
        <!-- Most Common Ships -->
        #{if length(most_common_ships) > 0 do
      """
      <div>
        <h4 class="font-medium text-gray-900 dark:text-white mb-2">Most Common Ships</h4>
        <div class="space-y-2">
          #{Enum.map_join(most_common_ships, "", fn ship ->
        ship_name = Map.get(ship, :ship_name, "Unknown")
        count = Map.get(ship, :count, 0)
        percentage = Map.get(ship, :percentage, 0)
        """
        <div class="bg-white dark:bg-gray-600 p-3 rounded flex justify-between items-center">
          <span class="text-sm font-medium text-gray-900 dark:text-white">#{ship_name}</span>
          <span class="text-sm text-gray-600 dark:text-gray-300">#{count} ships (#{Float.round(percentage, 1)}%)</span>
        </div>
        """
      end)}
        </div>
      </div>
      """
    else
      ""
    end}
        
        <!-- Ship Classes Overview -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-2">Ship Classes</h4>
          <div class="space-y-2">
            #{Enum.map_join(ship_class_breakdown, "", fn {ship_class, data} ->
      count = Map.get(data, :count, 0)
      percentage = Map.get(data, :percentage, 0)
      ship_types = Map.get(data, :ship_types, %{})
      ship_type_text = Enum.map_join(ship_types, ", ", fn {name, count} -> "#{count}x #{name}" end)

      """
      <div class="bg-white dark:bg-gray-600 p-3 rounded">
        <div class="flex justify-between items-center">
          <span class="text-sm font-medium text-gray-900 dark:text-white">#{ship_class}</span>
          <span class="text-sm font-medium text-gray-900 dark:text-white">#{count} ships (#{Float.round(percentage, 1)}%)</span>
        </div>
        #{if ship_type_text != "" and ship_class != "Unknown Class" do
        """
        <div class="text-xs text-gray-600 dark:text-gray-300 mt-1">#{ship_type_text}</div>
        """
      else
        ""
      end}
      </div>
      """
    end)}
          </div>
        </div>
        
        <!-- Fleet Roles -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-2">Fleet Roles</h4>
          <div class="space-y-2">
            #{Enum.map_join(role_breakdown, "", fn {role, data} ->
      count = case data do
        %{count: c} -> c
        c when is_number(c) -> c
        _ -> 0
      end
      percentage = case data do
        %{percentage: p} -> p
        _ -> if Map.get(fleet_overview, :total_participants, 0) > 0, do: count / Map.get(fleet_overview, :total_participants, 1) * 100, else: 0
      end
      role_color = case role do
        :dps -> "text-red-600"
        :heavy_dps -> "text-red-700"
        :logistics -> "text-blue-600"
        :ewar -> "text-purple-600"
        :tackle -> "text-yellow-600"
        :stealth -> "text-gray-500"
        :flexible -> "text-green-600"
        :command -> "text-orange-600"
        :capital_dps -> "text-red-800"
        :capital_support -> "text-blue-800"
        _ -> "text-gray-600"
      end

      """
      <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-2 rounded">
        <span class="text-sm text-gray-700 dark:text-gray-200">#{String.capitalize(to_string(role))}</span>
        <span class="text-sm font-medium #{role_color}">#{count} pilots (#{Float.round(percentage, 1)}%)</span>
      </div>
      """
    end)}
          </div>
        </div>
        
        <!-- Fleet Tactical Insights -->
        #{case Map.get(data || %{}, :composition_summary) do
      %{fleet_insights: insights} when is_list(insights) and length(insights) > 0 -> """
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-2">Tactical Insights</h4>
          <div class="space-y-2">
            #{Enum.map_join(insights, "", fn insight -> """
          <div class="bg-blue-50 dark:bg-blue-900/20 p-3 rounded border-l-4 border-blue-500">
            <p class="text-sm text-blue-800 dark:text-blue-200">#{insight}</p>
          </div>
          """ end)}
          </div>
        </div>
        """
      _ -> ""
    end}
        
      </div>
    </div>
    """
    |> Phoenix.HTML.raw()
  end

  defp render_effectiveness_analysis(data) do
    # Extract the real effectiveness data from the analysis
    effectiveness = Map.get(data || %{}, :effectiveness, %{})

    # Get actual calculated values
    overall_effectiveness = Map.get(effectiveness, :overall_effectiveness, 0)
    dps_rating = Map.get(effectiveness, :dps_rating, 0)
    survivability_rating = Map.get(effectiveness, :survivability_rating, 0)
    flexibility_rating = Map.get(effectiveness, :flexibility_rating, 0)
    fc_capability = Map.get(effectiveness, :fc_capability, false)
    estimated_dps = Map.get(effectiveness, :estimated_dps, 0)
    estimated_ehp = Map.get(effectiveness, :estimated_ehp, 0)
    logistics_ratio = Map.get(effectiveness, :logistics_ratio, 0)
    force_multiplier = Map.get(effectiveness, :force_multiplier, 0)

    """
    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">Fleet Effectiveness Analysis</h3>
      <div class="space-y-6">
        
        <!-- Overall Rating -->
        <div class="text-center bg-white dark:bg-gray-600 p-4 rounded-lg">
          <div class="text-sm text-gray-600 dark:text-gray-300 mb-1">Overall Effectiveness</div>
          <div class="text-3xl font-bold text-indigo-600">#{overall_effectiveness}%</div>
          <div class="text-xs text-gray-500 dark:text-gray-400">Combined fleet performance rating</div>
        </div>
        
        <!-- Combat Capabilities -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-3">Combat Capabilities</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Estimated DPS</div>
              <div class="text-xl font-bold text-red-600">#{estimated_dps |> format_number()}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Total fleet damage per second</div>
            </div>
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Fleet EHP</div>
              <div class="text-xl font-bold text-blue-600">#{estimated_ehp |> format_ehp()}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Total effective hit points</div>
            </div>
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Logistics Coverage</div>
              <div class="text-xl font-bold text-green-600">#{logistics_ratio}%</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Fleet logistics ratio</div>
            </div>
          </div>
        </div>
        
        <!-- Performance Ratings -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-3">Performance Ratings</h4>
          <div class="space-y-3">
            <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
              <span class="text-sm text-gray-700 dark:text-gray-200">DPS Rating</span>
              <div class="flex items-center">
                <div class="w-24 bg-gray-200 dark:bg-gray-500 rounded-full h-2 mr-3">
                  <div class="bg-red-500 h-2 rounded-full" style="width: #{dps_rating}%"></div>
                </div>
                <span class="text-sm font-medium text-gray-900 dark:text-white">#{dps_rating}%</span>
              </div>
            </div>
            <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
              <span class="text-sm text-gray-700 dark:text-gray-200">Survivability</span>
              <div class="flex items-center">
                <div class="w-24 bg-gray-200 dark:bg-gray-500 rounded-full h-2 mr-3">
                  <div class="bg-blue-500 h-2 rounded-full" style="width: #{survivability_rating}%"></div>
                </div>
                <span class="text-sm font-medium text-gray-900 dark:text-white">#{survivability_rating}%</span>
              </div>
            </div>
            <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
              <span class="text-sm text-gray-700 dark:text-gray-200">Flexibility</span>
              <div class="flex items-center">
                <div class="w-24 bg-gray-200 dark:bg-gray-500 rounded-full h-2 mr-3">
                  <div class="bg-green-500 h-2 rounded-full" style="width: #{flexibility_rating}%"></div>
                </div>
                <span class="text-sm font-medium text-gray-900 dark:text-white">#{flexibility_rating}%</span>
              </div>
            </div>
            <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
              <span class="text-sm text-gray-700 dark:text-gray-200">Force Multiplier</span>
              <div class="flex items-center">
                <div class="w-24 bg-gray-200 dark:bg-gray-500 rounded-full h-2 mr-3">
                  <div class="bg-purple-500 h-2 rounded-full" style="width: #{force_multiplier}%"></div>
                </div>
                <span class="text-sm font-medium text-gray-900 dark:text-white">#{force_multiplier}%</span>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Fleet Command -->
        <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-700 dark:text-gray-200">Fleet Command Capability</span>
            <span class="text-sm font-medium #{if fc_capability, do: "text-green-600", else: "text-red-600"}">
              #{if fc_capability, do: "✓ Available", else: "✗ Missing"}
            </span>
          </div>
        </div>
        
      </div>
    </div>
    """
    |> Phoenix.HTML.raw()
  end

  defp render_performance_analysis(data) do
    total_pilots = Map.get(data || %{}, :total_pilots, 0)
    top_performers = Map.get(data || %{}, :top_performers, [])
    survival_rate = Map.get(data || %{}, :survival_rate, 0)
    ship_distribution = Map.get(data || %{}, :ship_distribution, %{})
    performance_stats = Map.get(data || %{}, :performance_stats, %{})

    """
    <div class="bg-gray-50 dark:bg-gray-700 rounded-lg p-6">
      <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-white">Pilot Performance Analysis</h3>
      <div class="space-y-6">
        
        <!-- Performance Overview -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-3">Battle Performance</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Total Pilots</div>
              <div class="text-xl font-bold text-blue-600">#{total_pilots}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Participated in battle</div>
            </div>
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Survival Rate</div>
              <div class="text-xl font-bold text-green-600">#{survival_rate}%</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Pilots who survived</div>
            </div>
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Coordination</div>
              <div class="text-xl font-bold text-purple-600">#{Map.get(performance_stats, :fleet_coordination, 0)}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Fleet coordination score</div>
            </div>
          </div>
        </div>
        
        <!-- Ship Distribution -->
        #{if map_size(ship_distribution) > 0 do
      """
      <div>
        <h4 class="font-medium text-gray-900 dark:text-white mb-3">Ship Distribution</h4>
        <div class="space-y-2">
          #{Enum.map_join(ship_distribution, "", fn {ship_name, count} -> """
        <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
          <span class="text-sm text-gray-700 dark:text-gray-200">#{ship_name}</span>
          <span class="text-sm font-medium text-gray-900 dark:text-white">#{count} pilots</span>
        </div>
        """ end)}
        </div>
      </div>
      """
    else
      ""
    end}
        
        <!-- Top Performers -->
        #{if length(top_performers) > 0 do
      """
      <div>
        <h4 class="font-medium text-gray-900 dark:text-white mb-3">Top Performers</h4>
        <div class="space-y-2">
          #{Enum.map_join(top_performers, "", fn pilot ->
        character_name = Map.get(pilot, :character_name, "Unknown")
        ship_name = Map.get(pilot, :ship_name, "Unknown Ship")
        score = Map.get(pilot, :score, 0)
        survived = Map.get(pilot, :survived, false)
        """
        <div class="flex justify-between items-center bg-white dark:bg-gray-600 p-3 rounded">
          <div class="flex items-center">
            <span class="text-sm text-gray-700 dark:text-gray-200">#{character_name}</span>
            #{if survived do
          "<span class=\"ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 dark:bg-green-900/20 text-green-800 dark:text-green-400\">Survived</span>"
        else
          "<span class=\"ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-red-100 dark:bg-red-900/20 text-red-800 dark:text-red-400\">KIA</span>"
        end}
          </div>
          <div class="text-right">
            <div class="text-sm font-medium text-gray-900 dark:text-white">Score: #{score}</div>
            <div class="text-xs text-gray-500 dark:text-gray-400">#{ship_name}</div>
          </div>
        </div>
        """
      end)}
        </div>
      </div>
      """
    else
      ""
    end}
        
        <!-- Battle Statistics -->
        <div>
          <h4 class="font-medium text-gray-900 dark:text-white mb-3">Battle Statistics</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Average Ship Value</div>
              <div class="text-xl font-bold text-orange-600">#{format_isk(Map.get(performance_stats, :average_ship_value, 0))}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Per pilot investment</div>
            </div>
            <div class="bg-white dark:bg-gray-600 p-4 rounded-lg">
              <div class="text-sm text-gray-600 dark:text-gray-300">Most Common Ship</div>
              <div class="text-xl font-bold text-indigo-600">#{Map.get(performance_stats, :most_common_ship, "Unknown")}</div>
              <div class="text-xs text-gray-500 dark:text-gray-400">Primary fleet doctrine</div>
            </div>
          </div>
        </div>
        
      </div>
    </div>
    """
    |> Phoenix.HTML.raw()
  end

  # Generate a user-friendly fleet ID based on date/time
  defp generate_friendly_fleet_id(battle, _main_fleet) do
    battle_id = Map.get(battle, :battle_id, "")

    # Extract timestamp from battle ID and format as readable date/time
    case String.split(battle_id, "_") do
      ["battle", _system_id, timestamp] ->
        format_battle_datetime(timestamp)

      _ ->
        # Fallback to current time
        DateTime.utc_now() |> DateTime.to_string() |> String.slice(0..18)
    end
  end

  defp format_battle_datetime(timestamp) do
    # Convert YYYYMMDDHHMMSS to "YYYY-MM-DD HH:MM"
    case String.length(timestamp) do
      14 ->
        <<year::binary-4, month::binary-2, day::binary-2, hour::binary-2, minute::binary-2,
          _second::binary-2>> = timestamp

        "#{year}-#{month}-#{day} #{hour}:#{minute}"

      _ ->
        # Fallback
        DateTime.utc_now() |> DateTime.to_string() |> String.slice(0..18)
    end
  end

  # Convert pilot data from battle participants into fleet member format
  # Helper functions for pilot performance calculation
  defp calculate_pilot_score(pilot) do
    base_score = 50
    damage_bonus = min(30, Map.get(pilot, :damage_dealt, 0) / 1000)
    survival_bonus = if Map.get(pilot, :is_victim, false), do: 0, else: 20
    ship_value_bonus = min(20, Map.get(pilot, :ship_value, 0) / 10_000_000)

    score = base_score + damage_bonus + survival_bonus + ship_value_bonus

    %{
      character_name: Map.get(pilot, :character_name, "Unknown"),
      ship_name: Map.get(pilot, :ship_name, "Unknown"),
      score: round(score),
      damage_dealt: Map.get(pilot, :damage_dealt, 0),
      survived: !Map.get(pilot, :is_victim, false)
    }
  end

  defp calculate_average_ship_value(participants) do
    total_value = Enum.sum(Enum.map(participants, &Map.get(&1, :ship_value, 0)))
    if length(participants) > 0, do: round(total_value / length(participants)), else: 0
  end

  defp get_most_common_ship(ship_distribution) do
    case Enum.max_by(ship_distribution, &elem(&1, 1), fn -> {"Unknown", 0} end) do
      {ship_name, _count} -> ship_name
      _ -> "Unknown"
    end
  end

  defp calculate_fleet_coordination_score(participants) do
    # Simple coordination score based on ship diversity and role distribution
    ship_types = participants |> Enum.map(&Map.get(&1, :ship_name)) |> Enum.uniq() |> length()
    total_pilots = length(participants)

    if total_pilots > 0 do
      # Higher diversity = better coordination (up to a point)
      diversity_ratio = min(1.0, ship_types / (total_pilots * 0.3))
      round(diversity_ratio * 100)
    else
      0
    end
  end

  defp calculate_engagement_intensity(participants) do
    # Calculate based on survival rate and ship values
    total_value = Enum.sum(Enum.map(participants, &Map.get(&1, :ship_value, 0)))
    victims = Enum.count(participants, &Map.get(&1, :is_victim, false))

    if length(participants) > 0 do
      risk_factor = victims / length(participants)
      # Normalize to 1B ISK
      value_factor = min(1.0, total_value / 1_000_000_000)
      round((risk_factor + value_factor) * 50)
    else
      0
    end
  end

  defp extract_side_participants(battle, side) do
    try do
      killmails = Map.get(battle, :killmails, [])
      participants = extract_participants_from_killmails(killmails)
      fleet_sides = group_participants_into_sides(participants)

      # Add side_id to fleet sides for compatibility with battle analysis
      fleet_sides_with_ids =
        fleet_sides
        |> Enum.with_index()
        |> Enum.map(fn {fleet_side, index} ->
          Map.put(fleet_side, :side_id, "side_#{index + 1}")
        end)

      require Logger

      Logger.info(
        "Available fleet sides: #{inspect(Enum.map(fleet_sides_with_ids, fn s -> %{group_id: s.group_id, side_id: s.side_id} end))}"
      )

      Logger.info("Looking for side: #{inspect(side)}")

      # Improved side matching with both group_id and side_id
      target_side =
        Enum.find(fleet_sides_with_ids, fn fleet_side ->
          # Try exact side_id match (side_1, side_2, etc.)
          # Try exact group_id match (alliance/corp ID)
          # Try index-based matching (side_1 -> first side, side_2 -> second side)
          Map.get(fleet_side, :side_id) == side or
            to_string(Map.get(fleet_side, :group_id)) == side or
            (side == "side_1" and Map.get(fleet_side, :side_id) == "side_1") or
            (side == "side_2" and Map.get(fleet_side, :side_id) == "side_2")
        end)

      case target_side do
        nil ->
          available_sides =
            Enum.map(fleet_sides_with_ids, fn s ->
              "#{s.side_id} (#{s.group_id})"
            end)

          {:error,
           "Side '#{side}' not found in battle. Available sides: #{inspect(available_sides)}"}

        side_data ->
          Logger.info(
            "Found side data: #{side_data.side_id} with #{length(Map.get(side_data, :pilots, []))} pilots"
          )

          {:ok, Map.get(side_data, :pilots, [])}
      end
    rescue
      error ->
        {:error, "Failed to extract side participants: #{inspect(error)}"}
    end
  end

  defp convert_pilot_to_fleet_member(pilot) do
    ship_type_id = Map.get(pilot, :ship_type_id)
    ship_name = get_ship_name_from_type_id(ship_type_id)

    %{
      character_id: Map.get(pilot, :character_id),
      character_name: Map.get(pilot, :character_name, "Unknown Pilot"),
      # Add missing ship_name field
      ship_name: ship_name,
      ship_type: ship_name,
      ship_type_id: ship_type_id,
      ship_group: get_ship_class(ship_type_id),
      ship_value: estimate_ship_value(ship_type_id),
      fleet_role: determine_fleet_role(pilot),
      is_fleet_commander:
        Map.get(pilot, :role) == :attacker && Map.get(pilot, :final_blow, false),
      role: format_role(Map.get(pilot, :role)),
      ship_category: get_ship_category(ship_type_id),
      # Would need corp lookup
      corporation_name: "Unknown Corp",
      # From this battle
      fleet_ops_attended: 1,
      # Placeholder
      fleet_ops_available: 1,
      # Placeholder
      avg_fleet_duration: 60,
      leadership_roles: if(Map.get(pilot, :final_blow, false), do: 1, else: 0)
    }
  end

  defp get_ship_name_from_type_id(ship_type_id) do
    NameResolver.ship_name(ship_type_id)
  end

  defp estimate_ship_value(ship_type_id) when is_integer(ship_type_id) do
    # Rough ship value estimates in ISK
    case get_ship_class(ship_type_id) do
      "Frigate" -> 400_000
      "Destroyer" -> 1_200_000
      "Cruiser" -> 8_000_000
      "Battlecruiser" -> 45_000_000
      "Battleship" -> 150_000_000
      "Carrier" -> 2_000_000_000
      "Dreadnought" -> 3_500_000_000
      "Titan" -> 120_000_000_000
      _ -> 1_000_000
    end
  end

  defp estimate_ship_value(_), do: 1_000_000

  defp determine_fleet_role(pilot) do
    cond do
      Map.get(pilot, :final_blow, false) -> "FC"
      Map.get(pilot, :role) == :attacker -> "DPS"
      Map.get(pilot, :role) == :victim -> "Victim"
      true -> "DPS"
    end
  end

  defp format_role(role) do
    case role do
      :attacker -> "dps"
      :victim -> "victim"
      _ -> "dps"
    end
  end

  defp get_ship_category(ship_type_id) when is_integer(ship_type_id) do
    get_ship_class(ship_type_id) |> String.downcase()
  end

  defp get_ship_category(_), do: "other"

  defp get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    # More comprehensive ship class detection
    cond do
      # T3 Destroyers (specific IDs)
      ship_type_id in [29_248, 29_984, 29_986, 29_988] -> "T3 Destroyer"
      # Frigates
      ship_type_id in 582..650 -> "Frigate"
      # Regular Destroyers  
      ship_type_id in [16_219, 16_227, 16_236, 16_242] -> "Destroyer"
      ship_type_id in 324..380 -> "Destroyer"
      # Cruisers
      ship_type_id in 620..634 -> "Cruiser"
      # T3 Cruisers (Strategic Cruisers)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> "T3 Cruiser"
      ship_type_id in 11_567..12_034 -> "T3 Cruiser"
      # Battlecruisers
      ship_type_id in 1201..1310 -> "Battlecruiser"
      # Battleships
      ship_type_id in 638..648 -> "Battleship"
      # Capitals
      ship_type_id in 547..554 -> "Carrier"
      ship_type_id in 670..673 -> "Dreadnought"
      ship_type_id in 3514..3518 -> "Titan"
      true -> "Other"
    end
  end

  defp get_ship_class(_), do: "Other"
end
