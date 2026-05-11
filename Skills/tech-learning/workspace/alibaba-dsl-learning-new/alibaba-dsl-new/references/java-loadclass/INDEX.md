# Java Loadclass Index

Use this directory for Java loadclass/PMD extension API details. Read `GENERAL.md` first, then only the files needed for the task.

| Task | Read |
|---|---|
| Choose or review an `evaluate(...)` signature | `GENERAL.md`, `evaluate-lifecycle.md` |
| Match calls, literals, annotations, method names, or AST shape | `GENERAL.md`, `ast-node-api.md` |
| Add custom taint propagation or query taint state | `GENERAL.md`, `rule-base-api.md`, `data-model-api.md` |
| Build trace nodes or work with method context | `GENERAL.md`, `data-model-api.md` |
| Resolve class names, call strings, method declarations, inheritance, XPath, or cached inter-procedural info | `GENERAL.md`, `toolclass-api.md` |
| Start from a safe skeleton | `GENERAL.md`, `examples.md` |

Do not rely on memory for package APIs. Load the specific API file before using method names or signatures.
