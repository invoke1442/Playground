# JavaScript Extend-File Extension Points API

Use these hooks when `userDefineFunc` is not the right extension point.

| Extension | Signature and use |
|---|---|
| `customSourceFunc` | `function(rule, node, context)` returns `true` when the node is a source |
| `validateFunction` | `function(rule, bugList)` filters or modifies bug reports after analysis |
| `entranceEvalFun` | `function(rule, sourceFile, extraParams)` returns `true` when a source file is an FSM entrance |
| `evalFun` | `function(rule, node, extraParams, context, beforeDestroyFlag)` returns `true` when an FSM condition matches; engine catches errors around this hook |
| `helperFunctions` | Export helper functions as properties on `rule` and call them from other hooks |

DSL references:

```javascript
source.customSourceFunc = loadclass("XssTs_6991.rule.customSourceFunc")
general.validateFunction = loadclass("XssTs_6991.rule.validateFunction")
entrance.entranceFunc = loadclass("csrfTs_7022.rule.entranceEvalFun")
condition.conditionFunc = loadclass("csrfTs_7022.rule.evalFun_0")
```
