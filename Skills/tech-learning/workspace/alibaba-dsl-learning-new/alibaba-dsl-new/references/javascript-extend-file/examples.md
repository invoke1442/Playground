# JavaScript Extend-File Examples

## userDefineFunc Skeleton

```javascript
const ts = require("typescript");

let rule = {};
module.exports.rule = rule;

rule.userDefineFunc = function(rule, node, context) {
    try {
        if (!rule.analysisVisitor || rule.analysisVisitor.visitorName !== "TaintAnalysisVisitor") {
            return false;
        }
        if (!ts.isCallExpression(node)) {
            return false;
        }
        return false;
    } catch (e) {
        return false;
    }
};
```

## Custom Traversal Pattern

```javascript
const visitor = require("../../visitor");

class Finder extends visitor.TypeScriptVisitorAdapter {
    constructor() {
        super(...arguments);
        this.results = [];
    }
    visitCallExpression(node) {
        this.results.push(node);
        super.visitCallExpression(node);
    }
}
```

Prefer DSL field definitions for ordinary sources/sinks. Use JS extend-file for framework-specific AST traversal, custom source identification, result filtering, or bug-reporting logic that field matching cannot express.
