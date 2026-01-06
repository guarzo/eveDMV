defmodule EveDmv.Core.Analysis.DataRequirements do
  @moduledoc """
  Helper functions for analysis modules that require minimum data thresholds.

  Eliminates repeated patterns like:
      if killmail_count < 5, do: {:insufficient_data, 0.0}, else: calculate(...)

  ## Usage

      import EveDmv.Core.Analysis.DataRequirements

      def analyze_gang_patterns(kills, character_ids) do
        with_minimum_killmails(kills, 5, fn valid_kills ->
          calculate_gang_score(valid_kills, character_ids)
        end)
      end

  ## Default Scores

  When data is insufficient, this module returns the `insufficient_data_score`
  from `ThreatConfig` (currently 0.3) by default. You can override this with
  the `default` option.
  """

  alias EveDmv.Contexts.CharacterIntelligence.ThreatConfig

  @doc """
  Wraps a calculation function with minimum data check for lists.

  Returns `{:ok, result}` if the list meets the minimum threshold,
  or `{:insufficient_data, default_score}` otherwise.

  ## Options

    * `:default` - The score to return when data is insufficient (default: ThreatConfig.insufficient_data_score())

  ## Examples

      iex> with_minimum_data([1, 2, 3, 4, 5], 5, fn list -> Enum.sum(list) end)
      {:ok, 15}

      iex> with_minimum_data([1, 2], 5, fn list -> Enum.sum(list) end)
      {:insufficient_data, 0.3}

      iex> with_minimum_data([1, 2], 5, fn list -> Enum.sum(list) end, default: 0.0)
      {:insufficient_data, 0.0}
  """
  @spec with_minimum_data(list(), pos_integer(), (list() -> any()), keyword()) ::
          {:ok, any()} | {:insufficient_data, any()}
  def with_minimum_data(data, minimum, calculate_fn, opts \\ []) when is_list(data) do
    default = Keyword.get(opts, :default, ThreatConfig.insufficient_data_score())

    if length(data) >= minimum do
      {:ok, calculate_fn.(data)}
    else
      {:insufficient_data, default}
    end
  end

  @doc """
  Wraps a calculation function with minimum killmails check.

  Alias for `with_minimum_data/4` with clearer naming for killmail-specific analysis.

  ## Examples

      with_minimum_killmails(killmails, 5, fn kills ->
        calculate_complex_score(kills)
      end)
  """
  @spec with_minimum_killmails(list(), pos_integer(), (list() -> any()), keyword()) ::
          {:ok, any()} | {:insufficient_data, any()}
  def with_minimum_killmails(killmails, minimum, calculate_fn, opts \\ []) do
    with_minimum_data(killmails, minimum, calculate_fn, opts)
  end

  @doc """
  Requires minimum unique entities in a dataset before calculation.

  Counts unique values for the specified key in a list of maps, then runs
  the calculation if the threshold is met.

  ## Examples

      # Require at least 3 unique characters
      require_unique_entities(killmails, :character_id, 3, fn kills ->
        analyze_multi_character_patterns(kills)
      end)
  """
  @spec require_unique_entities(list(map()), atom(), pos_integer(), (list() -> any()), keyword()) ::
          {:ok, any()} | {:insufficient_data, any()}
  def require_unique_entities(data, key, minimum, calculate_fn, opts \\ [])
      when is_list(data) and is_atom(key) do
    default = Keyword.get(opts, :default, ThreatConfig.insufficient_data_score())

    unique_count = data |> Enum.map(&Map.get(&1, key)) |> Enum.uniq() |> length()

    if unique_count >= minimum do
      {:ok, calculate_fn.(data)}
    else
      {:insufficient_data, default}
    end
  end

  @doc """
  Requires minimum data points within a time window.

  Filters data to include only items within the specified time window,
  then checks if the minimum threshold is met.

  ## Options

    * `:default` - The score to return when data is insufficient
    * `:time_field` - The field containing the timestamp (default: :killmail_time)

  ## Examples

      # Require at least 10 killmails from the last 30 days
      require_recent_data(killmails, 30, 10, fn recent_kills ->
        calculate_recent_activity_score(recent_kills)
      end)
  """
  @spec require_recent_data(
          list(map()),
          pos_integer(),
          pos_integer(),
          (list() -> any()),
          keyword()
        ) ::
          {:ok, any()} | {:insufficient_data, any()}
  def require_recent_data(data, days, minimum, calculate_fn, opts \\ []) when is_list(data) do
    default = Keyword.get(opts, :default, ThreatConfig.insufficient_data_score())
    time_field = Keyword.get(opts, :time_field, :killmail_time)

    cutoff = DateTime.utc_now() |> DateTime.add(-days * 86_400, :second)

    recent_data =
      Enum.filter(data, fn item ->
        case Map.get(item, time_field) do
          %DateTime{} = time -> DateTime.compare(time, cutoff) == :gt
          _ -> false
        end
      end)

    if length(recent_data) >= minimum do
      {:ok, calculate_fn.(recent_data)}
    else
      {:insufficient_data, default}
    end
  end

  @doc """
  Validates data meets multiple requirements and runs calculation.

  Combines multiple requirement checks (minimum count, unique entities, etc.)
  into a single operation.

  ## Examples

      validate_and_calculate(killmails, [
        {:minimum_count, 10},
        {:unique_entities, {:ship_type_id, 3}},
        {:recent_data, {30, 5}}
      ], fn validated_kills ->
        calculate_complex_analysis(validated_kills)
      end)
  """
  @spec validate_and_calculate(list(), [{atom(), any()}], (list() -> any()), keyword()) ::
          {:ok, any()} | {:insufficient_data, any()}
  def validate_and_calculate(data, requirements, calculate_fn, opts \\ []) when is_list(data) do
    default = Keyword.get(opts, :default, ThreatConfig.insufficient_data_score())

    validation_result =
      Enum.reduce_while(requirements, {:ok, data}, fn
        {:minimum_count, minimum}, {:ok, current_data} ->
          if length(current_data) >= minimum do
            {:cont, {:ok, current_data}}
          else
            {:halt, {:insufficient_data, default}}
          end

        {:unique_entities, {key, minimum}}, {:ok, current_data} ->
          unique_count = current_data |> Enum.map(&Map.get(&1, key)) |> Enum.uniq() |> length()

          if unique_count >= minimum do
            {:cont, {:ok, current_data}}
          else
            {:halt, {:insufficient_data, default}}
          end

        {:recent_data, {days, minimum}}, {:ok, current_data} ->
          time_field = Keyword.get(opts, :time_field, :killmail_time)
          cutoff = DateTime.utc_now() |> DateTime.add(-days * 86_400, :second)

          recent_data =
            Enum.filter(current_data, fn item ->
              case Map.get(item, time_field) do
                %DateTime{} = time -> DateTime.compare(time, cutoff) == :gt
                _ -> false
              end
            end)

          if length(recent_data) >= minimum do
            {:cont, {:ok, recent_data}}
          else
            {:halt, {:insufficient_data, default}}
          end

        _unknown_requirement, acc ->
          {:cont, acc}
      end)

    case validation_result do
      {:ok, validated_data} -> {:ok, calculate_fn.(validated_data)}
      {:insufficient_data, score} -> {:insufficient_data, score}
    end
  end

  @doc """
  Returns true if the data meets minimum count requirement.

  Useful for guard-like checks in case statements.

  ## Examples

      case has_minimum_data?(killmails, 5) do
        true -> calculate_score(killmails)
        false -> {:insufficient_data, ThreatConfig.insufficient_data_score()}
      end
  """
  @spec has_minimum_data?(list(), pos_integer()) :: boolean()
  def has_minimum_data?(data, minimum) when is_list(data) do
    length(data) >= minimum
  end

  @doc """
  Returns the default insufficient data score from ThreatConfig.

  Convenient shorthand for `ThreatConfig.insufficient_data_score()`.
  """
  @spec default_insufficient_score() :: float()
  def default_insufficient_score do
    ThreatConfig.insufficient_data_score()
  end

  @doc """
  Returns a standardized empty result map for cases with insufficient data.

  Useful when analysis functions need to return a structured result even
  when data is insufficient.

  ## Options

    * `:reason` - The reason for insufficient data (default: :insufficient_data)
    * `:score` - The default score (default: ThreatConfig.insufficient_data_score())

  ## Examples

      def analyze(killmails) when length(killmails) < 5 do
        empty_result(reason: :too_few_killmails)
      end

      # Returns:
      # %{
      #   status: :insufficient_data,
      #   reason: :too_few_killmails,
      #   score: 0.3,
      #   data: %{}
      # }
  """
  @spec empty_result(keyword()) :: map()
  def empty_result(opts \\ []) do
    reason = Keyword.get(opts, :reason, :insufficient_data)
    score = Keyword.get(opts, :score, ThreatConfig.insufficient_data_score())

    %{
      status: :insufficient_data,
      reason: reason,
      score: score,
      data: %{}
    }
  end
end
