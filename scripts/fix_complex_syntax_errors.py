#!/usr/bin/env python3
"""
Fix more complex syntax patterns that weren't caught by the first pass.
"""

import re
import os
import glob

def fix_complex_patterns(content):
    """Fix the more complex broken patterns."""
    
    fixes = [
        # Fix cases like: Enum.map() |> Enum.uniq((killmails, & &1.victim_ship_type_id), )
        # Should be: killmails |> Enum.map(& &1.victim_ship_type_id) |> Enum.uniq()
        (r'(\w+) \|> Enum\.map\(\) \|> Enum\.uniq\(\((.*?), (.*?)\), \)', r'\1 |> Enum.map(\3) |> Enum.uniq()'),
        
        # Fix cases like: cluster.Enum.map() |> average((members, & &1.damage_rate), )
        # Should be: cluster.members |> Enum.map(& &1.damage_rate) |> average()
        (r'(\w+)\.Enum\.map\(\) \|> average\(\((.*?), (.*?)\), \)', r'\1.\2 |> Enum.map(\3) |> average()'),
        
        # Fix cases like: Enum.with_index() |> Enum.map((phases), fn {phase, index} ->
        # Should be: phases |> Enum.with_index() |> Enum.map(fn {phase, index} ->
        (r'Enum\.with_index\(\) \|> Enum\.map\(\((.*?)\), (fn.*?->)', r'\1 |> Enum.with_index() |> Enum.map(\2'),
        
        # Fix cases like: battle |> Enum.sort_by(killmails, & &1.killmail_time)
        # Should be: battle.killmails |> Enum.sort_by(& &1.killmail_time)
        (r'(\w+) \|> Enum\.sort_by\((\w+), (.*?)\)', r'\1.\2 |> Enum.sort_by(\3)'),
        
        # Fix cases like: window |> Enum.count(killmails, &ewar_ship_type?/1)
        # Should be: window.killmails |> Enum.count(&ewar_ship_type?/1)
        (r'(\w+) \|> Enum\.count\((\w+), (.*?)\)', r'\1.\2 |> Enum.count(\3)'),
        
        # Fix cases like: String.split() |> Enum.filter((path, "/", trim: true), &(&1 != ""))
        # Should be: String.split(path, "/", trim: true) |> Enum.filter(&(&1 != ""))
        (r'String\.split\(\) \|> Enum\.filter\(\((.*?)\), (.*?)\)', r'String.split(\1) |> Enum.filter(\2)'),
        
        # Fix cases like: Enum.group_by() |> Enum.map((killmails, & &1.victim_ship_type_id), fn {type_id, kills} ->
        # Should be: killmails |> Enum.group_by(& &1.victim_ship_type_id) |> Enum.map(fn {type_id, kills} ->
        (r'Enum\.group_by\(\) \|> Enum\.map\(\((.*?), (.*?)\), (fn.*?->)', r'\1 |> Enum.group_by(\2) |> Enum.map(\3'),
        
        # Fix cases like: Enum.sort_by() |> Enum.take((& &1.count, :desc), 3)
        # Should be: Enum.sort_by(& &1.count, :desc) |> Enum.take(3)
        (r'Enum\.sort_by\(\) \|> Enum\.take\(\((.*?), (.*?)\), (.*?)\)', r'Enum.sort_by(\1, \2) |> Enum.take(\3)'),
        
        # Fix cases like: Enum.zip() |> Enum.group_by((original_features, assignments), fn {_feature, {_point, cluster_id}} -> cluster_id end)
        # Should be: Enum.zip(original_features, assignments) |> Enum.group_by(fn {_feature, {_point, cluster_id}} -> cluster_id end)
        (r'Enum\.zip\(\) \|> Enum\.group_by\(\((.*?), (.*?)\), (fn.*?end)\)', r'Enum.zip(\1, \2) |> Enum.group_by(\3)'),
        
        # Fix cases like: Map.get() |> Enum.map((cluster_groups, cluster_id, []), fn {point, _cluster} -> point end)
        # Should be: Map.get(cluster_groups, cluster_id, []) |> Enum.map(fn {point, _cluster} -> point end)
        (r'Map\.get\(\) \|> Enum\.map\(\((.*?), (.*?), (.*?)\), (fn.*?end)\)', r'Map.get(\1, \2, \3) |> Enum.map(\4)'),
        
        # Fix cases like: Enum.map() |> Enum.sum((killmails, &estimate_engagement_distance/1), )
        # Should be: killmails |> Enum.map(&estimate_engagement_distance/1) |> Enum.sum()
        (r'Enum\.map\(\) \|> Enum\.sum\(\((.*?), (.*?)\), \)', r'\1 |> Enum.map(\2) |> Enum.sum()'),
        
        # Fix cases like: Enum.map() |> Enum.max((all_windows, & &1.end_time), )
        # Should be: all_windows |> Enum.map(& &1.end_time) |> Enum.max()
        (r'Enum\.map\(\) \|> Enum\.max\(\((.*?), (.*?)\), \)', r'\1 |> Enum.map(\2) |> Enum.max()'),
        
        # Fix cases like: Enum.map() |> Enum.min((all_windows, & &1.start_time), )
        # Should be: all_windows |> Enum.map(& &1.start_time) |> Enum.min()
        (r'Enum\.map\(\) \|> Enum\.min\(\((.*?), (.*?)\), \)', r'\1 |> Enum.map(\2) |> Enum.min()'),
        
        # Fix cases like: extract_all_participants() |> length((killmails), )
        # Should be: extract_all_participants(killmails) |> length()
        (r'extract_all_participants\(\) \|> length\(\((.*?)\), \)', r'extract_all_participants(\1) |> length()'),
        
        # Fix cases like: to_string() |> String.replace((phase_type), "_", " ")
        # Should be: to_string(phase_type) |> String.replace("_", " ")
        (r'to_string\(\) \|> String\.replace\(\((.*?)\), (.*?), (.*?)\)', r'to_string(\1) |> String.replace(\2, \3)'),
        
        # Fix cases like: cluster |> Enum.map(members, & &1.window)
        # Should be: cluster.members |> Enum.map(& &1.window)
        (r'(\w+) \|> Enum\.map\((\w+), (.*?)\)', r'\1.\2 |> Enum.map(\3)'),
        
        # Fix cases like: cluster |> Enum.flat_map() |> Enum.uniq_by((members, & &1.window.killmails), & &1.killmail_id)
        # Should be: cluster.members |> Enum.flat_map(& &1.window.killmails) |> Enum.uniq_by(& &1.killmail_id)
        (r'(\w+) \|> Enum\.flat_map\(\) \|> Enum\.uniq_by\(\((.*?), (.*?)\), (.*?)\)', r'\1.\2 |> Enum.flat_map(\3) |> Enum.uniq_by(\4)'),
        
        # Fix case like: Enum.flat_mapEnum.uniq_by((all_windows, & &1.killmails), & &1.killmail_id)
        # Should be: all_windows |> Enum.flat_map(& &1.killmails) |> Enum.uniq_by(& &1.killmail_id)
        (r'Enum\.flat_mapEnum\.uniq_by\(\((.*?), (.*?)\), (.*?)\)', r'\1 |> Enum.flat_map(\2) |> Enum.uniq_by(\3)'),
        
        # Fix specific broken case: Enum.sumeuclidean_distance((
        (r'Enum\.sumeuclidean_distance\(\(', 'Enum.sum('),
        
        # Fix broken function calls like cluster.Enum.map(members, fn member ->
        (r'(\w+)\.Enum\.map\((\w+), (fn.*?)$', r'\1.\2 |> Enum.map(\3'),
        
        # Fix broken calls like extract_numeric_features(member, ), cluster.centroid)
        (r'extract_numeric_features\((.*?), \), (.*?)\)', r'euclidean_distance(extract_numeric_features(\1), \2)'),
        
        # Fix Ash.Query.filter() |> Ash.read_one((KillmailRaw, killmail_id: killmail_id), domain: Api)
        # Should be: KillmailRaw |> Ash.Query.filter(killmail_id: killmail_id) |> Ash.read_one!(domain: Api)
        (r'Ash\.Query\.filter\(\) \|> Ash\.read_one\(\((.*?), (.*?)\), (.*?)\)', r'\1 |> Ash.Query.filter(\2) |> Ash.read_one!(\3)'),
        
        # Fix DateTime calls
        (r'DateTime\.from_naive!\("Etc/UTC"\), \)', 'DateTime.from_naive!("Etc/UTC"))'),
    ]
    
    modified = False
    for pattern, replacement in fixes:
        if re.search(pattern, content, re.MULTILINE | re.DOTALL):
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE | re.DOTALL)
            modified = True
    
    return content, modified

def fix_file(filepath):
    """Fix syntax errors in a single file."""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        fixed_content, was_modified = fix_complex_patterns(original_content)
        
        if was_modified:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(fixed_content)
            print(f"Fixed: {filepath}")
            return True
        return False
        
    except Exception as e:
        print(f"Error processing {filepath}: {e}")
        return False

def main():
    """Fix all Elixir files with complex broken syntax."""
    print("Fixing complex broken syntax patterns...")
    
    # Get all Elixir files
    elixir_files = glob.glob('lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    for filepath in elixir_files:
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"Fixed {fixed_count} files with complex broken syntax patterns")

if __name__ == "__main__":
    main()