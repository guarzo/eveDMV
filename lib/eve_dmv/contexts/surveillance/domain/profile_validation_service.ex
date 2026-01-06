defmodule EveDmv.Contexts.Surveillance.Domain.ProfileValidationService do
  @moduledoc """
  Validation service for surveillance profile data.

  Centralizes all validation logic for profiles, criteria,
  notifications, and test data structures.
  """

  import EveDmv.Core.Validation.Validators

  @allowed_profile_update_fields [:name, :criteria, :notification_config, :is_active]
  @allowed_notification_types [:email, :webhook, :in_app]

  @typedoc "Error types for profile data validation"
  @type profile_data_error ::
          :invalid_name_type
          | :invalid_criteria_type
          | :invalid_user_id
          | :name_too_short
          | :name_too_long
          | :name_empty
          | {atom(),
             :invalid_type | :required | :must_be_positive | [any(), ...] | {term(), term()}}

  @doc """
  Validate profile data for creation.
  """
  @spec validate_profile_data(map()) :: {:ok, map()} | {:error, profile_data_error()}
  def validate_profile_data(profile_data) do
    with :ok <- validate_required_keys(:profile_data, profile_data, [:name, :criteria, :user_id]),
         :ok <- validate_profile_name(profile_data[:name]),
         :ok <- validate_criteria_structure(profile_data[:criteria]),
         :ok <- validate_positive_integer(:user_id, profile_data[:user_id]) do
      {:ok, profile_data}
    else
      {:error, {:user_id, _}} -> {:error, :invalid_user_id}
      {:error, other} -> {:error, other}
    end
  end

  @doc """
  Validate and filter profile update data.
  """
  @spec validate_profile_updates(map()) :: {:ok, map()} | {:error, term()}
  def validate_profile_updates(updates) do
    filtered_updates = Map.take(updates, @allowed_profile_update_fields)

    with :ok <- validate_update_fields(filtered_updates) do
      {:ok, filtered_updates}
    end
  end

  @doc """
  Validate test data structure.
  """
  @spec validate_test_data(map()) :: {:ok, map()} | {:error, term()}
  def validate_test_data(test_data) do
    with :ok <- validate_map(:test_data, test_data),
         :ok <-
           validate_required_keys(:test_data, test_data, [
             :character_id,
             :corporation_id,
             :ship_type_id
           ]) do
      {:ok, test_data}
    else
      {:error, {:test_data, :invalid_type}} -> {:error, :invalid_test_data_type}
      {:error, {:test_data, :required}} -> {:error, :invalid_test_data_type}
      {:error, {:test_data, {:missing_keys, keys}}} -> {:error, {:missing_fields, keys}}
    end
  end

  @doc """
  Validate notification configuration.
  """
  @spec validate_notification_config(map()) :: {:ok, map()} | {:error, term()}
  def validate_notification_config(config) do
    case validate_map(:notification_config, config) do
      :ok ->
        config_keys = Map.keys(config)
        invalid_keys = Enum.reject(config_keys, fn key -> key in @allowed_notification_types end)

        case invalid_keys do
          [] -> {:ok, config}
          keys -> {:error, {:invalid_notification_types, keys}}
        end

      {:error, _} ->
        {:error, :invalid_notification_config_type}
    end
  end

  # Private validation functions

  defp validate_profile_name(name) do
    case validate_string(:name, name, min: 3, max: 100) do
      :ok -> :ok
      {:error, {:name, :required}} -> {:error, :invalid_name_type}
      {:error, {:name, :invalid_type}} -> {:error, :invalid_name_type}
      {:error, {:name, :too_short}} -> {:error, :name_too_short}
      {:error, {:name, :too_long}} -> {:error, :name_too_long}
      {:error, {:name, :empty}} -> {:error, :name_empty}
    end
  end

  defp validate_criteria_structure(criteria) do
    case validate_map(:criteria, criteria, allow_empty: false) do
      :ok ->
        case validate_required_keys(:criteria, criteria, [:type]) do
          :ok -> :ok
          {:error, {:criteria, {:missing_keys, _}}} -> {:error, {:missing_fields, [:type]}}
        end

      {:error, {:criteria, :invalid_type}} ->
        {:error, :invalid_criteria_type}

      {:error, {:criteria, :required}} ->
        {:error, :invalid_criteria_type}

      {:error, {:criteria, :empty}} ->
        {:error, {:missing_fields, [:type]}}
    end
  end

  defp validate_update_fields(updates) do
    Enum.reduce_while(updates, :ok, fn {field, value}, :ok ->
      case validate_update_field(field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
  end

  defp validate_update_field(:name, name), do: validate_profile_name(name)
  defp validate_update_field(:criteria, criteria), do: validate_criteria_structure(criteria)

  defp validate_update_field(:is_active, active) do
    case validate_boolean(:is_active, active) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_type}
    end
  end

  defp validate_update_field(:notification_config, config) do
    case validate_map(:notification_config, config) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_type}
    end
  end

  defp validate_update_field(field, _value), do: {:error, {:invalid_field, field}}
end
