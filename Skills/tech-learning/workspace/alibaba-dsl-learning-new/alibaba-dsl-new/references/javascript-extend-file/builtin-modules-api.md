# JavaScript Extend-File Built-In Modules API

Commonly confirmed modules:

| Module | Use |
|---|---|
| `require("../logger")` | `SimpleLogger` |
| `require("../global")` | `GlobalContext` |
| `require("typescript")` | TypeScript compiler API and `ts.is*` guards |
| `require("../util")` | XPath, source-location, const-string, name/path, property-access, file/config/framework helpers |
| `require("hashmap")` | HashMap data structure |
| `require("../../visitor")` | `TypeScriptVisitorAdapter` for custom AST traversal |
| `require("../InterApp/MapofVariable")` | `MapOfVariable.getVarFromNode(node)` |
| `require("../taintAnalysis/TagInfo")` | Tag info adapter |
| `require("module")` / `require("vm")` | Node built-ins used by engine examples |

## GlobalContext

Useful `GlobalContext` fields include `configParser`, `scopeVisitor`, `fullNameVisitor`, `languageService`, `targetProjectDir`, `routerEntries`, `relativeFilePathToAst`, export maps, DI/router/HSF maps, and framework maps.

Useful methods include `GlobalContext.httpEntrance(...)`, `GlobalContext.xpathEntrance(...)`, `GlobalContext.csrfEntrance(...)`, `GlobalContext.allEntrance(...)`, `GlobalContext.matchCallString(...)`, and `GlobalContext.commonLog(...)`.

## util

Useful `util` functions include `util.findNodesByXpath(...)`, `util.findFirstNodeByXpath(...)`, line/column helpers, `util.getConstString(...)`, `util.getConstStringStrict(...)`, name/path helpers, `util.getMostLeftNode(...)`, `util.collectLeftNames(...)`, `util.isSimplePropertyAccessExpression(...)`, file helpers, `util.getConfigString(...)`, `util.getMemberValue(...)`, `util.isMethodCallShouldExpand(...)`, and `util.addVertexFlag(...)`.

## MapOfVariable

Use `MapOfVariable.getVarFromNode(node)` to convert an AST node into a taint variable.

## TypeScriptVisitorAdapter

Use `TypeScriptVisitorAdapter` from `require("../../visitor")` for custom traversal when direct node inspection is not enough.
