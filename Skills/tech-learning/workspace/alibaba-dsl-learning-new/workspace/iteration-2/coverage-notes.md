# Iteration 2 API Coverage Notes

## Goal

Check whether the concrete API information in `official-docs/java-loadclass-api.md` and `official-docs/javascript-extend-file-api.md` is sufficiently present in the `alibaba-dsl-new` skill.

## Finding

The first-iteration skill was not sufficient for the two detailed official API documents:

- `references/java-loadclass.md` covered the common taint signature and a few AST/helper APIs, but missed most official evaluate overloads, Java AST custom methods, rule base APIs, data models, trace nodes, method contexts, and tool/cache utilities.
- `references/javascript-dsl-syntax.md` covered basic `.rul/.ros` syntax and a minimal `userDefineFunc`, but missed official extend-file discovery, `userDefineFunc` merge/lifecycle details, visitor/context APIs, `TaintVarSet`, built-in `require()` modules, and non-`userDefineFunc` extension points.

## Changes Made

- Expanded `references/java-loadclass.md` into a compact API cheat sheet for:
  - reflective `evaluate(...)` lifecycle and discovered signatures;
  - `TracerNode.TYPE` and known flags;
  - Java AST custom methods;
  - `BaseTaintedDataRule`, `AbstractTaintedDataRule`, and `BaseFSMMachineRule`;
  - `TaintedResult`, `MapOfVariable`, `InterJavaTracerNode`, `MethodArgs`, and `MethodContext`;
  - `InterDataCache`, `InterAppTypeInfor`, `ASTUtil`, `CodeUtil`, and `JavaRuleUtil`.
- Expanded `references/javascript-dsl-syntax.md` for:
  - `extendFileDir`, fallback discovery paths, rule/roster extend-file layout, and loadclass property resolution;
  - `userDefineFunc` merge behavior, node lifecycle, return semantics, and lack of engine try-catch;
  - `rule`, `node`, and `context` runtime APIs;
  - `rule.analysisVisitor` methods and visitor names;
  - `TaintVarSet` API;
  - built-in modules such as `require("../global")`, `require("../util")`, `require("../../visitor")`, and `require("../InterApp/MapofVariable")`;
  - `customSourceFunc`, `validateFunction`, `entranceEvalFun`, `evalFun`, and `helperFunctions`.
- Updated the JS extend-file template to wrap `userDefineFunc` in `try/catch` and return `false` on exceptions.
- Added `workspace/iteration-2/test_api_coverage.py` to make the coverage check repeatable.

## Boundary

The skill now contains a practical API surface for authoring and debugging extensions. It intentionally does not duplicate every line of the official documents. Full exhaustive detail remains in `official-docs/`.

The official verify API endpoint remains unavailable from this environment. No remote verify commands, `curl` probes, or `verify_alibaba_dsl.py` remote calls were used in this iteration.
