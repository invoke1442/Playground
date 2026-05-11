# Java Loadclass Reference Entry

Java loadclass is for AST/data-flow conditions that `.rul/.ros` fields cannot express. This file is only the navigation entry; read the detailed files under `references/java-loadclass/` for API facts.

## Read Order

1. Always read `references/java-loadclass/INDEX.md` to choose the minimum needed files.
2. Always read `references/java-loadclass/GENERAL.md` before writing or reviewing Java loadclass code.
3. Read task-specific files:
   - Entrypoints and return semantics: `references/java-loadclass/evaluate-lifecycle.md`
   - PMD Java AST custom methods: `references/java-loadclass/ast-node-api.md`
   - Taint/FSM rule APIs: `references/java-loadclass/rule-base-api.md`
   - Taint variables, results, trace nodes, method context: `references/java-loadclass/data-model-api.md`
   - `InterDataCache`, `ASTUtil`, `CodeUtil`, and other helpers: `references/java-loadclass/toolclass-api.md`
   - Copyable patterns: `references/java-loadclass/examples.md`

## Common Layout

```text
extend-file/{rule_id}/FilterSource.java
extend-file/rosters/{RosterName}_0/FilterSource.java
```

```java
general.userDefinePatternClass += {
    userDefineClass = loadclass("com.taobao.customrule.FilterSource");
};
```

Keep loadclass narrow and defensive: null-check nodes, check node types before casting, and return `false` on unknown node shapes.
