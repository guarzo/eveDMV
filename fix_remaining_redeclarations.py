#!/usr/bin/env python3
"""
Improved script to fix remaining variable redeclaration issues.
"""

import re
import subprocess
from pathlib import Path

def get_files_with_redeclarations():
    """Get list of files that still have variable redeclaration issues."""
    result = subprocess.run(
        ["mix", "credo", "--strict"],
        capture_output=True,
        text=True
    )
    
    files_with_issues = {}
    lines = result.stdout.split('\n')
    
    current_file = None
    for i, line in enumerate(lines):
        if '→' in line and '.ex:' in line:
            # Extract file path
            match = re.search(r'(lib/[^:]+\.ex):(\d+)', line)
            if match:
                current_file = match.group(1)
                line_num = match.group(2)
        elif 'Variable' in line and 'was declared more than once' in line and current_file:
            # Extract variable name
            match = re.search(r'Variable "([^"]+)" was declared', line)
            if match:
                var_name = match.group(1)
                if current_file not in files_with_issues:
                    files_with_issues[current_file] = []
                files_with_issues[current_file].append((var_name, line_num))
    
    return files_with_issues

def fix_specific_file_issues(filepath, var_issues):
    """Fix specific variable redeclarations in a file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        # Group issues by variable name
        vars_to_fix = {}
        for var_name, line_num in var_issues:
            if var_name not in vars_to_fix:
                vars_to_fix[var_name] = []
            vars_to_fix[var_name].append(line_num)
        
        # Fix each variable
        for var_name in vars_to_fix:
            content = fix_variable_in_content(content, var_name)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def fix_variable_in_content(content, var_name):
    """Fix a specific variable's redeclarations in content."""
    # Define naming strategies for common variables
    naming_strategies = {
        'recommendations': [
            'initial_recommendations',
            'base_recommendations', 
            'tactical_recommendations',
            'strategic_recommendations',
            'enhanced_recommendations',
            'final_recommendations'
        ],
        'factors': [
            'initial_factors',
            'base_factors',
            'numerical_factors',
            'tactical_factors',
            'control_factors',
            'final_factors'
        ],
        'warnings': [
            'initial_warnings',
            'critical_warnings',
            'security_warnings',
            'performance_warnings',
            'operational_warnings',
            'final_warnings'
        ],
        'alerts': [
            'initial_alerts',
            'critical_alerts',
            'warning_alerts',
            'info_alerts',
            'system_alerts',
            'final_alerts'
        ],
        'gaps': [
            'initial_gaps',
            'coverage_gaps',
            'skill_gaps',
            'resource_gaps',
            'strategic_gaps',
            'final_gaps'
        ],
        'risks': [
            'initial_risks',
            'operational_risks',
            'security_risks',
            'financial_risks',
            'strategic_risks',
            'final_risks'
        ],
        'risk_factors': [
            'initial_risk_factors',
            'behavioral_risk_factors',
            'environmental_risk_factors',
            'operational_risk_factors',
            'strategic_risk_factors',
            'final_risk_factors'
        ],
        'anomalies': [
            'initial_anomalies',
            'behavioral_anomalies',
            'statistical_anomalies',
            'temporal_anomalies',
            'pattern_anomalies',
            'final_anomalies'
        ],
        'suggestions': [
            'initial_suggestions',
            'improvement_suggestions',
            'optimization_suggestions',
            'tactical_suggestions',
            'strategic_suggestions',
            'final_suggestions'
        ],
        'actions': [
            'initial_actions',
            'immediate_actions',
            'remedial_actions',
            'preventive_actions',
            'long_term_actions',
            'final_actions'
        ],
        'improvements': [
            'initial_improvements',
            'priority_improvements',
            'performance_improvements',
            'quality_improvements',
            'strategic_improvements',
            'final_improvements'
        ],
        'confidence_factors': [
            'initial_confidence_factors',
            'data_confidence_factors',
            'analysis_confidence_factors',
            'prediction_confidence_factors',
            'validation_confidence_factors',
            'final_confidence_factors'
        ],
        'parts': [
            'initial_parts',
            'header_parts',
            'body_parts',
            'footer_parts',
            'metadata_parts',
            'final_parts'
        ],
        'report': [
            'initial_report',
            'summary_report',
            'detailed_report',
            'analysis_report',
            'metrics_report',
            'final_report'
        ],
        'suggested_additions': [
            'initial_suggested_additions',
            'tactical_suggested_additions',
            'strategic_suggested_additions',
            'operational_suggested_additions',
            'enhancement_suggested_additions',
            'final_suggested_additions'
        ]
    }
    
    # Get appropriate naming strategy
    replacements = naming_strategies.get(var_name, [
        f'initial_{var_name}',
        f'base_{var_name}',
        f'enhanced_{var_name}',
        f'processed_{var_name}',
        f'updated_{var_name}',
        f'final_{var_name}'
    ])
    
    # Find all functions in the file
    function_pattern = r'(defp?\s+\w+.*?(?=\n\s*defp?\s|\n\s*@|\nend\n|\Z))'
    functions = list(re.finditer(function_pattern, content, re.DOTALL))
    
    for func_match in functions:
        func_content = func_match.group(0)
        if f'{var_name} =' in func_content:
            new_func = fix_function_variable(func_content, var_name, replacements)
            if new_func != func_content:
                content = content.replace(func_content, new_func)
    
    return content

def fix_function_variable(func_content, var_name, replacements):
    """Fix variable redeclarations within a single function."""
    lines = func_content.split('\n')
    
    # Find all assignment lines for this variable
    assignment_lines = []
    for i, line in enumerate(lines):
        # Match variable assignment at start of expression
        if re.search(rf'^\s*{var_name}\s*=(?!=)', line):
            assignment_lines.append(i)
    
    if len(assignment_lines) <= 1:
        return func_content
    
    # Track what variable name is currently in use
    current_var_name = var_name
    
    # Process each assignment
    for idx, line_idx in enumerate(assignment_lines):
        if idx >= len(replacements):
            break
            
        new_var_name = replacements[idx]
        
        # Replace the assignment
        lines[line_idx] = re.sub(
            rf'^(\s*){var_name}(\s*=)',
            rf'\1{new_var_name}\2',
            lines[line_idx]
        )
        
        # Determine the range of lines affected by this assignment
        start_line = line_idx + 1
        if idx + 1 < len(assignment_lines):
            end_line = assignment_lines[idx + 1]
        else:
            end_line = len(lines)
        
        # Update references in the affected range
        for j in range(start_line, end_line):
            # Skip if this line is another assignment
            if not re.search(rf'^\s*{var_name}\s*=', lines[j]):
                # Replace variable references
                lines[j] = re.sub(rf'\b{current_var_name}\b', new_var_name, lines[j])
        
        current_var_name = new_var_name
    
    # Handle any final references to the variable (e.g., return statements)
    final_var_name = replacements[min(len(assignment_lines) - 1, len(replacements) - 1)]
    for i in range(len(lines) - 1, -1, -1):
        line = lines[i]
        # Look for return statements or final references
        if (re.search(rf'^\s*{var_name}\s*$', line) or 
            re.search(rf'^\s*{var_name}\s*\|>', line) or
            re.search(rf'^\s*\{{\s*:ok\s*,\s*{var_name}\s*\}}', line)):
            lines[i] = re.sub(rf'\b{var_name}\b', final_var_name, line)
            break
    
    return '\n'.join(lines)

def main():
    """Main function to fix remaining variable redeclarations."""
    print("Analyzing remaining variable redeclaration issues...")
    
    files_with_issues = get_files_with_redeclarations()
    
    if not files_with_issues:
        print("No variable redeclaration issues found!")
        return
    
    print(f"Found {len(files_with_issues)} files with variable redeclaration issues")
    
    fixed_count = 0
    for filepath, issues in files_with_issues.items():
        print(f"\nProcessing {filepath} ({len(issues)} issues)...")
        if fix_specific_file_issues(filepath, issues):
            fixed_count += 1
            print(f"  ✓ Fixed")
        else:
            print(f"  ✗ No changes needed or error occurred")
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()