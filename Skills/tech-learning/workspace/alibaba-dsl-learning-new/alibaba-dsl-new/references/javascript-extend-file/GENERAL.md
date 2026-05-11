# JavaScript Extend-File General

JavaScript extend-file code is loaded by the Node.js-based TypeScript engine with `require()`. DSL `loadclass("fileName.property.path")` resolves `fileName + ".js"`, reads `module.exports`, walks the property path, and embeds the function source.

## Required Conventions

- Store rule-specific files under `extend-file/{rule_id}/`.
- Store roster-specific files under `extend-file/rosters/{RosterName}_0/`.
- Export a CommonJS object, usually `module.exports.rule = rule`.
- Use TypeScript compiler guards such as `ts.isCallExpression(node)` before reading node-specific fields.
- In `userDefineFunc`, return `false` unless the custom code fully replaces default processing for the node.
- `userDefineFunc` has no engine try/catch wrapper. Wrap custom code in `try/catch` and return `false` on expected errors.

## Typical Uses

- Framework-specific AST traversal.
- Custom source identification.
- Custom sink trace or bug report creation.
- Result filtering with `validateFunction`.
- FSM entrance or condition evaluation.

## API File Map

- `loading-and-lifecycle.md`: discovery order, `loadclass`, merge behavior, visited node types.
- `runtime-params-api.md`: `rule` fields and TypeScript AST `node` basics.
- `visitor-api.md`: `rule.analysisVisitor` APIs.
- `context-api.md`: `context`, `SinkType`, `MethodContext`, `Vertex`.
- `taint-var-set-api.md`: `TaintVarSet`.
- `builtin-modules-api.md`: built-in `require()` modules and utilities.
- `extension-points-api.md`: hooks other than `userDefineFunc`.
- `examples.md`: skeletons and traversal patterns.
