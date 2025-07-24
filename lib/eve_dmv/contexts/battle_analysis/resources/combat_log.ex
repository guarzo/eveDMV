defmodule EveDmv.Contexts.BattleAnalysis.Resources.CombatLog do
  @moduledoc """
  Resource for storing uploaded combat logs and their parsed data.
  """

  use Ash.Resource,
    domain: EveDmv.Contexts.BattleAnalysis.Api,
    data_layer: AshPostgres.DataLayer

  require Logger

  postgres do
    table("combat_logs")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Metadata
    attribute(:pilot_name, :string, allow_nil?: false)
    attribute(:uploaded_at, :utc_datetime_usec, allow_nil?: false)
    attribute(:file_name, :string)
    attribute(:file_size, :integer)

    # Time range of the log
    attribute(:start_time, :utc_datetime_usec)
    attribute(:end_time, :utc_datetime_usec)

    # Raw content (compressed)
    attribute(:raw_content, :string, allow_nil?: false)
    # SHA256 of content for deduplication
    attribute(:content_hash, :string, allow_nil?: false)

    # Parsed data
    attribute(:parsed_data, :map, default: %{})
    attribute(:event_count, :integer, default: 0)

    attribute(:parse_status, :atom,
      constraints: [one_of: [:pending, :parsing, :completed, :failed]],
      default: :pending
    )

    attribute(:parse_error, :string)

    # Analysis results
    attribute(:summary, :map, default: %{})
    attribute(:performance_metrics, :map, default: %{})

    # Associated battle (optional)
    attribute(:battle_id, :uuid)
    # How well it matches the battle
    attribute(:battle_correlation, :map, default: %{})

    timestamps()
  end

  actions do
    defaults([:read])

    update :update do
      primary?(true)

      accept([
        :parsed_data,
        :summary,
        :event_count,
        :start_time,
        :end_time,
        :parse_status,
        :parse_error,
        :performance_metrics,
        :battle_correlation
      ])
    end

    create :upload do
      argument(:file_upload, :map, allow_nil?: false)
      argument(:pilot_name, :string, allow_nil?: false)
      argument(:battle_id, :string)

      change(fn changeset, _ ->
        file = Ash.Changeset.get_argument(changeset, :file_upload)

        # Read and compress file content
        {:ok, content} = File.read(file.path)
        compressed = :zlib.compress(content)

        content_hash =
          content
          |> :crypto.hash(:sha256)
          |> Base.encode16(case: :lower)

        changeset
        |> Ash.Changeset.change_attribute(:raw_content, Base.encode64(compressed))
        |> Ash.Changeset.change_attribute(:content_hash, content_hash)
        |> Ash.Changeset.change_attribute(:file_name, file.filename)
        |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
        |> Ash.Changeset.change_attribute(:uploaded_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(
          :pilot_name,
          Ash.Changeset.get_argument(changeset, :pilot_name)
        )
        |> Ash.Changeset.change_attribute(
          :battle_id,
          Ash.Changeset.get_argument(changeset, :battle_id)
        )
      end)
    end

    update :parse do
      require_atomic?(false)
      # Parse the combat log
      change(fn changeset, _ ->
        log = changeset.data

        # Decompress content
        compressed = Base.decode64!(log.raw_content)
        content = :zlib.uncompress(compressed)

        # Parse the log using helper module
        Logger.info("🔍 PARSING COMBAT LOG #{log.id}")

        case EveDmv.Contexts.BattleAnalysis.Domain.CombatLogHelper.parse_combat_log_content(
               content,
               pilot_name: log.pilot_name
             ) do
          {:ok,
           %{
             parsed_data: parsed_data,
             summary: summary,
             event_count: event_count,
             start_time: start_time,
             end_time: end_time
           }} ->
            changeset
            |> Ash.Changeset.change_attribute(:parsed_data, parsed_data)
            |> Ash.Changeset.change_attribute(:summary, summary)
            |> Ash.Changeset.change_attribute(:event_count, event_count)
            |> Ash.Changeset.change_attribute(:start_time, start_time)
            |> Ash.Changeset.change_attribute(:end_time, end_time)
            |> Ash.Changeset.change_attribute(:parse_status, :completed)

          {:error, reason} ->
            changeset
            |> Ash.Changeset.change_attribute(:parse_status, :failed)
            |> Ash.Changeset.change_attribute(:parse_error, inspect(reason))
        end
      end)
    end

    update :analyze_performance do
      require_atomic?(false)
      # Analyze combat performance
      change(fn changeset, _ ->
        log = changeset.data

        if log.parse_status == :completed && log.parsed_data[:events] do
          case EveDmv.Contexts.BattleAnalysis.Domain.CombatLogHelper.analyze_performance_metrics(
                 log.parsed_data,
                 log.pilot_name
               ) do
            {:ok, performance_metrics} ->
              changeset
              |> Ash.Changeset.change_attribute(:performance_metrics, performance_metrics)

            {:error, _reason} ->
              changeset
          end
        else
          changeset
        end
      end)
    end

    update :correlate_with_battle do
      require_atomic?(false)
      argument(:battle, :map, allow_nil?: false)

      change(fn changeset, _ ->
        log = changeset.data
        battle = Ash.Changeset.get_argument(changeset, :battle)

        if log.parse_status == :completed && log.parsed_data[:events] do
          events = log.parsed_data.events

          case EveDmv.Contexts.BattleAnalysis.Domain.CombatLogHelper.correlate_with_battle(
                 events,
                 battle.killmails
               ) do
            {:ok, battle_correlation} ->
              changeset
              |> Ash.Changeset.change_attribute(:battle_correlation, battle_correlation)

            {:error, _reason} ->
              changeset
          end
        else
          changeset
        end
      end)
    end

    destroy(:destroy)
  end

  code_interface do
    define(:upload)
    define(:parse)
    define(:analyze_performance)
    define(:correlate_with_battle)
    define(:read)
    define(:destroy)
  end
end
