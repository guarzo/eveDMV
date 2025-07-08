#!/usr/bin/env python3
"""
Comprehensive script to fix all variable redeclaration issues in Elixir files.
"""

import re
import os
from pathlib import Path

def fix_variable_redeclarations(content):
    """Fix common variable redeclaration patterns in Elixir code."""
    
    # Pattern 1: Fix 'recommendations' variable redeclarations
    content = fix_recommendations_pattern(content)
    
    # Pattern 2: Fix 'factors' variable redeclarations
    content = fix_factors_pattern(content)
    
    # Pattern 3: Fix 'alerts' variable redeclarations
    content = fix_alerts_pattern(content)
    
    # Pattern 4: Fix 'warnings' variable redeclarations
    content = fix_warnings_pattern(content)
    
    # Pattern 5: Fix 'risks' or 'risk_factors' variable redeclarations
    content = fix_risks_pattern(content)
    
    # Pattern 6: Fix 'gaps' variable redeclarations
    content = fix_gaps_pattern(content)
    
    # Pattern 7: Fix 'anomalies' variable redeclarations
    content = fix_anomalies_pattern(content)
    
    # Pattern 8: Fix 'suggestions' variable redeclarations
    content = fix_suggestions_pattern(content)
    
    # Pattern 9: Fix 'actions' variable redeclarations
    content = fix_actions_pattern(content)
    
    # Pattern 10: Fix 'improvements' variable redeclarations
    content = fix_improvements_pattern(content)
    
    return content

def fix_recommendations_pattern(content):
    """Fix recommendations = X; recommendations = Y pattern."""
    # Find functions that have recommendations redeclarations
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'recommendations =' in func and func.count('recommendations =') > 1:
            new_func = fix_accumulator_pattern(func, 'recommendations', [
                'initial_recommendations',
                'base_recommendations',
                'enhanced_recommendations',
                'tactical_recommendations',
                'strategic_recommendations',
                'final_recommendations'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_factors_pattern(content):
    """Fix factors = X; factors = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'factors =' in func and func.count('factors =') > 1:
            new_func = fix_accumulator_pattern(func, 'factors', [
                'initial_factors',
                'base_factors',
                'risk_factors',
                'confidence_factors',
                'weighted_factors',
                'final_factors'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_alerts_pattern(content):
    """Fix alerts = X; alerts = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'alerts =' in func and func.count('alerts =') > 1:
            new_func = fix_accumulator_pattern(func, 'alerts', [
                'initial_alerts',
                'base_alerts',
                'critical_alerts',
                'warning_alerts',
                'info_alerts',
                'final_alerts'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_warnings_pattern(content):
    """Fix warnings = X; warnings = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'warnings =' in func and func.count('warnings =') > 1:
            new_func = fix_accumulator_pattern(func, 'warnings', [
                'initial_warnings',
                'base_warnings',
                'critical_warnings',
                'security_warnings',
                'performance_warnings',
                'final_warnings'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_risks_pattern(content):
    """Fix risks = X; risks = Y or risk_factors = X; risk_factors = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'risks =' in func and func.count('risks =') > 1:
            new_func = fix_accumulator_pattern(func, 'risks', [
                'initial_risks',
                'base_risks',
                'operational_risks',
                'security_risks',
                'financial_risks',
                'final_risks'
            ])
            content = content.replace(func, new_func)
        
        if 'risk_factors =' in func and func.count('risk_factors =') > 1:
            new_func = fix_accumulator_pattern(func, 'risk_factors', [
                'initial_risk_factors',
                'base_risk_factors',
                'behavioral_risk_factors',
                'environmental_risk_factors',
                'operational_risk_factors',
                'final_risk_factors'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_gaps_pattern(content):
    """Fix gaps = X; gaps = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'gaps =' in func and func.count('gaps =') > 1:
            new_func = fix_accumulator_pattern(func, 'gaps', [
                'initial_gaps',
                'coverage_gaps',
                'skill_gaps',
                'resource_gaps',
                'strategic_gaps',
                'final_gaps'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_anomalies_pattern(content):
    """Fix anomalies = X; anomalies = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'anomalies =' in func and func.count('anomalies =') > 1:
            new_func = fix_accumulator_pattern(func, 'anomalies', [
                'initial_anomalies',
                'behavioral_anomalies',
                'statistical_anomalies',
                'temporal_anomalies',
                'pattern_anomalies',
                'final_anomalies'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_suggestions_pattern(content):
    """Fix suggestions = X; suggestions = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'suggestions =' in func and func.count('suggestions =') > 1:
            new_func = fix_accumulator_pattern(func, 'suggestions', [
                'initial_suggestions',
                'improvement_suggestions',
                'optimization_suggestions',
                'tactical_suggestions',
                'strategic_suggestions',
                'final_suggestions'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_actions_pattern(content):
    """Fix actions = X; actions = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'actions =' in func and func.count('actions =') > 1:
            new_func = fix_accumulator_pattern(func, 'actions', [
                'initial_actions',
                'immediate_actions',
                'remedial_actions',
                'preventive_actions',
                'long_term_actions',
                'final_actions'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_improvements_pattern(content):
    """Fix improvements = X; improvements = Y pattern."""
    functions = re.findall(r'(defp?\s+\w+[^}]+?\n\s*end)', content, re.DOTALL)
    
    for func in functions:
        if 'improvements =' in func and func.count('improvements =') > 1:
            new_func = fix_accumulator_pattern(func, 'improvements', [
                'initial_improvements',
                'priority_improvements',
                'performance_improvements',
                'quality_improvements',
                'strategic_improvements',
                'final_improvements'
            ])
            content = content.replace(func, new_func)
    
    return content

def fix_accumulator_pattern(func_content, var_name, replacement_names):
    """Fix accumulator pattern for a specific variable."""
    lines = func_content.split('\n')
    var_assignments = []
    
    # Find all lines with variable assignments
    for i, line in enumerate(lines):
        if re.match(rf'\s*{var_name}\s*=', line):
            var_assignments.append(i)
    
    if len(var_assignments) <= 1:
        return func_content
    
    # Replace each assignment with a unique name
    for idx, line_num in enumerate(var_assignments):
        if idx < len(replacement_names):
            old_var = var_name
            new_var = replacement_names[idx]
            
            # Replace the assignment
            lines[line_num] = lines[line_num].replace(f'{old_var} =', f'{new_var} =', 1)
            
            # Update references to this variable until the next assignment
            start_line = line_num + 1
            end_line = var_assignments[idx + 1] if idx + 1 < len(var_assignments) else len(lines)
            
            for j in range(start_line, end_line):
                # Don't replace if it's part of another assignment
                if not re.match(rf'\s*{var_name}\s*=', lines[j]):
                    # Replace variable references
                    lines[j] = re.sub(rf'\b{old_var}\b', new_var, lines[j])
    
    # Update the final return statement if it returns the variable
    for i in range(len(lines) - 1, -1, -1):
        if var_name in lines[i] and not '=' in lines[i]:
            if var_assignments:
                last_var = replacement_names[min(len(var_assignments) - 1, len(replacement_names) - 1)]
                lines[i] = re.sub(rf'\b{var_name}\b', last_var, lines[i])
            break
    
    return '\n'.join(lines)

def process_file(filepath):
    """Process a single file to fix variable redeclarations."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        content = fix_variable_redeclarations(content)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            print(f"Fixed: {filepath}")
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Main function to process all Elixir files."""
    lib_path = Path('/workspace/lib')
    fixed_count = 0
    
    for elixir_file in lib_path.rglob('*.ex'):
        if process_file(elixir_file):
            fixed_count += 1
    
    print(f"\nTotal files fixed: {fixed_count}")

if __name__ == '__main__':
    main()