#!/bin/bash

echo "Removing unused functions from battle_sharing_service.ex..."

# Create a backup
cp /workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex \
   /workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex.backup

# Remove the unused private functions that were only used by the removed public functions
cat > /tmp/remove_unused.py << 'EOF'
import re

with open('/workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex', 'r') as f:
    content = f.read()

# List of functions to remove (based on dialyzer output)
functions_to_remove = [
    # Functions only used by generate_battle_report
    'generate_markdown_report',
    'generate_json_report', 
    'generate_html_report',
    'generate_text_report',
    # Functions only used by export_battle_data
    'prepare_export_data',
    'export_to_csv',
    'format_for_zkillboard',
    # Helper functions only used by removed functions
    'format_statistics_markdown',
    'format_timeline_markdown',
    'format_participants_markdown',
    'format_fleet_comp_markdown',
    'format_tactical_markdown',
    'describe_event',
    'format_ship_classes',
    'describe_pattern',
    'format_stats_html',
    'format_timeline_html',
    'format_participants_html',
    'format_participant_rows',
    'format_top_killers_text',
    'format_timeline_text',
    'serialize_battle',
    'get_battle_killmails',
    'format_time'
]

# Remove each function
for func_name in functions_to_remove:
    # Pattern to match the entire function definition
    pattern = rf'^\s*defp?\s+{func_name}\([^)]*\)\s+do\n(?:.*?\n)*?\s*end\n'
    content = re.sub(pattern, '', content, flags=re.MULTILINE | re.DOTALL)

# Clean up multiple blank lines
content = re.sub(r'\n\n\n+', '\n\n', content)

with open('/workspace/lib/eve_dmv/contexts/combat/services/battle_sharing_service.ex', 'w') as f:
    f.write(content)
EOF

python3 /tmp/remove_unused.py

echo "Compilation check..."
mix compile

echo "Done!"