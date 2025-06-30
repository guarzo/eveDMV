♻️ Duplicate comments (1)
priv/repo/migrations/20250629081000_optimize_database_performance.exs (1)
38-45: Fix the date calculation to ensure runtime evaluation.

Despite the previous review being marked as "Addressed", there's still an issue with the date calculation. DateTime.utc_now() is evaluated when the migration module is compiled, not when it runs, making the index effectively static and less useful over time.

Apply this fix to ensure the date is calculated at migration runtime:

-    # Note: Using fixed date instead of now() to ensure IMMUTABLE constraint
-    recent_date = DateTime.utc_now() |> DateTime.add(-180, :day) |> DateTime.to_iso8601()
-    create index(:killmails_enriched, [:total_value], 
-      name: "killmails_enriched_recent_value_idx", 
-      where: "killmail_time > '#{recent_date}'::timestamp",
-      comment: "Optimizes recent killmail value queries (last ~6 months from migration date)"
-    )
+    # Calculate date at migration runtime for better relevance
+    recent_date = DateTime.utc_now() |> DateTime.add(-180, :day) |> DateTime.to_iso8601()
+    execute """
+    CREATE INDEX killmails_enriched_recent_value_idx 
+    ON killmails_enriched (total_value) 
+    WHERE killmail_time > '#{recent_date}'::timestamp
+    """
Or consider using a relative approach that doesn't require hardcoded dates:

+    execute """
+    CREATE INDEX killmails_enriched_recent_value_idx 
+    ON killmails_enriched (total_value) 
+    WHERE killmail_time > CURRENT_DATE - INTERVAL '6 months'
+    """
📜 Review details



In lib/eve_dmv/killmails/pipeline_test.ex around lines 136 to 163, the error
handling for the three Ash.create calls is duplicated with the same pattern of
logging and raising errors. Refactor by extracting this repeated error handling
logic into a helper function that takes the result of Ash.create and a
descriptive label, performs the logging and raising if there is an error, and
returns the successful result otherwise. Then replace the three Ash.create calls
with calls to this helper to reduce duplication and improve maintainability.