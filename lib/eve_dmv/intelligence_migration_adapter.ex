defmodule EveDmv.IntelligenceMigrationAdapter do
  @moduledoc """
  Migration adapter for transitioning from IntelligenceEngine to bounded contexts.

  This adapter provides backwards compatibility during the migration period,
  redirecting calls from the old IntelligenceEngine API to the new bounded
  context implementations.
  """

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
  alias EveDmv.Contexts.CorporationAnalysis.Domain.CorporationAnalyzer
  alias EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer
  alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache

  require Logger

  @doc """
  Analyze an entity using the new bounded context system.

  Maps legacy IntelligenceEngine calls to appropriate bounded contexts.
  """
  def analyze(domain, entity_id, opts \\ []) do
    case domain do
      :character ->
        analyze_character(entity_id, opts)

      :corporation ->
        analyze_corporation(entity_id, opts)

      :fleet ->
        analyze_fleet(entity_id, opts)

      :threat ->
        analyze_threat(entity_id, opts)

      _ ->
        {:error, :unsupported_domain}
    end
  end

  @doc """
  Batch analyze multiple entities.
  """
  def batch_analyze(domain, entity_ids, opts \\ []) when is_list(entity_ids) do
    # Execute batch analysis using Task.async_stream for parallel processing
    results =
      entity_ids
      |> Task.async_stream(
        fn entity_id ->
          {entity_id, analyze(domain, entity_id, opts)}
        end,
        timeout: 30_000,
        max_concurrency: 4
      )
      |> Enum.reduce(%{}, fn {:ok, {entity_id, result}}, acc ->
        Map.put(acc, entity_id, result)
      end)

    {:ok, results}
  end

  @doc """
  Invalidate cached analysis for an entity.

  Routes to appropriate bounded context for cache invalidation.
  """
  def invalidate_cache(domain, entity_id) do
    case domain do
      :character ->
        invalidate_character_cache(entity_id)

      :corporation ->
        invalidate_corporation_cache(entity_id)

      :fleet ->
        invalidate_fleet_cache(entity_id)

      :threat ->
        invalidate_threat_cache(entity_id)

      _ ->
        {:error, :unsupported_domain}
    end
  end

  # Private analysis functions

  defp analyze_character(character_id, opts) do
    scope = Keyword.get(opts, :scope, :standard)
    plugins = Keyword.get(opts, :plugins, get_default_character_plugins(scope))

    try do
      # Run character analysis through Player Profile context
      case PlayerAnalyzer.analyze_character(character_id, scope: scope) do
        {:ok, analysis} ->
          # Transform to legacy format if needed
          legacy_result = transform_to_legacy_format(:character, analysis, plugins)
          {:ok, legacy_result}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Character analysis migration failed: #{inspect(exception)}")
        {:error, {:analysis_failed, exception}}
    end
  end

  defp analyze_corporation(corporation_id, opts) do
    scope = Keyword.get(opts, :scope, :standard)

    try do
      case CorporationAnalyzer.analyze_corporation(corporation_id, scope: scope) do
        {:ok, analysis} ->
          legacy_result = transform_to_legacy_format(:corporation, analysis, [])
          {:ok, legacy_result}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Corporation analysis migration failed: #{inspect(exception)}")
        {:error, {:analysis_failed, exception}}
    end
  end

  defp analyze_fleet(_fleet_id, _opts) do
    # Use Fleet Operations bounded context
    case FleetAnalyzer.analyze_composition(%{participants: []}) do
      {:ok, analysis} ->
        legacy_result = transform_to_legacy_format(:fleet, analysis, [])
        {:ok, legacy_result}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    exception ->
      Logger.error("Fleet analysis migration failed: #{inspect(exception)}")
      {:error, {:analysis_failed, exception}}
  end

  defp analyze_threat(entity_id, opts) do
    entity_type = Keyword.get(opts, :entity_type, :character)

    try do
      case ThreatAnalyzer.assess_threat(entity_id, entity_type) do
        {:ok, analysis} ->
          legacy_result = transform_to_legacy_format(:threat, analysis, [])
          {:ok, legacy_result}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      exception ->
        Logger.error("Threat analysis migration failed: #{inspect(exception)}")
        {:error, {:analysis_failed, exception}}
    end
  end

  # Legacy format transformation

  defp transform_to_legacy_format(domain, analysis, plugins) do
    case domain do
      :character ->
        transform_character_analysis(analysis, plugins)

      :corporation ->
        transform_corporation_analysis(analysis)

      :fleet ->
        transform_fleet_analysis(analysis)

      :threat ->
        transform_threat_analysis(analysis)
    end
  end

  defp transform_character_analysis(analysis, plugins) do
    base_result = %{
      analysis_type: :character,
      timestamp: DateTime.utc_now(),
      plugins_executed: plugins,
      status: :completed
    }

    # Map new analysis format to legacy plugin format
    Enum.reduce(plugins, base_result, fn plugin, acc ->
      case plugin do
        :combat_stats ->
          Map.put(acc, :combat_stats, Map.get(analysis, :combat_analysis, %{}))

        :behavioral_patterns ->
          Map.put(acc, :behavioral_patterns, Map.get(analysis, :behavioral_analysis, %{}))

        :ship_preferences ->
          Map.put(acc, :ship_preferences, Map.get(analysis, :ship_analysis, %{}))

        :threat_assessment ->
          Map.put(acc, :threat_assessment, Map.get(analysis, :threat_analysis, %{}))

        _ ->
          acc
      end
    end)
  end

  defp transform_corporation_analysis(analysis) do
    %{
      analysis_type: :corporation,
      timestamp: DateTime.utc_now(),
      member_activity: Map.get(analysis, :member_activity, %{}),
      fleet_readiness: Map.get(analysis, :fleet_readiness, %{}),
      status: :completed
    }
  end

  defp transform_fleet_analysis(analysis) do
    %{
      analysis_type: :fleet,
      timestamp: DateTime.utc_now(),
      composition_analysis: Map.get(analysis, :composition_analysis, %{}),
      effectiveness_rating: Map.get(analysis, :effectiveness_rating, %{}),
      status: :completed
    }
  end

  defp transform_threat_analysis(analysis) do
    %{
      analysis_type: :threat,
      timestamp: DateTime.utc_now(),
      vulnerability_scan: Map.get(analysis, :vulnerability_scan, %{}),
      risk_assessment: Map.get(analysis, :risk_assessment, %{}),
      status: :completed
    }
  end

  # Plugin configuration

  defp get_default_character_plugins(scope) do
    case scope do
      :basic -> [:combat_stats]
      :standard -> [:combat_stats, :behavioral_patterns, :ship_preferences]
      :full -> [:combat_stats, :behavioral_patterns, :ship_preferences, :threat_assessment]
    end
  end

  @doc """
  Check if the migration adapter should be used for a given domain/entity.
  """
  def should_migrate?(domain, _entity_id) do
    # For now, migrate all domains
    domain in [:character, :corporation, :fleet, :threat]
  end

  @doc """
  Get migration status for monitoring purposes.
  """
  def get_migration_status do
    %{
      adapter_version: "1.0.0",
      supported_domains: [:character, :corporation, :fleet, :threat],
      migration_active: true,
      bounded_contexts_available: check_bounded_contexts_available()
    }
  end

  defp check_bounded_contexts_available do
    %{
      player_profile: function_exported?(PlayerAnalyzer, :analyze_character, 2),
      corporation_analysis: function_exported?(CorporationAnalyzer, :analyze_corporation, 2),
      fleet_operations: function_exported?(FleetAnalyzer, :analyze_composition, 1),
      threat_assessment: function_exported?(ThreatAnalyzer, :assess_threat, 3)
    }
  end

  # Private cache invalidation functions

  defp invalidate_character_cache(character_id) do
    try do
      # Invalidate cache in Combat Intelligence context
      if Code.ensure_loaded?(AnalysisCache) do
        AnalysisCache.invalidate_character(character_id)

        AnalysisCache.invalidate_threat_assessment(character_id)

        AnalysisCache.invalidate_intelligence_scores(character_id)
      end

      # Invalidate cache in Threat Assessment context
      if Code.ensure_loaded?(ThreatCache) do
        ThreatCache.invalidate_entity(
          character_id,
          :character
        )
      end

      Logger.debug("Invalidated character cache for #{character_id}")
      :ok
    rescue
      exception ->
        Logger.error("Failed to invalidate character cache: #{inspect(exception)}")
        {:error, :cache_invalidation_failed}
    end
  end

  defp invalidate_corporation_cache(corporation_id) do
    try do
      # Invalidate cache in Combat Intelligence context
      if Code.ensure_loaded?(AnalysisCache) do
        AnalysisCache.invalidate_corporation(corporation_id)
      end

      # Invalidate cache in Threat Assessment context
      if Code.ensure_loaded?(ThreatCache) do
        ThreatCache.invalidate_entity(
          corporation_id,
          :corporation
        )
      end

      Logger.debug("Invalidated corporation cache for #{corporation_id}")
      :ok
    rescue
      exception ->
        Logger.error("Failed to invalidate corporation cache: #{inspect(exception)}")
        {:error, :cache_invalidation_failed}
    end
  end

  defp invalidate_fleet_cache(fleet_id) do
    try do
      # Fleet operations don't have a dedicated cache yet, so just log for now
      Logger.debug("Fleet cache invalidation requested for #{fleet_id} (no-op)")
      :ok
    rescue
      exception ->
        Logger.error("Failed to invalidate fleet cache: #{inspect(exception)}")
        {:error, :cache_invalidation_failed}
    end
  end

  defp invalidate_threat_cache(entity_id) do
    try do
      # Invalidate cache in Threat Assessment context
      if Code.ensure_loaded?(ThreatCache) do
        ThreatCache.invalidate_entity(
          entity_id,
          :character
        )
      end

      Logger.debug("Invalidated threat cache for #{entity_id}")
      :ok
    rescue
      exception ->
        Logger.error("Failed to invalidate threat cache: #{inspect(exception)}")
        {:error, :cache_invalidation_failed}
    end
  end
end
