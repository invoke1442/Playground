# Java Loadclass General

Java loadclass links DSL fields to JVM classes, for example `loadclass("com.taobao.customrule.FilterSource")`. Use it when DSL fields cannot express a required AST condition, framework entrypoint, false-positive filter, or custom taint propagation.

## Required Conventions

- Put Java files under `extend-file/{rule_id}/` or `extend-file/rosters/{RosterName}_0/`.
- The Java class basename must match the `.java` filename.
- Loadclass methods are called reflectively with `Method.invoke(null, ...)`, so entrypoints should be `public static`.
- Return `Boolean.TRUE` only when the custom condition matches. Return `Boolean.FALSE` for non-matches. Avoid `null`; the engine treats it as false.
- Keep code defensive: check `treenode` type before casting and tolerate missing resolved type/call metadata.

## Typical Uses

- Match enclosing class, implemented interface, annotations, or framework entrypoints.
- Match literal values or AST shapes not represented by DSL fields.
- Add explicit taint propagation between variables.
- Filter overly broad DSL matches after field constraints are insufficient.

## API File Map

- `evaluate-lifecycle.md`: entrypoint signatures, return semantics, `TracerNode.TYPE`, flags.
- `ast-node-api.md`: PMD Java AST custom methods.
- `rule-base-api.md`: `BaseTaintedDataRule`, `AbstractTaintedDataRule`, `BaseFSMMachineRule`.
- `data-model-api.md`: `TaintedResult`, `MapOfVariable`, trace nodes, arguments, method context.
- `toolclass-api.md`: cache/type/AST/code/rule utility APIs.
- `examples.md`: skeletons and usage patterns.
