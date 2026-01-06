defmodule EveDmv.Contexts.FleetOperations.Domain.FleetValidationService do
  @moduledoc """
  Validation service for fleet operations data.

  Centralizes all validation logic for fleet data, doctrines,
  engagements, and related structures.
  """

  alias EveDmv.Core.Utils.ValidationUtils

  @valid_roles [:dps, :logistics, :tackle, :ewar, :command, :support]
  @allowed_doctrine_update_fields [
    :name,
    :description,
    :ship_requirements,
    :role_requirements,
    :optional_ships,
    :mass_limits,
    :is_active
  ]

  @typedoc "Error types for fleet data validation"
  @type fleet_error ::
          :no_participants
          | :invalid_participants_type
          | {:missing_fields, [atom(), ...]}
          | {:invalid_participants, term()}

  @typedoc "Error types for engagement data validation"
  @type engagement_error ::
          :no_participants
          | :no_killmails
          | :invalid_participants_type
          | :invalid_killmails_type
          | {:missing_fields, [atom(), ...]}
          | {:invalid_participants, term()}
          | {:invalid_killmails, term()}

  @doc """
  Validate fleet data structure.
  """
  @spec validate_fleet_data(map()) :: {:ok, map()} | {:error, fleet_error()}
  def validate_fleet_data(fleet_data) do
    required_fields = [:participants]

    with :ok <- ValidationUtils.validate_required_fields(fleet_data, required_fields),
         :ok <- validate_participants(fleet_data.participants) do
      {:ok, fleet_data}
    end
  end

  @doc """
  Validate engagement data structure.
  """
  @spec validate_engagement_data(map()) :: {:ok, map()} | {:error, engagement_error()}
  def validate_engagement_data(engagement_data) do
    required_fields = [:engagement_id, :participants, :killmails]

    with :ok <- ValidationUtils.validate_required_fields(engagement_data, required_fields),
         :ok <- validate_participants(engagement_data.participants),
         :ok <- validate_killmails(engagement_data.killmails) do
      {:ok, engagement_data}
    end
  end

  @doc """
  Validate doctrine data structure for creation.
  """
  @spec validate_doctrine_data(map()) :: {:ok, map()} | {:error, term()}
  def validate_doctrine_data(doctrine_data) do
    required_fields = [:name, :ship_requirements, :role_requirements]

    with :ok <- ValidationUtils.validate_required_fields(doctrine_data, required_fields),
         :ok <- validate_doctrine_name(doctrine_data.name),
         :ok <- validate_ship_requirements(doctrine_data.ship_requirements),
         :ok <- validate_role_requirements(doctrine_data.role_requirements) do
      {:ok, doctrine_data}
    end
  end

  @doc """
  Validate and filter doctrine update data.
  """
  @spec validate_doctrine_updates(map()) :: {:ok, map()} | {:error, term()}
  def validate_doctrine_updates(updates) do
    filtered_updates = Map.take(updates, @allowed_doctrine_update_fields)

    with :ok <- validate_update_fields(filtered_updates) do
      {:ok, filtered_updates}
    end
  end

  # Private validation functions

  defp validate_participants(participants) when is_list(participants) do
    if Enum.empty?(participants) do
      {:error, :no_participants}
    else
      case validate_participant_structure(participants) do
        :ok -> :ok
        {:error, reason} -> {:error, {:invalid_participants, reason}}
      end
    end
  end

  defp validate_participants(_), do: {:error, :invalid_participants_type}

  defp validate_participant_structure(participants) do
    Enum.reduce_while(participants, :ok, fn participant, :ok ->
      required_participant_fields = [:character_id, :ship_type_id]

      case ValidationUtils.validate_required_fields(participant, required_participant_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_killmails(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      {:error, :no_killmails}
    else
      case validate_killmail_structure(killmails) do
        :ok -> :ok
        {:error, reason} -> {:error, {:invalid_killmails, reason}}
      end
    end
  end

  defp validate_killmails(_), do: {:error, :invalid_killmails_type}

  defp validate_killmail_structure(killmails) do
    Enum.reduce_while(killmails, :ok, fn killmail, :ok ->
      required_killmail_fields = [:killmail_id, :victim, :attackers]

      case ValidationUtils.validate_required_fields(killmail, required_killmail_fields) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_doctrine_name(name) when is_binary(name) do
    cond do
      String.length(name) < 3 -> {:error, :name_too_short}
      String.length(name) > 50 -> {:error, :name_too_long}
      String.trim(name) == "" -> {:error, :name_empty}
      not Regex.match?(~r/^[a-zA-Z0-9\s\-_]+$/, name) -> {:error, :invalid_name_characters}
      true -> :ok
    end
  end

  defp validate_doctrine_name(_), do: {:error, :invalid_name_type}

  defp validate_ship_requirements(ship_requirements) when is_map(ship_requirements) do
    if map_size(ship_requirements) == 0 do
      {:error, :no_ship_requirements}
    else
      Enum.reduce_while(ship_requirements, :ok, fn {ship_type_id, requirement}, :ok ->
        case validate_ship_requirement(ship_type_id, requirement) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, {ship_type_id, reason}}}
        end
      end)
    end
  end

  defp validate_ship_requirements(_), do: {:error, :invalid_ship_requirements_type}

  defp validate_ship_requirement(ship_type_id, requirement)
       when is_integer(ship_type_id) and is_map(requirement) do
    required_fields = [:min_count]

    with :ok <- ValidationUtils.validate_required_fields(requirement, required_fields),
         :ok <- validate_min_count(requirement.min_count) do
      :ok
    end
  end

  defp validate_ship_requirement(_ship_type_id, _requirement),
    do: {:error, :invalid_requirement_structure}

  defp validate_role_requirements(role_requirements) when is_map(role_requirements) do
    Enum.reduce_while(role_requirements, :ok, fn {role, requirement}, :ok ->
      cond do
        role not in @valid_roles -> {:halt, {:error, {:invalid_role, role}}}
        not is_map(requirement) -> {:halt, {:error, {:invalid_role_requirement, role}}}
        true -> {:cont, :ok}
      end
    end)
  end

  defp validate_role_requirements(_), do: {:error, :invalid_role_requirements_type}

  defp validate_min_count(count) when is_integer(count) and count >= 0, do: :ok
  defp validate_min_count(_), do: {:error, :invalid_min_count}

  defp validate_update_fields(updates) do
    Enum.reduce_while(updates, :ok, fn {field, value}, :ok ->
      case validate_update_field(field, value) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, {field, reason}}}
      end
    end)
  end

  defp validate_update_field(:name, name), do: validate_doctrine_name(name)
  defp validate_update_field(:description, desc) when is_binary(desc), do: :ok
  defp validate_update_field(:ship_requirements, reqs), do: validate_ship_requirements(reqs)
  defp validate_update_field(:role_requirements, reqs), do: validate_role_requirements(reqs)
  defp validate_update_field(:optional_ships, ships) when is_list(ships), do: :ok
  defp validate_update_field(:mass_limits, limits) when is_map(limits), do: :ok
  defp validate_update_field(:is_active, active) when is_boolean(active), do: :ok
  defp validate_update_field(field, _value), do: {:error, {:invalid_field, field}}
end
