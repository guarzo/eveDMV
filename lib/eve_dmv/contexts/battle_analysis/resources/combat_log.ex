defmodule EveDmv.Contexts.BattleAnalysis.Resources.CombatLog do
  @moduledoc """
  Resource for storing uploaded combat logs and their parsed data.
  """
  
  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer
    
  require Logger
  
  postgres do
    table "combat_logs"
    repo EveDmv.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    # Metadata
    attribute :pilot_name, :string, allow_nil?: false
    attribute :uploaded_at, :utc_datetime_usec, allow_nil?: false
    attribute :file_name, :string
    attribute :file_size, :integer
    
    # Time range of the log
    attribute :start_time, :utc_datetime_usec
    attribute :end_time, :utc_datetime_usec
    
    # Raw content (compressed)
    attribute :raw_content, :string, allow_nil?: false
    attribute :content_hash, :string, allow_nil?: false # SHA256 of content for deduplication
    
    # Parsed data
    attribute :parsed_data, :map, default: %{}
    attribute :event_count, :integer, default: 0
    attribute :parse_status, :atom, constraints: [one_of: [:pending, :parsing, :completed, :failed]], default: :pending
    attribute :parse_error, :string
    
    # Analysis results
    attribute :summary, :map, default: %{}
    attribute :performance_metrics, :map, default: %{}
    
    # Associated battle (optional)
    attribute :battle_id, :string
    attribute :battle_correlation, :map, default: %{} # How well it matches the battle
    
    timestamps()
  end
  
  actions do
    defaults [:read]
    
    update :update do
      primary? true
      accept [:parsed_data, :summary, :event_count, :start_time, :end_time, :parse_status, :parse_error, :performance_metrics, :battle_correlation]
    end
    
    create :upload do
      argument :file_upload, :map, allow_nil?: false
      argument :pilot_name, :string, allow_nil?: false
      argument :battle_id, :string
      
      change fn changeset, _ ->
        file = Ash.Changeset.get_argument(changeset, :file_upload)
        
        # Read and compress file content
        {:ok, content} = File.read(file.path)
        compressed = :zlib.compress(content)
        content_hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
        
        changeset
        |> Ash.Changeset.change_attribute(:raw_content, Base.encode64(compressed))
        |> Ash.Changeset.change_attribute(:content_hash, content_hash)
        |> Ash.Changeset.change_attribute(:file_name, file.filename)
        |> Ash.Changeset.change_attribute(:file_size, byte_size(content))
        |> Ash.Changeset.change_attribute(:uploaded_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:pilot_name, Ash.Changeset.get_argument(changeset, :pilot_name))
        |> Ash.Changeset.change_attribute(:battle_id, Ash.Changeset.get_argument(changeset, :battle_id))
      end
    end
    
    update :parse do
      require_atomic? false
      # Parse the combat log
      change fn changeset, _ ->
        log = changeset.data
        
        # Decompress content
        compressed = Base.decode64!(log.raw_content)
        content = :zlib.uncompress(compressed)
        
        # Parse the log with enhanced parser
        Logger.info("🔍 USING ENHANCED PARSER for combat log #{log.id}")
        case EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log(content, pilot_name: log.pilot_name) do
          {:ok, %{events: events, summary: summary, metadata: metadata, tactical_analysis: tactical_analysis, recommendations: recommendations}} ->
            changeset
            |> Ash.Changeset.change_attribute(:parsed_data, %{
              events: events,
              tactical_analysis: tactical_analysis,
              recommendations: recommendations
            })
            |> Ash.Changeset.change_attribute(:summary, summary)
            |> Ash.Changeset.change_attribute(:event_count, length(events))
            |> Ash.Changeset.change_attribute(:start_time, metadata[:start_time])
            |> Ash.Changeset.change_attribute(:end_time, metadata[:end_time])
            |> Ash.Changeset.change_attribute(:parse_status, :completed)
            
          {:error, reason} ->
            changeset
            |> Ash.Changeset.change_attribute(:parse_status, :failed)
            |> Ash.Changeset.change_attribute(:parse_error, inspect(reason))
        end
      end
    end
    
    update :analyze_performance do
      require_atomic? false
      # Analyze combat performance
      change fn changeset, _ ->
        log = changeset.data
        
        if log.parse_status == :completed && log.parsed_data[:events] do
          events = log.parsed_data.events
          
          # Try to get fitting data for enhanced analysis
          fitting_data = case Ash.read(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting, 
                                      filter: [pilot_name: log.pilot_name],
                                      sort: [updated_at: :desc],
                                      limit: 1) do
            {:ok, [fitting | _]} -> fitting.parsed_fitting
            _ -> nil
          end
          
          # Enhanced performance analysis with fitting correlation
          performance = if fitting_data do
            fitting_analysis = EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.analyze_fitting_vs_usage(events, fitting_data)
            Map.merge(log.parsed_data[:tactical_analysis] || %{}, %{fitting_correlation: fitting_analysis})
          else
            log.parsed_data[:tactical_analysis] || %{}
          end
          
          changeset
          |> Ash.Changeset.change_attribute(:performance_metrics, performance)
        else
          changeset
        end
      end
    end
    
    update :correlate_with_battle do
      require_atomic? false
      argument :battle, :map, allow_nil?: false
      
      change fn changeset, _ ->
        log = changeset.data
        battle = Ash.Changeset.get_argument(changeset, :battle)
        
        if log.parse_status == :completed && log.parsed_data[:events] do
          events = log.parsed_data.events
          correlation = EveDmv.Contexts.BattleAnalysis.Domain.CombatLogParser.correlate_with_killmails(events, battle.killmails)
          
          changeset
          |> Ash.Changeset.change_attribute(:battle_correlation, %{
            killmail_correlations: correlation,
            match_quality: calculate_match_quality(correlation)
          })
        else
          changeset
        end
      end
    end
    
    destroy :destroy
  end
  
  code_interface do
    define :upload
    define :parse
    define :analyze_performance
    define :correlate_with_battle
    define :read
    define :destroy
  end
  
  defp calculate_match_quality(correlations) do
    # Calculate how well the combat log matches the battle
    matched_kills = Enum.count(correlations, fn c -> length(c.combat_events) > 0 end)
    total_kills = length(correlations)
    
    if total_kills > 0 do
      Float.round(matched_kills / total_kills * 100, 1)
    else
      0.0
    end
  end
end