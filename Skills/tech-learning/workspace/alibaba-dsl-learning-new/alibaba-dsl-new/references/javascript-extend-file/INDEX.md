# JavaScript Extend-File Index

Use this directory for JavaScript extend-file API details. Read `GENERAL.md` first, then only the files needed for the task.

| Task | Read |
|---|---|
| Understand `extendFileDir`, directory discovery, `loadclass`, or `userDefineFunc` call timing | `GENERAL.md`, `loading-and-lifecycle.md` |
| Inspect `rule` fields or TypeScript AST `node` shapes | `GENERAL.md`, `runtime-params-api.md` |
| Report bugs, build traces, or interact with current visitor state | `GENERAL.md`, `visitor-api.md`, `context-api.md` |
| Read or mutate taint variables | `GENERAL.md`, `taint-var-set-api.md` |
| Use `require("../global")`, `require("../util")`, `TypeScriptVisitorAdapter`, or `MapOfVariable` | `GENERAL.md`, `builtin-modules-api.md` |
| Implement `customSourceFunc`, `validateFunction`, FSM entrance, FSM condition, or helpers | `GENERAL.md`, `extension-points-api.md` |
| Start from a safe skeleton | `GENERAL.md`, `examples.md` |

Do not rely on memory for visitor/context/TaintVarSet APIs. Load the specific API file before using method names or signatures.
