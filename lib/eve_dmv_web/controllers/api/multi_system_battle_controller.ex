defmodule EveDmvWeb.Api.MultiSystemBattleController do
  @moduledoc """
  API controller for multi-system battle analysis.

  Provides endpoints for analyzing correlated battles across
  multiple star systems and combat flow patterns.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.BattleAnalysis

  @doc """
  GET /api/v1/battles/:id/multi_system

  Returns multi-system battle correlation data.
  """
  def show(conn, %{"id" => battle_id}) do
    case BattleAnalysis.get_multi_system_battle_chain(battle_id) do
      {:ok, chain} ->
        json(conn, %{
          data: %{
            battle_id: battle_id,
            correlated_battles: chain.correlated_battles,
            combat_flow_pattern: chain.combat_flow_pattern,
            total_systems: length(chain.correlated_battles) + 1
          }
        })

      {:error, :battle_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{message: "Battle not found", code: "BATTLE_NOT_FOUND"}})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: %{message: "Failed to load multi-system data", code: "INTERNAL_ERROR"}})
    end
  end
end
