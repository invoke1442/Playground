# JavaScript Extend-File Runtime Params API

## rule

`rule` is the generated rule object. Important fields include:

- Metadata: `ruleName`, `ruleType`, `bugType`, `desc`, `tips`, `scanModel`, `subject`, `deployCheck`.
- Sources: `paramDecoratorSources`, `functionSources`, `expressionSources`, `customSourceFunc`, `customSourceNodes`, `entranceParam`, `hsfProviderSource`.
- Sanitizers: `returnSanitizers`, `paramSanitizers`, `objectSanitizers`.
- Sinks: `callSinks`, `assignSinks`, `xpathSinks`, `jsxElementSinks`, `newExpressionSinks`.
- Control: `useMultiTaintVars`, `preserveValueTaint`, `preserveValueTags`.
- Extensions: `userDefineFunc`, `validateFunction`, `templateRenderCall`, `fsm`.
- Runtime: `bugTrace`, `entranceFiles`, `analysisVisitor`.

`rule.analysisVisitor` is the main runtime API entry for visitor state.

## analysisVisitor Names

`rule.analysisVisitor.visitorName` can be:

- `"TaintAnalysisVisitor"`
- `"FsmAnalysisVisitor"`
- `"InterTaintAnalysisVisitor"`
- `"InterFsmAnalysisVisitor"`

## node

`node` is a TypeScript compiler AST node. Use standard fields and methods such as `kind`, `parent`, `getSourceFile()`, `getText()`, `getStart()`, `getEnd()`, `getFullStart()`, `getChildCount()`, `getChildAt()`, `getChildren()`, `pos`, `end`, and `flags`.

Use type guards before node-specific reads:

- `ts.isCallExpression(node)`
- `ts.isPropertyAccessExpression(node)`
- `ts.isElementAccessExpression(node)`
- `ts.isBinaryExpression(node)`
- `ts.isIdentifier(node)`
- related `ts.is*` guards from the TypeScript compiler API

Common node shapes include `CallExpression`, `PropertyAccessExpression`, `ElementAccessExpression`, `BinaryExpression`, `Identifier`, `StringLiteral`, `FunctionDeclaration`, `ArrowFunction`, `ReturnStatement`, `IfStatement`, `ForInStatement`, `SourceFile`, `VariableDeclaration`, and `ObjectLiteralExpression`.
