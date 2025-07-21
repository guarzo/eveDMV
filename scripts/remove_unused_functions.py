#!/usr/bin/env python3
"""
Remove all UNUSED commented out functions from battle_analysis_service.ex
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_unused2")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Remove all UNUSED function blocks
# Pattern matches # UNUSED: defp ... through the closing # end
pattern = r'\s*# UNUSED:.*?\n(?:.*?#.*?\n)*?\s*# end'

content = re.sub(pattern, '', content, flags=re.DOTALL | re.MULTILINE)

# Also remove simple UNUSED comments
pattern2 = r'\s*# UNUSED:.*?\n'
content = re.sub(pattern2, '', content)

# Clean up multiple blank lines
content = re.sub(r'\n\s*\n\s*\n', '\n\n', content)

# Write the updated content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"Complete! New line count: {line_count}")
