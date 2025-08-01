defmodule EveDmv.Platform.Utilities.ValidationHelpers do
  @moduledoc """
  Common validation functions and patterns used across the application.

  This module provides standardized validation logic for:
  - EVE Online specific data types
  - Common input validation patterns
  - Business rule validation
  - Data integrity checks
  """

  require Logger

  # EVE Online specific validations

  @doc """
  Validate an EVE character ID.

  Character IDs are integers greater than 90,000,000.
  """
  @spec validate_character_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_character_id(id) when is_integer(id) and id > 90_000_000 do
    {:ok, id}
  end

  def validate_character_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_character_id(parsed_id)
      _ -> {:error, "Invalid character ID format"}
    end
  end

  def validate_character_id(_) do
    {:error, "Character ID must be an integer greater than 90,000,000"}
  end

  @doc """
  Validate an EVE corporation ID.

  Corporation IDs are integers greater than 98,000,000.
  """
  @spec validate_corporation_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_corporation_id(id) when is_integer(id) and id > 98_000_000 do
    {:ok, id}
  end

  def validate_corporation_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_corporation_id(parsed_id)
      _ -> {:error, "Invalid corporation ID format"}
    end
  end

  def validate_corporation_id(_) do
    {:error, "Corporation ID must be an integer greater than 98,000,000"}
  end

  @doc """
  Validate an EVE alliance ID.

  Alliance IDs are integers greater than 99,000,000.
  """
  @spec validate_alliance_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_alliance_id(id) when is_integer(id) and id > 99_000_000 do
    {:ok, id}
  end

  def validate_alliance_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_alliance_id(parsed_id)
      _ -> {:error, "Invalid alliance ID format"}
    end
  end

  def validate_alliance_id(_) do
    {:error, "Alliance ID must be an integer greater than 99,000,000"}
  end

  @doc """
  Validate an EVE solar system ID.

  Solar system IDs are integers between 30,000,000 and 32,000,000.
  """
  @spec validate_system_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_system_id(id) when is_integer(id) and id >= 30_000_000 and id <= 32_000_000 do
    {:ok, id}
  end

  def validate_system_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_system_id(parsed_id)
      _ -> {:error, "Invalid system ID format"}
    end
  end

  def validate_system_id(_) do
    {:error, "System ID must be an integer between 30,000,000 and 32,000,000"}
  end

  @doc """
  Validate an EVE item type ID.

  Item type IDs are positive integers.
  """
  @spec validate_type_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_type_id(id) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  def validate_type_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_type_id(parsed_id)
      _ -> {:error, "Invalid type ID format"}
    end
  end

  def validate_type_id(_) do
    {:error, "Type ID must be a positive integer"}
  end

  @doc """
  Validate a killmail ID.

  Killmail IDs are positive integers.
  """
  @spec validate_killmail_id(any()) :: {:ok, integer()} | {:error, String.t()}
  def validate_killmail_id(id) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  def validate_killmail_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {parsed_id, ""} -> validate_killmail_id(parsed_id)
      _ -> {:error, "Invalid killmail ID format"}
    end
  end

  def validate_killmail_id(_) do
    {:error, "Killmail ID must be a positive integer"}
  end

  # Common input validations

  @doc """
  Validate a required string field.
  """
  @spec validate_required_string(any(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_required_string(value, field_name) when is_binary(value) do
    trimmed = String.trim(value)

    if trimmed == "" do
      {:error, "#{field_name} cannot be empty"}
    else
      {:ok, trimmed}
    end
  end

  def validate_required_string(_, field_name) do
    {:error, "#{field_name} must be a string"}
  end

  @doc """
  Validate string length within bounds.
  """
  @spec validate_string_length(String.t(), integer(), integer()) :: :ok | {:error, String.t()}
  def validate_string_length(value, min_length, max_length) when is_binary(value) do
    length = String.length(value)

    cond do
      length < min_length ->
        {:error, "Must be at least #{min_length} characters long"}

      length > max_length ->
        {:error, "Must be no more than #{max_length} characters long"}

      true ->
        :ok
    end
  end

  def validate_string_length(_, _, _) do
    {:error, "Value must be a string"}
  end

  @doc """
  Validate a positive number.
  """
  @spec validate_positive_number(any()) :: {:ok, number()} | {:error, String.t()}
  def validate_positive_number(value) when is_number(value) and value > 0 do
    {:ok, value}
  end

  def validate_positive_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} when num > 0 -> {:ok, num}
      _ -> {:error, "Must be a positive number"}
    end
  end

  def validate_positive_number(_) do
    {:error, "Must be a positive number"}
  end

  @doc """
  Validate a non-negative number.
  """
  @spec validate_non_negative_number(any()) :: {:ok, number()} | {:error, String.t()}
  def validate_non_negative_number(value) when is_number(value) and value >= 0 do
    {:ok, value}
  end

  def validate_non_negative_number(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} when num >= 0 -> {:ok, num}
      _ -> {:error, "Must be a non-negative number"}
    end
  end

  def validate_non_negative_number(_) do
    {:error, "Must be a non-negative number"}
  end

  @doc """
  Validate a percentage (0-100).
  """
  @spec validate_percentage(any()) :: {:ok, number()} | {:error, String.t()}
  def validate_percentage(value) when is_number(value) and value >= 0 and value <= 100 do
    {:ok, value}
  end

  def validate_percentage(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} when num >= 0 and num <= 100 -> {:ok, num}
      _ -> {:error, "Must be a percentage between 0 and 100"}
    end
  end

  def validate_percentage(_) do
    {:error, "Must be a percentage between 0 and 100"}
  end

  @doc """
  Validate an email address format.
  """
  @spec validate_email(any()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_email(email) when is_binary(email) do
    email_regex = ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/

    if Regex.match?(email_regex, email) do
      {:ok, String.downcase(email)}
    else
      {:error, "Invalid email format"}
    end
  end

  def validate_email(_) do
    {:error, "Email must be a string"}
  end

  @doc """
  Validate a URL format.
  """
  @spec validate_url(any()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme in ["http", "https"] and uri.host do
      {:ok, url}
    else
      {:error, "Invalid URL format"}
    end
  end

  def validate_url(_) do
    {:error, "URL must be a string"}
  end

  # Date and time validations

  @doc """
  Validate a date string in ISO 8601 format.
  """
  @spec validate_date(any()) :: {:ok, Date.t()} | {:error, String.t()}
  def validate_date(%Date{} = date), do: {:ok, date}

  def validate_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Invalid date format. Use YYYY-MM-DD"}
    end
  end

  def validate_date(_) do
    {:error, "Date must be a string or Date struct"}
  end

  @doc """
  Validate a datetime string in ISO 8601 format.
  """
  @spec validate_datetime(any()) :: {:ok, DateTime.t()} | {:error, String.t()}
  def validate_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  def validate_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} -> {:error, "Invalid datetime format. Use ISO 8601"}
    end
  end

  def validate_datetime(_) do
    {:error, "Datetime must be a string or DateTime struct"}
  end

  @doc """
  Validate that a date is not in the future.
  """
  @spec validate_not_future_date(Date.t()) :: :ok | {:error, String.t()}
  def validate_not_future_date(%Date{} = date) do
    today = Date.utc_today()

    if Date.compare(date, today) == :gt do
      {:error, "Date cannot be in the future"}
    else
      :ok
    end
  end

  def validate_not_future_date(_) do
    {:error, "Value must be a Date"}
  end

  # Business rule validations

  @doc """
  Validate that a value is within a list of allowed values.
  """
  @spec validate_inclusion(any(), [any()]) :: {:ok, any()} | {:error, String.t()}
  def validate_inclusion(value, allowed_values) when is_list(allowed_values) do
    if value in allowed_values do
      {:ok, value}
    else
      {:error, "Value must be one of: #{Enum.join(allowed_values, ", ")}"}
    end
  end

  def validate_inclusion(_, _) do
    {:error, "Allowed values must be a list"}
  end

  @doc """
  Validate that a value is not in a list of forbidden values.
  """
  @spec validate_exclusion(any(), [any()]) :: {:ok, any()} | {:error, String.t()}
  def validate_exclusion(value, forbidden_values) when is_list(forbidden_values) do
    if value in forbidden_values do
      {:error, "Value is not allowed"}
    else
      {:ok, value}
    end
  end

  def validate_exclusion(_, _) do
    {:error, "Forbidden values must be a list"}
  end

  @doc """
  Validate a map has required keys.
  """
  @spec validate_required_keys(map(), [atom()]) :: :ok | {:error, String.t()}
  def validate_required_keys(map, required_keys) when is_map(map) and is_list(required_keys) do
    missing_keys = Enum.reject(required_keys, &Map.has_key?(map, &1))

    if Enum.empty?(missing_keys) do
      :ok
    else
      {:error, "Missing required keys: #{Enum.join(missing_keys, ", ")}"}
    end
  end

  def validate_required_keys(_, _) do
    {:error, "First argument must be a map, second must be a list"}
  end

  # Composite validations

  @doc """
  Run multiple validations and return the first error or all results.
  """
  @spec validate_all([{(-> {:ok, any()} | {:error, String.t()}), String.t()}]) ::
          {:ok, [any()]} | {:error, String.t()}
  def validate_all(validations) when is_list(validations) do
    results =
      Enum.reduce_while(validations, [], fn {validator, field_name}, acc ->
        case validator.() do
          {:ok, value} -> {:cont, [value | acc]}
          {:error, error} -> {:halt, {:error, "#{field_name}: #{error}"}}
        end
      end)

    case results do
      {:error, _} = error -> error
      values -> {:ok, Enum.reverse(values)}
    end
  end

  def validate_all(_) do
    {:error, "Validations must be a list of {validator_fn, field_name} tuples"}
  end

  @doc """
  Create a validation function that checks if a value passes all given validators.
  """
  @spec compose_validations([(-> {:ok, any()} | {:error, String.t()})]) :: (-> {:ok, any()}
                                                                               | {:error,
                                                                                  String.t()})
  def compose_validations(validators) when is_list(validators) do
    fn ->
      Enum.reduce_while(validators, {:ok, nil}, fn validator, _acc ->
        case validator.() do
          {:ok, value} -> {:cont, {:ok, value}}
          error -> {:halt, error}
        end
      end)
    end
  end

  # Utility functions

  @doc """
  Sanitize input by removing potentially dangerous characters.
  """
  @spec sanitize_input(String.t()) :: String.t()
  def sanitize_input(input) when is_binary(input) do
    input
    |> String.replace(~r/[<>\"'&]/, "")
    |> String.trim()
  end

  def sanitize_input(_), do: ""

  @doc """
  Log validation errors for debugging.
  """
  @spec log_validation_error(String.t(), any(), String.t()) :: {:error, String.t()}
  def log_validation_error(field_name, value, error_message) do
    Logger.warning("Validation failed", %{
      field: field_name,
      value: inspect(value),
      error: error_message
    })

    {:error, error_message}
  end
end
