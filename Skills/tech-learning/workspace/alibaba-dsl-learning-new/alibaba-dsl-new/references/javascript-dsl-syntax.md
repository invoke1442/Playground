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

## Extend-File Pointer

For JS `loadclass`, CommonJS exports, `userDefineFunc`, runtime APIs, `TaintVarSet`, built-in modules, and FSM/custom hooks, read:

- `references/javascript-extend-file.md`
- `references/javascript-extend-file/INDEX.md`
- `references/javascript-extend-file/GENERAL.md`
