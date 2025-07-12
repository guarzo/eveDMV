defmodule EveDmvWeb.Api.BattleShareController do
  @moduledoc """
  API controller for battle sharing functionality.

  Enables users to create shareable battle reports with
  custom metadata, visibility settings, and external links.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.BattleSharing

  @doc """
  POST /api/v1/battles/:id/share

  Creates a shareable battle report.
  """
  def create(conn, %{"id" => battle_id} = params) do
    # In production, get character_id from authenticated user
    creator_id = conn.assigns[:current_user_id] || 12345

    options = [
      title: params["title"],
      description: params["description"],
      video_urls: params["video_urls"] || [],
      visibility: String.to_existing_atom(params["visibility"] || "public"),
      tags: params["tags"] || []
    ]

    case BattleSharing.create_battle_report(battle_id, creator_id, options) do
      {:ok, report} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            report_id: report.report_id,
            share_url: report.share_url,
            visibility: report.visibility,
            created_at: report.created_at
          }
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: %{message: "Failed to create battle report", details: inspect(reason)}})
    end
  end
end
