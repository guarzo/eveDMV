defmodule Mix.Tasks.Eve.ApplyQuerySafety do
  @moduledoc """
  Mix task to apply query safety to Ash resources.

  This task updates resource files to include query safety preparations
  for all read actions.

  Usage:
    mix eve.apply_query_safety --dry-run    # Show what would be changed
    mix eve.apply_query_safety               # Apply changes
  """

  @shortdoc "Apply query safety to Ash resources"

  use Mix.Task
  require Logger

  @resources_to_update [
    "lib/eve_dmv/killmails/killmail_raw.ex",
    "lib/eve_dmv/killmails/participant.ex",
    "lib/eve_dmv/intelligence/character_stats.ex",
    "lib/eve_dmv/analytics/player_stats.ex",
    "lib/eve_dmv/analytics/ship_stats.ex",
    "lib/eve_dmv/surveillance/profile.ex",
    "lib/eve_dmv/surveillance/profile_match.ex",
    "lib/eve_dmv/contexts/battle_analysis/resources/battle.ex",
    "lib/eve_dmv/contexts/battle_analysis/resources/battle_killmail.ex"
  ]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [dry_run: :boolean])
    dry_run = Keyword.get(opts, :dry_run, false)

    Logger.info("Applying query safety to Ash resources#{if dry_run, do: " (DRY RUN)", else: ""}")

    |> Enum.each(@resources_to_update, fn file_path ->
      apply_query_safety_to_file(file_path, dry_run)
    end)

    Logger.info("Query safety application complete!")
  end

  defp apply_query_safety_to_file(file_path, dry_run) do
    case File.read(file_path) do
      {:ok, content} ->
        if has_preparations_block?(content) do
          Logger.info("Skipping #{file_path} - already has preparations block")
        else
          updated_content = add_query_safety_preparation(content)

          if dry_run do
            Logger.info("Would update #{file_path}")
            Logger.debug("Changes:\n#{generate_diff(content, updated_content)}")
          else
            File.write!(file_path, updated_content)
            Logger.info("Updated #{file_path}")
          end
        end

      {:error, reason} ->
        Logger.error("Failed to read #{file_path}: #{inspect(reason)}")
    end
  end

  defp has_preparations_block?(content) do
    content =~ ~r/preparations\s+do/
  end

  defp add_query_safety_preparation(content) do
    # Find the position after the resource configuration blocks
    # but before the actions block
    insertion_point = find_insertion_point(content)

    preparation_block = """

      # Query safety preparations
      preparations do
        EveDmv.Api.DomainExtensions.query_safety_preparation(prepare)
      end
    """

    {before, after_part} = String.split_at(content, insertion_point)
    before <> preparation_block <> after_part
  end

  defp find_insertion_point(content) do
    # Find the line before "actions do" or "relationships do"
    # This is a simplified implementation
    lines = String.split(content, "\n")

    index =
      Enum.find_index(lines, fn line ->
        line =~ ~r/^\s*(actions|relationships)\s+do/
      end)

    if index do
      # Calculate byte position
      partial_content =
        lines
        |> Enum.take(index)
        |> Enum.join("\n")

      byte_size(partial_content)
    else
      # Default to end of attributes block
      case Regex.run(~r/attributes\s+do.*?end/s, content) do
        [match] ->
          {start_pos, _} = :binary.match(content, match)
          start_pos + byte_size(match)

        _ ->
          # Fallback: insert before the last "end"
          byte_size(content) - 10
      end
    end
  end

  defp generate_diff(original, updated) do
    # Simple diff showing the added lines
    added_lines = String.split(updated, "\n") -- String.split(original, "\n")
    |> Enum.map_join(added_lines, "\n", &"+ #{&1}")
  end
end
