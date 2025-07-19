defmodule EveDmv.Api.BattleAnalysisApi do
  @moduledoc """
  Ash API for battle analysis-related resources.

  This sub-API handles all battle analysis functionality including combat logs
  and ship fittings to reduce dependencies in the main API.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Contexts.BattleAnalysis.Resources.Battle)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting)
  end

  authorization do
    authorize(:when_requested)
  end
end
