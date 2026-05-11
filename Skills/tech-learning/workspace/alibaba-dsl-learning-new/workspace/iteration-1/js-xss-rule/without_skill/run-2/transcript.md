## Eval Prompt

Create an Alibaba DSL JavaScript XSS rule package for Express/Koa style apps. Sources are req.query, req.body, and ctx.request.body. Sinks are res.send/res.write/ctx.body. Include an escapeHtml sanitizer and mention how JS extend-file loadclass should be structured.

## Codex Final Message

I could not complete the requested file save because this session is read-only and approvals are disabled. I also attempted the required noninteractive Codex subprocess, but it failed before receiving the task:

```text
Error: failed to initialize in-process app-server client: Read-only file system (os error 30)
```

A direct write probe to `outputs/` also failed:

```text
touch: cannot touch 'outputs/.codex_write_probe': Read-only file system
```

No files were created under `outputs/`. Here is the package content that should be saved when rerun in a writable sandbox.

**Intended Tree**

```text
outputs/
├── README.md
├── user_notes.md
└── js-xss-rule/
    ├── 90002.rul
    ├── rosters/
    │   └── NodeJS_web_taint_0.ros
    ├── relation/
    │   ├── actual_use_config.json
    │   └── config_addition_relation.json
    └── extend-file/
        └── 90002/
            └── XssTs_90002.js
```

**`js-xss-rule/90002.rul`**

```typescript
Rule NodeJSWebTaintRule extends AbstractTaintRule {
    import roster NodeJS_web_taint;
    type = "Xss";
    subType = "XssTs";

    general.userDefinePatternClass += {
        userDefineClass = loadclass("XssTs_90002.rule.userDefineFunc");
    };
}
```

**`js-xss-rule/rosters/NodeJS_web_taint_0.ros`**

```typescript
Roster NodeJS_web_taint {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\bctx\\.request\\.body\\b/";
    };

    source.expression += {
        taintTag = "xss_tag";
        value += "/ctx\\.query\\.[A-Za-z_$][\\w$]*$/";
    };

    sink.methodArg += {
        pattern += "/\\bres\\.send\\b|\\bres\\.write\\b|\\bctx\\.body$/";
        paramIndex = 0;
        taintTag = "xss_tag";
    };

    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b/";
    };
}
```

**`js-xss-rule/relation/config_addition_relation.json`**

```json
{
  "90002": ["NodeJS_web_taint_0"]
}
```

**`js-xss-rule/relation/actual_use_config.json`**

```json
[90002]
```

**`js-xss-rule/extend-file/90002/XssTs_90002.js`**

```javascript
const ts = require("typescript");

let rule = {};
module.exports.rule = rule;

rule.userDefineFunc = function(rule, node, context) {
    if (!rule.analysisVisitor || rule.analysisVisitor.visitorName !== "TaintAnalysisVisitor") {
        return false;
    }

    if (!ts.isCallExpression(node) && !ts.isBinaryExpression(node)) {
        return false;
    }

    return false;
};
```

**`README.md`**

```markdown
# Alibaba DSL JavaScript XSS Rule Package

This package models Express/Koa-style XSS taint flow for JavaScript/TypeScript apps.

Sources:
- `req.query`
- `req.body`
- `ctx.request.body`

Sinks:
- `res.send(...)`
- `res.write(...)`
- `ctx.body`

Sanitizer:
- `escapeHtml(...)`

The JavaScript roster uses `value` / `value +=` for source blocks and `pattern` / `pattern +=` for sink and sanitizer call blocks.

JavaScript extend-file loadclass structure:
- Rule extension file path: `extend-file/{rule_id}/XssTs_{rule_id}.js`
- The JS file must be a CommonJS module.
- `loadclass("XssTs_90002.rule.userDefineFunc")` resolves as:
  - file basename: `XssTs_90002.js`
  - exported property path: `module.exports.rule.userDefineFunc`

`userDefineFunc(rule, node, context)` should return `false` unless it intentionally replaces or short-circuits the default analysis for that node. Returning `false` lets the default taint analysis continue.

Suggested verification commands from a writable checkout:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/lint_alibaba_dsl.py outputs/js-xss-rule --language javascript

python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py outputs/js-xss-rule --language javascript --verify-type rule --rule-id 90002
```
```

**`user_notes.md`**

```markdown
# User Notes

Human review needed: rerun this task in a writable sandbox so the package can be saved under `outputs/` and linted.

The current session is read-only. The noninteractive Codex subprocess failed during startup with `failed to initialize in-process app-server client: Read-only file system`, and direct writes to `outputs/` also failed.
```

## Codex Stderr

Reading prompt from stdin...
