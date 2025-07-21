#!/usr/bin/env python3
"""
Clean up malformed delegations in battle_analysis_service.ex after tactical recommendation extraction
"""

import re
import shutil

FILE_PATH = "/workspace/lib/eve_dmv/contexts/combat_intelligence/domain/battle_analysis_service.ex"

# Backup the file
shutil.copy(FILE_PATH, FILE_PATH + ".backup_tactical_cleanup")

# Read the file
with open(FILE_PATH, 'r') as f:
    content = f.read()

# Clean up malformed delegations - pattern matches delegation followed by leftover code
patterns_to_clean = [
    # Pattern: TacticalRecommendationEngine.func(...)\n      end\n    rest of function\n  end
    r'(TacticalRecommendationEngine\.[a-z_?]+\([^)]*\))\s*\n\s*end\s*\n.*?(?=\n\s*(?:def|@|#|\Z))',
    # Pattern: TacticalRecommendationEngine.func(...)\n  end\n  rest of function
    r'(TacticalRecommendationEngine\.[a-z_?]+\([^)]*\))\s*\n\s*end\s*\n.*?(?=\n\s*end\s*\n)',
    # Pattern: Leftover code fragments after delegations
    r'\n\s*end\s*\n\s*(\w+.*?)\n\s*end(?=\s*\n)',
]

# Apply cleanup patterns
for i, pattern in enumerate(patterns_to_clean):
    def cleanup_replacer(match):
        if i < 2:  # For delegation patterns
            return f"{match.group(1)}\n  end"
        else:  # For leftover code patterns  
            return "\n  end"
    
    old_content = content
    content = re.sub(pattern, cleanup_replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if content != old_content:
        print(f"Applied cleanup pattern {i+1}")

# Specific cleanup for malformed function structures
malformed_patterns = [
    # Remove leftover lines after delegation calls
    r'(TacticalRecommendationEngine\.[a-z_?]+\([^)]*\))\s*\n\s*end\s*\n(?:\s*.*?\n)*?\s*end',
    # Fix incomplete function definitions
    r'(defp\s+\w+.*?do)\s*\n\s*(TacticalRecommendationEngine\.[a-z_?]+\([^)]*\))\s*\n\s*end\s*\n(?:.*?(?=\n\s*(?:def|#|\Z)))',
]

for i, pattern in enumerate(malformed_patterns):
    def malformed_replacer(match):
        if len(match.groups()) >= 2:
            return f"{match.group(1)}\n    {match.group(2)}\n  end"
        else:
            return f"{match.group(1)}\n  end"
    
    old_content = content
    content = re.sub(pattern, malformed_replacer, content, flags=re.DOTALL | re.MULTILINE)
    
    if content != old_content:
        print(f"Fixed malformed pattern {i+1}")

# Remove duplicate 'end' statements
content = re.sub(r'\n\s*end\s*\n\s*end\s*\n', '\n  end\n', content)

# Remove empty lines after delegation calls
content = re.sub(r'(TacticalRecommendationEngine\.[a-z_?]+\([^)]*\))\s*\n\s*\n\s*\n', r'\1\n', content)

# Write the cleaned content
with open(FILE_PATH, 'w') as f:
    f.write(content)

# Count final lines
with open(FILE_PATH, 'r') as f:
    line_count = len(f.readlines())

print(f"\nCleanup complete! New line count: {line_count}")

# Check progress
if line_count < 1000:
    print(f"🎉 SUCCESS! File is now under 1000 lines ({line_count} lines)")
    reduction = 1701 - line_count  
    percentage = (reduction / 1701) * 100
    print(f"Total reduction: {reduction} lines ({percentage:.1f}%)")
else:
    remaining = line_count - 999
    print(f"Need {remaining} more lines to reach target")