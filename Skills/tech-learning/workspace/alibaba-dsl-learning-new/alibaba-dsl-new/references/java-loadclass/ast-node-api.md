# Java Loadclass AST Node API

Use these PMD Java AST custom methods after checking node types with `instanceof`.

| API | Use |
|---|---|
| `ASTPrimaryExpression.getCallString()` | FQN-like method call string such as `java.lang.String.format` |
| `ASTPrimaryExpression.getClassName()` | Resolved expression type |
| `ASTPrimaryExpression.getRawClassName()` | Cached raw class name without forcing recomputation |
| `ASTPrimaryExpression.getRawCallString()` | Cached raw call string without forcing recomputation |
| `ASTPrimaryExpression.setCallString(...)` / `setClassName(...)` | Override cached call/type data when needed |
| `ASTExpression.getClassName()` / `getRawClassName()` | Resolved expression type |
| `ASTExpression.setClassName(...)` | Override cached expression type |
| `ASTExpression.getLiteralValue()` / `setLiteralValue(...)` | Resolved literal value where available |
| `ASTExpression.isConditionExpression()` | Whether the expression is used as a condition |
| `ASTExpression.getSingleChildOfName()` | Fetch the single child `ASTName`, including cast-expression handling |
| `ASTName.getClassName()` / `getRawClassName()` | Resolved name type |
| `ASTName.setClassName(...)` | Override cached name type |
| `ASTName.getNameDeclaration()` / `setNameDeclaration(...)` | Name binding information |
| `ASTName.isSingleName()` | Whether the name is a single identifier |
| `ASTMethodDeclaration.getFullProfile()` / `setFullProfile(...)` | Full method signature/profile |
| `ASTMethodDeclaration.getMethodName()` / `getName()` | Method name |
| `AbstractNode.getFirstNextSibling(Class<T>)` | Find the first following sibling of a given type |
| `ASTArguments.getMethodName()` / `setMethodName(...)` | Call arguments' associated method name |
| `ASTConstructorDeclaration.getMethodName()` | Constructor name |

Prefer `CodeUtil` helpers from `toolclass-api.md` when resolving class names or call strings across node variants.
