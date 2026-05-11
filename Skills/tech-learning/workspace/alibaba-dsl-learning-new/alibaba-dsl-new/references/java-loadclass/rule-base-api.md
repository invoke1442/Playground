# Java Loadclass Rule Base API

Use these APIs when a Java loadclass must inspect or modify taint/FSM state.

## BaseTaintedDataRule

| API | Use |
|---|---|
| `BaseTaintedDataRule.getGraphs()` / `setGraphs(...)` | Static trace graph access |
| `BaseTaintedDataRule.getEntranceSources()` | Entrance source graph data |
| `BaseTaintedDataRule.addEntranceSource(...)` | Add an entrance source trace node |
| `BaseTaintedDataRule.addCriticalNode(...)` / `addDbCriticalNode(...)` | Mark critical trace nodes |
| `BaseTaintedDataRule.addFieldEdge(...)` / `addEdgeToGraph(...)` / `addNodeToGraph(...)` | Add graph structure |
| `BaseTaintedDataRule.handleSingleVar(var, node)` | Evaluate one variable against current taint state |
| `BaseTaintedDataRule.handleSingleVar(var, node, handleContainer)` | Evaluate one variable with container handling |
| `BaseTaintedDataRule.handleUserDefineInvoke(...)` | Handle custom invocation summary/propagation |
| `BaseTaintedDataRule.handleUserDefineTaintFlow(TaintedResult, MapOfVariable, AbstractJavaNode)` | Propagate taint from a result to a variable |
| `BaseTaintedDataRule.handleUserDefineTaintFlow(MapOfVariable, MapOfVariable, AbstractJavaNode)` | Propagate taint from one variable to another |
| `BaseTaintedDataRule.addTaintedVariable(MapOfVariable, boolean, AbstractJavaNode)` | Add or reassign a tainted variable |

## AbstractTaintedDataRule

| API | Use |
|---|---|
| `AbstractTaintedDataRule.getVisitedMethodShortName()` | Current method short name |
| `AbstractTaintedDataRule.getVisitedMethodProfile()` | Current method profile |
| `AbstractTaintedDataRule.getVisitedMethodContext()` | Current `MethodContext` |
| `AbstractTaintedDataRule.isPrimitiveType(type)` / `isEnumType(typeName)` | Type filters |
| `AbstractTaintedDataRule.isArgTypeSafe(...)` | Check whether argument type is configured safe |
| `AbstractTaintedDataRule.isArgumentTainted(...)` | Check an argument list against a param pattern |
| `AbstractTaintedDataRule.isVariableMayTainted(MapOfVariable)` | Check possible variable taint |
| `AbstractTaintedDataRule.isTainted(...)` / `isTaint(...)` / `isSafe(...)` | Result-state helpers |
| `AbstractTaintedDataRule.getTaintVarSet(results, taintTag)` | Extract taint variables from result sets |
| `AbstractTaintedDataRule.getParamVariables(profile)` | Get method parameter variables |
| `AbstractTaintedDataRule.getSelfSummaryByProfile(profile)` | Fetch current rule method summary |
| `AbstractTaintedDataRule.getFlag()` / `setFlag(...)` | Current rule flag |
| `AbstractTaintedDataRule.getCurrentEntrance()` / `setCurrentEntrance(...)` | Current entrance marker |

## BaseFSMMachineRule

| API | Use |
|---|---|
| `BaseFSMMachineRule.getGraphs()` / `setGraphs(...)` | FSM graph access |
| `BaseFSMMachineRule.getDirectGraph()` / `setDirectGraph(...)` | Current direct graph |
| `BaseFSMMachineRule.getVisitedMethodShortName()` | Current method short name |
| `BaseFSMMachineRule.getParentMethodShortName()` / `getParentMethodProfile()` | Caller context |
| `BaseFSMMachineRule.getParentNode()` | Parent AST node |
| `BaseFSMMachineRule.getLogInfo()` | FSM log builder |
| `BaseFSMMachineRule.getMaxAnalysisDepth()` | Depth budget |
| `BaseFSMMachineRule.getVisitedMethods()` | Visited method set |
