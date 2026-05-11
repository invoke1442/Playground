const ts = require("typescript");

let rule = {};
module.exports.rule = rule;

rule.userDefineFunc = function(rule, node, context) {
    try {
        if (!rule.analysisVisitor || rule.analysisVisitor.visitorName !== "TaintAnalysisVisitor") {
            return false;
        }
        if (!ts.isCallExpression(node) && !ts.isBinaryExpression(node)) {
            return false;
        }
        return false;
    } catch (error) {
        return false;
    }
};
