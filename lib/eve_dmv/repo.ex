defmodule EveDmv.Repo do
  @moduledoc """
  The main repository for EVE DMV application using AshPostgres.

  Handles database connections and provides Ash framework integration
  with PostgreSQL, including support for partitioned tables and 
  advanced EVE Online data processing features.
  """

  use AshPostgres.Repo,
    otp_app: :eve_dmv

  # Tell AshPostgres where your domains are
  def installed_extensions do
    ["uuid-ossp", "citext", "pg_trgm", "ash-functions"]
  end

  def min_pg_version do
    %Version{major: 14, minor: 0, patch: 0}
  end

  def all_tenants do
    # We don't use multi-tenancy in this application
    ["public"]
  end
end
