#!/bin/bash
#
# Fast Dialyzer Runner
# Optimized for speed by skipping PLT checks when possible
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
REBUILD_PLT=false
TIMING=false
CHECK_PLT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild-plt)
            REBUILD_PLT=true
            shift
            ;;
        --check-plt)
            CHECK_PLT=true
            shift
            ;;
        --timing)
            TIMING=true
            shift
            ;;
        --help)
            echo "Fast Dialyzer Runner"
            echo
            echo "Usage: $0 [options]"
            echo
            echo "Options:"
            echo "  --rebuild-plt    Force rebuild of PLT file"
            echo "  --check-plt      Enable PLT checking (slower)"
            echo "  --timing         Show timing information"
            echo "  --help           Show this help message"
            echo
            echo "By default, PLT checking is disabled for speed."
            echo "The PLT is only ~57 seconds without checking vs 8+ minutes with."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Start timing if requested
if [ "$TIMING" = true ]; then
    START_TIME=$(date +%s)
fi

cd "$PROJECT_ROOT"

echo -e "${BLUE}=== Fast Dialyzer Run ===${NC}"
echo

# Step 1: Handle PLT rebuild if requested
if [ "$REBUILD_PLT" = true ]; then
    echo -e "${YELLOW}⚠${NC} Rebuilding PLT file..."
    rm -f priv/plts/dialyzer.plt
    mix dialyzer --plt
    echo -e "${GREEN}✓${NC} PLT rebuilt"
fi

# Step 2: Check if PLT exists
if [ ! -f "priv/plts/dialyzer.plt" ]; then
    echo -e "${YELLOW}⚠${NC} PLT file not found. Building..."
    mix dialyzer --plt
fi

# Step 3: Compile the project
echo -e "${BLUE}Compiling project...${NC}"
if ! mix compile; then
    echo -e "${RED}✗${NC} Compilation failed"
    exit 1
fi

# Step 4: Run Dialyzer with optimized settings
echo
echo -e "${BLUE}Running Dialyzer analysis...${NC}"

DIALYZER_OPTS=""
if [ "$CHECK_PLT" = false ]; then
    DIALYZER_OPTS="--no-check"
    echo -e "${GREEN}✓${NC} Skipping PLT check for speed"
fi

# Run dialyzer
if mix dialyzer $DIALYZER_OPTS; then
    echo -e "${GREEN}✓${NC} Dialyzer completed successfully"
    EXIT_CODE=0
else
    EXIT_CODE=$?
    echo -e "${RED}✗${NC} Dialyzer found issues (exit code: $EXIT_CODE)"
fi

# Show timing if requested
if [ "$TIMING" = true ]; then
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))
    echo
    echo -e "${BLUE}Total time: ${MINUTES}m ${SECONDS}s${NC}"
fi

exit $EXIT_CODE