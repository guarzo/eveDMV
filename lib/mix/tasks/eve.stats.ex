defmodule Mix.Tasks.Eve.Stats do
  @moduledoc """
  Display statistics about the EVE DMV database.

  ## Usage

      mix eve.stats
      mix eve.stats --verbose
  """
  """

  @shortdoc "Display EVE DMV database statistics"

  use Mix.Task

  import Ecto.Query

  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args} =
      OptionParser.parse!(args,
        strict: [verbose: :boolean],
        aliases: [v: :verbose]
      )

    verbose = opts[:verbose] || false

    Logger.info("EVE DMV Database Statistics")
    Logger.info("==========================")

    # Total killmails
    total_killmails =
      from(k in "killmails_raw", select: count(k.killmail_id))
      |> EveDmv.Repo.one()

    formatted_total = format_number(total_killmails)
    Logger.info("Total Killmails: #{formatted_total}")

    if verbose do
      # Killmails by source
      Logger.info("\nKillmails by Source:")

      source_counts =
        from(k in "killmails_raw", group_by: k.source, select: {k.source, count(k.killmail_id)})
        |> EveDmv.Repo.all()

      Enum.each(source_counts, fn {source, count} ->
        Logger.info("  #{source}: #{format_number(count)}")
      end)

      # Date range
      {oldest, newest} =
        from(k in "killmails_raw", select: {min(k.killmail_time), max(k.killmail_time)})
        |> EveDmv.Repo.one()

      if oldest && newest do
        Logger.info("\nDate Range:")
        Logger.info("  Oldest: #{format_datetime(oldest)}")
        Logger.info("  Newest: #{format_datetime(newest)}")
      end

      # Killmails by month
      Logger.info("\nKillmails by Month (last 6 months):")

      six_months_ago = DateTimeUtils.add(DateTime.utc_now(), -180 * 24 * 60 * 60, :second)

      monthly_counts =
        from(k in "killmails_raw",
          where: k.killmail_time >= ^six_months_ago,
          group_by: fragment("DATE_TRUNC('month', ?)", k.killmail_time),
          order_by: [desc: fragment("DATE_TRUNC('month', ?)", k.killmail_time)],
          select: {fragment("DATE_TRUNC('month', ?)", k.killmail_time), count(k.killmail_id)}
        )
        |> EveDmv.Repo.all()

      Enum.each(monthly_counts, fn {month, count} ->
        month_str = Calendar.strftime(month, "%B %Y")
        Logger.info("  #{month_str}: #{format_number(count)}")
      end)

      # Top systems
      Logger.info("\nTop 10 Systems by Kills:")

      initial_systems =
        from(k in "killmails_raw",
          join: s in "eve_solar_systems",
          on: k.solar_system_id == s.system_id,
          group_by: [k.solar_system_id, s.system_name],
          order_by: [desc: count(k.killmail_id)],
          limit: 10,
          select: {s.system_name, count(k.killmail_id)}
        )
        |> EveDmv.Repo.all()

      top_systems =
        case initial_systems do
          [] ->
            # Fallback if no solar system data
            fallback_data =
              from(k in "killmails_raw",
                group_by: k.solar_system_id,
                order_by: [desc: count(k.killmail_id)],
                limit: 10,
                select: {k.solar_system_id, count(k.killmail_id)}
              )
              |> EveDmv.Repo.all()

            fallback_data
            |> Enum.map(fn {system_id, count} -> {"System #{system_id}", count} end)

          systems ->
            systems
        end

      Enum.each(top_systems, fn {system, count} ->
        Logger.info("  #{system}: #{format_number(count)}")
      end)

      # Storage info
      Logger.info("\nStorage Information:")

      table_sizes =
        from(t in fragment("SELECT
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
            pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes
          FROM pg_tables
          WHERE schemaname = 'public'
            AND tablename LIKE 'killmails_raw%'
          ORDER BY size_bytes DESC"),
          select: %{
            table: fragment("tablename"),
            size: fragment("size")
          }
        )
        |> EveDmv.Repo.all()

      Enum.each(table_sizes, fn %{table: table, size: size} ->
        Logger.info("  #{table}: #{size}")
      end)
    end

    # Quick check for duplicates
    duplicate_check =
      from(k in "killmails_raw",
        group_by: k.killmail_id,
        having: count(k.killmail_id) > 1,
        select: count(k.killmail_id)
      )
      |> EveDmv.Repo.one()
      |> Kernel.||(0)

    if duplicate_check > 0 do
      Logger.warning("\n⚠️  Found #{duplicate_check} duplicate killmail IDs!")
    else
      Logger.info("\n✅ No duplicate killmail IDs found")
    end
  end

  defp format_number(nil), do: "0"

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp format_datetime(nil), do: "N/A"

  defp format_datetime(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end
end
