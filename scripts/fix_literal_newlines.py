#!/usr/bin/env python3
"""
Fix literal \n characters in delegations to actual newlines
"""

import re

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis/phases/fleet_composition_analyzer.ex"

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Replace literal \n with actual newlines in delegations
# Pattern: defp function_name(...) do\n    BattleOutcomePredictor.function_name(...)\n
patterns_to_fix = [
    # Pattern 1: defp func(...) do\n    Module.func(...)\n
    (r'(defp\s+\w+\s*\([^)]*\)\s+do)\\n(\s+BattleOutcomePredictor\.\w+\([^)]*\))\\n', r'\1\n\2\n'),
    
    # Pattern 2: Simple function end with \n
    (r'\\n(\s*end)', r'\n\1'),
    
    # Pattern 3: Function calls with \n
    (r'\\n(\s+[^\\]+)', r'\n\1'),
]

for pattern, replacement in patterns_to_fix:
    content = re.sub(pattern, replacement, content)

# Additional manual fixes for specific malformed patterns
fixes = [
    # Fix defp lines that have literal \n
    ('do\\n    BattleOutcomePredictor.', 'do\n    BattleOutcomePredictor.'),
    ('\\n        end,', '\n        end,'),
    ('\\n    end', '\n  end'),
    ('\\n  end', '\n  end'),
]

for old, new in fixes:
    content = content.replace(old, new)

# Write the fixed content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"Fixed literal newlines. New line count: {line_count}")