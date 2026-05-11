# Alibaba DSL JavaScript XSS Rule Package

Deliverable root: `outputs/config`

Rule id: `90002`

This package models Express/Koa-style XSS taint flow:

- Sources: `req.query`, `req.body`, `ctx.request.body`
- Sinks: `res.send(...)`, `res.write(...)`, `ctx.body`
- Sanitizer: `escapeHtml(...)`

The rule entrypoint is `config/90002.rul`, which imports roster declaration `NodeJS_web_taint`. The roster file is `config/rosters/NodeJS_web_taint_0.ros`; relation config uses the `_0` file stem in `config/relation/config_addition_relation.json`.

JavaScript extend-file loadclass structure:

- `loadclass("XssTs_90002.rule.userDefineFunc")` resolves to `config/extend-file/90002/XssTs_90002.js`, then `module.exports.rule.userDefineFunc`.
- `loadclass("NodeJS_web_taint.rule.customSourceFunc")` resolves to `config/extend-file/rosters/NodeJS_web_taint_0/NodeJS_web_taint.js`, then `module.exports.rule.customSourceFunc`.
- JS extend files should export a CommonJS object:

```javascript
let rule = {};
module.exports.rule = rule;
rule.userDefineFunc = function(rule, node, context) {
    return false;
};
```

Returning `false` lets the default analyzer continue. Return `true` only if the extension fully handles the node and should replace default analysis.

Local lint:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/lint_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/js-xss-rule/without_skill/run-4/outputs/config --language javascript --json
```

Remote verify commands for later use:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/js-xss-rule/without_skill/run-4/outputs/config --language javascript --verify-type rule --rule-id 90002
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/js-xss-rule/without_skill/run-4/outputs/config --language javascript --verify-type roster --roster-name NodeJS_web_taint_0
```

No remote verify endpoint was called.
