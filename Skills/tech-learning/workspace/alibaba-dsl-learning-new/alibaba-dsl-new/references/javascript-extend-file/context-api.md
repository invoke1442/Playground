# JavaScript Extend-File Context API

`context` is usually `TaintAnalysisContext` or `FsmAnalysisContext`.

## Shared Context APIs

Common APIs include:

- `context.getTaintContext()`
- `context.setTaintContext(...)`
- `context.setMultiTaintContext(...)`
- `context.copyTaintContext(...)`
- `context.clearTaint()`
- `context.isTaintContext()`
- method-context stack helpers
- invoke-flag helpers
- field taint helpers
- method-argument context
- `context.getCustomData()`
- return-taint helpers
- parent/ancestor taint context helpers

## TaintAnalysisContext-Specific APIs

- `context.isSafeContext()`
- `context.setSafe(...)`
- `context.addReturnTaintContextWithInstance(...)`
- `context.handleDistinctReturnContext(...)`
- `context.checkInvokeParentTaint(...)`
- `context.setTaintContextByAllArg(...)`

## FsmAnalysisContext-Specific APIs

- `context.getFsmInstances()`
- `context.getCurrentEntrance()`
- `context.setCurrentEntrance(...)`

## Key Interfaces

Key runtime interfaces include `TaintContext`, `SinkType`, `MethodContext`, and `Vertex`.

`SinkType` is used when constructing traces, including `SinkType.Trace` and `SinkType.Output`.
