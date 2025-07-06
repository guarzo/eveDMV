# Complete Remaining Credo Work - ALL Categories

## **Error Breakdown - Current State (925 Total Errors)**

### **1. Single-Function Pipelines: 223 errors**
**Status**: Major category still requiring work across entire codebase
**Pattern**: `Use a function call when a pipeline is only one function long`
**Scope**: All modules - intelligence, database, infrastructure, web, contexts

### **2. Trailing Whitespace: 220 errors**  
**Status**: Widespread formatting issue
**Pattern**: `There should be no trailing white-space at the end of a line`
**Scope**: Nearly every file in codebase
**Solution**: Automated fix with code formatter

### **3. Alias Organization: 121 errors**
**Status**: Import organization issues throughout codebase
**Patterns**: 
- `alias must appear before require`
- `Avoid grouping aliases in '{ ... }'`
**Scope**: Most modules need import cleanup

### **4. Variable Redeclaration: 76 errors**
**Status**: Logic and naming issues across analysis modules  
**Pattern**: `Variable "X" was declared more than once`
**Scope**: Intelligence analyzers, context modules, database operations

### **5. Pipe Chain Structure: 58 errors**
**Status**: Pipeline structure issues
**Pattern**: `Pipe chain should start with a raw value`
**Scope**: Database modules, infrastructure, analysis engines

### **6. Critical Issues (Smaller Counts)**
- **Excessive Dependencies**: 1 error (Services module)
- **Duplicate Code**: 3 instances (analyzer modules)
- **Performance Warnings**: 1 error (length vs Enum.empty?)
- **Software Design**: ~8 total issues
- **Nested Module Aliasing**: Several in test files

## **Files Requiring Work By Category**

### **Intelligence Modules**
- All analyzer modules (member participation, fleet pilot, etc.)
- Intelligence engine plugins
- Analysis workers and supervisors

### **Database Layer**
- Materialized view managers
- Cache warming modules  
- Health check systems
- Query analyzers

### **Web Layer**
- LiveView modules
- Components and services
- Controllers and authentication

### **Infrastructure**
- Event bus systems
- Worker supervisors
- Telemetry modules
- Security systems

### **Context Modules**
- Player profile analyzers
- Corporation analysis
- Threat assessment
- Fleet operations
- Wormhole operations
- Surveillance systems

### **Test Files**
- Performance test suites
- Manual testing generators
- Unit test modules

## **Implementation Strategy**

### **Phase 1: Automated Fixes (440+ errors)**
1. **Trailing Whitespace**: 220 errors - Run code formatter
2. **Single-Function Pipelines**: 223 errors - Systematic conversion
3. **Total Impact**: ~48% error reduction with automated tools

### **Phase 2: Import Organization (121 errors)**
1. **Alias Ordering**: Fix alias/require order
2. **Grouped Aliases**: Convert to individual lines
3. **Import Cleanup**: Alphabetize and organize

### **Phase 3: Logic Issues (140+ errors)**
1. **Variable Redeclaration**: 76 errors - Rename variables
2. **Pipe Chain Structure**: 58 errors - Fix pipeline starts
3. **Critical Issues**: Dependencies, duplicate code, performance

### **Phase 4: Final Cleanup**
1. **Software Design**: Address remaining architectural issues
2. **Test Organization**: Fix test file structure
3. **Documentation**: Complete any missing docs

## **Success Target**
- **Current**: 925 errors
- **After Phase 1**: ~485 errors (47% reduction)  
- **After Phase 2**: ~364 errors (60% reduction)
- **After Phase 3**: ~224 errors (76% reduction)
- **Final Target**: <50 errors (95% reduction)

This represents the complete scope of remaining work across ALL areas of the codebase, not just 3 critical issues.