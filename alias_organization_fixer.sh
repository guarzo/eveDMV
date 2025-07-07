#!/bin/bash
# alias_organization_fixer.sh

echo "=== Alias Organization Fixer ==="

# Step 1: Fix alias/require ordering
echo "Step 1: Fixing alias/require ordering..."
find lib -name "*.ex" | while read file; do
  # Create temporary file for reorganized imports
  temp_file="${file}.temp"
  
  # Extract and reorganize imports
  awk '
  BEGIN { in_imports = 0; aliases = ""; requires = ""; imports = ""; uses = ""; other = "" }
  
  /^[[:space:]]*alias / { aliases = aliases $0 "\n"; next }
  /^[[:space:]]*require / { requires = requires $0 "\n"; next }
  /^[[:space:]]*import / { imports = imports $0 "\n"; next }
  /^[[:space:]]*use / { uses = uses $0 "\n"; next }
  
  # Print non-import lines and reorganized imports when we hit the first function
  /^[[:space:]]*def / { 
    if (aliases != "" || requires != "" || imports != "" || uses != "") {
      print uses aliases requires imports
      aliases = ""; requires = ""; imports = ""; uses = ""
    }
    print; next
  }
  
  { print }
  ' "$file" > "$temp_file"
  
  # Replace original if different
  if ! cmp -s "$file" "$temp_file"; then
    mv "$temp_file" "$file"
    echo "Fixed: $file"
  else
    rm "$temp_file"
  fi
done

# Step 2: Expand grouped aliases
echo "Step 2: Expanding grouped aliases..."
find lib -name "*.ex" -exec sed -i 's/alias \([^{]*\){\([^}]*\)}/\1\2/g' {} \;

# Convert {A, B, C} to individual lines
find lib -name "*.ex" | while read file; do
  perl -pi -e '
    if (/^(\s*)alias\s+([^{]+)\{([^}]+)\}/) {
      my ($indent, $prefix, $modules) = ($1, $2, $3);
      my @mods = map { s/^\s+|\s+$//gr } split /,/, $modules;
      my $result = "";
      for my $mod (@mods) {
        $result .= "${indent}alias ${prefix}${mod}\n";
      }
      $_ = $result;
    }
  ' "$file"
done

# Step 3: Alphabetize aliases within groups
echo "Step 3: Alphabetizing aliases..."
find lib -name "*.ex" | while read file; do
  python3 -c "
import re
import sys

with open('$file', 'r') as f:
    content = f.read()

# Find alias blocks and sort them
def sort_aliases(match):
    lines = match.group(0).split('\n')
    alias_lines = []
    other_lines = []
    
    for line in lines:
        if re.match(r'^\s*alias\s+', line):
            alias_lines.append(line)
        else:
            other_lines.append(line)
    
    # Sort alias lines
    alias_lines.sort()
    
    return '\n'.join(alias_lines + other_lines)

# Process alias blocks
content = re.sub(
    r'(^\s*alias\s+.*\n)+',
    sort_aliases,
    content,
    flags=re.MULTILINE
)

with open('$file', 'w') as f:
    f.write(content)
"
done

echo "=== Alias organization complete! ==="