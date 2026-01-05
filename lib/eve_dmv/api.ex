defmodule EveDmv.Api do
  @moduledoc """
  The main Ash API for the EVE DMV application.

  This API provides the central access point for all core resources and
  standardized CRUD operations with comprehensive error handling and
  type safety.

  ## Core Resources
  - Users and authentication (User, Token, ApiAuthentication)
  - Killmail data (KillmailRaw, Participant)
  - EVE static data (ItemType, SolarSystem, ShipAttributes)
  - Intelligence data (CharacterStats, CharacterProfile)
  - Corporation data (Corporation, Alliance, etc.)

  ## Sub-domains
  - EveDmv.Api.SurveillanceApi - Surveillance resources
  - EveDmv.Api.AnalyticsApi - Analytics resources
  - EveDmv.Api.BattleAnalysisApi - Battle analysis resources

  ## Error Handling
  All functions return standardized `{:ok, result}` or `{:error, reason}` tuples
  for consistent error handling across the application.

  ## Type Safety
  All public functions include comprehensive `@spec` annotations for
  compile-time type checking with Dialyzer.
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
    resource(EveDmv.Contexts.Intelligence.Resources.CharacterProfile)
    # Corporation resources
    resource(EveDmv.Contexts.Corporation.Resources.Alliance)
    resource(EveDmv.Contexts.Corporation.Resources.Corporation)
    resource(EveDmv.Contexts.Corporation.Resources.CorporationMember)
    resource(EveDmv.Contexts.Corporation.Resources.ActivityMetric)
    resource(EveDmv.Contexts.Corporation.Resources.RecruitmentApplication)
    resource(EveDmv.Contexts.Corporation.Resources.MemberPerformanceSnapshot)
    resource(EveDmv.Contexts.Corporation.Resources.MemberActivityLog)
    resource(EveDmv.Contexts.Corporation.Resources.RecruitmentCampaign)

    # Killmail processing resources
    resource(EveDmv.Contexts.KillmailProcessing.Resources.HistoricalFetchStatus)
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
  """
  @spec read!(Ash.Query.t()) :: [Ash.Resource.record()] | Ash.Resource.record()
  def read!(query) do
    Ash.read!(query, domain: __MODULE__)
  end
end
