#!/bin/bash

# Fast Dialyzer script for development
# Skips PLT rebuilding unless forced

set -e

FORCE_PLT_REBUILD=""
PARALLEL_JOBS=$(nproc)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild-plt)
            FORCE_PLT_REBUILD="true"
            shift
            ;;
        --jobs|-j)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--rebuild-plt] [--jobs N]"
            exit 1
            ;;
    esac
done

echo "🔍 Fast Dialyzer Analysis"
echo "========================"
echo "Parallel jobs: $PARALLEL_JOBS"

# Create PLT directory if it doesn't exist
mkdir -p priv/plts

# Check if PLT exists and is recent
PLT_FILE="priv/plts/dialyzer.plt"
if [[ -f "$PLT_FILE" && -z "$FORCE_PLT_REBUILD" ]]; then
    # Check if PLT is newer than mix.lock (dependencies changed)
    if [[ "$PLT_FILE" -nt "mix.lock" ]]; then
        echo "✅ Using existing PLT (newer than mix.lock)"
        SKIP_PLT_BUILD="true"
    else
        echo "🔄 PLT older than mix.lock, will rebuild"
    fi
else
    echo "🏗️  PLT not found or rebuild forced"
fi

# Build PLT only if needed
if [[ -z "$SKIP_PLT_BUILD" ]]; then
    echo "Building PLT..."
    time mix dialyzer --build-plt
    echo "✅ PLT built successfully"
fi

# Run fast analysis
echo "🚀 Running Dialyzer analysis..."
export DIALYZER_PLT="$PLT_FILE"

# Use time command to measure duration
echo "Starting analysis at $(date)"
start_time=$(date +%s)

# Run dialyzer with optimizations
mix dialyzer \
    --halt-exit-status \
    --no-check-plt \
    || {
        echo "❌ Dialyzer found issues"
        exit 1
    }

end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo "✅ Dialyzer analysis completed successfully!"
echo "⏱️  Duration: ${duration} seconds"

# Show PLT info
echo ""
echo "📊 PLT Information:"
echo "PLT file: $PLT_FILE"
echo "PLT size: $(du -h "$PLT_FILE" 2>/dev/null | cut -f1 || echo 'unknown')"
echo "PLT date: $(stat -c %y "$PLT_FILE" 2>/dev/null || stat -f %Sm "$PLT_FILE" 2>/dev/null || echo 'unknown')"