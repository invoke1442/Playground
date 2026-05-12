# JavaScript DSL Syntax

Use this file for JavaScript `.rul/.ros` field syntax. For JavaScript extend-file APIs, read `references/javascript-extend-file.md` first.

## Rule Pattern

```javascript
Rule NodeJSWebTaintRule extends AbstractTaintRule {
    import roster NodeJS_web_taint;
    type = "Xss";
    subType = "XssTs";
}
```

Put `import roster ...;` statements before `type`, `subType`, or any field assignment.

## Verified Rule/Roster Facts

This section consolidates the stable JavaScript Rule/Roster conclusions from official docs, bundled configs, and broad verification runs. Use `references/javascript-extend-file/` for extend-file APIs rather than inferring them from `.rul/.ros` syntax notes.

- `precise is not recognized in JavaScript rules`.
- `group is valid in JavaScript Roster only; group in Rule causes ParseError`.
- `source.methodReturn, source.expression, and source.paramDecorator use value`.
- `sink.methodArg and sanitizer.methodReturn use pattern`.
- `value and pattern are mutually exclusive`; do not put both in the same block.
- `paramIndex and taintTag are JavaScript-side sink constraints`.
- Official JavaScript examples use `relation/config_addition_relation.json`; rule verification examples also include `relation/actual_use_config.json`.

## Roster Pattern

```javascript
Roster NodeJS_web_taint {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b/";
    };

    source.expression += {
        taintTag = "xss_tag";
        value += "/ctx\\.query\\.[A-Za-z_$][\\w$]*$/";
    };

    sink.methodArg += {
        pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/";
        paramIndex = 0;
        taintTag = "xss_tag";
    };

    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b|\\bsanitizeHtml\\b/";
    };
}
```

## JavaScript Field Rules

- Do not use `precise`; it is Java-only.
- Source call/expression blocks use `value`.
- Sink and sanitizer call blocks use `pattern`.
- Use regex literal strings such as `"/\\breq\\.query\\b/"`.
- `paramIndex` selects the tainted argument for call sinks.
- `taintTag` ties sources and sinks in multi-taint configurations.
- `config_addition_relation.json` maps a JS rule id to related roster stems.
- `actual_use_config.json` lists the JS rule/roster configuration files that should be considered active by the verifier package.
- Keep `group` blocks in JavaScript Rosters, not Rules. Groups can carry `includePlatforms` / `excludePlatforms` and field entries.

## Verify-Tested Field Grammar

| Field or pattern | Verified syntax boundary |
|---|---|
| `source.methodReturn` | Block syntax with `value`; `pattern` is rejected |
| `source.expression` | Block syntax with `value` and optional `taintTag`; `pattern` is rejected |
| `source.paramDecorator` | Block syntax with `value`; `pattern` is rejected |
| `sink.methodArg` | JS sink.methodArg requires block syntax with pattern; string syntax is rejected |
| `sink.expression`, `sink.methodReturn`, `sink.paramDecorator`, `sink.param_annotation`, `sink.method_annotation`, `sink.method_param`, `sink.functionArg`, `sink.customSinkFunc` | String syntax |
| `sanitizer.methodReturn` | JS sanitizer.methodReturn is block syntax with pattern |
| `sanitizer.methodArg` | JS sanitizer.methodArg is string syntax |
| `sanitizer.expression`, `sanitizer.paramDecorator`, `sanitizer.param_annotation`, `sanitizer.method_annotation`, `sanitizer.method_param`, `sanitizer.customSanitizerFunc` | String syntax |

JavaScript block fields do not accept Java-specific `flag`, `excludeTag`, or `param`. Keep JS constraints to `value`/`pattern` plus JS-supported `paramIndex` and `taintTag`.

## JavaScript Relation Files

Use the official JS relation names when packaging examples for the verifier:

```text
relation/
├── config_addition_relation.json
└── actual_use_config.json
```

`config_addition_relation.json` is the roster relation file used by official JS examples. `actual_use_config.json` is present in official JS rule verification examples and identifies the active rule/roster files. This differs from common Java examples, which usually use `config_roster_relation.json`.

## Extend-File Pointer

For JS `loadclass`, CommonJS exports, `userDefineFunc`, runtime APIs, `TaintVarSet`, built-in modules, and FSM/custom hooks, read:

- `references/javascript-extend-file.md`
- `references/javascript-extend-file/INDEX.md`
- `references/javascript-extend-file/GENERAL.md`
