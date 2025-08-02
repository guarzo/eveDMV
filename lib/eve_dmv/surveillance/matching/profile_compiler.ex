defmodule EveDmv.Surveillance.Matching.ProfileCompiler do
  @moduledoc """
  Profile filter compilation module for surveillance matching.

  This module compiles profile filter trees into optimized anonymous functions
  that can be efficiently evaluated against killmail data.
  """

  alias EveDmv.Surveillance.Matching.KillmailFieldExtractor
  require Logger

  @doc """
  Compile a filter tree into an executable function.

  Takes a filter tree structure and returns an anonymous function
  that can be called with a killmail map to evaluate the filter.

  Returns {:ok, function} or {:error, reason}.
  """
  def compile_filter_tree(nil), do: {:ok, fn _ -> true end}

  def compile_filter_tree(filter_tree) when is_map(filter_tree) do
    compiled_fn = compile_node(filter_tree)
    {:ok, compiled_fn}
  rescue
    error ->
      Logger.error("Failed to compile filter tree: #{inspect(error)}")
      {:error, "compilation failed: #{inspect(error)}"}
  end

  def compile_filter_tree(_), do: {:error, "invalid filter tree"}

  @doc """
  Compile a single filter node (rule, and, or).

  Returns an anonymous function for the node.
  """
  def compile_node(%{"type" => "rule"} = rule) do
    compile_rule(rule)
  end

  def compile_node(%{"type" => "and", "children" => children}) when is_list(children) do
    compiled_children = Enum.map(children, &compile_node/1)

    fn killmail ->
      Enum.all?(compiled_children, fn child_fn -> child_fn.(killmail) end)
    end
  end

  def compile_node(%{"type" => "or", "children" => children}) when is_list(children) do
    compiled_children = Enum.map(children, &compile_node/1)

    fn killmail ->
      Enum.any?(compiled_children, fn child_fn -> child_fn.(killmail) end)
    end
  end

  def compile_node(_), do: fn _ -> false end

  @doc """
  Compile a rule node with field, operator, and value.

  Returns an anonymous function that evaluates the rule.
  """
  def compile_rule(%{"field" => field, "operator" => operator, "value" => value}) do
    case compile_operator(operator, field, value) do
      {:ok, compiled_fn} -> compiled_fn
      :error -> fn _ -> false end
    end
  end

  def compile_rule(_), do: fn _ -> false end

  @doc """
  Compile an operator with field and value into an evaluator function.
  """
  def compile_operator(operator, field, value) do
    case operator do
      op when op in ["eq", "ne"] ->
        {:ok, compile_equality_operator(op, field, value)}

      op when op in ["gt", "lt", "gte", "lte"] ->
        {:ok, compile_numeric_operator(op, field, value)}

      op when op in ["in", "not_in"] ->
        {:ok, compile_list_operator(op, field, value)}

      op when op in ["contains_any", "contains_all", "not_contains"] ->
        {:ok, compile_array_operator(op, field, value)}

      _ ->
        :error
    end
  end

  # Equality operators

  defp compile_equality_operator("eq", field, value) do
    fn km -> KillmailFieldExtractor.get_field(km, field) == value end
  end

  defp compile_equality_operator("ne", field, value) do
    fn km -> KillmailFieldExtractor.get_field(km, field) != value end
  end

  # Numeric operators

  defp compile_numeric_operator("gt", field, value) do
    fn km ->
      compare_numeric(
        KillmailFieldExtractor.get_field(km, field),
        value,
        :gt
      )
    end
  end

  defp compile_numeric_operator("lt", field, value) do
    fn km ->
      compare_numeric(
        KillmailFieldExtractor.get_field(km, field),
        value,
        :lt
      )
    end
  end

  defp compile_numeric_operator("gte", field, value) do
    fn km ->
      compare_numeric(
        KillmailFieldExtractor.get_field(km, field),
        value,
        :gte
      )
    end
  end

  defp compile_numeric_operator("lte", field, value) do
    fn km ->
      compare_numeric(
        KillmailFieldExtractor.get_field(km, field),
        value,
        :lte
      )
    end
  end

  # List operators

  defp compile_list_operator("in", field, value) do
    fn km -> KillmailFieldExtractor.get_field(km, field) in value end
  end

  defp compile_list_operator("not_in", field, value) do
    fn km ->
      KillmailFieldExtractor.get_field(km, field) not in value
    end
  end

  # Array operators

  defp compile_array_operator("contains_any", field, value) do
    fn km ->
      field_value = KillmailFieldExtractor.get_field(km, field) || []
      is_list(field_value) and not MapSet.disjoint?(MapSet.new(field_value), MapSet.new(value))
    end
  end

  defp compile_array_operator("contains_all", field, value) do
    fn km ->
      field_value = KillmailFieldExtractor.get_field(km, field) || []
      is_list(field_value) and MapSet.subset?(MapSet.new(value), MapSet.new(field_value))
    end
  end

  defp compile_array_operator("not_contains", field, value) do
    fn km ->
      field_value = KillmailFieldExtractor.get_field(km, field) || []
      is_list(field_value) and MapSet.disjoint?(MapSet.new(field_value), MapSet.new(value))
    end
  end

  # Helper functions

  defp compare_numeric(field_value, target_value, operation) do
    with {field_num, ""} <- Float.parse(to_string(field_value || 0)),
         {target_num, ""} <- Float.parse(to_string(target_value || 0)) do
      case operation do
        :gt -> field_num > target_num
        :lt -> field_num < target_num
        :gte -> field_num >= target_num
        :lte -> field_num <= target_num
      end
    else
      _ -> false
    end
  end
end
