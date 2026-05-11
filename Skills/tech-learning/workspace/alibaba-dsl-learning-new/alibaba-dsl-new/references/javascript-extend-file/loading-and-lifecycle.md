# JavaScript Extend-File Loading And Lifecycle

## Discovery Order

Official JS discovery order is:

1. Explicit `extendFileDir`.
2. `{ruleDir}/../rule-extend-file/`.
3. `{ruleDir}/extend-file/`.

Rules can store extend files under `extend-file/{rule_id}/`; roster extensions can store them under `extend-file/rosters/{RosterName}_0/`. Extend files are loaded during rule initialization and reused during scanning.

## Loadclass Resolution

`loadclass("XssTs_90002.rule.userDefineFunc")` resolves to:

1. `XssTs_90002.js` in the selected extend-file directory.
2. `require()` of that file.
3. `module.exports.rule`.
4. property `userDefineFunc`.
5. function source text embedded into the generated rule.

Common DSL references:

```javascript
general.userDefinePatternClass = loadclass("XssTs_6991.rule.userDefineFunc")
source.customSourceFunc = loadclass("XssTs_6991.rule.customSourceFunc")
general.validateFunction = loadclass("XssTs_6991.rule.validateFunction")
entrance.entranceFunc = loadclass("csrfTs_7022.rule.entranceEvalFun")
condition.conditionFunc = loadclass("csrfTs_7022.rule.evalFun_0")
```

## userDefineFunc Semantics

| Return | Effect |
|---|---|
| `false` | Continue engine default analysis |
| `true` | Skip default analysis for that node; use only when custom logic fully handles it |

Multiple userDefineFunc values from Rule and imported Rosters are merged into an array. Every function is called, later functions still run after one returns `true`, and the final result is `true` if any function returns `true`.

`userDefineFunc` has no try-catch wrapper in the engine. Catch expected errors inside the function and return `false`; otherwise the current file analysis can be interrupted.

## Call Sites

| Visitor | Node types that call `handleUserDefine` |
|---|---|
| `TaintAnalysisVisitor` | `ExpressionStatement`, `VariableStatement`, `IfStatement`, `ForOfStatement`, `ForInStatement`, `WhileStatement`, `ForStatement`, `BinaryExpression`, `ElementAccessExpression`, `ReturnStatement`, `CallExpression`, `TypeOfExpression`, `DeleteExpression` |
| `FsmAnalysisVisitor` | `Constructor`, `FunctionDeclaration`, `FunctionExpression`, `ArrowFunction`, `MethodDeclaration`, `ExpressionStatement`, `VariableStatement`, `ReturnStatement`, `IfStatement`, `CallExpression` |

In taint analysis, `true` skips default analysis for the current node. In FSM analysis, `true` may replace default traversal for function-like nodes or skip default processing for statement/call nodes.
