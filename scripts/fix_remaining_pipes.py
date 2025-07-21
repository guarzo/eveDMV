#!/usr/bin/env python3
"""Fix remaining pipe chain issues in Elixir code."""

import re
import subprocess

def get_pipe_chain_issues():
    """Get files and lines with pipe chain issues."""
    result = subprocess.run(
        ["mix", "credo", "--only", "refactor", "--format", "oneline"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True
    )
    
    issues = []
    for line in result.stdout.split('\n'):
        if "Pipe chain should start" in line:
            match = re.search(r'→ ([^:]+):(\d+):(\d+)', line)
            if match:
                issues.append({
                    'file': match.group(1),
                    'line': int(match.group(2)),
                    'col': int(match.group(3))
                })
    return issues

def fix_pipe_chain_in_file(file_path, line_num, col_num):
    """Fix a specific pipe chain issue."""
    try:
        with open(file_path, 'r') as f:
            lines = f.readlines()
        
        if line_num <= len(lines):
            line_idx = line_num - 1
            line = lines[line_idx]
            
            # Common patterns to fix
            # Pattern 1: Function call with pipe as first argument
            if re.search(r'\(\s*\|>', line):
                lines[line_idx] = re.sub(r'\(\s*\|>\s*', '(', line)
            
            # Pattern 2: Assignment with pipe on right side
            elif re.search(r'=\s*\|>', line):
                # This needs context from previous line
                if line_idx > 0 and lines[line_idx - 1].strip().endswith('\\'):
                    # Multi-line assignment
                    lines[line_idx] = re.sub(r'^\s*\|>\s*', '', line)
                
            # Pattern 3: Case/if branch starting with pipe
            elif re.search(r'->\s*\|>', line):
                lines[line_idx] = re.sub(r'->\s*\|>\s*', '-> ', line)
            
            # Pattern 4: Standalone pipe at beginning of line
            elif re.match(r'^\s*\|>', line):
                lines[line_idx] = re.sub(r'^\s*\|>\s*', '', line)
            
            with open(file_path, 'w') as f:
                f.writelines(lines)
            return True
    except Exception as e:
        print(f"Error fixing {file_path}:{line_num} - {e}")
    return False

def main():
    print("Fixing remaining pipe chain issues...")
    
    issues = get_pipe_chain_issues()
    print(f"Found {len(issues)} pipe chain issues")
    
    fixed = 0
    for issue in issues:
        if fix_pipe_chain_in_file(issue['file'], issue['line'], issue['col']):
            fixed += 1
            print(f"Fixed: {issue['file']}:{issue['line']}")
    
    print(f"Fixed {fixed} pipe chain issues")
    
    # Recount issues
    remaining = len(get_pipe_chain_issues())
    print(f"Remaining pipe chain issues: {remaining}")

if __name__ == "__main__":
    main()