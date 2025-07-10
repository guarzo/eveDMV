defmodule EveDmv.Contexts.CorporationAnalysis.Infrastructure.ParticipationDataProvider do
  @moduledoc """
  Data provider for corporation participation analysis.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the corporation analysis feature.
  """

  @doc """
  Get participation data for a character over a time period.
  """
  @spec get_participation_data(integer(), DateTime.t(), DateTime.t()) ::
          {:ok, map()} | {:error, term()}
  def get_participation_data(_character_id, _period_start, _period_end) do
    {:ok,
     %{
       fleet_participations: 0,
       operation_participations: 0,
       activity_score: 0.0,
       engagement_rate: 0.0,
       preferred_timezones: []
     }}
  end

  @doc """
  Get corporation member participations over a time period.
  """
  @spec get_corporation_member_participations(integer(), DateTime.t(), DateTime.t()) ::
          {:ok, [map()]} | {:error, term()}
  def get_corporation_member_participations(_corporation_id, _period_start, _period_end) do
    {:ok, []}
  end

  @doc """
  Get all members of a corporation.
  """
  @spec get_corporation_members(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_corporation_members(_corporation_id) do
    {:ok, []}
  end
end
