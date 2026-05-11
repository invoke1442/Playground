# Java Loadclass Data Model API

Use these types when reading or writing taint state, trace data, and method context.

## TaintedResult

`TaintedResult` represents taint/safe/sink matching state. Common methods include:

`copy()`, `detachCopy()`, `copyTo(...)`, `getName()`, `getMethodName()`, `getSink()`, `setSink(...)`, `getSafe()`, `setSafe(...)`, `getMethodSignature()`, `setCritical(...)`, `isCritical()`, `getTaintSubPathes()`, `getSafeSubPathes()`, `getTaintedVar()`, `setTaintedVar(...)`, `isPrecise()`, `isApproximate()`, `isBlackBox()`, `getMultiTaintVar()`, `getMultiTaintSubPathes()`, `getMultiSafeSubPathes()`, `getMatchArgPos()`, and `fixLineBias(...)`.

## MapOfVariable

`MapOfVariable` is the variable identity used by taint APIs. Common methods include `copy()`, `detachCopy()`, `mockCopy()`, `isNone()`, `getBaseVariable()`, `getOriginBaseVariable()`, `getImage()`, `getSubPath()`, `setSubPath(...)`, `isSymbolic()`, `isReturn()`, `isLocalVar()`, `isMemberVar()`, `startsWith(...)`, and `isCritical()`.

Static helpers:

- `MapOfVariable.getMapOfVariableFromString(...)`
- `MapOfVariable.getTempMapOfVariable(...)`
- `MapOfVariable.getMapOfVariableFromNode(node)`
- `MapOfVariable.getMapOfVariableFromNodeWithDecl(node)`
- `MapOfVariable.getMapOfVariable(...)`

## InterJavaTracerNode

`InterJavaTracerNode` builds trace graph vertices. Constructors accept name, method name/signature, line/column ranges, and `TracerNode.TYPE`. Common methods include getters/setters for classpath, code segment, method signature, flag, app name, line/column ranges, variable type, black-box marker, method begin/end lines, and tag.

## MethodArgs

`MethodArgs` exposes argument order/type/name, `TaintedResult`, `TaintedResultSet`, argument expression, and parameter name.

## MethodContext

`MethodContext` tracks per-method taint state with `MethodContext.addTaintedVariable(...)`, `MethodContext.addMultiTaintedVariable(...)`, `MethodContext.addSafeVariable(...)`, `MethodContext.removeTaintedVariable(...)`, `MethodContext.isTaintedVariable(...)`, `MethodContext.isMultiTaintedVariable(...)`, `MethodContext.isSafeVariable(...)`, `MethodContext.addMustSafeVariable(...)`, `MethodContext.addUpcastVariable(...)`, `MethodContext.addInputVariable(...)`, `MethodContext.addTaintArg(...)`, `MethodContext.getClassName()`, `MethodContext.getTaintedReturn()`, and `MethodContext.getCustomData()`.
