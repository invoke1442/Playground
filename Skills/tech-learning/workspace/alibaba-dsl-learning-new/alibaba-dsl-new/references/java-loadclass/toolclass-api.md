# Java Loadclass Tool Class API

Use these helper APIs to resolve class names, call strings, inheritance, declarations, AST nodes, and cached inter-procedural data.

## InterDataCache

| API | Use |
|---|---|
| `InterDataCache.getInstance()` | Get global inter-procedural cache |
| `InterDataCache.findDefinedClassNodeByRootNode(root)` | Class node for an AST root |
| `InterDataCache.findSuperClassesByClassName(className)` | Recursive superclass queue |
| `InterDataCache.findInterfaceByClassName(className)` | Implemented interfaces |
| `InterDataCache.findDirectImplementsByInterface(interfaceName)` | Direct implementors |
| `InterDataCache.findFilePathByClassName(className)` | Class-to-file lookup |
| `InterDataCache.findDefinedClassByFileName(filePath)` | File-to-class lookup |
| `InterDataCache.findContentByFilePath(filePath)` | File content |
| `InterDataCache.findMethodNodes(methodName)` | Method AST nodes by `pkg.Class.method` |
| `InterDataCache.findMethodNodeByProfile(profile)` | Method declaration by full profile |
| `InterDataCache.findExactMethodDeclarationsWithBody(methodName)` | Exact method declarations with body |
| `InterDataCache.findMethodDeclarationsWithBody(methodName)` | Method declarations including subclasses |
| `InterDataCache.findFieldNode(fieldName)` | Field declaration node |
| `InterDataCache.getClassToFilter()` | Class-to-filter mapping |

## InterAppTypeInfor

| API | Use |
|---|---|
| `InterAppTypeInfor.getInterAppTypeInfor()` | Get global type information |
| `InterAppTypeInfor.getClasses()` / `getMethods()` / `getFields()` | Type-model maps |
| `InterAppTypeInfor.getClassToSuperClasses()` / `getSuperToSubClasses()` | Inheritance maps |
| `InterAppTypeInfor.getClassToInterfaces()` / `getInterfaceToImpls()` | Interface maps |
| `InterAppTypeInfor.getConstantMap()` / `getExtMap()` / `getAspectConfigs()` | Auxiliary maps |
| `InterAppTypeInfor.isInterface(className)` / `isAbstract(className)` | Type checks |
| `InterAppTypeInfor.findDirectImplementsByInterface(interfaceName)` | Direct implementations |
| `InterAppTypeInfor.findDirectSubClassesBySuperClass(superClass)` | Direct subclasses |
| `InterAppTypeInfor.findSelfAndAllSubClasses(superClass)` | Self plus subclasses |

## ASTUtil

| API | Use |
|---|---|
| `ASTUtil.findNodes(node, xpath)` / `findFirstNode(node, xpath)` | XPath lookup with cache |
| `ASTUtil.findNodesNoCache(node, xpath)` / `findFirstNodeNoCache(node, xpath)` | XPath lookup without cache |
| `ASTUtil.getAst(classpath, ...)` | Build an AST |
| `ASTUtil.sumExpressionComplexity(expr)` | Expression complexity |
| `ASTUtil.getAllControlNodes(node)` | Related control nodes |
| `ASTUtil.getSuffixImage(exp)` / `getFullName(type, method, exp)` | Expression naming |
| `ASTUtil.hasClassAnnotation(...)` / `getMethodLevelAnnotations(...)` | Annotation helpers |
| `ASTUtil.findFirstArguments(...)` / `findFirstMethodDeclarationParent(node)` | Node relation helpers |
| `ASTUtil.isFunctionalInterface(className)` / `isTypeParameter(typeImage, node)` | Type helpers |
| `ASTUtil.preparePatternInXpath(key, pattern)` / `prepareSetInXpath(key, pattern)` | Register XPath regex/set variables |
| `ASTUtil.hasJavadoc(node)` | Javadoc check |

## CodeUtil

| API | Use |
|---|---|
| `CodeUtil.getClassName(...)` | Resolve class names for primary expressions, expressions, annotations, types, names, etc. |
| `CodeUtil.getCallString(expression)` | Resolve call string |
| `CodeUtil.getExpectClassName(expression)` | Expected class name for call target |
| `CodeUtil.getEnclosingClassName(node)` / `getDefinedClassName(node, absolute)` / `getCurrentClassName(node)` | Class context |
| `CodeUtil.getEnclosingMethod(node)` / `getPackageName(node)` / `getRootNode(node)` | AST context |
| `CodeUtil.isSuperClass(clazz, superClass)` / `isInterface(clazz, inter)` / `isImplInterface(interfaceName)` | Inheritance/interface checks |
| `CodeUtil.findVariableDeclaration(...)` / `findMemberVariableDeclaration(...)` | Declaration lookup |
| `CodeUtil.getTypeDesFromNode(typeNode)` / `getTypeDesFromDecl(decl)` | Type descriptors |
| `CodeUtil.getViolationCodeByAstNode(node)` / `getCodeSegmentByAstNode(node)` | Source snippets |

## JavaRuleUtil

| API | Use |
|---|---|
| `JavaRuleUtil.generateSlimVariableSet(varMap)` | Slim variable sets |
| `JavaRuleUtil.getMethod(...)` / `getMethodName(...)` / `getClassName(...)` | Method/class names |
| `JavaRuleUtil.getReferenType(...)` / `getResultType(...)` | Referenced/result types |
| `JavaRuleUtil.getPattern(regex)` / `isMatched(...)` / `isMultiMatched(...)` | Pattern and tag matching |
| `JavaRuleUtil.arrayAsHashSet(array)` / `getVarNameImage(name)` | Misc helpers |
