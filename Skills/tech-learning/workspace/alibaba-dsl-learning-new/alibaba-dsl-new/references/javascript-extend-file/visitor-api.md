# JavaScript Extend-File Visitor API

Use `rule.analysisVisitor` to read or modify current analysis state.

| API | Use |
|---|---|
| `rule.analysisVisitor.visit(node)` | Visit a node manually |
| `rule.analysisVisitor.copyTaintContext(...)` | Copy a taint context before custom traversal |
| `rule.analysisVisitor.addBugReport(sinkName, vertex)` | Report a finding |
| `rule.analysisVisitor.getTraces(vertex)` | Get traces for an output vertex |
| `rule.analysisVisitor.handleSinkTrace(...)` | Build a sink trace |
| `rule.analysisVisitor.handleMultiTaintSinkTrace(...)` | Build a multi-taint sink trace with `SinkType.Output` |
| `rule.analysisVisitor.addMultiTaintTrace(...)` | Add a multi-taint trace edge |
| `rule.analysisVisitor.handleTaintResult(...)` | Apply a taint result to a destination variable/node |
| `rule.analysisVisitor.getCurrentTaintVarSet()` | Read/update current taint variables |
| `rule.analysisVisitor.getCurrentTaintFieldSet()` | Read/update field taint variables |
| `rule.analysisVisitor.getFromVertex(...)` / `getToVertex(...)` | Build trace vertices |
| `rule.analysisVisitor.addResultNode(...)` | Add a result node to analysis data |
| `rule.analysisVisitor.resetAnalysisDataSink(node)` | Reset current sink analysis data |
| `rule.analysisVisitor.isSafeType(node)` | Check type-level safety |
| `rule.analysisVisitor.isUseMultiTaintVars()` | Check multi-taint mode |
| `rule.analysisVisitor.setControlFlowBroken(...)` / `getControlFlowBroken()` | Control-flow break marker |
| `rule.analysisVisitor.addParentFieldTrace(...)` | Add parent field trace |
| `rule.analysisVisitor.addSideEffectTrace(...)` | Add side-effect trace |
| `rule.analysisVisitor.addChildFieldTrace(...)` | Add child field trace |
| `rule.analysisVisitor.getFullNames(expressionText)` | Resolve possible full names |
| `rule.analysisVisitor.isRiskString(value)` | Check if a string is considered risky |
| `rule.analysisVisitor.checkNeedVisit(node)` | Check whether a node should be visited |
| `rule.analysisVisitor.handleInvokeMethodEnter(node)` / `handleInvokeMethodLeave(node)` | Custom invocation enter/leave bookkeeping |
| `rule.analysisVisitor.getVisitedMethodContext(node)` | Get visited method context |
