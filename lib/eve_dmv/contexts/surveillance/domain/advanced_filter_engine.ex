defmodule EveDmv.Contexts.Surveillance.Domain.AdvancedFilterEngine do
  @moduledoc """
  Advanced filtering engine for complex surveillance profile criteria.

  Supports:
  - Nested filter conditions with complex logic (AND/OR/NOT)
  - Range-based filters (ISK value, distance, time)
  - Proximity filters (system distance, region proximity)
  - Time-based conditions (time of day, day of week, duration since)
  - Performance-optimized evaluation
  """

  alias EveDmv.Intelligence.WandererClient

  @doc """
  Evaluate complex criteria against killmail data.

  Criteria structure:
  %{
    logic_operator: :and | :or,
    conditions: [
      %{
        type: :simple | :nested | :range | :proximity | :temporal,
        logic_operator: :and | :or | :not,
        field: "character_ids" | "isk_value" | "system_distance" | etc,
        operator: :equals | :in | :greater_than | :less_than | :within | :near | :during,
        value: any(),
        nested_conditions: [...] # for nested types
      }
    ]
  }
  """
  def evaluate_complex_criteria(criteria, killmail_data) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = evaluate_condition_group(criteria, killmail_data)
      execution_time = System.monotonic_time(:millisecond) - start_time

      %{
        matches: result.matches,
        matched_conditions: result.matched_conditions,
        execution_time_ms: execution_time,
        performance_metrics: result.performance_metrics
      }
    rescue
      error ->
        %{
          matches: false,
          matched_conditions: [],
          execution_time_ms: System.monotonic_time(:millisecond) - start_time,
          error: Exception.message(error)
        }
    end
  end

  @doc """
  Validate complex criteria structure and logic.
  """
  def validate_complex_criteria(criteria) do
    with :ok <- validate_criteria_structure(criteria),
         :ok <- validate_condition_types(criteria.conditions),
         :ok <- validate_nested_logic(criteria.conditions) do
      {:ok, :valid}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Optimize criteria for performance by reordering conditions.
  """
  def optimize_criteria(criteria) do
    optimized_conditions =
      criteria.conditions
      |> sort_by_performance_cost()
      |> optimize_nested_conditions()
      |> precompute_static_values()

    %{criteria | conditions: optimized_conditions}
  end

  # Private implementation functions

  defp evaluate_condition_group(criteria, killmail_data) do
    logic_operator = Map.get(criteria, :logic_operator, :and)
    conditions = Map.get(criteria, :conditions, [])

    performance_metrics = %{
      conditions_evaluated: 0,
      short_circuits: 0,
      cache_hits: 0
    }

    {matches, matched_conditions, metrics} =
      evaluate_conditions_with_logic(
        conditions,
        killmail_data,
        logic_operator,
        performance_metrics
      )

    %{
      matches: matches,
      matched_conditions: matched_conditions,
      performance_metrics: metrics
    }
  end

  defp evaluate_conditions_with_logic(conditions, killmail_data, :and, metrics) do
    # Short-circuit evaluation for AND logic
    Enum.reduce_while(conditions, {true, [], metrics}, fn condition,
                                                          {_acc_matches, matched, acc_metrics} ->
      {condition_matches, condition_matched, updated_metrics} =
        evaluate_single_condition(condition, killmail_data, acc_metrics)

      if condition_matches do
        {:cont, {true, [condition_matched | matched], updated_metrics}}
      else
        # Short-circuit: if any condition fails in AND, return false
        {:halt, {false, matched, Map.update(updated_metrics, :short_circuits, 0, &(&1 + 1))}}
      end
    end)
  end

  defp evaluate_conditions_with_logic(conditions, killmail_data, :or, metrics) do
    # Short-circuit evaluation for OR logic
    Enum.reduce_while(conditions, {false, [], metrics}, fn condition,
                                                           {_acc_matches, matched, acc_metrics} ->
      {condition_matches, condition_matched, updated_metrics} =
        evaluate_single_condition(condition, killmail_data, acc_metrics)

      if condition_matches do
        # Short-circuit: if any condition succeeds in OR, return true
        {:halt,
         {true, [condition_matched | matched],
          Map.update(updated_metrics, :short_circuits, 0, &(&1 + 1))}}
      else
        {:cont, {false, matched, updated_metrics}}
      end
    end)
  end

  defp evaluate_single_condition(condition, killmail_data, metrics) do
    updated_metrics = Map.update(metrics, :conditions_evaluated, 0, &(&1 + 1))

    case condition.type do
      :simple ->
        result = evaluate_simple_condition(condition, killmail_data)
        {result, condition, updated_metrics}

      :nested ->
        nested_result =
          evaluate_condition_group(
            %{
              logic_operator: condition.logic_operator,
              conditions: condition.nested_conditions
            },
            killmail_data
          )

        {nested_result.matches, condition, updated_metrics}

      :range ->
        result = evaluate_range_condition(condition, killmail_data)
        {result, condition, updated_metrics}

      :proximity ->
        result = evaluate_proximity_condition(condition, killmail_data)
        {result, condition, updated_metrics}

      :temporal ->
        result = evaluate_temporal_condition(condition, killmail_data)
        {result, condition, updated_metrics}

      _ ->
        {false, condition, updated_metrics}
    end
  end

  defp evaluate_simple_condition(condition, killmail_data) do
    field_value = extract_field_value(killmail_data, condition.field)

    case condition.operator do
      :equals ->
        field_value == condition.value

      :in ->
        field_value in condition.value

      :not_in ->
        field_value not in condition.value

      :contains ->
        String.contains?(to_string(field_value), to_string(condition.value))

      :matches_regex ->
        Regex.match?(condition.value, to_string(field_value))

      _ ->
        false
    end
  end

  defp evaluate_range_condition(condition, killmail_data) do
    field_value = extract_field_value(killmail_data, condition.field)

    case condition.operator do
      :between ->
        {min_val, max_val} = condition.value
        numeric_value = to_numeric(field_value)
        numeric_value >= min_val and numeric_value <= max_val

      :greater_than ->
        to_numeric(field_value) > to_numeric(condition.value)

      :less_than ->
        to_numeric(field_value) < to_numeric(condition.value)

      :greater_equal ->
        to_numeric(field_value) >= to_numeric(condition.value)

      :less_equal ->
        to_numeric(field_value) <= to_numeric(condition.value)

      _ ->
        false
    end
  end

  defp evaluate_proximity_condition(condition, killmail_data) do
    case condition.field do
      "system_distance" ->
        evaluate_system_distance(condition, killmail_data)

      "region_proximity" ->
        evaluate_region_proximity(condition, killmail_data)

      "chain_proximity" ->
        evaluate_chain_proximity(condition, killmail_data)

      _ ->
        false
    end
  end

  defp evaluate_temporal_condition(condition, killmail_data) do
    killmail_time = extract_field_value(killmail_data, "killmail_time")

    case condition.field do
      "time_of_day" ->
        hour =
          killmail_time
          |> DateTime.to_time()
          |> Time.to_iso8601()
          |> String.slice(0, 2)
          |> String.to_integer()

        {start_hour, end_hour} = condition.value
        hour >= start_hour and hour <= end_hour

      "day_of_week" ->
        day = Date.day_of_week(DateTime.to_date(killmail_time))
        day in condition.value

      "time_since" ->
        diff_seconds = DateTime.diff(DateTime.utc_now(), killmail_time, :second)

        case condition.operator do
          :within_minutes ->
            diff_seconds <= condition.value * 60

          :within_hours ->
            diff_seconds <= condition.value * 3600

          :within_days ->
            diff_seconds <= condition.value * 86_400

          _ ->
            false
        end

      "recurring_schedule" ->
        evaluate_recurring_schedule(condition, killmail_time)

      _ ->
        false
    end
  end

  defp evaluate_system_distance(condition, killmail_data) do
    killmail_system = extract_field_value(killmail_data, "solar_system_id")
    target_systems = condition.value[:systems] || []
    max_jumps = condition.value[:max_jumps] || 5

    # Check if killmail system is within jump range of any target system
    Enum.any?(target_systems, fn target_system ->
      calculate_system_distance(killmail_system, target_system) <= max_jumps
    end)
  end

  defp evaluate_region_proximity(condition, killmail_data) do
    killmail_system = extract_field_value(killmail_data, "solar_system_id")
    target_regions = condition.value

    # Get system's region and check if it matches
    system_region = get_system_region(killmail_system)
    system_region in target_regions
  end

  defp evaluate_chain_proximity(condition, killmail_data) do
    killmail_system = extract_field_value(killmail_data, "solar_system_id")

    case WandererClient.check_system_in_chain(killmail_system) do
      {:ok, %{in_chain: true, jumps_from_home: jumps}} ->
        max_jumps = condition.value[:max_jumps_from_home] || 10
        jumps <= max_jumps

      _ ->
        false
    end
  end

  defp evaluate_recurring_schedule(condition, killmail_time) do
    schedule = condition.value
    current_time = DateTime.to_time(killmail_time)
    current_day = Date.day_of_week(DateTime.to_date(killmail_time))

    # Check if current time falls within any scheduled time slots
    Enum.any?(schedule, fn slot ->
      day_matches = current_day in slot[:days]

      time_matches =
        Time.compare(current_time, slot[:start_time]) != :lt and
          Time.compare(current_time, slot[:end_time]) != :gt

      day_matches and time_matches
    end)
  end

  # Helper functions

  defp extract_field_value(killmail_data, field) do
    case field do
      "killmail_id" ->
        killmail_data["killmail_id"]

      "solar_system_id" ->
        killmail_data["solar_system_id"]

      "killmail_time" ->
        case DateTime.from_iso8601(killmail_data["killmail_time"]) do
          {:ok, datetime} -> datetime
          {:error, _} -> nil
        end

      "total_value" ->
        killmail_data["zkb"]["totalValue"] || 0

      "victim_character_id" ->
        get_in(killmail_data, ["victim", "character_id"])

      "victim_corporation_id" ->
        get_in(killmail_data, ["victim", "corporation_id"])

      "victim_alliance_id" ->
        get_in(killmail_data, ["victim", "alliance_id"])

      "victim_ship_type_id" ->
        get_in(killmail_data, ["victim", "ship_type_id"])

      "attacker_count" ->
        length(killmail_data["attackers"] || [])

      "points" ->
        killmail_data["zkb"]["points"] || 0

      _ ->
        nil
    end
  end

  defp to_numeric(value) when is_number(value), do: value

  defp to_numeric(value) when is_binary(value) do
    case Integer.parse(value) do
      {int_val, ""} ->
        int_val

      _ ->
        case Float.parse(value) do
          {float_val, ""} -> float_val
          _ -> 0
        end
    end
  end

  defp to_numeric(_), do: 0

  defp calculate_system_distance(system1, system2) do
    # Placeholder for actual jump distance calculation
    # In reality, this would use the EVE static data for system connections
    cond do
      system1 == system2 -> 0
      abs(system1 - system2) <= 10 -> 1
      abs(system1 - system2) <= 100 -> 2
      true -> 5
    end
  end

  defp get_system_region(system_id) do
    # Placeholder for region lookup
    # In reality, this would query the EVE static data
    div(system_id, 1_000_000)
  end

  # Performance optimization functions

  defp sort_by_performance_cost(conditions) do
    # Sort conditions by estimated performance cost (cheapest first)
    Enum.sort_by(conditions, &estimate_condition_cost/1)
  end

  defp estimate_condition_cost(condition) do
    base_cost =
      case condition.type do
        :simple -> 1
        :range -> 2
        :temporal -> 3
        :proximity -> 5
        :nested -> 10
      end

    # Additional cost based on operator complexity
    operator_cost =
      case condition.operator do
        :equals -> 0
        :in -> 1
        :contains -> 2
        :matches_regex -> 5
        :between -> 1
        _ -> 0
      end

    base_cost + operator_cost
  end

  defp optimize_nested_conditions(conditions) do
    Enum.map(conditions, fn condition ->
      if condition.type == :nested do
        optimized_nested = sort_by_performance_cost(condition.nested_conditions)
        %{condition | nested_conditions: optimized_nested}
      else
        condition
      end
    end)
  end

  defp precompute_static_values(conditions) do
    # Precompute regex patterns and other static expensive operations
    Enum.map(conditions, fn condition ->
      if condition.operator == :matches_regex and is_binary(condition.value) do
        compiled_regex = Regex.compile!(condition.value)
        %{condition | value: compiled_regex}
      else
        condition
      end
    end)
  end

  # Validation functions

  defp validate_criteria_structure(criteria) do
    required_fields = [:logic_operator, :conditions]

    if Enum.all?(required_fields, &Map.has_key?(criteria, &1)) do
      :ok
    else
      {:error, "Missing required fields in criteria structure"}
    end
  end

  defp validate_condition_types(conditions) do
    valid_types = [:simple, :nested, :range, :proximity, :temporal]

    invalid_conditions =
      Enum.filter(conditions, fn condition ->
        condition.type not in valid_types
      end)

    if Enum.empty?(invalid_conditions) do
      :ok
    else
      {:error, "Invalid condition types found"}
    end
  end

  defp validate_nested_logic(conditions) do
    # Validate that nested conditions don't create infinite recursion
    max_nesting_depth = 5

    if check_nesting_depth(conditions, 0) <= max_nesting_depth do
      :ok
    else
      {:error, "Nesting depth exceeds maximum allowed (#{max_nesting_depth})"}
    end
  end

  defp check_nesting_depth(conditions, current_depth) do
    Enum.reduce(conditions, current_depth, fn condition, max_depth ->
      if condition.type == :nested do
        nested_depth = check_nesting_depth(condition.nested_conditions, current_depth + 1)
        max(max_depth, nested_depth)
      else
        max_depth
      end
    end)
  end
end
