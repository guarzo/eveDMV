defmodule EveDmvWeb.Components.ReusableComponents do
  @moduledoc """
  Core reusable components for EVE DMV.

  Consolidates imports for all reusable components including page headers,
  stats grids, data tables, and various state components.
  """

  defmacro __using__(_) do
    quote do
      import EveDmvWeb.Components.PageHeaderComponent
      import EveDmvWeb.Components.StatsGridComponent
      import EveDmvWeb.Components.DataTableComponent
      import EveDmvWeb.Components.LoadingStateComponent
      import EveDmvWeb.Components.ErrorStateComponent
      import EveDmvWeb.Components.EmptyStateComponent
      import EveDmvWeb.Components.TabNavigationComponent
      import EveDmvWeb.Components.CharacterInfoComponent
      import EveDmvWeb.Components.FormatHelpers
    end
  end

  # Re-export commonly used components for direct import
  defdelegate page_header(assigns), to: EveDmvWeb.Components.PageHeaderComponent
  defdelegate stats_grid(assigns), to: EveDmvWeb.Components.StatsGridComponent
  defdelegate data_table(assigns), to: EveDmvWeb.Components.DataTableComponent
  defdelegate loading_state(assigns), to: EveDmvWeb.Components.LoadingStateComponent
  defdelegate loading_spinner(assigns), to: EveDmvWeb.Components.LoadingStateComponent
  defdelegate error_state(assigns), to: EveDmvWeb.Components.ErrorStateComponent
  defdelegate error_message(assigns), to: EveDmvWeb.Components.ErrorStateComponent
  defdelegate empty_state(assigns), to: EveDmvWeb.Components.EmptyStateComponent
  defdelegate tab_navigation(assigns), to: EveDmvWeb.Components.TabNavigationComponent
  defdelegate character_info(assigns), to: EveDmvWeb.Components.CharacterInfoComponent
  defdelegate character_link(assigns), to: EveDmvWeb.Components.CharacterInfoComponent
end
