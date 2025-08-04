defmodule EveDmvWeb.Api.CorporationThreatController do
  @moduledoc """
  API controller for corporation threat assessment.

  Provides comprehensive threat analysis and intelligence
  reports for EVE Online corporations.
  """

  use EveDmvWeb, :controller

  alias EveDmv.Contexts.CorporationIntelligence

  @doc """
  GET /api/v1/corporations/:id/threat_assessment

  Returns comprehensive threat assessment for a corporation.
  """
  def show(conn, %{"id" => corporation_id_str}) do
    corporation_id = String.to_integer(corporation_id_str)

    {:ok, report} = CorporationIntelligence.get_corporation_intelligence_report(corporation_id)
    
    json(conn, %{
      data: %{
        corporation_id: corporation_id,
        threat_level: report.summary.threat_level,
        primary_doctrine: report.summary.primary_doctrine,
        average_member_threat: report.summary.average_member_threat,
        key_capabilities: report.summary.key_capabilities,
        vulnerabilities: report.summary.vulnerabilities,
        recommendations: report.summary.recommendations
      }
    })
  end
end
