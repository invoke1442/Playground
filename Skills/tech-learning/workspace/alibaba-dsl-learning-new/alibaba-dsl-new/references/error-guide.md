# Error Guide

This guide is not a catalog of successful live verifier responses from this environment. The official verify API endpoint is currently unavailable here. Entries are sourced from:

- `official-docs/alibaba-dsl-api-doc.md`, especially the official "common error messages" section.
- Local structural checks emitted by `scripts/lint_alibaba_dsl.py`.
- Inferences from official DSL field docs and bundled official configs, marked as inferred.

| Error or symptom | Source | Likely cause | Fix |
|---|---|---|
| `Line N, Column M: ParseError` | Official common error message | DSL parse error; a common local cause is placing `import roster` after fields or blocks | Move imports to the top of the Rule body, then rerun local lint |
| `IMPORT_AFTER_FIELD` | Local lint | `import roster` appears after fields or blocks | Move imports to the top of the Rule body |
| `can not find rule declaration in rule:ID` | Official common error message | `.rul` has no `Rule ... extends AbstractTaintRule` or wrong file uploaded | Check Rule declaration and tar root |
| `MISSING_RULE_DECL` | Local lint | Rule file has no `Rule ... extends AbstractTaintRule` declaration | Add the Rule declaration or fix the uploaded file |
| `content is null` | Inferred from verify API parameters and local packaging rules | `rule_id` does not match `{rule_id}.rul`, or the archive root does not contain the expected file | Rename file, pass the correct `--rule-id`, and check tar layout |
| `can not find roster declaration in roster:xxx` | Official common error message | `.ros` declaration missing or roster filename/name mismatch | Use `Roster Name {}` and file `Name_0.ros` |
| `MISSING_ROSTER_DECL` | Local lint | Roster file has no `Roster Name` declaration | Add the Roster declaration |
| `ROSTER_FILENAME_MISMATCH` | Local lint | Roster declaration and filename do not follow `Name_0.ros` convention | Rename file to `{RosterDeclaration}_0.ros` |
| Roster has no runtime effect | Inferred from official configs and relation layout | Rule does not import it or relation omits it | Add `import roster Name;` and relation `"Name_0"` |
| `IMPORTED_ROSTER_MISSING` | Local lint | Rule imports a roster that is absent from `rosters/` | Add `rosters/{Name}_0.ros` |
| `RELATION_MISSING_ROSTER` | Local lint | Relation config omits an imported roster | Add `{rule_id}: ["Name_0"]` |
| `cannot find field by name: xxx` | Official common error message | Field is unsupported in that language/block | Check the Java/JavaScript field reference and remove or move the field |
| `cannot find field by name: precise` | Inferred from JS field docs | JavaScript rule used Java-only `precise` | Remove `precise` from JS fields |
| `the field value is required` | Official common error message | Required field is missing | Add the required `value`, `pattern`, or field-specific value |
| `field pattern is required` | Inferred from JS sink/sanitizer field rules | JS sink/sanitizer used `value` or omitted `pattern` | Use `pattern`/`pattern +=` for JS sink/sanitizer calls |
| `the value should be string type` | Official common error message | Used a block where the field expects a string, or bad `loadclass +=` shape | Check field kind in language reference; Java loadclass usually goes inside `userDefineClass = loadclass(...)` |
| `invalid regular expression` | Official common error message | Bad regex escaping in DSL string | Escape backslashes for DSL strings and test the regex separately |
| `invalid xpath` | Official common error message | XPath syntax or unsupported axis/function | Minimize XPath and validate against known AST shapes |
| `invalid json` / `INVALID_RELATION_JSON` | Official common error message / local lint | Relation or `param` string has malformed JSON-ish syntax | Validate relation with `python -m json.tool`; compare `param` strings against templates |
| `ruleDir has no roster sub directory` / `NO_ROSTERS_DIR` | Inferred from official packaging rules / local lint | Missing `rosters/` for roster-based verification | Create `rosters/` and add at least one `.ros` |
| `LOADCLASS_FILE_NOT_FOUND` | Local lint | Extend-file path or class/file basename mismatch | Java: class basename must match `.java`; JS: first path segment must match `.js` |

When in doubt, create the smallest reproducer: one Rule, one Roster, one source, one sink, relation config, then add fields one at a time.
