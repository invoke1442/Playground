---
name: alibaba-dsl-new
description: Use when writing, debugging, reviewing, packaging, or verifying Alibaba DSL taint-analysis rules or rosters for Java or JavaScript web SAST, including .rul, .ros, import roster relations, loadclass extensions, source/sink/sanitizer/propagate modeling, and verify API errors.
---

# Alibaba DSL Taint Rules

## Overview

Use this skill to author Alibaba DSL web taint rules that are runnable by the official verifier. Treat a `.rul` Rule as the entry point and `.ros` Rosters as the reusable source/sink/sanitizer/propagate model library.

## Verify API Status

The official verify API should be treated as part of the normal validation flow, but the deployed verify URL may change over time. Run local lint first, then use `scripts/verify_alibaba_dsl.py` when you need official verifier acceptance. If the deployment endpoint has changed, pass `--url` or set `ALIBABA_DSL_VERIFY_URL` instead of editing commands by hand.

## Workflow

1. Identify language (`java` or `javascript`), vulnerability type, source, sink, sanitizer, and propagation assumptions.
2. Treat `references/` as the API source of truth. `SKILL.md` gives workflow and routing only. Do not write API signatures, field names, return semantics, or loadclass paths from memory.
3. Read only the needed references:
   - Java `.rul/.ros` fields: `references/java-dsl-syntax.md`
   - Java loadclass entry: `references/java-loadclass.md`
   - Java loadclass detailed API: `references/java-loadclass/INDEX.md`
   - JavaScript `.rul/.ros` fields: `references/javascript-dsl-syntax.md`
   - JavaScript extend-file entry: `references/javascript-extend-file.md`
   - JavaScript extend-file detailed API: `references/javascript-extend-file/INDEX.md`
   - Web vulnerability modeling patterns: `references/web-taint-patterns.md`
   - Verify API and packaging details: `references/verification.md`
   - Error messages and fixes: `references/error-guide.md`
4. For Java loadclass work, read `references/java-loadclass.md` and `references/java-loadclass/GENERAL.md` before choosing task-specific API files from `references/java-loadclass/INDEX.md`.
5. For JavaScript extend-file work, read `references/javascript-extend-file.md` and `references/javascript-extend-file/GENERAL.md` before choosing task-specific API files from `references/javascript-extend-file/INDEX.md`.
6. Treat the syntax references as already integrated: `java-dsl-syntax.md` and `javascript-dsl-syntax.md` carry the unified Rule/Roster conclusions, while `java-loadclass/` and `javascript-extend-file/` carry the unified extension-mechanism conclusions.
7. Create a config directory with this shape:
   ```text
   config/
   ├── 90001.rul
   ├── rosters/
   │   └── RosterName_0.ros
   ├── relation/
   │   └── config_roster_relation.json
   └── extend-file/
       ├── 90001/CustomClass.java
       └── rosters/RosterName_0/CustomClass.java
   ```
   For JavaScript, use `.js` extend files and `relation/config_addition_relation.json` when matching official JS examples.
8. Put all `import roster ...;` statements at the top of the Rule body, before `type`, `subType`, or any field assignment. Import by roster declaration name, not filename: `import roster Java_web_taint;`.
9. Add relation entries using the rule id and roster file stem: `{ "90001": ["Java_web_taint_0"] }`.
10. Run local lint:
   ```bash
   python scripts/lint_alibaba_dsl.py path/to/config --language java
   python scripts/lint_alibaba_dsl.py path/to/config --language javascript
   ```
11. Report validation status precisely: say whether local lint passed or failed, and say whether remote verify was run with `scripts/verify_alibaba_dsl.py` and what it returned.

## Core Rules

- `.rul` filename should match the numeric rule id passed to `verify_type=rule`.
- `.ros` filename should be `{RosterDeclaration}_0.ros`; the declaration inside stays `Roster RosterDeclaration`.
- Rule `import roster` names omit `_0`; relation config names include `_0`.
- Use plain tar, not tar.gz or zip.
- Prefer Rosters for most source/sink/sanitizer/propagate definitions. Use Rule fields only for rule-specific overrides.
- Use `group Name { includePlatforms = "..."; ... };` for framework/platform-specific behavior.
- Use `exclude` on imports to disable tagged groups or items, for example `import roster Java_common_propagate exclude StringConcatMethod;`.
- Add `loadclass` when DSL field matching cannot express the needed AST or data-flow condition.

## Java Notes

- Java block fields commonly use `value`, optional `precise`, and optional `param`, `tag`, `excludeTag`, or `xpath`.
- Choose sanitizer fields by data-flow shape: use `sanitizer.methodReturn` when the method returns a safe replacement value; use `sanitizer.methodArg` when a validator/checker marks its argument safe. Official SSRF configs model `com.alibaba.security.SecurityUtil.checkSSRF` as `sanitizer.methodArg`.
- Java loadclass points to a JVM class: `loadclass("com.taobao.customrule.FilterSource")`.
- Java taint extensions normally expose static `Boolean evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)`.

## JavaScript Notes

- JavaScript source blocks use `value` or `value +=`; sink/sanitizer call blocks use `pattern` or `pattern +=`.
- Do not use Java-only `precise` in JavaScript rules.
- JavaScript loadclass points to a CommonJS export path: `loadclass("XssTs_90002.rule.userDefineFunc")`.
- In JS `userDefineFunc`, return `false` unless the custom function deliberately replaces default analysis for the node.

## Common Recovery

| Symptom | Fix |
|---|---|
| `IMPORT_AFTER_FIELD` or `ParseError` near `import` | Move every `import roster` to the first statements in the Rule body. |
| `content is null` or rule not found | Ensure `rule_id` equals the `.rul` filename stem. |
| Imported roster has no effect | Ensure both Rule `import roster Name;` and relation `"Name_0"` are present. |
| `cannot find field by name: precise` in JS | Remove `precise`; use JS `value`/`pattern` fields. |
| `field pattern is required` in JS sink/sanitizer | Use `pattern`, not `value`, for JS sink/sanitizer call blocks. |
| `loadclass` file not found | Match Java class basename or JS file basename with the extend-file directory layout. |

Use `assets/templates/java/` and `assets/templates/javascript/` as copyable starting points for new rule packages.
