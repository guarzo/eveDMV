defmodule EveDmv.Intelligence.Fleet.DoctrineTemplateBuilder do
  @moduledoc """
  Doctrine template building and sizing module for fleet operations.

  Handles the creation and standardization of fleet doctrine templates,
  including size categorization and pilot count calculations.
  """

  @doc """
  Build a standardized doctrine template from raw doctrine parameters.

  Converts role definitions to a standardized format with default values.
  """
  def build_doctrine_template(doctrine_params) do
    roles = doctrine_params["roles"] || %{}

    # Convert role definitions to standardized format
    template =
      Enum.map(roles, fn {role_name, role_config} ->
        {role_name,
         %{
           "required" => role_config["required"] || 1,
           "preferred_ships" => role_config["preferred_ships"] || [],
           "skills_required" => role_config["skills_required"] || [],
           "priority" => role_config["priority"] || 5
         }}
      end)
      |> Enum.into(%{})

    {:ok, template}
  end

  @doc """
  Determine fleet size category based on doctrine template.

  Returns {:ok, category} where category is "small", "medium", or "large".
  """
  def determine_size_category(doctrine_template) do
    total_pilots =
      Enum.map(doctrine_template, fn {_role, config} -> config["required"] || 1 end)
      |> Enum.sum()

    category = categorize_fleet_size(total_pilots)
    {:ok, category}
  end

  @doc """
  Categorize fleet size based on total pilot count.
  """
  def categorize_fleet_size(total_pilots) when total_pilots <= 5, do: "small"
  def categorize_fleet_size(total_pilots) when total_pilots <= 15, do: "medium"
  def categorize_fleet_size(_total_pilots), do: "large"

  @doc """
  Calculate minimum pilots needed for doctrine.

  Returns the absolute minimum pilots needed (all required roles with 1 pilot each).
  """
  def calculate_minimum_pilots(doctrine_template) do
    # Calculate absolute minimum pilots needed (all required roles filled with 1 pilot each)
    doctrine_template
    |> Enum.map(fn {_role, config} -> min(1, config["required"] || 1) end)
    |> Enum.sum()
  end

  @doc """
  Calculate optimal pilot count for doctrine.

  Returns the optimal pilot count (all required roles fully filled).
  """
  def calculate_optimal_pilots(doctrine_template) do
    # Calculate optimal pilot count (all required roles fully filled)
    Enum.map(doctrine_template, fn {_role, config} -> config["required"] || 1 end)
    |> Enum.sum()
  end

  @doc """
  Calculate maximum useful pilots for doctrine.

  Returns the maximum useful pilots (150% of optimal).
  """
  def calculate_maximum_pilots(doctrine_template) do
    # Calculate maximum useful pilots (150% of optimal)
    optimal = calculate_optimal_pilots(doctrine_template)
    round(optimal * 1.5)
  end
end
