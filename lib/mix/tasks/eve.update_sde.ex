defmodule Mix.Tasks.Eve.UpdateSde do
  @moduledoc """
  Updates EVE Static Data Export (SDE) data from Fuzzwork.

  This task checks for new SDE versions and downloads/processes updated data
  if necessary. It coordinates updates across all SDE data types including
  wormhole classes and effects.

  ## Usage

      mix eve.update_sde

  ## Options

    * `--force` - Force update even if data appears current
    * `--check-only` - Only check for updates without downloading
    * `--verbose` - Show detailed progress information

  ## Examples

      mix eve.update_sde
      mix eve.update_sde --force
      mix eve.update_sde --check-only
      mix eve.update_sde --verbose
  """

  @shortdoc "Update EVE SDE data from Fuzzwork"

  use Mix.Task

  alias EveDmv.Eve.StaticDataLoader, as: SDL
  alias SDL.{SdeVersionManager, SdeStartupService}

  def run(args) do
    # Start the application to access the database
    Mix.Task.run("app.start")

    {opts, _args} =
      OptionParser.parse!(args,
        strict: [
          force: :boolean,
          check_only: :boolean,
          verbose: :boolean
        ]
      )

    # Set log level based on verbose flag
    if opts[:verbose] do
      Logger.configure(level: :debug)
    end

    if opts[:check_only] do
      check_only()
    else
      perform_update(opts[:force] || false)
    end
  end

  defp check_only do
    Mix.shell().info("🔍 Checking for SDE updates...")

    case SdeVersionManager.check_for_updates() do
      {:ok, :up_to_date} ->
        Mix.shell().info("✅ SDE data is up to date")

      {:ok, _results} ->
        Mix.shell().info("📦 Updates available")
        Mix.shell().info("Use 'mix eve.update_sde' to download and install updates")

      {:error, reason} ->
        Mix.shell().error("❌ Failed to check for updates: #{reason}")
        System.halt(1)
    end
  end

  defp perform_update(force) do
    Mix.shell().info("🚀 Starting SDE update process...")

    if force do
      Mix.shell().info("⚡ Force mode enabled - will update regardless of version")
    end

    # Check service status
    case SdeStartupService.get_status() do
      %{enabled: true} ->
        Mix.shell().info("📡 SDE startup service is enabled")

      %{enabled: false} ->
        Mix.shell().info("⚠️  SDE startup service is disabled")

      {:error, _} ->
        Mix.shell().info("ℹ️  SDE startup service not available, running manual update")
    end

    # Perform the update
    case SdeVersionManager.check_for_updates() do
      {:ok, :up_to_date} ->
        if force do
          Mix.shell().info("🔄 Forcing update even though data appears current...")
          force_update()
        else
          Mix.shell().info("✅ SDE data is already up to date")
        end

      {:ok, results} ->
        Mix.shell().info("✅ SDE update completed successfully!")
        display_results(results)

      {:error, reason} ->
        Mix.shell().error("❌ SDE update failed: #{reason}")
        System.halt(1)
    end
  end

  defp force_update do
    case SdeStartupService.force_update() do
      {:ok, results} ->
        Mix.shell().info("✅ Forced SDE update completed successfully!")
        display_results(results)

      {:error, reason} ->
        Mix.shell().error("❌ Forced SDE update failed: #{reason}")
        System.halt(1)
    end
  end

  defp display_results(results) do
    Mix.shell().info("📊 Update Results:")

    case results do
      %{wormhole_classes: {:ok, classes_count}, wormhole_effects: {:ok, effects_count}} ->
        Mix.shell().info("  • Wormhole classes: #{classes_count} updated")
        Mix.shell().info("  • Wormhole effects: #{effects_count} updated")

      %{wormhole_classes: {:error, class_error}, wormhole_effects: {:ok, effects_count}} ->
        Mix.shell().error("  • Wormhole classes: failed (#{class_error})")
        Mix.shell().info("  • Wormhole effects: #{effects_count} updated")

      %{wormhole_classes: {:ok, classes_count}, wormhole_effects: {:error, effects_error}} ->
        Mix.shell().info("  • Wormhole classes: #{classes_count} updated")
        Mix.shell().error("  • Wormhole effects: failed (#{effects_error})")

      %{wormhole_classes: {:error, class_error}, wormhole_effects: {:error, effects_error}} ->
        Mix.shell().error("  • Wormhole classes: failed (#{class_error})")
        Mix.shell().error("  • Wormhole effects: failed (#{effects_error})")

      other ->
        Mix.shell().info("  • #{inspect(other)}")
    end
  end
end
