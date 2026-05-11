# Iteration 1 Learning Notes

## Scope

Source material was limited to:

- `official-docs/alibaba-dsl-api-doc.md`
- `official-docs/java-loadclass-api.md`
- `official-docs/javascript-extend-file-api.md`
- `official-docs/configs_v3.3`
- `official-docs/demo_roster_rule`

The older `alibaba-dsl-learning` directory was not used.

## Rule/Roster Model

- `.rul` files define `Rule ... extends AbstractTaintRule`.
- `.ros` files define `Roster Name`.
- Production Java rules in `configs_v3.3` consistently place `import roster` statements first in the Rule body.
- Rule imports use roster declaration names, while relation config uses file stems with `_0`.
- A runnable config package usually needs both:
  - Runtime link: `import roster Name;`
  - Verifier discovery link: `relation/config_roster_relation.json` mapping rule id to `Name_0`

## Packaging

- Official verifier accepts plain tar archives.
- Rule verification needs `.rul`; roster verification needs `rosters/*.ros`.
- Java official configs use `config_roster_relation.json`.
- JS official examples use `config_addition_relation.json` plus `actual_use_config.json`.

## Java DSL

Common official fields include:

- `source.methodReturn`, `source.methodParam`, `source.paramAnnotation`, `source.mvcMapping`
- `sink.methodArg`, `sink.methodObject`, `sink.allocArg`
- `sanitizer.methodReturn`, `sanitizer.methodArg`, `sanitizer.safeTypes`, `sanitizer.safeVarNames`
- `propagate.customMethodPropagate`, `propagate.methodObjectToReturn`, `propagate.methodArgOrObjectToObjectAndReturn`
- `general.userDefinePatternClass`, `general.userDefineEntranceClass`, `general.entranceFileXpath`

Java block items often support `value`, optional `precise`, `param`, `tag`, and `excludeTag`.

For sanitizers, match the field to the official data-flow shape. Replacement APIs usually use `sanitizer.methodReturn`; checker APIs may mark an argument safe. The official SSRF roster models `com.alibaba.security.SecurityUtil.checkSSRF` as `sanitizer.methodArg`, not `methodReturn`.

## Java Loadclass

- Java loadclass links to JVM class names, for example `loadclass("com.taobao.customrule.FilterSource")`.
- Common taint signature: `public static Boolean evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)`.
- Useful APIs from official docs include `ASTPrimaryExpression.getCallString()`, `getClassName()`, `ASTExpression.getLiteralValue()`, `ASTUtil.findFirstNode`, and `CodeUtil.getEnclosingClassName`.

## JavaScript DSL

- JS sources use `value`/`value +=`.
- JS sinks and sanitizers use `pattern`/`pattern +=`.
- JS should not use Java-only `precise`.
- JS `loadclass("XssTs_90002.rule.userDefineFunc")` resolves to `{fileName}.js`, then CommonJS property path.
- `userDefineFunc(rule, node, context)` returns `true` to skip default analysis and `false` to continue it.
- The JS engine does not wrap `userDefineFunc` in try/catch, so custom functions must fail closed.

## Experiments

- `invalid-import-order` confirms local lint catches Rule fields before imports as `IMPORT_AFTER_FIELD`.
- `valid-java-web-taint` passes local lint.
- `valid-js-web-taint` passes local lint.
- Remote verify API calls to `43.106.136.189:8081` timed out in this environment; artifacts are stored under experiment `.verify-*` directories.

## Skill Design Decisions

- Keep `SKILL.md` under 5000 words and focused on workflow.
- Move field matrices and loadclass details to references.
- Bundle `lint_alibaba_dsl.py` to catch structural mistakes before expensive remote verify.
- Bundle `verify_alibaba_dsl.py` to standardize plain tar packaging and binary multipart upload.
- Include Java and JS templates under `assets/templates`.
