defmodule EveDmv.Core.Validation.Validators do
  @moduledoc """
  Shared validation functions for use across context APIs.

  Reduces duplicated validation code by providing reusable, well-tested validators.

  ## Usage

      import EveDmv.Core.Validation.Validators

      def create_profile(attrs) do
        with :ok <- validate_string(:name, attrs[:name], min: 3, max: 100),
             :ok <- validate_positive_integer(:entity_id, attrs[:entity_id]),
             :ok <- validate_enum(:entity_type, attrs[:entity_type], [:character, :corporation]) do
          # Create profile...
        end
      end

  ## Error Format

  All validators return either `:ok` or `{:error, {field_name, error_atom}}`.
  This consistent format makes it easy to handle errors upstream.
  """

  @doc """
  Validates a string field with length constraints.

  ## Options

    * `:min` - Minimum length (default: 1)
    * `:max` - Maximum length (default: 255)
    * `:allow_nil` - Allow nil values (default: false)
    * `:trim` - Trim whitespace before validation (default: true)

  ## Examples

      iex> validate_string(:name, "John", min: 2, max: 50)
      :ok

      iex> validate_string(:name, "J", min: 2)
      {:error, {:name, :too_short}}

      iex> validate_string(:name, nil)
      {:error, {:name, :required}}
  """
  @spec validate_string(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_string(field, value, opts \\ []) do
    min = Keyword.get(opts, :min, 1)
    max = Keyword.get(opts, :max, 255)
    allow_nil = Keyword.get(opts, :allow_nil, false)
    trim = Keyword.get(opts, :trim, true)

    cond do
      is_nil(value) and allow_nil ->
        :ok

      is_nil(value) ->
        {:error, {field, :required}}

      not is_binary(value) ->
        {:error, {field, :invalid_type}}

      true ->
        val = if trim, do: String.trim(value), else: value
        len = String.length(val)

        cond do
          val == "" and not allow_nil -> {:error, {field, :empty}}
          len < min -> {:error, {field, :too_short}}
          len > max -> {:error, {field, :too_long}}
          true -> :ok
        end
    end
  end

  @doc """
  Validates a positive integer field.

  ## Options

    * `:allow_nil` - Allow nil values (default: false)
    * `:allow_zero` - Allow zero as a valid value (default: false)

  ## Examples

      iex> validate_positive_integer(:id, 123)
      :ok

      iex> validate_positive_integer(:id, -1)
      {:error, {:id, :must_be_positive}}

      iex> validate_positive_integer(:id, 0)
      {:error, {:id, :must_be_positive}}

      iex> validate_positive_integer(:id, 0, allow_zero: true)
      :ok
  """
  @spec validate_positive_integer(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_positive_integer(field, value, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)
    allow_zero = Keyword.get(opts, :allow_zero, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_integer(value) -> {:error, {field, :invalid_type}}
      value < 0 -> {:error, {field, :must_be_positive}}
      value == 0 and not allow_zero -> {:error, {field, :must_be_positive}}
      true -> :ok
    end
  end

  @doc """
  Validates a non-negative integer field (allows zero).

  Shorthand for `validate_positive_integer(field, value, allow_zero: true)`.

  ## Options

    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_non_negative_integer(:count, 0)
      :ok

      iex> validate_non_negative_integer(:count, -1)
      {:error, {:count, :must_be_non_negative}}
  """
  @spec validate_non_negative_integer(atom(), any(), keyword()) ::
          :ok | {:error, {atom(), atom()}}
  def validate_non_negative_integer(field, value, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_integer(value) -> {:error, {field, :invalid_type}}
      value < 0 -> {:error, {field, :must_be_non_negative}}
      true -> :ok
    end
  end

  @doc """
  Validates a value is one of allowed enum values.

  ## Options

    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_enum(:status, :active, [:active, :pending, :completed])
      :ok

      iex> validate_enum(:status, :invalid, [:active, :pending])
      {:error, {:status, :invalid_value}}
  """
  @spec validate_enum(atom(), any(), [atom()], keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_enum(field, value, allowed, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      value in allowed -> :ok
      true -> {:error, {field, :invalid_value}}
    end
  end

  @doc """
  Validates a map has required keys.

  ## Examples

      iex> validate_required_keys(:criteria, %{name: "x", type: "y"}, [:name, :type])
      :ok

      iex> validate_required_keys(:criteria, %{name: "x"}, [:name, :type])
      {:error, {:criteria, {:missing_keys, [:type]}}}
  """
  @spec validate_required_keys(atom(), map(), [atom()]) :: :ok | {:error, {atom(), any()}}
  def validate_required_keys(field, map, required_keys) when is_map(map) do
    missing = Enum.reject(required_keys, &Map.has_key?(map, &1))

    case missing do
      [] -> :ok
      keys -> {:error, {field, {:missing_keys, keys}}}
    end
  end

  def validate_required_keys(field, _value, _keys), do: {:error, {field, :invalid_type}}

  @doc """
  Validates a list has minimum/maximum items.

  ## Options

    * `:min` - Minimum number of items (default: 0)
    * `:max` - Maximum number of items (default: :infinity)
    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_list(:items, [1, 2, 3], min: 1)
      :ok

      iex> validate_list(:items, [], min: 1)
      {:error, {:items, :too_few_items}}
  """
  @spec validate_list(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_list(field, value, opts \\ []) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_list(value) -> {:error, {field, :invalid_type}}
      length(value) < min -> {:error, {field, :too_few_items}}
      max != :infinity and length(value) > max -> {:error, {field, :too_many_items}}
      true -> :ok
    end
  end

  @doc """
  Validates a list of positive integers.

  Common pattern for character_ids, corporation_ids, etc.

  ## Options

    * `:min` - Minimum number of items (default: 0)
    * `:max` - Maximum number of items (default: :infinity)
    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_integer_list(:character_ids, [123, 456, 789])
      :ok

      iex> validate_integer_list(:character_ids, [123, -1, 789])
      {:error, {:character_ids, :invalid_items}}

      iex> validate_integer_list(:character_ids, [])
      :ok

      iex> validate_integer_list(:character_ids, [], min: 1)
      {:error, {:character_ids, :too_few_items}}
  """
  @spec validate_integer_list(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_integer_list(field, value, opts \\ []) do
    min = Keyword.get(opts, :min, 0)
    max = Keyword.get(opts, :max, :infinity)
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_list(value) -> {:error, {field, :invalid_type}}
      length(value) < min -> {:error, {field, :too_few_items}}
      max != :infinity and length(value) > max -> {:error, {field, :too_many_items}}
      not Enum.all?(value, &(is_integer(&1) and &1 > 0)) -> {:error, {field, :invalid_items}}
      true -> :ok
    end
  end

  @doc """
  Validates a boolean value.

  ## Options

    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_boolean(:active, true)
      :ok

      iex> validate_boolean(:active, "yes")
      {:error, {:active, :invalid_type}}
  """
  @spec validate_boolean(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_boolean(field, value, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      is_boolean(value) -> :ok
      true -> {:error, {field, :invalid_type}}
    end
  end

  @doc """
  Validates a map is present and is indeed a map.

  ## Options

    * `:allow_nil` - Allow nil values (default: false)
    * `:allow_empty` - Allow empty maps (default: true)

  ## Examples

      iex> validate_map(:config, %{key: "value"})
      :ok

      iex> validate_map(:config, %{}, allow_empty: false)
      {:error, {:config, :empty}}

      iex> validate_map(:config, "not a map")
      {:error, {:config, :invalid_type}}
  """
  @spec validate_map(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_map(field, value, opts \\ []) do
    allow_nil = Keyword.get(opts, :allow_nil, false)
    allow_empty = Keyword.get(opts, :allow_empty, true)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_map(value) -> {:error, {field, :invalid_type}}
      map_size(value) == 0 and not allow_empty -> {:error, {field, :empty}}
      true -> :ok
    end
  end

  @doc """
  Validates a numeric value is within a range.

  ## Options

    * `:min` - Minimum value (inclusive)
    * `:max` - Maximum value (inclusive)
    * `:allow_nil` - Allow nil values (default: false)

  ## Examples

      iex> validate_in_range(:limit, 50, min: 1, max: 500)
      :ok

      iex> validate_in_range(:limit, 1000, min: 1, max: 500)
      {:error, {:limit, :out_of_range}}
  """
  @spec validate_in_range(atom(), any(), keyword()) :: :ok | {:error, {atom(), atom()}}
  def validate_in_range(field, value, opts \\ []) do
    min = Keyword.get(opts, :min)
    max = Keyword.get(opts, :max)
    allow_nil = Keyword.get(opts, :allow_nil, false)

    cond do
      is_nil(value) and allow_nil -> :ok
      is_nil(value) -> {:error, {field, :required}}
      not is_number(value) -> {:error, {field, :invalid_type}}
      not is_nil(min) and value < min -> {:error, {field, :out_of_range}}
      not is_nil(max) and value > max -> {:error, {field, :out_of_range}}
      true -> :ok
    end
  end

  @doc """
  Runs multiple validations and collects all errors.

  ## Examples

      iex> validate_all([
      ...>   fn -> validate_string(:name, "x", min: 2) end,
      ...>   fn -> validate_positive_integer(:id, -1) end
      ...> ])
      {:error, [{:name, :too_short}, {:id, :must_be_positive}]}

      iex> validate_all([
      ...>   fn -> validate_string(:name, "John") end,
      ...>   fn -> validate_positive_integer(:id, 123) end
      ...> ])
      :ok
  """
  @spec validate_all([(-> :ok | {:error, any()})]) :: :ok | {:error, [any()]}
  def validate_all(validations) when is_list(validations) do
    errors =
      validations
      |> Enum.map(fn validation -> validation.() end)
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(fn {:error, error} -> error end)

    case errors do
      [] -> :ok
      errs -> {:error, errs}
    end
  end

  @doc """
  Validates optional keyword list options against allowed keys.

  Useful for validating API options like `limit`, `offset`, etc.

  ## Examples

      iex> validate_options(:opts, [limit: 10, offset: 0], [:limit, :offset, :sort])
      :ok

      iex> validate_options(:opts, [invalid_key: true], [:limit, :offset])
      {:error, {:opts, {:invalid_keys, [:invalid_key]}}}
  """
  @spec validate_options(atom(), keyword(), [atom()]) :: :ok | {:error, {atom(), any()}}
  def validate_options(field, opts, allowed_keys) when is_list(opts) do
    provided_keys = Keyword.keys(opts)
    invalid_keys = provided_keys -- allowed_keys

    case invalid_keys do
      [] -> :ok
      keys -> {:error, {field, {:invalid_keys, keys}}}
    end
  end

  def validate_options(field, _opts, _allowed_keys), do: {:error, {field, :invalid_type}}
end
