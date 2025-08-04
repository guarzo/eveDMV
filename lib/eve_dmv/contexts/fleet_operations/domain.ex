defmodule EveDmv.Contexts.FleetOperations.Domain do
  @moduledoc """
  Ash domain for Fleet Operations resources.

  Manages fleet doctrines and related fleet management functionality.
  """

  use Ash.Domain, otp_app: :eve_dmv

  resources do
    resource(EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine)
  end

  authorization do
    authorize(:when_requested)
  end

  @doc """
  Reads records from a query.
  """
  def read(query) do
    Ash.read(query, domain: __MODULE__)
  end

  @doc """
  Reads one record from a query.
  """
  def read_one(query) do
    Ash.read_one(query, domain: __MODULE__)
  end

  @doc """
  Creates a record.
  """
  def create(changeset) do
    Ash.create(changeset, domain: __MODULE__)
  end

  @doc """
  Updates a record.
  """
  def update(changeset) do
    Ash.update(changeset, domain: __MODULE__)
  end

  @doc """
  Destroys a record.
  """
  def destroy(changeset_or_record) do
    Ash.destroy(changeset_or_record, domain: __MODULE__)
  end

  @doc """
  Gets a record by ID.
  """
  def get(resource, id, opts \\ []) do
    Ash.get(resource, id, [domain: __MODULE__] ++ opts)
  end

  @doc """
  Counts records matching a query.
  """
  def count(query) do
    Ash.count(query, domain: __MODULE__)
  end
end
