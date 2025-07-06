# Error Handling Migration Example

This document shows how to migrate an existing analyzer to use the new unified error handling system.

## Before: Using Legacy Error Handling

```elixir
defmodule EveDmv.Intelligence.CharacterAnalyzer do
  use EveDmv.Intelligence.Analyzer

  @impl true
  def analysis_type, do: :character

  @impl true
  def analyze(character_id, opts) do
    try do
      # Validation
      if character_id <= 0 do
        {:error, "Invalid character ID"}
      else
        # Analysis logic
        case fetch_character_data(character_id) do
          {:ok, data} ->
            analysis_result = perform_analysis(data, opts)
            {:ok, analysis_result}
            
          {:error, :not_found} ->
            {:error, "Character not found"}
            
          {:error, :timeout} ->
            {:error, "Request timed out"}
            
          error ->
            {:error, "Unknown error: #{inspect(error)}"}
        end
      end
    rescue
      e ->
        Logger.error("Character analysis failed: #{Exception.message(e)}")
        {:error, "Analysis failed"}
    end
  end

  defp fetch_character_data(character_id) do
    # Some external API call that might fail
    case HTTPoison.get("https://esi.evetech.net/characters/#{character_id}") do
      {:ok, %{status_code: 200, body: body}} ->
        {:ok, Jason.decode!(body)}
      {:ok, %{status_code: 404}} ->
        {:error, :not_found}
      {:error, %HTTPoison.Error{reason: :timeout}} ->
        {:error, :timeout}
      error ->
        {:error, error}
    end
  end

  defp perform_analysis(data, _opts) do
    # Analysis logic here
    %{
      character_name: data["name"],
      analysis_timestamp: DateTime.utc_now(),
      threat_level: calculate_threat_level(data)
    }
  end

  defp calculate_threat_level(_data) do
    # Simplified threat calculation
    :medium
  end
end
```

## After: Using Unified Error Handling

```elixir
defmodule EveDmv.Intelligence.CharacterAnalyzer do
  use EveDmv.Intelligence.AnalyzerV2

  @impl true
  def analysis_type, do: :character

  @impl true  
  def analyze(character_id, opts) do
    # All error handling is now managed by the framework
    with {:ok, data} <- fetch_character_data(character_id),
         {:ok, analysis_result} <- perform_analysis(data, opts) do
      Result.ok(analysis_result)
    end
  end

  @impl true
  def validate_params(character_id, opts) do
    cond do
      character_id <= 0 ->
        {:error, "Character ID must be positive"}
      
      Map.get(opts, :invalid_option) ->
        {:error, "Invalid option provided"}
        
      true ->
        :ok
    end
  end

  # Custom error handling for this analyzer
  @impl EveDmv.ErrorHandler
  def handle_error(error, context) do
    case error.code do
      :character_not_found ->
        # Create fallback analysis for unknown characters
        fallback_analysis = %{
          character_id: context.entity_id,
          analysis_type: :character,
          status: :unknown_character,
          threat_level: :unknown,
          timestamp: DateTime.utc_now()
        }
        {:fallback, fallback_analysis}
        
      :esi_timeout ->
        # Retry with exponential backoff
        {:retry, 2000}
        
      :esi_rate_limited ->
        # Wait longer for rate limits
        {:retry, 10_000}
        
      _ ->
        # Use default error handling
        super(error, context)
    end
  end

  defp fetch_character_data(character_id) do
    # Use Result.safely to convert exceptions to errors
    Result.safely(fn ->
      case HTTPoison.get("https://esi.evetech.net/characters/#{character_id}") do
        {:ok, %{status_code: 200, body: body}} ->
          Result.ok(Jason.decode!(body))
          
        {:ok, %{status_code: 404}} ->
          Result.error(:character_not_found, "Character #{character_id} not found")
          
        {:ok, %{status_code: 429}} ->
          Result.error(:esi_rate_limited, "ESI rate limit exceeded")
          
        {:error, %HTTPoison.Error{reason: :timeout}} ->
          Result.error(:esi_timeout, "ESI request timed out")
          
        {:error, %HTTPoison.Error{reason: reason}} ->
          Result.error(:esi_api_error, "ESI API error: #{inspect(reason)}")
          
        error ->
          Result.error(:unknown_error, "Unexpected error: #{inspect(error)}")
      end
    end)
    |> Result.flat_map(&Function.identity/1)
  end

  defp perform_analysis(data, opts) do
    # Enhanced analysis with better error handling
    try do
      threat_level = calculate_threat_level(data)
      
      analysis_result = %{
        character_name: data["name"],
        character_id: data["character_id"],
        analysis_timestamp: DateTime.utc_now(),
        threat_level: threat_level,
        confidence: calculate_confidence(data, opts),
        metadata: %{
          esi_data_version: data["version"] || "unknown",
          analysis_version: "2.0"
        }
      }
      
      Result.ok(analysis_result)
    rescue
      KeyError ->
        Result.error(:malformed_data, "Required fields missing from ESI response")
      ArgumentError ->
        Result.error(:invalid_data, "Invalid data format in ESI response")
    end
  end

  defp calculate_threat_level(data) do
    # Enhanced threat calculation with error handling
    case data do
      %{"security_status" => security} when security < -5.0 -> :high
      %{"security_status" => security} when security < 0.0 -> :medium
      %{"security_status" => _} -> :low
      _ -> :unknown
    end
  end

  defp calculate_confidence(data, opts) do
    base_confidence = if Map.has_key?(data, "security_status"), do: 0.8, else: 0.3
    
    # Adjust confidence based on options
    case Map.get(opts, :analysis_depth, :normal) do
      :shallow -> base_confidence * 0.7
      :normal -> base_confidence
      :deep -> base_confidence * 1.2
    end
  end
end
```

## Key Changes

### 1. **Import New Modules**
```elixir
# Before
use EveDmv.Intelligence.Analyzer

# After  
use EveDmv.Intelligence.AnalyzerV2
```

### 2. **Return Result Types**
```elixir
# Before
{:ok, result} | {:error, string}

# After
Result.ok(result) | Result.error(code, message, opts)
```

### 3. **Enhanced Error Codes**
```elixir
# Before
{:error, "Character not found"}

# After
Result.error(:character_not_found, "Character #{character_id} not found")
```

### 4. **Custom Error Handling**
```elixir
# Before - Manual try/rescue everywhere
try do
  # operation
rescue
  e -> {:error, "Failed"}
end

# After - Declarative error handling
@impl EveDmv.ErrorHandler
def handle_error(error, context) do
  case error.code do
    :character_not_found -> {:fallback, default_value()}
    :esi_timeout -> {:retry, 2000}
    _ -> {:propagate, error}
  end
end
```

### 5. **Better Error Context**
```elixir
# Before - Limited error information
{:error, "Request failed"}

# After - Rich error context
Result.error(:esi_api_error, "ESI request failed", 
  context: %{character_id: character_id, endpoint: "/characters/"},
  details: %{status_code: 500, response_time_ms: 30000}
)
```

## Usage Examples

### Basic Analysis
```elixir
# Old way
{:ok, analysis} = CharacterAnalyzer.analyze_with_telemetry(123456)

# New way with enhanced error handling
{:ok, analysis} = CharacterAnalyzer.analyze_with_error_handling(123456)
```

### Batch Analysis
```elixir
# New capability - batch processing with error aggregation
{:ok, %{successes: successes, failures: failures}} = 
  CharacterAnalyzer.batch_analyze([123456, 789012, 345678])
```

### Error Handling
```elixir
# Errors are now structured and actionable
case CharacterAnalyzer.analyze_with_error_handling(123456) do
  {:ok, analysis} -> 
    # Handle success
    
  {:error, %EveDmv.Error{code: :character_not_found}} ->
    # Handle specific error type
    
  {:error, %EveDmv.Error{code: :esi_timeout} = error} ->
    # Could retry with: Result.retry(fn -> CharacterAnalyzer.analyze(...) end)
    
  {:error, error} ->
    # Handle any other error with user-friendly message
    message = EveDmv.Error.user_message(error)
    {:error, message}
end
```

## Benefits of Migration

1. **Consistent Error Handling**: All errors follow the same structure
2. **Better Error Context**: Errors include debugging information
3. **Automatic Retries**: Transient failures are automatically retried
4. **Fallback Values**: Graceful degradation for non-critical errors
5. **Enhanced Telemetry**: Better error tracking and monitoring
6. **User-Friendly Messages**: Consistent error messages for end users
7. **Batch Processing**: Built-in support for batch operations with error aggregation
8. **Type Safety**: Result types make error handling explicit