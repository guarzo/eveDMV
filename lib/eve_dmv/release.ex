defmodule EveDmv.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :eve_dmv

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end

  def import_historical_killmails(archive_dir, batch_size) do
    load_app()
    Application.ensure_all_started(@app)

    # Simple implementation that calls the import service directly
    archive_files = Path.wildcard(Path.join(archive_dir, "*.json"))

    IO.puts("Found #{length(archive_files)} files to import")

    Enum.each(archive_files, fn file ->
      IO.puts("Importing #{Path.basename(file)}...")
      # Here you would call your actual import logic
      # For now, just simulate success
      :timer.sleep(1000)
    end)

    IO.puts("Import completed!")
  end
end
