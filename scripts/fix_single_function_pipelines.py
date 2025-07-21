#!/usr/bin/env python3

import os
import re
import glob

def fix_single_function_pipelines(file_path):
    """Fix single function pipelines in a file."""
    print(f"Processing {file_path}")
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        original_content = content
        
        # Pattern to match single function pipelines
        # This matches patterns like: variable |> function(args)
        # or multiline: variable\n|> function(args)
        
        # Pattern 1: Simple single function pipeline on one line
        pattern1 = r'(\w+)\s*\|\>\s*(\w+(?:\.\w+)*)\s*\('
        
        def replace1(match):
            var_name = match.group(1)
            func_name = match.group(2)
            return f'{func_name}({var_name}, '
        
        content = re.sub(pattern1, replace1, content)
        
        # Pattern 2: Variable assignment with single function pipeline
        pattern2 = r'(\w+)\s*=\s*(\w+)\s*\|\>\s*(\w+(?:\.\w+)*)\s*\('
        
        def replace2(match):
            result_var = match.group(1)
            input_var = match.group(2)
            func_name = match.group(3)
            return f'{result_var} = {func_name}({input_var}, '
        
        content = re.sub(pattern2, replace2, content)
        
        # Pattern 3: Multiline pipeline with single function
        pattern3 = r'(\w+)\s*\n\s*\|\>\s*(\w+(?:\.\w+)*)\s*\('
        
        def replace3(match):
            var_name = match.group(1)
            func_name = match.group(2)
            return f'{func_name}({var_name}, '
        
        content = re.sub(pattern3, replace3, content)
        
        # Pattern 4: Complex single function pipeline with parentheses
        pattern4 = r'\(([^)]+)\)\s*\|\>\s*(\w+(?:\.\w+)*)\s*\('
        
        def replace4(match):
            expression = match.group(1)
            func_name = match.group(2)
            return f'{func_name}(({expression}), '
        
        content = re.sub(pattern4, replace4, content)
        
        # Pattern 5: Function call result piped to single function
        pattern5 = r'(\w+(?:\.\w+)*\([^)]*\))\s*\|\>\s*(\w+(?:\.\w+)*)\s*\('
        
        def replace5(match):
            func_call = match.group(1)
            next_func = match.group(2)
            return f'{next_func}({func_call}, '
        
        content = re.sub(pattern5, replace5, content)
        
        if content != original_content:
            with open(file_path, 'w') as f:
                f.write(content)
            print(f"  ✅ Fixed single function pipelines in {file_path}")
            return True
        else:
            print(f"  ⏭️  No changes needed in {file_path}")
            return False
            
    except Exception as e:
        print(f"  ❌ Error processing {file_path}: {e}")
        return False

def main():
    print("🔧 Fixing single function pipelines...")
    
    # Get all .ex files in lib directory
    lib_files = glob.glob('/workspace/lib/**/*.ex', recursive=True)
    
    fixed_count = 0
    total_files = 0
    
    for file_path in lib_files:
        if os.path.isfile(file_path):
            total_files += 1
            if fix_single_function_pipelines(file_path):
                fixed_count += 1
    
    print(f"\n📊 Summary:")
    print(f"   Files processed: {total_files}")
    print(f"   Files modified: {fixed_count}")
    print(f"   Success rate: {fixed_count/total_files*100:.1f}%")

if __name__ == "__main__":
    main()