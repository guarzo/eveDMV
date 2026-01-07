defmodule EveDmv.Ash.Fragments do
  @moduledoc """
  Reusable SQL fragments for Ash expressions.
  Wraps PostgreSQL-specific functions not natively supported in Ash.

  These macros can be used within Ash filter expressions to access PostgreSQL
  functionality like JSONB operations, timestamp extraction, and array operations.

  ## Usage

      import EveDmv.Ash.Fragments

      # In an Ash query filter:
      Ash.Query.filter(query, jsonb_text(raw_data, ["victim", "character_name"]) == "Some Name")
  """

  @doc """
  Extract text value from JSONB field using PostgreSQL's ->> operator.

  ## Parameters
    - field: The JSONB column
    - path: List of keys to navigate (e.g., ["victim", "character_name"])

  ## Example

      jsonb_text(raw_data, ["victim", "ship_type_id"])
      # Generates: raw_data->'victim'->>'ship_type_id'
  """
  defmacro jsonb_text(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)

    quote do
      fragment(unquote("(?#{path_navigation})"), unquote(field))
    end
  end

  @doc """
  Extract integer value from JSONB field with cast.

  ## Example

      jsonb_int(raw_data, ["victim", "ship_type_id"])
      # Generates: (raw_data->'victim'->>'ship_type_id')::integer
  """
  defmacro jsonb_int(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)

    quote do
      fragment(unquote("(?#{path_navigation})::integer"), unquote(field))
    end
  end

  @doc """
  Extract bigint value from JSONB field with cast.

  Useful for EVE IDs which can exceed integer range.

  ## Example

      jsonb_bigint(raw_data, ["victim", "character_id"])
      # Generates: (raw_data->'victim'->>'character_id')::bigint
  """
  defmacro jsonb_bigint(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)

    quote do
      fragment(unquote("(?#{path_navigation})::bigint"), unquote(field))
    end
  end

  @doc """
  Extract numeric/decimal value from JSONB field with cast.

  ## Example

      jsonb_numeric(raw_data, ["zkb", "totalValue"])
      # Generates: (raw_data->'zkb'->>'totalValue')::numeric
  """
  defmacro jsonb_numeric(field, path) when is_list(path) do
    path_navigation = build_jsonb_path(path)

    quote do
      fragment(unquote("(?#{path_navigation})::numeric"), unquote(field))
    end
  end

  @doc """
  Extract hour from timestamp in UTC timezone.

  ## Example

      extract_hour_utc(killmail_time)
      # Generates: EXTRACT(HOUR FROM killmail_time AT TIME ZONE 'UTC')
  """
  defmacro extract_hour_utc(timestamp_field) do
    quote do
      fragment("EXTRACT(HOUR FROM ? AT TIME ZONE 'UTC')", unquote(timestamp_field))
    end
  end

  @doc """
  Extract day of week from timestamp (0=Sunday, 6=Saturday).

  ## Example

      extract_dow_utc(killmail_time)
      # Generates: EXTRACT(DOW FROM killmail_time AT TIME ZONE 'UTC')
  """
  defmacro extract_dow_utc(timestamp_field) do
    quote do
      fragment("EXTRACT(DOW FROM ? AT TIME ZONE 'UTC')", unquote(timestamp_field))
    end
  end

  @doc """
  Extract date from timestamp.

  ## Example

      extract_date(killmail_time)
      # Generates: killmail_time::date
  """
  defmacro extract_date(timestamp_field) do
    quote do
      fragment("?::date", unquote(timestamp_field))
    end
  end

  @doc """
  Check if JSONB array contains a specific value.

  ## Example

      jsonb_array_contains(raw_data, ["attackers"], "character_id", 123456)
      # Generates: EXISTS (SELECT 1 FROM jsonb_array_elements(raw_data->'attackers') elem
      #            WHERE (elem->>'character_id')::bigint = 123456)
  """
  defmacro jsonb_array_contains(field, array_path, key, value) do
    array_path_str = build_jsonb_arrow_path(array_path)

    quote do
      fragment(
        unquote(
          "EXISTS (SELECT 1 FROM jsonb_array_elements(?#{array_path_str}) elem WHERE (elem->>'#{key}')::bigint = ?)"
        ),
        unquote(field),
        unquote(value)
      )
    end
  end

  @doc """
  Count elements in a JSONB array.

  ## Example

      jsonb_array_length(raw_data, ["attackers"])
      # Generates: COALESCE(jsonb_array_length(raw_data->'attackers'), 0)
  """
  defmacro jsonb_array_length(field, array_path) do
    array_path_str = build_jsonb_arrow_path(array_path)

    quote do
      fragment(
        unquote("COALESCE(jsonb_array_length(?#{array_path_str}), 0)"),
        unquote(field)
      )
    end
  end

  @doc """
  Coalesce a potentially null value with a default.

  ## Example

      coalesce(some_field, 0)
      # Generates: COALESCE(some_field, 0)
  """
  defmacro coalesce(field, default) do
    quote do
      fragment("COALESCE(?, ?)", unquote(field), unquote(default))
    end
  end

  @doc """
  Calculate age in days from a timestamp to now.

  ## Example

      age_in_days(killmail_time)
      # Generates: EXTRACT(DAY FROM NOW() - killmail_time)
  """
  defmacro age_in_days(timestamp_field) do
    quote do
      fragment("EXTRACT(DAY FROM NOW() - ?)", unquote(timestamp_field))
    end
  end

  # Private helper to build JSONB path with -> and ->> operators
  # For path ["a", "b", "c"], builds: ->'a'->'b'->>'c'
  defp build_jsonb_path(path) do
    {leading, [last]} = Enum.split(path, -1)
    leading_path = Enum.map_join(leading, "", fn key -> "->'#{key}'" end)
    "#{leading_path}->>'#{last}'"
  end

  # Build JSONB path with only -> operators (for arrays/objects)
  # For path ["a", "b"], builds: ->'a'->'b'
  defp build_jsonb_arrow_path(path) do
    Enum.map_join(path, "", fn key -> "->'#{key}'" end)
  end
end
