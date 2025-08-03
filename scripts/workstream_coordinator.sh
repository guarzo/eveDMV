#!/bin/bash
# Workstream Coordination Script
# Manages parallel workstream activities and tracks progress

REGISTRY_FILE="/workspace/.workstream_coordination/function_registry.json"
WORKSTREAM=$1
ACTION=$2

show_usage() {
    echo "Usage: $0 WORKSTREAM ACTION [ARGS]"
    echo ""
    echo "Workstreams: alpha, beta, gamma, delta, epsilon"
    echo ""
    echo "Actions:"
    echo "  status                    - Show workstream status"
    echo "  claim MODULE FUNCTION     - Claim a function for removal"
    echo "  release MODULE FUNCTION   - Release a claimed function"
    echo "  fixed COUNT              - Report errors fixed"
    echo "  summary                  - Show overall progress"
    echo ""
    echo "Example: $0 alpha claim EveDmv.Platform.Cache get_data"
}

if [ -z "$WORKSTREAM" ] || [ -z "$ACTION" ]; then
    show_usage
    exit 1
fi

case "$ACTION" in
    status)
        echo "=== Workstream $WORKSTREAM Status ==="
        jq ".workstream_status.$WORKSTREAM" "$REGISTRY_FILE"
        ;;
        
    claim)
        MODULE=$3
        FUNCTION=$4
        if [ -z "$MODULE" ] || [ -z "$FUNCTION" ]; then
            echo "Error: MODULE and FUNCTION required for claim"
            exit 1
        fi
        
        # Add to removal requests
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        jq ".removal_requests[\"$MODULE.$FUNCTION\"] = {\"workstream\": \"$WORKSTREAM\", \"claimed_at\": \"$TIMESTAMP\"}" "$REGISTRY_FILE" > tmp.json && mv tmp.json "$REGISTRY_FILE"
        echo "✅ Function $MODULE.$FUNCTION claimed by workstream $WORKSTREAM"
        ;;
        
    release)
        MODULE=$3
        FUNCTION=$4
        if [ -z "$MODULE" ] || [ -z "$FUNCTION" ]; then
            echo "Error: MODULE and FUNCTION required for release"
            exit 1
        fi
        
        # Remove from removal requests
        jq "del(.removal_requests[\"$MODULE.$FUNCTION\"])" "$REGISTRY_FILE" > tmp.json && mv tmp.json "$REGISTRY_FILE"
        echo "✅ Function $MODULE.$FUNCTION released"
        ;;
        
    fixed)
        COUNT=$3
        if [ -z "$COUNT" ]; then
            echo "Error: COUNT required for fixed action"
            exit 1
        fi
        
        # Update errors fixed count
        CURRENT=$(jq ".workstream_status.$WORKSTREAM.errors_fixed" "$REGISTRY_FILE")
        NEW_COUNT=$((CURRENT + COUNT))
        jq ".workstream_status.$WORKSTREAM.errors_fixed = $NEW_COUNT" "$REGISTRY_FILE" > tmp.json && mv tmp.json "$REGISTRY_FILE"
        echo "✅ Workstream $WORKSTREAM: $NEW_COUNT total errors fixed (+$COUNT)"
        ;;
        
    summary)
        echo "=== Sprint Progress Summary ==="
        echo ""
        echo "Baseline: $(jq '.baseline_error_count' "$REGISTRY_FILE") errors"
        echo "Target: $(jq '.target_error_count' "$REGISTRY_FILE") errors"
        echo ""
        echo "Workstream Progress:"
        jq -r '.workstream_status | to_entries[] | "  \(.key): \(.value.errors_fixed) errors fixed (\(.value.status))"' "$REGISTRY_FILE"
        
        TOTAL_FIXED=$(jq '[.workstream_status[].errors_fixed] | add' "$REGISTRY_FILE")
        echo ""
        echo "Total Fixed: $TOTAL_FIXED errors"
        
        BASELINE=$(jq '.baseline_error_count' "$REGISTRY_FILE")
        CURRENT=$((BASELINE - TOTAL_FIXED))
        echo "Current Count: $CURRENT errors"
        
        TARGET=$(jq '.target_error_count' "$REGISTRY_FILE")
        if [ "$CURRENT" -le "$TARGET" ]; then
            echo "✅ Sprint target achieved!"
        else
            REMAINING=$((CURRENT - TARGET))
            echo "📊 Need to fix $REMAINING more errors to reach target"
        fi
        ;;
        
    *)
        echo "Error: Unknown action '$ACTION'"
        show_usage
        exit 1
        ;;
esac