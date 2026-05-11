# JavaScript Extend-File TaintVarSet API

Access `TaintVarSet` with `rule.analysisVisitor.getCurrentTaintVarSet()`, `rule.analysisVisitor.getCurrentTaintFieldSet()`, or `context.getVisitMethodContext().taintedvars`.

| API | Use |
|---|---|
| `getTaintVars()` / `setTaintVars(...)` | Get or replace taint variable map |
| `getSafeVars()` / `setSafeVars(...)` | Get or replace safe variable map |
| `getMultiTaintVars()` / `setMultiTaintVars(...)` | Get or replace tag-partitioned taint map |
| `copy()` | Deep copy the set |
| `addTaintVariable(taintVar)` | Add taint and remove matching safe state |
| `addMultiTaintVariable(taintVar, taintTag)` | Add multi-taint for a tag |
| `deleteTaintVariable(taintVar)` | Remove taint |
| `deleteMultiTaintVariable(taintVar, taintTag)` | Remove multi-taint for one or all tags |
| `addSafeVariable(safeVar)` | Add safe state and remove matching taint |
| `isVariableAllTaint(taintVar)` | Full taint query |
| `isMultiVariableAllTaint(taintVar, taintTag)` | Full multi-taint query |
| `isVariableMayTaint(taintVar)` | Possible taint query including subpaths |
| `isVariableMayMultiTaint(taintVar, taintTag)` | Possible multi-taint query |
| `isSafeVariable(safeVar)` | Safe-state query |
| `isEmptyTaint()` | Whether the taint set is empty |
| `getVariableMayMultiTaintTags(taintVar)` | Tags that may taint the variable |
| `containsTaintVar(taintVar)` / `containsSafeVar(safeVar)` | Exact membership |
| `containsMultiTaintVar(taintVar, taintTag)` / `containsMultiTaintVarAllTag(taintVar)` | Exact multi-taint membership |
| `getLastTaintedVar(taintVar)` / `getLastMultiTaintedVar(taintVar, taintTag)` | Closest tainted ancestor |
| `getAllTaintedSubPathesSet(taintVar)` / `getTaintedSubPathesSet(taintVar)` | Tainted subpaths |
| `getMultiTaintedSubPathesSet(taintVar, taintTag)` | Multi-tainted subpaths |
| `getAllSafeSubPathesSet(safeVar)` / `getSafeSubPathesSet(safeVar)` | Safe subpaths |
| `getFieldTaintVarSet(baseVar)` | Field-level `TaintVarSet` |
| `getAllTaintVars()` / `getAllTaintVarsSet()` | All taint variables |
| `getAllSafeVars()` / `getAllSafeVarsSet()` | All safe variables |
| `getAllMultiTaintVars()` | All multi-taint variables by tag |
| `printAllTaintVars()` / `printAllSafeVars()` | Debug strings |
