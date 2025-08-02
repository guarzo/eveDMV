defmodule EveDmv.Contexts.BattleAnalysis.Api do
  @moduledoc """
  Ash API domain for battle analysis resources.

  This domain manages resources related to combat log analysis,
  ship fittings, and battle correlation functionality.
  """
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    # Core battle analysis resources
    resource(EveDmv.Contexts.BattleAnalysis.Resources.Battle)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleReport)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleReportRating)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.BattleReportComment)

    # Combat log and fitting analysis
    resource(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting)
    # Combat context resources that use this domain
    resource(EveDmv.Contexts.Combat.Resources.Battle)
    resource(EveDmv.Contexts.Combat.Resources.BattleKillmail)
    resource(EveDmv.Contexts.Combat.Resources.CombatLog)
    resource(EveDmv.Contexts.Combat.Resources.ShipFitting)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
