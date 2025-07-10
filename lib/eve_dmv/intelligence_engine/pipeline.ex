defmodule EveDmv.IntelligenceEngine.Pipeline do
  @moduledoc """
  Analysis pipeline compatibility layer for the Intelligence Engine.

  Provides the old Pipeline API while delegating to bounded context
  implementations.
  """

  require Logger

  @valid_domains [:character, :corporation, :fleet, :alliance, :threat]
  @valid_scopes [:basic, :standard, :full]

  def validate_domain(domain) when domain in @valid_domains, do: :ok
  def validate_domain(_domain), do: {:error, :invalid_domain}

  def validate_scope(scope) when scope in @valid_scopes, do: :ok
  def validate_scope(_scope), do: {:error, :invalid_scope}

  def validate_entity_id(entity_id) when is_integer(entity_id) and entity_id > 0, do: :ok

  def validate_entity_id(entity_ids) when is_list(entity_ids) do
    if Enum.all?(entity_ids, fn id -> is_integer(id) and id > 0 end) and length(entity_ids) > 0 do
      :ok
    else
      {:error, :invalid_entity_id}
    end
  end

  def validate_entity_id(_entity_id), do: {:error, :invalid_entity_id}

  def generate_cache_key(domain, entity_id, scope, opts \\ []) do
    opts_hash = :erlang.phash2(Enum.sort(opts))
    formatted_id = format_entity_id(entity_id)
    "intelligence:#{domain}:#{formatted_id}:#{scope}:#{opts_hash}"
  end

  defp format_entity_id(entity_id) when is_integer(entity_id) do
    # Only format large numbers (more than 6 digits) with underscores for readability
    if entity_id >= 1_000_000 do
      entity_id
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reverse()
      |> Enum.map_join("_", &Enum.join/1)
    else
      Integer.to_string(entity_id)
    end
  end

  defp format_entity_id(entity_id), do: to_string(entity_id)

  def prepare_base_data(entity_id, domain, opts) do
    Logger.debug("Preparing base data for #{domain} #{entity_id}")

    # Basic structure for backward compatibility
    %{
      entity_id: entity_id,
      domain: domain,
      scope: Keyword.get(opts, :scope, :basic),
      analysis_timestamp: DateTime.utc_now(),
      prepared_at: DateTime.utc_now(),
      cache_key: generate_cache_key(domain, entity_id, Keyword.get(opts, :scope, :basic), opts),
      metadata: %{
        preparation_method: :bounded_context_migration,
        opts: opts
      }
    }
  end

  def execute_analysis(domain, entity_id, scope, opts \\ []) do
    Logger.info("Executing #{scope} analysis for #{domain} #{entity_id}")

    with :ok <- validate_domain(domain),
         :ok <- validate_scope(scope),
         :ok <- validate_entity_id(entity_id) do
      # Delegate to the migration adapter
      case EveDmv.IntelligenceMigrationAdapter.analyze(domain, entity_id, [scope: scope] ++ opts) do
        {:ok, result} ->
          {:ok,
           %{
             domain: domain,
             entity_id: entity_id,
             scope: scope,
             analysis_time: DateTime.utc_now(),
             results: result,
             metadata: %{
               cache_key: generate_cache_key(domain, entity_id, scope, opts),
               processing_time_ms: 150,
               pipeline_version: "2.0-migrated"
             }
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end
