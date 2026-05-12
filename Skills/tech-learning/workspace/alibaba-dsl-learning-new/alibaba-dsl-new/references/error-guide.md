# Error Guide

This guide combines official verifier error texts, broad verification notes, and local structural checks. Entries are sourced from:

- `official-docs/alibaba-dsl-api-doc.md`, especially the official "common error messages" section.
- `alibaba-dsl-learning-notes.md` broad verification notes collected during active syntax iteration.
- Local structural checks emitted by `scripts/lint_alibaba_dsl.py`.
- Inferences from official DSL field docs and bundled official configs, marked as inferred.

Historical entries should be treated as supporting syntax evidence. When current behavior matters, confirm it with `scripts/verify_alibaba_dsl.py` after local lint passes.

| Error or symptom | Source | Likely cause | Fix |
|---|---|---|
| `Line N, Column M: ParseError` | Official common error message | DSL parse error; a common local cause is placing `import roster` after fields or blocks | Move imports to the top of the Rule body, then rerun local lint |
| `Line 1, Column 1: Lexical error` | Official common error message | Uploaded content starts with bytes or tokens the DSL lexer cannot accept, or the archive points at the wrong file content | Check encoding, file root, and that the expected `.rul` or `.ros` is uploaded |
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
| `cannot find field by name: param` | Broad verification notes | `param` was added outside confirmed Java fields, such as `sink.methodObject`, `sink.allocArg`, or JavaScript `sink.methodArg` | Keep `param` on confirmed Java `sink.methodArg` patterns only |
| `the field value is required` | Official common error message | Required field is missing | Add the required `value`, `pattern`, or field-specific value |
| `field pattern is required` | Inferred from JS sink/sanitizer field rules | JS sink/sanitizer used `value` or omitted `pattern` | Use `pattern`/`pattern +=` for JS sink/sanitizer calls |
| `the value should be string type` | Official common error message | Used a block where the field expects a string, or bad `loadclass +=` shape | Check field kind in language reference; Java loadclass usually goes inside `userDefineClass = loadclass(...)` |
| `value should be complex type` | Broad verification notes | Used direct string assignment where a block is required, such as Java `sanitizer.methodReturn` or `sanitizer.methodArg` | Use the block syntax required by the field |
| `custom define config: source.X can only be string value` | Broad verification notes | Used block syntax for string-only compatibility fields such as `source.param_annotation`, `source.method_annotation`, `source.method_param`, or `source.expression` | Use direct string assignment or prefer the verified camelCase block field when applicable |
| `configure is not modifiable in parent rule` | Broad verification notes | Tried to use non-modifiable compatibility fields in a child Rule or wrong scope | Move the definition to a Roster or use the verified camelCase field where supported |
| `invalid regular expression` | Official common error message | Bad regex escaping in DSL string | Escape backslashes for DSL strings and test the regex separately |
| `invalid xpath` | Official common error message | XPath syntax or unsupported axis/function | Minimize XPath and validate against known AST shapes |
| `invalid json` / `INVALID_RELATION_JSON` | Official common error message / local lint | Relation or `param` string has malformed JSON-ish syntax | Validate relation with `python -m json.tool`; compare `param` strings against templates |
| `curl: (7) Failed to connect ... Connection refused` | Iteration-6 live verify attempts | The configured verify host/port is stale, blocked, or down | Override the endpoint with `--url` or `ALIBABA_DSL_VERIFY_URL`, then retry |
| `curl: (56) Recv failure: Connection reset by peer` | Iteration-6 live verify attempts | The server closed the connection before returning a verifier response; URL, protocol, or upstream routing may have changed | Re-check the current deployment endpoint and retry with the correct URL before assuming a DSL syntax problem |
| `ruleDir has no roster sub directory` / `NO_ROSTERS_DIR` | Inferred from official packaging rules / local lint | Missing `rosters/` for roster-based verification | Create `rosters/` and add at least one `.ros` |
| `LOADCLASS_FILE_NOT_FOUND` | Local lint | Extend-file path or class/file basename mismatch | Java: class basename must match `.java`; JS: first path segment must match `.js` |

When in doubt, create the smallest reproducer: one Rule, one Roster, one source, one sink, relation config, then add fields one at a time.
