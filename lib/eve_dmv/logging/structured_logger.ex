defmodule EveDmv.Logging.StructuredLogger do
  @moduledoc """
  Structured logging utilities for EVE DMV application.

  Provides consistent structured logging patterns for different types of events
  and operations throughout the application.
  """

  require Logger

  @doc """
  Log a security event with structured metadata.
  """
  def log_security_event(event_name, _measurements \\ %{}, metadata \\ %{}) do
    Logger.info("Security event: #{event_name}",
      security_event: event_name,
      user_id: metadata[:user_id],
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      threat_level: metadata[:threat_level] || :info,
      request_id: metadata[:request_id]
    )
  end

  @doc """
  Log a performance event with timing and resource usage.
  """
  def log_performance_event(operation, duration_ms, metadata \\ %{}) do
    Logger.info("Performance: #{operation} completed",
      operation: operation,
      duration_ms: duration_ms,
      memory_usage: metadata[:memory_usage],
      query_time: metadata[:query_time],
      response_time: metadata[:response_time],
      entity_type: metadata[:entity_type],
      entity_id: metadata[:entity_id]
    )
  end

  @doc """
  Log a business event with relevant context.
  """
  def log_business_event(event_name, entity_type, entity_id, metadata \\ %{}) do
    Logger.info("Business event: #{event_name}",
      event: event_name,
      entity_type: entity_type,
      entity_id: entity_id,
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      killmail_id: metadata[:killmail_id],
      battle_id: metadata[:battle_id],
      request_id: metadata[:request_id]
    )
  end

  @doc """
  Log an error with structured context.
  """
  def log_error(message, error, metadata \\ %{}) do
    Logger.error(message,
      error: error,
      exception: metadata[:exception],
      reason: metadata[:reason],
      entity_type: metadata[:entity_type],
      entity_id: metadata[:entity_id],
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      request_id: metadata[:request_id]
    )
  end

  @doc """
  Log a warning with structured context.
  """
  def log_warning(message, metadata \\ %{}) do
    Logger.warning(message,
      entity_type: metadata[:entity_type],
      entity_id: metadata[:entity_id],
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      threat_level: metadata[:threat_level],
      request_id: metadata[:request_id]
    )
  end

  @doc """
  Log a debug message with structured context.
  """
  def log_debug(message, metadata \\ %{}) do
    Logger.debug(message,
      entity_type: metadata[:entity_type],
      entity_id: metadata[:entity_id],
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      operation: metadata[:operation],
      request_id: metadata[:request_id]
    )
  end

  @doc """
  Log a task supervisor event.
  """
  def log_task_event(supervisor, task_id, event, metadata \\ %{}) do
    Logger.info("Task #{event}: #{task_id}",
      supervisor: supervisor,
      task_id: task_id,
      event: event,
      duration_ms: metadata[:duration_ms],
      memory_usage: metadata[:memory_usage],
      priority: metadata[:priority],
      description: metadata[:description]
    )
  end

  @doc """
  Log a database operation with performance metrics.
  """
  def log_database_operation(operation, table, duration_ms, metadata \\ %{}) do
    Logger.debug("Database #{operation} on #{table}",
      operation: operation,
      table: table,
      duration_ms: duration_ms,
      query_time: metadata[:query_time],
      rows_affected: metadata[:rows_affected],
      cache_hit: metadata[:cache_hit]
    )
  end

  @doc """
  Log an API call with request/response details.
  """
  def log_api_call(service, endpoint, status, duration_ms, metadata \\ %{}) do
    Logger.info("API call: #{service} #{endpoint} -> #{status}",
      service: service,
      endpoint: endpoint,
      status: status,
      duration_ms: duration_ms,
      request_id: metadata[:request_id],
      response_size: metadata[:response_size],
      rate_limit_remaining: metadata[:rate_limit_remaining]
    )
  end

  @doc """
  Log a killmail processing event.
  """
  def log_killmail_event(event, killmail_id, metadata \\ %{}) do
    Logger.info("Killmail #{event}: #{killmail_id}",
      event: event,
      killmail_id: killmail_id,
      entity_type: :killmail,
      entity_id: killmail_id,
      character_id: metadata[:character_id],
      corporation_id: metadata[:corporation_id],
      solar_system_id: metadata[:solar_system_id],
      duration_ms: metadata[:duration_ms]
    )
  end

  @doc """
  Log a pipeline event with stage information.
  """
  def log_pipeline_event(pipeline, stage, event, metadata \\ %{}) do
    Logger.info("Pipeline #{pipeline} #{stage}: #{event}",
      pipeline: pipeline,
      stage: stage,
      event: event,
      duration_ms: metadata[:duration_ms],
      batch_size: metadata[:batch_size],
      success_count: metadata[:success_count],
      error_count: metadata[:error_count]
    )
  end
end
