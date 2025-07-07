#!/usr/bin/env python3
"""
Final comprehensive script to fix ALL remaining variable redeclarations.
"""

import re
import subprocess
import sys
from pathlib import Path

# Files and their specific variable issues based on credo output
KNOWN_ISSUES = {
    "lib/eve_dmv/database/archive_manager/restore_operations.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/fleet_optimizer.ex": ["suggested_additions", "anomalies"],
    "lib/eve_dmv/eve/reliability_config.ex": ["recommendations"],
    "lib/eve_dmv/database/performance_optimizer.ex": ["recommendations"],
    "lib/eve_dmv/contexts/threat_assessment/analyzers/vulnerability_scanner.ex": ["confidence_factors"],
    "lib/eve_dmv/contexts/threat_assessment/analyzers/threat_analyzer.ex": ["warnings", "risk_factors", "factors"],
    "lib/eve_dmv/contexts/threat_assessment/domain/threat_analyzer.ex": ["recommendations", "risk_factors"],
    "lib/eve_dmv/database/partition_utils.ex": ["recommendations"],
    "lib/eve_dmv/database/query_plan_analyzer/slow_query_detector.ex": ["recommendations"],
    "lib/eve_dmv/database/query_plan_analyzer/table_stats_analyzer.ex": ["factors", "gaps", "actions", "recommendations", "recommendations"],
    "lib/eve_dmv/database/repository/cache_helper.ex": ["parts"],
    "lib/eve_dmv/intelligence/alert_system.ex": ["alerts", "alerts", "alerts"],
    "lib/eve_dmv/intelligence/analyzers/corporation_analyzer.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/analyzers/fleet_asset_manager/readiness_analyzer.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/analyzers/fleet_skill_analyzer.ex": ["gaps", "recommendations"],
    "lib/eve_dmv/intelligence/analyzers/home_defense_analyzer.ex": ["gaps"],
    "lib/eve_dmv/intelligence/analyzers/mass_calculator.ex": ["suggestions"],
    "lib/eve_dmv/intelligence/analyzers/member_activity_analyzer/recruitment_retention_analyzer.ex": ["risks", "actions", "recommendations", "recommendations"],
    "lib/eve_dmv/intelligence/analyzers/member_activity_pattern_analyzer/anomaly_detector.ex": ["anomalies"],
    "lib/eve_dmv/intelligence/analyzers/member_risk_assessment.ex": ["warnings"],
    "lib/eve_dmv/intelligence/analyzers/wh_fleet_analyzer/doctrine_manager.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/fleet/fleet_composition_analyzer.ex": ["suggestions"],
    "lib/eve_dmv/intelligence/generators/recruitment_insight_generator.ex": ["recommendations", "recommendations"],
    "lib/eve_dmv/intelligence/intelligence_scoring/behavioral_scoring.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/intelligence_scoring/fleet_scoring.ex": ["recommendations", "suggestions", "recommendations"],
    "lib/eve_dmv/intelligence/intelligence_scoring/intelligence_suitability.ex": ["recommendations", "recommendations", "risks"],
    "lib/eve_dmv/intelligence/intelligence_scoring/recruitment_scoring.ex": ["recommendations", "recommendations", "risks"],
    "lib/eve_dmv/intelligence/metrics/character_metrics.ex": ["recommendations"],
    "lib/eve_dmv/intelligence/pattern_analysis.ex": ["factors"],
    "lib/eve_dmv/intelligence/ship_database/doctrine_data.ex": ["gaps", "suggestions"],
    "lib/eve_dmv/intelligence/ship_database/wormhole_utils.ex": ["recommendations"],
    "lib/eve_dmv/killmails/display_service.ex": ["factors"],
    "lib/eve_dmv/quality/metrics_collector/ci_cd_metrics.ex": ["recommendations"],
    "lib/eve_dmv/quality/metrics_collector/code_quality_metrics.ex": ["recommendations"],
    "lib/eve_dmv/quality/metrics_collector/documentation_metrics.ex": ["recommendations"],
    "lib/eve_dmv/quality/metrics_collector/performance_metrics.ex": ["recommendations"],
    "lib/eve_dmv/result.ex": ["results"],
    "lib/eve_dmv/shared/ship_database_service.ex": ["recommendations"],
    "lib/eve_dmv/telemetry/performance_monitor/connection_pool_monitor.ex": ["recommendations", "recommendations", "recommendations"],
    "lib/eve_dmv/telemetry/performance_monitor/health_monitor.ex": ["warnings", "recommendations"],
    "lib/eve_dmv/telemetry/performance_monitor/index_partition_analyzer.ex": ["recommendations"],
    "lib/eve_dmv/telemetry/query_monitor.ex": ["patterns"],
    "lib/mix/tasks/security.audit.ex": ["report", "recommendations"],
    "lib/eve_dmv/contexts/player_profile/domain/player_analyzer.ex": ["recommendations", "risk_factors"],
    "lib/eve_dmv/contexts/player_profile/formatters/character_display_formatter.ex": ["recommendations", "recommendations"],
    "lib/eve_dmv/contexts/corporation_analysis/analyzers/member_activity_analyzer.ex": ["recommendations"],
    "lib/eve_dmv/contexts/surveillance/domain/chain_intelligence_service.ex": ["factors"],
    "lib/eve_dmv/contexts/threat_assessment/analyzers/vulnerability_scanner.ex": ["anomalies"],
    "lib/eve_dmv/intelligence/ship_database/wormhole_utils.ex": ["factors"],
}

def fix_file_variable_redeclarations(filepath, variables):
    """Fix all variable redeclarations in a specific file."""
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        original_content = content
        
        for var_name in set(variables):  # Use set to handle duplicates
            content = fix_all_occurrences_of_variable(content, var_name)
        
        if content != original_content:
            with open(filepath, 'w') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def fix_all_occurrences_of_variable(content, var_name):
    """Fix all occurrences of a variable redeclaration in the content."""
    # Define comprehensive naming strategies
    naming_strategies = {
        'recommendations': [
            'initial_recommendations', 'base_recommendations', 'activity_recommendations',
            'tactical_recommendations', 'strategic_recommendations', 'operational_recommendations',
            'enhanced_recommendations', 'priority_recommendations', 'final_recommendations'
        ],
        'factors': [
            'initial_factors', 'base_factors', 'risk_factors', 'confidence_factors',
            'weight_factors', 'score_factors', 'analysis_factors', 'final_factors'
        ],
        'warnings': [
            'initial_warnings', 'critical_warnings', 'security_warnings',
            'performance_warnings', 'operational_warnings', 'system_warnings', 'final_warnings'
        ],
        'alerts': [
            'initial_alerts', 'critical_alerts', 'warning_alerts',
            'info_alerts', 'system_alerts', 'user_alerts', 'final_alerts'
        ],
        'risks': [
            'initial_risks', 'operational_risks', 'security_risks',
            'financial_risks', 'strategic_risks', 'compliance_risks', 'final_risks'
        ],
        'risk_factors': [
            'initial_risk_factors', 'behavioral_risk_factors', 'environmental_risk_factors',
            'operational_risk_factors', 'strategic_risk_factors', 'system_risk_factors', 'final_risk_factors'
        ],
        'gaps': [
            'initial_gaps', 'coverage_gaps', 'skill_gaps',
            'resource_gaps', 'capability_gaps', 'strategic_gaps', 'final_gaps'
        ],
        'anomalies': [
            'initial_anomalies', 'behavioral_anomalies', 'statistical_anomalies',
            'temporal_anomalies', 'pattern_anomalies', 'system_anomalies', 'final_anomalies'
        ],
        'suggestions': [
            'initial_suggestions', 'improvement_suggestions', 'optimization_suggestions',
            'tactical_suggestions', 'strategic_suggestions', 'operational_suggestions', 'final_suggestions'
        ],
        'actions': [
            'initial_actions', 'immediate_actions', 'remedial_actions',
            'preventive_actions', 'corrective_actions', 'long_term_actions', 'final_actions'
        ],
        'confidence_factors': [
            'initial_confidence_factors', 'data_confidence_factors', 'analysis_confidence_factors',
            'prediction_confidence_factors', 'validation_confidence_factors', 'model_confidence_factors', 'final_confidence_factors'
        ],
        'suggested_additions': [
            'initial_suggested_additions', 'tactical_suggested_additions', 'strategic_suggested_additions',
            'operational_suggested_additions', 'enhancement_suggested_additions', 'optimization_suggested_additions', 'final_suggested_additions'
        ],
        'parts': [
            'initial_parts', 'header_parts', 'body_parts',
            'content_parts', 'footer_parts', 'metadata_parts', 'final_parts'
        ],
        'report': [
            'initial_report', 'summary_report', 'detailed_report',
            'analysis_report', 'metrics_report', 'comprehensive_report', 'final_report'
        ],
        'patterns': [
            'initial_patterns', 'behavioral_patterns', 'temporal_patterns',
            'usage_patterns', 'access_patterns', 'query_patterns', 'final_patterns'
        ],
        'results': [
            'initial_results', 'processed_results', 'filtered_results',
            'validated_results', 'transformed_results', 'aggregated_results', 'final_results'
        ]
    }
    
    replacements = naming_strategies.get(var_name, [
        f'initial_{var_name}', f'base_{var_name}', f'processed_{var_name}',
        f'enhanced_{var_name}', f'updated_{var_name}', f'modified_{var_name}', f'final_{var_name}'
    ])
    
    # Process each function separately
    func_pattern = r'((?:defp?|def)\s+\w+(?:\([^)]*\))?\s*do\s*(?:(?!(?:defp?|def)\s+\w+)[\s\S])*?\n\s*end)'
    
    def process_function(match):
        func_content = match.group(0)
        if f'{var_name} =' not in func_content:
            return func_content
        
        lines = func_content.split('\n')
        assignments = []
        
        # Find all assignments
        for i, line in enumerate(lines):
            if re.search(rf'^\s*{var_name}\s*=(?!=)', line):
                assignments.append(i)
        
        if len(assignments) <= 1:
            return func_content
        
        # Apply replacements
        used_names = []
        for idx, line_idx in enumerate(assignments):
            if idx >= len(replacements):
                break
            
            new_name = replacements[idx]
            used_names.append(new_name)
            
            # Replace assignment
            lines[line_idx] = re.sub(
                rf'^(\s*){var_name}(\s*=)',
                rf'\1{new_name}\2',
                lines[line_idx]
            )
            
            # Update references between assignments
            start = line_idx + 1
            end = assignments[idx + 1] if idx + 1 < len(assignments) else len(lines)
            
            for j in range(start, end):
                if not re.search(rf'^\s*{var_name}\s*=', lines[j]):
                    # Replace references
                    prev_name = used_names[idx - 1] if idx > 0 else var_name
                    lines[j] = re.sub(rf'\b{prev_name}\b(?!\s*=)', new_name, lines[j])
        
        # Fix final references
        if used_names:
            final_name = used_names[-1]
            for i in range(len(lines) - 1, assignments[-1], -1):
                if re.search(rf'\b{var_name}\b', lines[i]) and not re.search(rf'{var_name}\s*=', lines[i]):
                    lines[i] = re.sub(rf'\b{var_name}\b', final_name, lines[i])
        
        return '\n'.join(lines)
    
    # Apply to all functions
    content = re.sub(func_pattern, process_function, content, flags=re.MULTILINE)
    
    return content

def main():
    """Process all known files with variable redeclaration issues."""
    print("Fixing all remaining variable redeclaration issues...")
    print(f"Processing {len(KNOWN_ISSUES)} files")
    
    fixed_count = 0
    for filepath, variables in KNOWN_ISSUES.items():
        if Path(filepath).exists():
            print(f"Processing {filepath}...")
            if fix_file_variable_redeclarations(filepath, variables):
                fixed_count += 1
                print(f"  ✓ Fixed")
            else:
                print(f"  - No changes needed")
        else:
            print(f"  ✗ File not found: {filepath}")
    
    print(f"\nTotal files fixed: {fixed_count}")
    
    # Verify results
    print("\nVerifying results...")
    result = subprocess.run(
        ["mix", "credo", "--strict"],
        capture_output=True,
        text=True
    )
    
    remaining = len(re.findall(r'Variable.*was declared more than once', result.stdout))
    print(f"Remaining variable redeclaration errors: {remaining}")

if __name__ == '__main__':
    main()