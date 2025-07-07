defmodule EveDmv.Contexts.CombatIntelligence.Infrastructure.KillmailEventProcessor do
  @moduledoc """
  Processes killmail events for combat intelligence analysis.
  """

  use GenServer

  alias EveDmv.Contexts.CombatIntelligence.Domain.CharacterAnalyzer
  alias EveDmv.DomainEvents.KillmailEnriched

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a killmail event for intelligence analysis.
  """
  @spec process_killmail_event(KillmailEnriched.t()) :: :ok
  def process_killmail_event(%KillmailEnriched{} = event) do
    GenServer.cast(__MODULE__, {:process_killmail, event})
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    {:ok, %{processed_count: 0}}
  end

  @impl GenServer
  def handle_cast({:process_killmail, event}, state) do
    Logger.debug("Processing killmail for combat intelligence", %{killmail_id: event.killmail_id})

    # Extract character IDs from the killmail
    character_ids = extract_character_ids(event)

    # Trigger analysis for each character
    Enum.each(character_ids, fn character_id ->
      CharacterAnalyzer.analyze(character_id, %{})
    end)

    {:noreply, %{state | processed_count: state.processed_count + 1}}
  end

  defp extract_character_ids(event) do
    victim_id = get_in(event.victim, [:character_id])

    attacker_ids =
      event.attackers
      |> Enum.map(& &1[:character_id])
      |> Enum.filter(& &1)

    [victim_id | attacker_ids]
    |> Enum.filter(& &1)
    |> Enum.uniq()
  end
end
