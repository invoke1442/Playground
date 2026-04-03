# AST Coverage (based on codeql-java-ast-classes-learning-notes.md)

This demo intentionally includes most common Java-side AST classes from the notes.

- Stmt family covered:
  - `AssertStmt`, `BlockStmt`, `BreakStmt`, `ContinueStmt`, `DoStmt`, `ExprStmt`, `ForStmt`, `IfStmt`, `LabeledStmt`, `ReturnStmt`, `SwitchStmt`, `SynchronizedStmt`, `ThrowStmt`, `TryStmt`, `WhileStmt`
- Expr family covered (common Java classes):
  - Literal: `NullLiteral`, `BooleanLiteral`, `NumberLiteral`, `IntegerLiteral`, `FloatLiteral`, `StringLiteral`, `ClassLiteral`
  - Unary/Binary: `PrefixExpr`, `PostfixExpr`, `NotExpr`, `BitNotExpr`, `AddExpr`, `MulExpr`, `AndExpr`, `OrExpr`, `EqExpr`, `GeExpr`, `LeExpr`, `InstanceOfExpr`
  - Assignment: `AssignExpr`, `AssignAddExpr`, `AssignSubExpr`, `AssignMulExpr`, `AssignDivExpr`, `AssignBitAndExpr`, `AssignURShiftExpr`
  - Access/other: `VarAccess`, `FieldAccess`, `MethodAccess`, `ArrayExpr`, `SuperAccess`, `ThisAccess`, `EnclosingInstanceAccess`, `MethodCall`, `ClassInstanceExpr`, `CastExpr`, `ConditionalExpr`, `LambdaExpr`, `MethodReferenceExpr`

Not covered here:
- Kotlin-specific nodes such as `NotNullExpr`, `WhenExpr`
- Language-specific nodes like `DeleteExpr`, `AwaitExpr`, `InExpr`
