# Fix Refactoring Opportunities (127 Issues)

You are an AI assistant tasked with resolving refactoring opportunities found by Credo in an Elixir Phoenix codebase. Focus ONLY on [F] (Refactoring) issues.

## Instructions

1. **Refactoring Issues to Address**:
   - Avoid negated conditions in if-else blocks
   - Use `Enum.map_join/3` instead of `Enum.map/2 |> Enum.join/2`  
   - Avoid long quote blocks
   - Fix pipe chains that should start with raw values

2. **Key Transformation Patterns**:

   **A. Negated Conditions**:
   ```elixir
   # Before
   if !condition do
     handle_false_case()
   else  
     handle_true_case()
   end
   
   # After
   if condition do
     handle_true_case()
   else
     handle_false_case()  
   end
   ```

   **B. Enum.map_join Optimization**:
   ```elixir
   # Before
   list |> Enum.map(&transform/1) |> Enum.join(", ")
   
   # After
   Enum.map_join(list, ", ", &transform/1)
   ```

   **C. Pipe Chain Starting Points**:
   ```elixir
   # Before
   function_call() |> transform() |> process()
   
   # After (if function_call() doesn't return raw value)
   raw_value = function_call()
   raw_value |> transform() |> process()
   ```

3. **Areas to Focus On**:
   - Look for patterns like `data |> Enum.map(...) |> Enum.join(...)`
   - Find negated if conditions with `!` or `not`
   - Identify pipe chains starting with function calls instead of raw values
   - Check for overly long quote blocks that could be split

4. **File Types to Prioritize**:
   - Start with utility modules and shared code
   - Move to context modules
   - Handle web/LiveView files last to avoid conflicts

5. **Examples from Common Patterns**:
   ```elixir
   # Map-Join Pattern
   # Before
   ships |> Enum.map(&"#{&1.name} (#{&1.type})") |> Enum.join(", ")
   
   # After  
   Enum.map_join(ships, ", ", &"#{&1.name} (#{&1.type})")
   
   # Negated Condition Pattern
   # Before
   if !valid_input?(data) do
     {:error, "Invalid input"}
   else
     process_data(data)
   end
   
   # After
   if valid_input?(data) do
     process_data(data)
   else
     {:error, "Invalid input"}
   end
   ```

6. **Quote Block Guidelines**:
   - Split long quote blocks into smaller, focused sections
   - Use proper indentation and formatting
   - Consider extracting complex quotes into separate functions

## Important Notes

- This is part of a parallel fix effort - only modify [F] refactoring issues
- Do NOT modify TODO comments, module aliases, pipeline usage, predicate naming, number formatting, or other issue types
- Test changes incrementally with `mix compile`
- Preserve all existing functionality and behavior
- Focus on readability and performance improvements

## Success Criteria

- All negated conditions are restructured positively
- `Enum.map/2 |> Enum.join/2` patterns are replaced with `Enum.map_join/3`
- Pipe chains start with appropriate raw values
- Long quote blocks are reasonably sized
- Code compiles without errors
- All tests pass
- Performance is improved where applicable