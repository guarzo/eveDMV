# Prompt 6: Fix Function Complexity and Parameter Issues

## Task
Refactor functions with too many parameters and address complex function issues.

## Context
Credo has identified functions that take too many parameters (more than 6) and other complexity issues that need to be addressed for better maintainability.

## Instructions

### Part 1: Functions with Too Many Parameters
1. Find functions with more than 6 parameters (arity > 6)
2. Refactor using one of these strategies:
   - **Option structs**: Group related parameters into a struct
   - **Keyword lists**: Use keyword arguments for optional parameters
   - **Context objects**: Create a context struct that holds related data
   - **Function splitting**: Break complex functions into smaller ones

3. Example refactoring:
   ```elixir
   # Before: Function with 11 parameters
   def complex_function(a, b, c, d, e, f, g, h, i, j, k) do
     # ...
   end
   
   # After: Use options struct
   defmodule ComplexOptions do
     defstruct [:a, :b, :c, :d, :e, :f, :g, :h, :i, :j, :k]
   end
   
   def complex_function(%ComplexOptions{} = opts) do
     # ...
   end
   ```

### Part 2: Long Quote Blocks
1. Find long quote blocks that exceed reasonable length
2. Break them into smaller, more manageable pieces
3. Consider using heredocs for multi-line strings

## Files to Focus On
Based on credo output, these files have high-arity functions:
- Look for functions with arity 11, 9, and other high counts
- Search in battle analysis modules
- Check intelligence infrastructure modules
- Review data processing modules

## Areas to Search
Use these patterns to find problematic functions:
- `grep -n "def.*(" lib/ | grep -E "\w+,\s*\w+,\s*\w+,\s*\w+,\s*\w+,\s*\w+,\s*\w+"` (functions with many parameters)
- Look in modules that handle complex data structures
- Check functions that process multiple related pieces of data

## Success Criteria
- No functions have more than 6 parameters
- Complex parameter lists are replaced with structured data
- Long quote blocks are broken into manageable pieces
- Function interfaces are cleaner and more maintainable
- All existing functionality is preserved

## Important Notes
- This is a significant refactoring task
- Maintain all existing API contracts
- Update all callers when function signatures change
- Consider backwards compatibility if these are public APIs
- Test thoroughly after refactoring