defmodule EveDmv.Api do
  @moduledoc """
  The main Ash API for the EVE PvP Tracker application.

  This API contains core resources needed for the application's primary
  functionality. Additional specialized resources are managed through
  focused sub-domains to reduce complexity and dependencies.

  Sub-domains:
  - EveDmv.Api.SurveillanceApi - Surveillance resources
  - EveDmv.Api.AnalyticsApi - Analytics resources
  - EveDmv.Api.BattleAnalysisApi - Battle analysis resources
  """

  use Ash.Domain,
    otp_app: :eve_dmv,
    default_read_preparations: &default_read_preparations/0

  # Core application resources only
  resources do
    # Essential user and authentication
    resource(EveDmv.Users.Account)
    resource(EveDmv.Users.User)
    resource(EveDmv.Users.Token)
    resource(EveDmv.Security.ApiAuthentication)

    # Primary killmail data
    resource(EveDmv.Killmails.KillmailRaw)
    # REMOVED: KillmailEnriched - see /docs/architecture/enriched-raw-analysis.md
    resource(EveDmv.Killmails.Participant)

    # Battle analysis resources moved to dedicated domain
    # See: EveDmv.Contexts.BattleAnalysis.Api

    # Essential EVE static data
    resource(EveDmv.Eve.ItemType)
    resource(EveDmv.Eve.SolarSystem)
    resource(EveDmv.StaticData.ShipAttributes)

    # Core intelligence resources
    resource(EveDmv.Intelligence.CharacterStats)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end

  # Global query safety configuration
  # Apply default query limits to all read actions
  @doc false
  def default_read_preparations do
    [
      {EveDmv.Ash.Preparations.QuerySafety, [limit: 1000]}
    ]
  end

  @doc """
  Executes a read query against this domain and returns the result or raises an error.

  This function provides a convenient wrapper around Ash.read!/2 that automatically
  passes this domain as the target.

  ## Parameters
  - `query` - An Ash query struct or queryable resource

  ## Returns
  - The query results on success
  - Raises an error on failure

  ## Examples
      iex> KillmailRaw |> Ash.Query.limit(10) |> Api.read!()
      [%KillmailRaw{}, ...]

      iex> Api.read!(KillmailRaw)
      [%KillmailRaw{}, ...]
  """
  def read!(query) do
    Ash.read!(query, domain: __MODULE__)
  end
end
