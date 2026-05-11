# JavaScript Extend-File Reference Entry

JavaScript extend-file code handles AST/runtime behavior that `.rul/.ros` fields cannot express. This file is only the navigation entry; read the detailed files under `references/javascript-extend-file/` for API facts.

## Read Order

1. Always read `references/javascript-extend-file/INDEX.md` to choose the minimum needed files.
2. Always read `references/javascript-extend-file/GENERAL.md` before writing or reviewing JS extend-file code.
3. Read task-specific files:
   - Loading, `loadclass`, and `userDefineFunc` lifecycle: `references/javascript-extend-file/loading-and-lifecycle.md`
   - `rule` and TypeScript AST `node` shape: `references/javascript-extend-file/runtime-params-api.md`
   - `rule.analysisVisitor`: `references/javascript-extend-file/visitor-api.md`
   - `context`, `SinkType`, `MethodContext`, `Vertex`: `references/javascript-extend-file/context-api.md`
   - `TaintVarSet`: `references/javascript-extend-file/taint-var-set-api.md`
   - Built-in modules and utility APIs: `references/javascript-extend-file/builtin-modules-api.md`
   - Other hooks: `references/javascript-extend-file/extension-points-api.md`
   - Copyable patterns: `references/javascript-extend-file/examples.md`

## Common Layout

```text
extend-file/{rule_id}/XssTs_90002.js
extend-file/rosters/{RosterName}_0/NodeJS_web_taint.js
```

```javascript
general.userDefinePatternClass = loadclass("XssTs_90002.rule.userDefineFunc")
```

Use JS extend-file for framework-specific AST traversal, custom source identification, result filtering, or bug-reporting logic that field matching cannot express.
