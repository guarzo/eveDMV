# Dialyzer Performance Optimization

## Problem
Dialyzer was taking 8+ minutes to run due to PLT (Persistent Lookup Table) checking with 4,741 modules.

## Solution
Implemented a fast dialyzer approach that skips PLT checking by default:

- **With PLT checking**: 8m22s 
- **Without PLT checking**: ~57 seconds (87% faster!)

## Usage

### Development
```bash
# Fast run (no PLT check - ~57 seconds)
./scripts/fast_dialyzer.sh

# With timing information
./scripts/fast_dialyzer.sh --timing

# Force PLT rebuild (when dependencies change)
./scripts/fast_dialyzer.sh --rebuild-plt

# Run with PLT check (slower, ~8+ minutes)
./scripts/fast_dialyzer.sh --check-plt
```

### CI/CD
The GitHub Actions workflow `.github/workflows/dialyzer-cache.yml`:
1. Caches the PLT file between runs
2. Only rebuilds PLT when mix.lock changes
3. Uses fast dialyzer without PLT checking

### Configuration
In `mix.exs`:
```elixir
dialyzer: [
  check_plt: false,  # Skip PLT checking for speed
  # ... other settings
]
```

## When to Rebuild PLT
- After adding/updating dependencies
- After Elixir/OTP version changes
- If you see "Unknown functions" errors

## Trade-offs
- **Pros**: 87% faster dialyzer runs for daily development
- **Cons**: May miss some dependency-related type errors
- **Recommendation**: Run with `--check-plt` before releases or in nightly CI builds