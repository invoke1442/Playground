
# Alibaba STC 引擎 — JavaScript extend-file 扩展 API 参考文档

> **文档状态: ✅ 已完成** — 核心调度链路、三个参数类型、可用 API、TaintVarSet 完整 API、FSM 扩展点精确签名均已从源码确认。所有结论附有 `[来源: file:line]` 标注。

---

## §1. 扩展机制概览

### 1.1 调度链路

STC TypeScript 引擎在 AST 遍历过程中，通过 `handleUserDefine` 方法调用用户自定义的 `userDefineFunc`。该方法存在于两个 Visitor 类中：

**调用入口 1 — TaintAnalysisVisitor（污点分析）**

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5437-L5460]

```typescript
handleUserDefine(rule: Rule, node: ts.Node, context: TaintAnalysisContext): boolean {
    if (!rule.userDefineFunc) {
        return false;
    }

    if (typeof (rule.userDefineFunc) === "function") {
        if (rule.userDefineFunc(rule, node, context)) {
            return true;
        }
    } else {
        let ret = false;
        for (const fun of rule.userDefineFunc) {
            if (typeof (fun) === "function") {
                if (fun(rule, node, context)) {
                    ret = true;
                }
            }
        }
        return ret;
    }

    return false;
}
```

**调用入口 2 — FsmAnalysisVisitor（有限状态机分析）**

> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts:L2787-L2810]

代码结构与上方完全一致，唯一区别是 `context` 参数类型为 `FsmAnalysisContext`。

### 1.2 JS 运行时

STC TypeScript 引擎**本身就是 Node.js 应用**（TypeScript 编译后运行于 Node.js）。extend-file 中的 `.js` 文件通过 Node.js 原生的 `require()` 机制加载。

> [来源: src/dsl/RuleUtil.ts:L1511-L1512]

```typescript
let loadDynamicRule = require("../rule/rules.js").loadDynamicRule;
let loadDynamicRuleByString = require("../rule/rules.js").loadDynamicRuleByString;
```

`loadDynamicRule(filePath)` 内部使用 Node.js 的 `require()` 加载 `.js` 文件，返回 `{ rule: ... }` 对象。

### 1.3 加载机制

#### 1.3.1 extend-file 目录发现

> [来源: src/dsl/RuleUtil.ts:L1248-L1262]

```typescript
function readNewDslRulesSetting(ruleDir, jobSource, extendFileDir) {
    // ...
    if (!extendFileDir || !fs.existsSync(extendFileDir)) {
        extendFileDir = path.join(path.dirname(ruleDir), "rule-extend-file");
        if (!fs.existsSync(extendFileDir)) {
            extendFileDir = path.join(ruleDir, "extend-file");
        }
    }
    // ...
}
```

**目录查找优先级**：
1. 外部传入的 `extendFileDir` 参数
2. `{ruleDir}/../rule-extend-file/`
3. `{ruleDir}/extend-file/`

#### 1.3.2 DSL `loadclass` 语法引用 extend-file

> [来源: src/dsl/RuleUtil.ts:L1641-L1687]

DSL 规则中通过 `loadclass("fileName.propertyPath")` 语法引用 extend-file 中的函数：

```typescript
function loadClassPath(stringLiteral, extendFileDir, classMap) {
    let classPath = stringLiteral.getText().substring(1, stringLiteral.getText().length - 1);
    let filePath = classPath.substring(0, classPath.indexOf(".")) + ".js";
    filePath = path.join(extendFileDir, filePath);

    let accessPath = classPath.substring(classPath.indexOf(".") + 1);
    let rule = null;
    if (classMap.has(filePath)) {
        rule = classMap.get(filePath);
    } else {
        rule = loadDynamicRule(filePath).rule;
        classMap.set(filePath, rule);
    }

    let keys = accessPath.split(".");
    let cur = rule;
    for (let i = 0; i < keys.length; i++) {
        cur = cur[keys[i]];
    }
    return cur.toString();  // 返回函数代码的字符串形式
}
```

**解析规则**：`loadclass("XssTs_6991.rule.userDefineFunc")` →
1. 取 `"XssTs_6991"` + `.js` → 在 `extendFileDir` 下查找 `XssTs_6991.js`
2. `require()` 加载该文件，获取 `module.exports`
3. 按 `.rule.userDefineFunc` 路径访问属性
4. 将函数 `.toString()` 嵌入生成的 JS 规则代码

#### 1.3.3 userDefineFunc 合并逻辑

> [来源: src/dsl/RuleUtil.ts:L5778-L5791]

当规则继承 roster（名单）时，多个 `userDefineFunc` 会被合并为数组：

```typescript
if (config.userDefineFunc) {
    if (rule.userDefineFunc) {
        if (typeof (rule.userDefineFunc) === "function") {
            let arr = [];
            arr.push(rule.userDefineFunc);
            rule.userDefineFunc = arr;
        }
        if (typeof (config.userDefineFunc) === "function") {
            rule.userDefineFunc.push(config.userDefineFunc);
        } else {
            rule.userDefineFunc = rule.userDefineFunc.concat(config.userDefineFunc);
        }
    } else {
        rule.userDefineFunc = config.userDefineFunc;
    }
}
```

当存在多个 `userDefineFunc` 时，`handleUserDefine` 会遍历数组中的每个函数并依次调用。只要任一函数返回 `true`，最终结果即为 `true`。

#### 1.3.4 目录结构

```
规则目录/
├── extend-file/
│   ├── {rule_id}/                    # 按规则 ID 组织
│   │   └── {RuleName}_{rule_id}.js   # 规则扩展文件
│   └── rosters/                      # 名单扩展文件
│       └── {RosterName}_0/
│           └── {RosterName}.js
├── {rule_id}.rul                     # DSL 规则文件
└── rosters/
    └── {roster_name}.ros             # DSL 名单文件
```

> [来源: src/dsl/RuleUtil.ts:L1591 — 规则 extend-file 路径]
> [来源: src/dsl/RuleUtil.ts:L1549 — roster extend-file 路径]

**是的，JS 扩展文件可以放在 `extend-file/rosters/{RosterName}_0/` 下。**

#### 1.3.5 加载时机

extend-file 在**规则初始化阶段**加载（通过 `readNewDslRulesSetting` → DSL 解析 → `loadClassPath`），而非每次扫描时重新加载。加载后函数引用存储在 `Rule` 对象的 `userDefineFunc` 属性中，在整个扫描过程中复用。

---

## §2. userDefineFunc 生命周期

### 2.1 调用频率

`handleUserDefine` 被嵌入到多种 AST 节点的 `visit*` 方法中。**每当引擎遍历到对应类型的 AST 节点时，都会调用一次 `handleUserDefine`**。

#### TaintAnalysisVisitor 中的调用点（13 种节点类型）

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts]

| visit 方法 | 节点类型 | 行号 |
|-----------|---------|------|
| `visitExpressionStatement` | `ts.ExpressionStatement` | L5462 |
| `visitVariableStatement` | `ts.VariableStatement` | L5469 |
| `visitIfStatement` | `ts.IfStatement` | L5476 |
| `visitForOfStatement` | `ts.ForOfStatement` | L3168 |
| `visitForInStatement` | `ts.ForInStatement` | L3175 |
| `visitWhileStatement` | `ts.WhileStatement` | L3182 |
| `visitForStatement` | `ts.Node` | L3189 |
| `visitBinaryExpression` | `ts.BinaryExpression` | L3196 |
| `visitElementAccessExpression` | `ts.ElementAccessExpression` | L3533 |
| `visitReturnStatement` | `ts.ReturnStatement` | L3699 |
| `visitCallExpression` | `ts.CallExpression` | L4027 |
| `visitTypeOfExpression` | `ts.TypeOfExpression` | L5076 |
| `visitDeleteExpression` | `ts.DeleteExpression` | L5800 |

#### FsmAnalysisVisitor 中的调用点（10 种节点类型）

> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts]

| visit 方法 | 节点类型 | 行号 |
|-----------|---------|------|
| `visitConstructor` | `ts.ConstructorDeclaration` | L702 |
| `visitFunctionDeclaration` | `ts.FunctionDeclaration` | L721 |
| `visitFunctionExpression` | `ts.FunctionExpression` | L740 |
| `visitArrowFunction` | `ts.ArrowFunction` | L758 |
| `visitMethodDeclaration` | `ts.MethodDeclaration` | L777 |
| `visitExpressionStatement` | `ts.ExpressionStatement` | L1432 |
| `visitVariableStatement` | `ts.VariableStatement` | L1441 |
| `visitReturnStatement` | `ts.ReturnStatement` | L1450 |
| `visitIfStatement` | `ts.IfStatement` | L1505 |
| `visitCallExpression` | `ts.CallExpression` | L1638 |

### 2.2 调用时机

- **TaintAnalysisVisitor**：在**污点分析阶段**调用。此阶段引擎追踪数据从 source（输入源）到 sink（危险操作）的流动路径。`handleUserDefine` 在每个 visit 方法的**最开头**被调用，在引擎默认分析逻辑之前执行。
- **FsmAnalysisVisitor**：在**有限状态机分析阶段**调用。此阶段引擎基于 FSM 模型检测特定的代码模式（如 CSRF 防护缺失）。在 FSM 中，`handleUserDefine` 的调用位置有两种模式：
  - 对于函数级节点（Constructor、FunctionDeclaration 等）：`if (!this.handleUserDefine(...)) { super.visit*(); }` — 返回 `true` 时**替代**默认遍历
  - 对于语句级节点（ExpressionStatement、IfStatement 等）：`if (this.handleUserDefine(...)) { return; }` — 返回 `true` 时**跳过**默认处理

### 2.3 返回值语义

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5462-L5479]

```typescript
visitExpressionStatement(node: ts.ExpressionStatement): void {
    if (this.handleUserDefine(this.rule, node, this.taintAnalysisContext)) {
        return;  // true → 跳过引擎默认分析
    }
    super.visitExpressionStatement(node);  // false → 继续引擎默认分析
}
```

| 返回值 | 行为 |
|--------|------|
| `true` | **跳过**引擎对该节点的默认分析流程。自定义代码已完全处理该节点。 |
| `false` | **继续**引擎默认分析流程。自定义代码不干预（或仅做了辅助处理）。 |

**重要**：当存在多个 `userDefineFunc`（数组形式）时，所有函数都会被调用，只要任一返回 `true`，最终结果为 `true`。但即使某个函数返回了 `true`，后续函数仍会被调用。

### 2.4 错误处理

`handleUserDefine` 方法中**没有 try-catch 包裹** `userDefineFunc` 的调用。如果自定义函数抛出异常，异常会直接向上传播，可能导致当前文件的分析中断。

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5437-L5460 — 无 try-catch]

---

## §3. 参数 `rule` 的完整 API

### 3.1 类型定义

> [来源: src/rule/Rule.ts:L1-L88]

`rule` 参数的类型是 `Rule` 类实例。以下是完整的属性列表：

#### 规则元信息

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `ruleName` | `string` | 规则名称 | L17 |
| `ruleType` | `string` | 规则类型（`"taint"` / `"fsm"`） | L16 |
| `bugType` | `string` | 缺陷类型 | L18 |
| `desc` | `string` | 规则描述 | L22 |
| `tips` | `string` | 修复建议 | L23 |
| `scanModel` | `string` | 扫描模型 | L13 |
| `subject` | `string` | 规则主题 | L14 |
| `deployCheck` | `boolean` | 是否部署检查 | L19 |
| `asInformationData` | `boolean` | 是否作为信息数据 | L20 |
| `customTags` | `string` | 自定义标签 | L21 |

#### Source（污点源）配置

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `paramDecoratorSources` | `RegExp[] \| Map<string, RegExp[]>` | 参数装饰器 source | L26 |
| `functionSources` | `RegExp[] \| Map<string, RegExp[]>` | 函数返回值 source | L27 |
| `expressionSources` | `RegExp[] \| Map<string, RegExp[]>` | 表达式 source | L28 |
| `customSourceFunc` | `Function \| Function[]` | 自定义 source 函数 | L29 |
| `customSourceFunExtraParams` | `[]` | 自定义 source 函数额外参数 | L30 |
| `customSourceNodes` | `HashMap<any, any>` | 自定义 source 节点集合 | L31 |
| `entranceParam` | `number[]` | 入口参数索引 | L32 |
| `hsfProviderSource` | `boolean` | HSF Provider 是否作为 source | L53 |

#### Sanitizer（净化函数）配置

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `returnSanitizers` | `IRuleReturnSanitizer[]` | 返回值安全的净化函数 | L35 |
| `paramSanitizers` | `RegExp[]` | 参数安全的净化函数 | L38 |
| `objectSanitizers` | `RegExp[]` | 对象方法净化函数 | L39 |

#### Sink（危险操作）配置

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `callSinks` | `IRuleCallSink[]` | 函数调用类型 sink | L40 |
| `assignSinks` | `RegExp[]` | 赋值类型 sink | L41 |
| `xpathSinks` | `string[]` | XPath 匹配 sink | L42 |
| `jsxElementSinks` | `IRuleJsxElementSink[]` | JSX 元素 sink | L43 |
| `newExpressionSinks` | `IRuleNewExpressionSink[]` | new 表达式 sink | L46 |

#### 分析控制

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `userDefineFunc` | `Function \| Function[]` | 用户自定义函数（即本文档描述的扩展点） | L50 |
| `functionTrustSource` | `RegExp[] \| Map<string, RegExp[]>` | 信任的函数 source | L48 |
| `xpathTrustSource` | `string[]` | XPath 信任 source | L49 |
| `onlyTaintDomain` | `boolean` | 是否仅追踪域字段 | L54 |
| `filterBlackFile` | `boolean` | 是否过滤黑名单文件 | L55 |
| `domainFields` | `RegExp` | 域字段匹配 | L57 |
| `safeMethodNoSourceFile` | `boolean` | 黑盒函数是否不传播污点 | L58 |
| `useMultiTaintVars` | `boolean` | 是否开启多数据流 | L61 |
| `preserveValueTaint` | `boolean` | 是否保留值污点 | L63 |
| `preserveValueTags` | `string[]` | 保留值的标签列表 | L64 |
| `taintJsxElement` | `boolean` | 是否污染 JSX 元素 | L66 |
| `dataMergeStrategy` | `ControlFlowMergeStrategy` | 控制流合并策略 | L84 |

#### 扩展与回调

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `validateFunction` | `RuleValidateFunctionType[]` | 规则验证函数 | L76 |
| `templateRenderCall` | `RegExp[]` | 模板渲染调用匹配 | L82 |
| `fsm` | `FsmMachine` | FSM 状态机定义 | L48 |

#### 运行时属性（引擎在分析过程中设置）

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| **`analysisVisitor`** | `any` | **当前分析 Visitor 实例** — 这是 userDefineFunc 中最重要的 API 入口 | L73 |
| `bugTrace` | `BugTrace` | 缺陷追踪图 | L71 |
| `entranceFiles` | `string[]` | 入口文件列表 | L68 |

### 3.2 通过 `rule.analysisVisitor` 访问的 Visitor API

`rule.analysisVisitor` 在 Visitor 构造函数中被赋值为当前 Visitor 实例：

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L55]

```typescript
this.rule.analysisVisitor = this;
```

> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts:L47]

```typescript
this.rule.analysisVisitor = this;
```

可通过 `rule.analysisVisitor.visitorName` 判断当前 Visitor 类型：

```javascript
if (rule.analysisVisitor.visitorName === "TaintAnalysisVisitor") { ... }
if (rule.analysisVisitor.visitorName === "FsmAnalysisVisitor") { ... }
```

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L57 — `this.visitorName = "TaintAnalysisVisitor"`]
> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts:L52 — `this.visitorName = "FsmAnalysisVisitor"`]

以下是从源码中确认的、可在 `userDefineFunc` 中通过 `rule.analysisVisitor` 调用的方法：

---

#### `visit(node: ts.Node)` → `void`

> [来源: visitor.ts:L1 — TypeScriptVisitorAdapter 基类]

遍历指定的 AST 节点，触发引擎的默认分析流程（包括污点传播）。

- **node** (`ts.Node`): 要遍历的 AST 节点
- **调用示例**:
  ```javascript
  // 手动遍历子表达式以获取其污点状态
  rule.analysisVisitor.visit(node.expression);
  ```

> [实际使用: src/utils/prototypePollutionUtil.ts:L155 — `visitor.visit(node.expression)`]

---

#### `copyTaintContext(source: TaintContext)` → `TaintContext`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L59]

深拷贝一个 TaintContext 对象。常用于在手动遍历前保存当前污点状态，遍历后恢复。

- **source** (`TaintContext`): 要拷贝的污点上下文
- **返回值**: 新的 TaintContext 副本
- **调用示例**:
  ```javascript
  let oldTaintContext = rule.analysisVisitor.copyTaintContext(context.getTaintContext());
  context.clearTaint();
  rule.analysisVisitor.visit(someNode);
  // ... 检查污点状态 ...
  context.copyTaintContext(oldTaintContext);  // 恢复
  ```

> [实际使用: src/utils/prototypePollutionUtil.ts:L153 — `visitor.copyTaintContext(context.getTaintContext())`]

---

#### `addBugReport(sinkName: string, toVertex: Vertex)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5815-L5822]

```typescript
/* 用于userDefineFunc callback */
addBugReport(sinkName, toVertex): void {
    this.bugTrace.addBugReport(this.rule,
        sinkName,
        this.taintAnalysisContext.genCallString(),
        toVertex,
        false,
        this.taintAnalysisContext.getCustomData()
    );
    this.taintAnalysisContext.setCustomData(new HashMap());
}
```

向引擎报告一个安全缺陷。这是 userDefineFunc 中**上报漏洞的核心方法**。

- **sinkName** (`string`): sink 名称（通常是 `node.getText()`）
- **toVertex** (`Vertex`): 输出顶点（通常由 `handleMultiTaintSinkTrace` 返回）
- **调用示例**:
  ```javascript
  let toVertex = rule.analysisVisitor.handleMultiTaintSinkTrace(
      node.getText(), node, objTaintResult, TAINT_TAG_OBJ_PROTO
  );
  rule.analysisVisitor.addBugReport(node.getText(), toVertex);
  ```

> [实际使用: src/utils/prototypePollutionUtil.ts:L169]

---

#### `getTraces(outputVex: Vertex)` → `Vertex[]`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5823-L5825]

```typescript
getTraces(outputVex: Vertex): Vertex[] {
    return this.bugTrace.genBugTraceSingleVex(outputVex);
}
```

获取指定输出顶点的缺陷追踪链路。

- **outputVex** (`Vertex`): 输出顶点
- **返回值**: 追踪链路中的所有顶点数组

---

#### `handleMultiTaintSinkTrace(sinkName, toNode, taintResult, fromTag, toTag?)` → `Vertex`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L269-L276]

```typescript
handleMultiTaintSinkTrace(sinkName: string, toNode: ts.Node,
    taintResult: TaintContext, fromTag: string, toTag: string = null): Vertex {
    if (this.taintAnalysisContext.isTaintContext(taintResult) && taintResult.multiTaintBaseVar) {
        this.addResultNode(taintResult);
    }
    return this.addMultiTaintTrace(sinkName, toNode, taintResult, SinkType.Output, fromTag, toTag);
}
```

在多数据流分析中处理 sink 追踪。返回一个 `Vertex` 对象，可传给 `addBugReport`。

- **sinkName** (`string`): sink 名称
- **toNode** (`ts.Node`): 目标 AST 节点
- **taintResult** (`TaintContext`): 污点上下文
- **fromTag** (`string`): 来源污点标签（如 `"taint_tag_default"`）
- **toTag** (`string`, 可选): 目标污点标签（默认与 fromTag 相同）
- **返回值**: `Vertex` — 输出顶点

> [实际使用: src/utils/prototypePollutionUtil.ts:L163-L168]

---

#### `addMultiTaintTrace(toName, toNode, fromTaintResult, type, fromTag, toTag?)` → `Vertex`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L279-L310]

在多数据流分析中新增一条 trace 边，支持跨标签。

- **toName** (`string`): 目标名称
- **toNode** (`ts.Node`): 目标 AST 节点
- **fromTaintResult** (`TaintContext`): 来源污点上下文
- **type** (`SinkType`): 类型（`SinkType.Trace` = 2, `SinkType.Output` = 3）
- **fromTag** (`string`): 来源标签
- **toTag** (`string`, 可选): 目标标签
- **返回值**: `Vertex`

> [实际使用: resources/benchmark/prototype_pollution/rule/extend-file/assignment/prototypePollutionAssignment_assignment.js:L58-L62]

---

#### `handleTaintResult(toVar, toNode, taintResult)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L651]

处理污点传播结果，将污点状态应用到目标变量。

- **toVar** (`MapOfVariable`): 目标变量
- **toNode** (`ts.Node`): 目标 AST 节点
- **taintResult** (`TaintContext`): 污点上下文

> [实际使用: src/utils/prototypePollutionUtil.ts:L260 — `rule.analysisVisitor.handleTaintResult(MapOfVariable.getVarFromNode(param), param, inputTaint)`]

---

#### `getCurrentTaintVarSet()` → `TaintVarSet`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts — 多处使用]
> [来源: src/InterApp/InterTaintAnalysisVisitor.ts:L84-L86]

```typescript
getCurrentTaintVarSet(): TaintVarSet {
    return this.taintAnalysisContext.visitMethodContext.taintedvars;
}
```

获取当前方法上下文中的污点变量集合。

- **返回值**: `TaintVarSet` — 完整 API 见 §5.6

> [实际使用: src/utils/prototypePollutionUtil.ts:L293 — `rule.analysisVisitor.getCurrentTaintVarSet().addMultiTaintVariable(toVar, TAINT_TAG_DEFAULT)`]

---

#### `getCurrentTaintFieldSet()` → `TaintVarSet`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L211]

获取当前方法上下文中的污点字段集合。

- **返回值**: `TaintVarSet`

---

#### `getFromVertex(vertexName, taintContext, taintTag?)` → `Vertex`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L112]

创建源顶点（source vertex），用于污点追踪图的起点。

- **vertexName** (`string`): 顶点名称
- **taintContext** (`TaintContext`): 污点上下文
- **taintTag** (`string`, 可选): 污点标签
- **返回值**: `Vertex`

---

#### `getToVertex(vertexName, node, type, taintTag?)` → `Vertex`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L166]

创建目标顶点（target vertex），用于污点追踪图的终点。

- **vertexName** (`string`): 顶点名称
- **node** (`ts.Node`): AST 节点
- **type** (`number`): SinkType 枚举值
- **taintTag** (`string`, 可选): 污点标签
- **返回值**: `Vertex`

---

#### `addResultNode(taintResult)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L217]

添加结果节点到污点追踪图。

- **taintResult** (`TaintContext`): 污点上下文

---

#### `resetAnalysisDataSink(node)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L87]

重置分析数据汇，根据节点类型判断是否清除污点。

- **node** (`ts.Node`): AST 节点

---

#### `isSafeType(node)` → `boolean`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L860]

判断节点类型是否安全（数字、布尔、枚举、BigInt 等不会被污染的类型）。

- **node** (`ts.Node`): AST 节点
- **返回值**: `true` 表示该类型安全，不会被污染

---

#### `isUseMultiTaintVars()` → `boolean`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5805]

判断当前规则是否使用多标签污点变量模式。

- **返回值**: `boolean`

---

#### `setControlFlowBroken(isControlFlowBroken)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L205]

设置控制流是否中断（如 `return`、`throw` 后的代码）。

- **isControlFlowBroken** (`boolean`): 是否中断

---

#### `getControlFlowBroken()` → `boolean`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L213]

获取控制流是否中断状态。

---

#### `addParentFieldTrace(invokeNode, parentMethodContext, field, funDeclNode, taintTag?)` → `void`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5278]

添加父字段污点追踪边。

- **invokeNode** (`ts.Node`): 调用节点
- **parentMethodContext** (`MethodContext`): 父方法上下文
- **field** (`MapOfVariable`): 字段变量
- **funDeclNode** (`ts.Node`): 函数声明节点
- **taintTag** (`string`, 可选): 污点标签

---

#### `addSideEffectTrace(invokeNode, parentMethodContext, fromVar, toVar, funDeclNode, taintTag?)` → `{fromVertex, toVertex}`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5316]

添加副作用污点追踪边。

- **返回值**: `{fromVertex: Vertex, toVertex: Vertex}`

---

#### `addChildFieldTrace(invokeNode, parentMethodContext, field, funDeclNode, taintTag?)` → `{fromVertex, toVertex}`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5357]

添加子字段污点追踪边。

- **返回值**: `{fromVertex: Vertex, toVertex: Vertex}`

---

#### `getFullNames(expressionText)` → `string[]`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5267]

获取表达式的所有全限定名。

- **expressionText** (`string`): 表达式文本
- **返回值**: 全名数组

---

#### `isRiskString(value)` → `boolean`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5146]

判断字符串是否为风险字符串。

- **value** (`string`): 要检查的字符串
- **返回值**: `boolean`

---

#### `checkNeedVisit(node)` → `boolean`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L1709]

检查是否需要访问该节点（基于规则配置和文件运行时间限制）。

- **node** (`ts.Node`): AST 节点
- **返回值**: `boolean`

---

#### `handleSinkTrace(sinkName, toNode, taintResult)` → `Vertex`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L249-L268]

在单数据流分析中处理 sink 追踪。

- **sinkName** (`string`): sink 名称
- **toNode** (`ts.Node`): 目标 AST 节点
- **taintResult** (`TaintContext`): 污点上下文
- **返回值**: `Vertex`

---

#### `handleInvokeMethodEnter(node)` / `handleInvokeMethodLeave(node)` → `void`

> [推断来源: src/utils/prototypePollutionUtil.ts:L340-L341]

方法调用进入/离开的处理。用于模拟函数调用的上下文切换。

> [实际使用: src/utils/prototypePollutionUtil.ts:L340 — `visitor.handleInvokeMethodEnter(decl)`]

---

#### `getVisitedMethodContext(node)` → `MethodContext`

> [推断来源: src/utils/prototypePollutionUtil.ts:L337]

获取指定函数声明节点的方法上下文。

> [实际使用: src/utils/prototypePollutionUtil.ts:L337 — `context.pushVisitedmethodcontext(visitor.getVisitedMethodContext(decl))`]

---

#### `visitorName` → `string`

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L57]

标识当前 Visitor 类型的字符串属性。

| 值 | Visitor 类 |
|----|-----------|
| `"TaintAnalysisVisitor"` | TaintAnalysisVisitor |
| `"FsmAnalysisVisitor"` | FsmAnalysisVisitor |
| `"InterTaintAnalysisVisitor"` | InterTaintAnalysisVisitor |
| `"InterFsmAnalysisVisitor"` | InterFsmAnalysisVisitor |

**常见用法**（在 userDefineFunc 开头进行守卫检查）：

```javascript
if (!rule.analysisVisitor || rule.analysisVisitor.visitorName !== "TaintAnalysisVisitor") {
    return false;
}
```

> [实际使用: resources/benchmark/prototype_pollution/rule/extend-file/assignment/prototypePollutionAssignment_assignment.js:L37]

---

## §4. 参数 `node` 的完整 API（AST 节点）

### 4.1 类型

`node` 的类型是 **`ts.Node`** — TypeScript 编译器（`typescript` 包）的 AST 节点基类。

> [来源: src/taintAnalysis/TaintAnalysisVisitor.ts:L5437 — `handleUserDefine(rule: Rule, node: ts.Node, context: TaintAnalysisContext)`]

这不是自定义的 AST 类型，而是 TypeScript 编译器原生的 AST 节点。所有 TypeScript/JavaScript 的语法结构都由 `ts.Node` 的子类型表示。

### 4.2 通用属性和方法

所有 `ts.Node` 共有的属性和方法：

| 属性/方法 | 返回类型 | 说明 |
|-----------|---------|------|
| `kind` | `ts.SyntaxKind` | 节点类型枚举值 |
| `parent` | `ts.Node` | 父节点 |
| `getSourceFile()` | `ts.SourceFile` | 所在源文件 |
| `getText()` | `string` | 节点的源代码文本 |
| `getStart()` | `number` | 起始位置（字符偏移） |
| `getEnd()` | `number` | 结束位置（字符偏移） |
| `getFullStart()` | `number` | 含前导空白的起始位置 |
| `getChildCount()` | `number` | 子节点数量 |
| `getChildAt(index)` | `ts.Node` | 获取指定索引的子节点 |
| `getChildren()` | `ts.Node[]` | 获取所有子节点 |
| `pos` | `number` | 位置（含前导空白） |
| `end` | `number` | 结束位置 |
| `flags` | `ts.NodeFlags` | 节点标志 |

### 4.3 节点类型判断

TypeScript 编译器提供了大量的类型守卫函数：

```javascript
const ts = require("typescript");

ts.isCallExpression(node)          // 函数调用: foo(), a.b()
ts.isIdentifier(node)              // 标识符: foo, bar
ts.isPropertyAccessExpression(node) // 属性访问: a.b
ts.isElementAccessExpression(node)  // 元素访问: a[b]
ts.isBinaryExpression(node)        // 二元表达式: a = b, a + b
ts.isStringLiteral(node)           // 字符串字面量: "hello"
ts.isStringLiteralLike(node)       // 字符串类字面量
ts.isNumericLiteral(node)          // 数字字面量: 42
ts.isFunctionDeclaration(node)     // 函数声明: function foo() {}
ts.isFunctionExpression(node)      // 函数表达式: function() {}
ts.isArrowFunction(node)           // 箭头函数: () => {}
ts.isFunctionLike(node)            // 任何函数类节点
ts.isSourceFile(node)              // 源文件根节点
ts.isObjectLiteralExpression(node) // 对象字面量: { a: 1 }
ts.isVariableDeclaration(node)     // 变量声明: let x = 1
ts.isReturnStatement(node)         // return 语句
ts.isIfStatement(node)             // if 语句
ts.isForInStatement(node)          // for...in 语句
ts.isForOfStatement(node)          // for...of 语句
ts.isDeleteExpression(node)        // delete 表达式
ts.isToken(node)                   // 是否为 token
ts.isClassDeclaration(node)        // 类声明
ts.isMethodDeclaration(node)       // 方法声明
ts.isConstructorDeclaration(node)  // 构造函数声明
ts.isObjectBindingPattern(node)    // 对象解构: { a, b }
ts.isVariableDeclarationList(node) // 变量声明列表
```

### 4.4 常用节点类型的特有属性

| 节点类型 | 对应 JS 语法 | 特有属性 |
|---------|-------------|---------|
| `CallExpression` | `foo()` / `a.b()` | `expression`, `arguments`, `typeArguments` |
| `PropertyAccessExpression` | `a.b` | `expression`, `name` |
| `ElementAccessExpression` | `a[b]` | `expression`, `argumentExpression` |
| `BinaryExpression` | `a = b` / `a + b` | `left`, `right`, `operatorToken` |
| `Identifier` | `foo` | `text`, `escapedText` |
| `StringLiteral` | `"hello"` | `text` |
| `FunctionDeclaration` | `function foo() {}` | `name`, `parameters`, `body` |
| `ArrowFunction` | `() => {}` | `parameters`, `body` |
| `ReturnStatement` | `return x` | `expression` |
| `IfStatement` | `if (x) {}` | `expression`, `thenStatement`, `elseStatement` |
| `ForInStatement` | `for (x in y) {}` | `initializer`, `expression`, `statement` |
| `SourceFile` | 整个文件 | `fileName`, `statements` |
| `VariableDeclaration` | `let x = 1` | `name`, `initializer`, `type` |
| `ObjectLiteralExpression` | `{ a: 1 }` | `properties` |

### 4.5 XPath 查询

引擎提供了 XPath 查询能力，可在 AST 上执行 XPath 表达式：

> [来源: src/util.ts:L1516-L1540]

```javascript
const util = require("../util");

// 查找所有匹配节点
let nodes = util.findNodesByXpath(node, xpath);

// 查找第一个匹配节点
let firstNode = util.findFirstNodeByXpath(node, xpath);
```

**XPath 示例**（从实际 extend-file 中提取）：

```javascript
// 查找所有 CallExpression 中 PropertyAccessExpression 的 name 为 'get' 或 'post' 的节点
let xpath = "./SourceFile//CallExpression[PropertyAccessExpression/@name/self::Identifier[text() = 'get' or text() = 'post']]";
let nodes = util.findNodesByXpath(node, xpath);
```

> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7022/csrfTs_7022.js:L40-L41]

### 4.6 链式调用的 AST 表示

`require("mysql").createConnection(...).query(...)` 在 TypeScript AST 中表示为嵌套的 `CallExpression`：

```
CallExpression                          // .query(...)
├── PropertyAccessExpression            // ...createConnection(...).query
│   ├── CallExpression                  // .createConnection(...)
│   │   ├── PropertyAccessExpression    // require("mysql").createConnection
│   │   │   ├── CallExpression          // require("mysql")
│   │   │   │   ├── Identifier: require
│   │   │   │   └── StringLiteral: "mysql"
│   │   │   └── Identifier: createConnection
│   │   └── arguments: [...]
│   └── Identifier: query
└── arguments: [...]
```

### 4.7 节点遍历

```javascript
// 遍历所有直接子节点
ts.forEachChild(node, (child) => { /* ... */ });

// 获取父节点
let parent = node.parent;

// 获取源文件
let sourceFile = node.getSourceFile();
let fileName = sourceFile.fileName;

// 使用 TypeScriptVisitorAdapter 进行自定义遍历
const visitor = require("../../visitor");
class MyFinder extends visitor.TypeScriptVisitorAdapter {
    constructor() {
        super(...arguments);
        this.results = [];
    }
    visitCallExpression(node) {
        this.results.push(node);
        super.visitCallExpression(node);
    }
    getResult() { return this.results; }
}
let finder = new MyFinder();
finder.visit(node);
let calls = finder.getResult();
```

> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7022/csrfTs_7022.js — 未使用自定义 Visitor]
> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7021/NodeJS_backend_common_source.js — 使用 FunctionDeclarationFinder]

---

## §5. 参数 `context` 的完整 API

### 5.1 类型

`context` 的类型取决于当前分析阶段：

| Visitor | context 类型 | 来源文件 |
|---------|-------------|---------|
| `TaintAnalysisVisitor` | `TaintAnalysisContext` | `src/taintAnalysis/TaintAnalysisContext.ts` (523行) |
| `FsmAnalysisVisitor` | `FsmAnalysisContext` | `src/taintAnalysis/FsmAnalysisiContext.ts` (391行) |

两个类有大量相似的方法。以下列出**两者共有的方法**和**各自特有的方法**。

### 5.2 共有方法

#### 污点上下文操作

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `getTaintContext()` | `TaintContext` | 获取当前污点上下文 | TaintAnalysisContext.ts:L66 |
| `setTaintContext(sink, name, astnode, baseVar, taintSubPathes, safeSubPathes, precise)` | `void` | 设置污点上下文 | TaintAnalysisContext.ts:L70 |
| `setMultiTaintContext(sink, name, astnode, multiTaintBaseVar, multiTaintSubPathes, multiSafeSubPathes, precise)` | `void` | 设置多数据流污点上下文 | TaintAnalysisContext.ts:L83 |
| `copyTaintContext(source: TaintContext)` | `void` | 从 source 复制污点上下文到当前 context | TaintAnalysisContext.ts:L97 |
| `clearTaint()` | `void` | 清除当前污点状态 | TaintAnalysisContext.ts:L264 |
| `isTaintContext(taintContext?)` | `boolean` | 判断是否处于污点状态（可传入指定 context 判断） | TaintAnalysisContext.ts:L277 |

#### 方法上下文管理

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `getVisitMethodContext()` | `MethodContext` | 获取当前方法上下文 | TaintAnalysisContext.ts:L54 |
| `getLastMethodContext()` | `MethodContext` | 获取上一个方法上下文 | TaintAnalysisContext.ts:L58 |
| `getParentMethodContext()` | `MethodContext` | 获取父方法上下文 | TaintAnalysisContext.ts:L293 |
| `getMethodContexts()` | `MethodContext[]` | 获取方法上下文栈 | TaintAnalysisContext.ts:L341 |
| `pushVisitedmethodcontext(ctx)` | `void` | 压入方法上下文 | TaintAnalysisContext.ts:L32 |
| `popVisitedmethodcontext()` | `void` | 弹出方法上下文 | TaintAnalysisContext.ts:L37 |
| `inMethodContexts(node)` | `boolean` | 判断节点是否在方法上下文栈中 | TaintAnalysisContext.ts:L345 |
| `genVisitid()` | `number` | 生成唯一的 visit ID | TaintAnalysisContext.ts:L392 |
| `genCallString()` | `string` | 生成调用链字符串 | TaintAnalysisContext.ts:L397 |

#### 调用标志管理

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `isInvokeFlag()` | `boolean` | 是否处于函数调用中 | TaintAnalysisContext.ts:L248 |
| `setInvokeFlag(node)` | `void` | 设置调用标志 | TaintAnalysisContext.ts:L238 |
| `clearInvokeFlag()` | `void` | 清除调用标志 | TaintAnalysisContext.ts:L243 |
| `getInvokeNode()` | `ts.Node` | 获取当前调用节点 | TaintAnalysisContext.ts:L260 |
| `setCascadeInvoke(flag)` | `void` | 设置级联调用标志 | TaintAnalysisContext.ts:L252 |
| `isCascadeInvoke()` | `boolean` | 是否级联调用 | TaintAnalysisContext.ts:L256 |

#### 字段污点管理

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `setTaintFields(fields)` | `void` | 设置污点字段集 | TaintAnalysisContext.ts:L384 |
| `getTaintFields()` | `TaintVarSet` | 获取污点字段集 | TaintAnalysisContext.ts:L388 |
| `isAddFieldFlag()` | `boolean` | 是否添加字段标志 | TaintAnalysisContext.ts:L226 |
| `setAddFieldFlag()` | `void` | 设置添加字段标志 | TaintAnalysisContext.ts:L230 |
| `clearAddFieldFlag()` | `void` | 清除添加字段标志 | TaintAnalysisContext.ts:L234 |

#### 方法参数上下文

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `setMethodargContext(args)` | `void` | 设置方法参数上下文 | TaintAnalysisContext.ts:L371 |
| `getMethodargContext()` | `any[]` | 获取方法参数上下文 | TaintAnalysisContext.ts:L376 |
| `clearMethodargContext()` | `void` | 清除方法参数上下文 | TaintAnalysisContext.ts:L380 |

#### 自定义数据

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `getCustomData()` | `Map<string, any>` | 获取自定义数据 | TaintAnalysisContext.ts:L46 |
| `setCustomData(data)` | `void` | 设置自定义数据 | TaintAnalysisContext.ts:L50 |

#### 返回值污点

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `addReturnTaintContext(sink, methodname, visitid, name, astnode, baseVar, taintSubPathes, safeSubPathes, precise)` | `void` | 添加返回值污点上下文 | TaintAnalysisContext.ts:L130 |
| `addReturnMultiTaintContext(sink, methodname, visitid, name, astnode, multiTaintBaseVar, multiTaintSubPathes, multiSafeSubPathes, precise)` | `void` | 添加多数据流返回值污点 | TaintAnalysisContext.ts:L171 |

#### 污点变量追踪

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `parentTaintVar(taintVar, taintTag?)` | `MethodContext` | 在父上下文中查找污点变量 | TaintAnalysisContext.ts:L309 |
| `getAncestorContextNoInvoke(node)` | `MethodContext` | 获取非调用的祖先上下文 | TaintAnalysisContext.ts:L355 |

### 5.3 TaintAnalysisContext 特有方法

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `isSafeContext(taintContext?)` | `boolean` | 判断是否处于安全（已净化）状态 | TaintAnalysisContext.ts:L285 |
| `setSafe()` | `void` | 设置为安全状态 | TaintAnalysisContext.ts:L268 |
| `addReturnTaintContextWithInstance(ctx)` | `void` | 添加带实例的返回值污点 | TaintAnalysisContext.ts:L122 |
| `handleDistinctReturnContext(ctx)` | `void` | 处理不同的返回上下文 | TaintAnalysisContext.ts:L144 |
| `checkInvokeParentTaint()` | `boolean` | 检查调用父级污点 | TaintAnalysisContext.ts:L421 |
| `setTaintContextByAllArg(...)` | `void` | 通过所有参数设置污点上下文 | TaintAnalysisContext.ts:L206 |

### 5.4 FsmAnalysisContext 特有方法

| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| `getFsmInstances()` | `Map<any, any>` | 获取 FSM 实例集合 | FsmAnalysisiContext.ts:L41 |
| `getCurrentEntrance()` | `ts.Node` | 获取当前入口节点 | FsmAnalysisiContext.ts:L148 |
| `setCurrentEntrance(node)` | `void` | 设置当前入口节点 | FsmAnalysisiContext.ts:L152 |

### 5.5 关键数据结构

#### TaintContext 接口

> [来源: src/interface.ts:L90-L106]

```typescript
interface TaintContext {
    sink: SinkType,           // 当前 sink 类型
    filename: string,         // 文件名
    methodname: string,       // 方法名
    visitid: number,          // 访问 ID
    name: string,             // 名称
    astnode: ts.Node,         // AST 节点
    baseVar: MapOfVariable,   // 基础变量
    taintSubPathes: string[], // 污点子路径
    safeSubPathes: string[],  // 安全子路径
    multiTaintBaseVar: Map<string, MapOfVariable>,   // 多数据流基础变量
    multiTaintSubPathes: Map<string, string[]>,      // 多数据流污点子路径
    multiSafeSubPathes: Map<string, string[]>,       // 多数据流安全子路径
    precise: boolean,         // 是否精确
}
```

#### SinkType 枚举

> [来源: src/interface.ts:L145-L150]

```typescript
enum SinkType {
    None = 0,    // 无
    Input = 1,   // 输入（source）
    Trace = 2,   // 追踪（中间节点）
    Output = 3,  // 输出（sink）
    Clear = -1   // 清除
}
```

#### MethodContext 接口

> [来源: src/interface.ts:L67-L88]

```typescript
interface MethodContext {
    methodname: string,
    astnode: ts.Node,
    taintedvars: TaintVarSet,
    taintedfields: TaintVarSet,
    visitid: number,
    invokeflag: boolean,
    invokeNode: ts.Node,
    returnContextList: TaintContext[],
    createdFsmInstance: FsmInstance,
    sourceEncapFeatures: Set<SourceEncapFeature>,
    sinkEncapFeatures: Set<SinkEncapFeature>,
    taintOrigins: Map<MapOfVariable, Set<MapOfVariable>>,
    taintResults: Map<MapOfVariable, Set<MapOfVariable>>,
    currentToVar: MapOfVariable,
    returnNodeList: ts.ReturnStatement[],
    methodargContext: any[],
    taintArgs: Set<MapOfVariable>,
    multiTaintArgs: Map<string, Set<MapOfVariable>>,
    isXssContentTypeContext: boolean,
    isObjectBindingReturnContext: boolean,
    isControlFlowBroken: boolean,
}
```

#### Vertex 接口

> [来源: src/interface.ts:L30-L43]

```typescript
interface Vertex {
    appname: string,
    id: string,
    name: string,
    file: string,
    method: string,
    callid: number,
    type: number,       // SinkType 枚举值
    tracetype: string,
    line: number,
    codesegment: string,
    flag: string,
    column: number,
    end_column: number,
    tag: string,
}
```

### 5.6 TaintVarSet 完整 API

> [来源: src/InterApp/TaintVarSet.ts — 1072 行]

`TaintVarSet` 是污点变量集合，通过 `rule.analysisVisitor.getCurrentTaintVarSet()` 或 `context.getVisitMethodContext().taintedvars` 获取。它管理三类变量集合：污点变量（taintVars）、安全变量（safeVars）、多数据流污点变量（multiTaintVars）。

#### Getter / Setter

| 方法 | 返回类型 | 说明 | 行号 |
|------|---------|------|------|
| `getTaintVars()` | `Map<string, Set<MapOfVariable>>` | 获取污点变量集合 | L15 |
| `getSafeVars()` | `Map<string, Set<MapOfVariable>>` | 获取安全变量集合 | L19 |
| `getMultiTaintVars()` | `Map<string, Map<string, Set<MapOfVariable>>>` | 获取多数据流污点变量集合 | L23 |
| `setTaintVars(taintVars)` | `void` | 设置污点变量集合 | L27 |
| `setSafeVars(safeVars)` | `void` | 设置安全变量集合 | L31 |
| `setMultiTaintVars(multiTaintVars)` | `void` | 设置多数据流污点变量集合 | L35 |

#### 核心操作 — 添加/删除变量

| 方法 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `addTaintVariable(taintVar)` | `MapOfVariable` | `boolean` | 添加污点变量（同时从安全集合中移除） | L72 |
| `addMultiTaintVariable(taintVar, taintTag)` | `MapOfVariable, string` | `boolean` | 添加多数据流污点变量（按 tag 分组） | L108 |
| `deleteTaintVariable(taintVar)` | `MapOfVariable` | `void` | 删除污点变量 | L157 |
| `deleteMultiTaintVariable(taintVar, taintTag?)` | `MapOfVariable, string?` | `void` | 删除多数据流污点变量（taintTag 为 null 时删除所有 tag） | L180 |
| `addSafeVariable(safeVar)` | `MapOfVariable` | `boolean` | 添加安全变量（同时从污点集合中移除） | L222 |

#### 查询 — 变量污点状态

| 方法 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `isVariableAllTaint(taintVar)` | `MapOfVariable` | `boolean` | 判断变量是否**完全**被污染（考虑安全变量） | L275 |
| `isMultiVariableAllTaint(taintVar, taintTag)` | `MapOfVariable, string` | `boolean` | 判断变量在指定 tag 下是否完全被污染 | L336 |
| `isVariableMayTaint(taintVar)` | `MapOfVariable` | `boolean` | 判断变量是否**可能**被污染（包括部分污染） | L395 |
| `isVariableMayMultiTaint(taintVar, taintTag)` | `MapOfVariable, string` | `boolean` | 判断变量在指定 tag 下是否可能被污染 | L463 |
| `isSafeVariable(safeVar)` | `MapOfVariable` | `boolean` | 判断变量是否为安全变量 | L247 |
| `isEmptyTaint()` | — | `boolean` | 判断污点变量集合是否为空 | L68 |
| `getVariableMayMultiTaintTags(taintVar)` | `MapOfVariable` | `string[]` | 获取变量可能被污染的所有 tag 列表 | L453 |

#### 查询 — 精确匹配

| 方法 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `containsTaintVar(taintVar)` | `MapOfVariable` | `boolean` | 精确检查污点集合中是否包含该变量 | L969 |
| `containsSafeVar(safeVar)` | `MapOfVariable` | `boolean` | 精确检查安全集合中是否包含该变量 | L983 |
| `containsMultiTaintVar(taintVar, taintTag)` | `MapOfVariable, string` | `boolean` | 精确检查多数据流集合中是否包含该变量 | L1013 |
| `containsMultiTaintVarAllTag(taintVar)` | `MapOfVariable` | `string \| null` | 在所有 tag 中查找该变量，返回找到的 tag 名 | L997 |

#### 路径查询 — 子路径分析

| 方法 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `getLastTaintedVar(taintVar)` | `MapOfVariable` | `MapOfVariable` | 获取最近的被污染的祖先变量 | L530 |
| `getLastMultiTaintedVar(taintVar, taintTag)` | `MapOfVariable, string` | `MapOfVariable` | 获取多数据流中最近的被污染的祖先变量 | L586 |
| `getAllTaintedSubPathesSet(taintVar)` | `MapOfVariable` | `string[]` | 获取变量所有被污染的子路径 | L649 |
| `getTaintedSubPathesSet(taintVar)` | `MapOfVariable` | `string[]` | 获取变量被污染的子路径（去重合并） | L669 |
| `getMultiTaintedSubPathesSet(taintVar, taintTag)` | `MapOfVariable, string` | `string[]` | 获取多数据流中变量被污染的子路径 | L723 |
| `getAllSafeSubPathesSet(safeVar)` | `MapOfVariable` | `string[]` | 获取变量所有安全的子路径 | L786 |
| `getSafeSubPathesSet(safeVar)` | `MapOfVariable` | `string[]` | 获取变量安全的子路径（去重合并） | L806 |
| `getFieldTaintVarSet(baseVar)` | `MapOfVariable` | `TaintVarSet` | 获取基础变量的字段级污点集合 | L861 |

#### 获取所有变量

| 方法 | 返回类型 | 说明 | 行号 |
|------|---------|------|------|
| `getAllTaintVars()` | `MapOfVariable[]` | 获取所有污点变量数组 | L910 |
| `getAllSafeVars()` | `MapOfVariable[]` | 获取所有安全变量数组 | L920 |
| `getAllMultiTaintVars()` | `Map<string, MapOfVariable[]>` | 获取所有多数据流污点变量（按 tag 分组） | L930 |
| `getAllTaintVarsSet()` | `Set<MapOfVariable>` | 获取所有污点变量 Set | L943 |
| `getAllSafeVarsSet()` | `Set<MapOfVariable>` | 获取所有安全变量 Set | L953 |

#### 其他

| 方法 | 返回类型 | 说明 | 行号 |
|------|---------|------|------|
| `copy()` | `TaintVarSet` | 深拷贝当前 TaintVarSet | L39 |
| `printAllTaintVars()` | `string` | 打印所有污点变量（调试用） | L1031 |
| `printAllSafeVars()` | `string` | 打印所有安全变量（调试用） | L1047 |

**常见用法示例**：

```javascript
let taintVarSet = rule.analysisVisitor.getCurrentTaintVarSet();
let varRef = MapOfVariable.getVarFromNode(node);

// 添加污点变量
taintVarSet.addTaintVariable(varRef);

// 添加多数据流污点变量
taintVarSet.addMultiTaintVariable(varRef, "taint_tag_default");

// 查询变量是否被污染
if (taintVarSet.isVariableMayTaint(varRef)) {
    // 变量可能被污染
}

// 标记变量为安全
taintVarSet.addSafeVariable(varRef);
```

> [实际使用: src/utils/prototypePollutionUtil.ts:L293 — `rule.analysisVisitor.getCurrentTaintVarSet().addMultiTaintVariable(toVar, TAINT_TAG_DEFAULT)`]

---

## §6. 可 require 的内置模块

### 6.1 已确认的模块列表

以下模块在多个 extend-file 示例中被 `require` 引用：

> [来源: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7022/csrfTs_7022.js:L1-L18]
> [来源: resources/benchmark/prototype_pollution/rule/extend-file/assignment/prototypePollutionAssignment_assignment.js:L1-L11]

| require 路径 | 模块 | 说明 |
|-------------|------|------|
| `"../logger"` | SimpleLogger | 日志工具 |
| `"../global"` | GlobalContext | 全局上下文 |
| `"typescript"` | ts | TypeScript 编译器 API |
| `"../util"` | util/utils | 工具函数集 |
| `"hashmap"` | HashMap | HashMap 数据结构 |
| `"../../visitor"` | TypeScriptVisitorAdapter | AST 遍历基类 |
| `"../InterApp/MapofVariable"` | MapOfVariable | 变量映射工具 |
| `"../taintAnalysis/TagInfo"` | TagInfoTreeAdapter | 标签信息适配器 |
| `"module"` | m | Node.js module 模块 |
| `"vm"` | vm | Node.js vm 模块 |

### 6.2 `../logger` — SimpleLogger

> [来源: src/logger.ts:L1-L67]

```typescript
class SimpleLogger {
    constructor(tag: string)
    debug(message: string): void    // 绿色输出
    info(message: string): void     // 白色输出
    warning(message: string): void  // 黄色输出
    error(message: string): void    // 红色输出
    fatal(message: string): void    // 红色背景输出
}
```

**使用示例**：
```javascript
const logger_1 = require("../logger");
// 注意：logger_1 导出的是 SimpleLogger 类，需要实例化
// 或直接使用已有的 logger 实例
```

### 6.3 `../global` — GlobalContext

> [来源: src/global.ts:L72-L116]

`GlobalContext` 包含引擎运行时的全局状态。以下是完整属性列表：

#### 核心属性（extend-file 中常用）

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `configParser` | `ConfigParser` | 配置解析器实例 | L72 |
| `scopeVisitor` | `ScopeVisitor` | 作用域访问者 | L73 |
| `fullNameVisitor` | `GenFullNameVisitor` | 全名访问者，生成节点完整名称 | L74 |
| `languageService` | `ts.LanguageService` | TypeScript 语言服务 | L75 |
| `targetProjectDir` | `string` | 目标项目目录路径 | L76 |
| `routerEntries` | `Map` | 路由入口映射 | L91 |
| `routerSourceFiles` | `Map` | 路由源文件映射 | L92 |
| `relativeFilePathToAst` | `Map` | 文件路径到 AST 的映射 | L78 |
| `fileToRequiredFiles` | `Map` | 文件依赖关系映射 | L115 |

#### AST 和导出映射

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `relativeFilePathToExports` | `Map` | 文件路径到导出内容的映射 | L79 |
| `mainExports` | `Map` | 主导出内容映射 | L80 |
| `mainExportsDecls` | `Map` | 主导出声明映射 | L81 |
| `mainExportNames` | `Map` | 主导出名称映射 | L82 |
| `mainExportsSourceFiles` | `Set` | 主导出源文件集合 | L83 |
| `relativeFilePathToFunAsts` | `Map` | 文件路径到函数 AST 的映射 | L84 |
| `scopeNameToFunAsts` | `Map` | 作用域名称到函数 AST 的映射 | L85 |
| `funNameToFunAsts` | `Map` | 函数名到函数 AST 的映射 | L86 |

#### 框架集成

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `routerConfigs` | `Map` | 路由配置映射 | L90 |
| `midwayHooksRouteMapping` | `Map` | Midway Hooks 路由映射 | L93 |
| `provideNameToClassNode` | `Map` | 依赖注入名称到类节点的映射 | L88 |
| `eggContextInjectionFunctions` | `Map` | Egg 上下文注入函数映射 | L110 |
| `eggPropsToRelativePlugins` | `any` | Egg 属性到相对插件的映射 | L111 |

#### HSF 相关

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `hsfProfileToFunAst` | `Map` | HSF 配置文件到函数 AST 的映射 | L89 |
| `proxyClassToHsf` | `Map` | 代理类到 HSF 的映射 | L96 |
| `proxyClassToHsfInfo` | `Map` | 代理类到 HSF 信息的映射 | L97 |
| `callNodeToHsf` | `Map` | 调用节点到 HSF 的映射 | L98 |
| `hsfConfigs` | `Map` | HSF 配置映射 | L102 |
| `hsfConsumerMethodInfos` | `Array` | HSF 消费者方法信息数组 | L103 |
| `hsfInvokeNodes` | `Map` | HSF 调用节点映射 | L116 |

#### 其他

| 属性 | 类型 | 说明 | 行号 |
|------|------|------|------|
| `project` | `ts.Project` | TypeScript 项目对象 | L77 |
| `tempFileToRealFile` | `Map` | 临时文件到真实文件的映射 | L94 |
| `obfuscatedFiles` | `Set` | 混淆文件集合 | L95 |
| `entranceUrls` | `Map` | 入口 URL 映射 | L99 |
| `senstiveApis` | `Map` | 敏感 API 映射 | L100 |
| `mtopInfos` | `Map` | MTOP 信息映射 | L101 |
| `preRuleResults` | `Map` | 预规则结果映射 | L105 |
| `bigFiles` | `Set` | 大文件集合 | L108 |
| `bigFunctions` | `Set` | 大函数集合 | L109 |
| `templateAnalyzer` | `TemplateAnalyzer` | 模板分析器实例 | L112 |
| `globalCustomSourceNodes` | `Map` | 全局自定义源节点映射 | L113 |
| `serviceNameToFuncAsts` | `Map` | 服务名称到函数 AST 的映射 | L114 |

#### GlobalContext 方法

| 方法 | 说明 | 行号 |
|------|------|------|
| `httpEntrance(rule, node)` | HTTP 入口判断，检查节点是否在 controller 作用域中 | L132 |
| `xpathEntrance(rule, node)` | XPath 入口判断，通过 XPath 查找节点 | L140 |
| `csrfEntrance(rule, node)` | CSRF 入口判断，根据 CSRF 配置判断路由入口 | L146 |
| `allEntrance(rule, node)` | 综合入口判断，综合判断 controller 和路由 | L307 |
| `matchCallString(callString, patterns)` | 匹配调用字符串，支持正则表达式 | L336 |
| `commonLog(rule, node, context)` | 通用日志函数，记录标签信息和追踪树 | L323 |

> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7022/csrfTs_7022.js:L24-L26]

### 6.4 `../util` — 工具函数

> [来源: src/util.ts — 5524 行]

#### XPath 和节点查询

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `findNodesByXpath(node, xpath)` | `ts.Node, string` | `ts.Node[]` | XPath 查询所有匹配节点 | L1516 |
| `findFirstNodeByXpath(node, xpath)` | `ts.Node, string` | `ts.Node` | XPath 查询第一个匹配节点 | L1539 |

#### 节点位置信息

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `getBeginLine(node)` | `ts.Node` | `number` | 获取节点起始行号 | L1436 |
| `getEndLine(node)` | `ts.Node` | `number` | 获取节点结束行号 | L1445 |
| `getBeginColumn(node)` | `ts.Node` | `number` | 获取节点起始列号 | L1454 |
| `getEndColumn(node)` | `ts.Node` | `number` | 获取节点结束列号 | L1463 |
| `getSpecialLine(node)` | `ts.Node` | `number` | 获取特殊行号（方法/函数使用名字所在行） | L1391 |
| `getSpecialBeginColumn(node)` | `ts.Node` | `number` | 获取特殊起始列号 | L1406 |
| `getSpecialEndColumn(node)` | `ts.Node` | `number` | 获取特殊结束列号 | L1421 |

#### 常量字符串解析

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `getConstString(node)` | `ts.Node` | `string` | 获取常量字符串值 | L210 |
| `getConstStringStrict(node)` | `ts.Node` | `string` | 严格获取常量字符串值 | L403 |
| `getConstStringWithUnresolvableValue(node, list)` | `ts.Node, ts.Node[]` | `string` | 获取含不可解析值的常量字符串 | L844 |
| `findReplaceStrings(text, node)` | `string, ts.Node` | `string` | 查找替换字符串 | — |

#### 名称和路径处理

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `extractName(node)` | `ts.Node` | `string` | 提取节点名称 | L189 |
| `getShortFileName(filePath)` | `string` | `string` | 获取短文件名 | L88 |
| `fileToRelativeFile(filePath, rootPath)` | `string, string` | `string` | 获取文件相对路径 | L1178 |
| `getRelativePath(node)` | `ts.Node` | `string` | 获取节点相对路径 | L1186 |
| `removeWhiteSpace(text)` | `string` | `string` | 移除空白字符 | L182 |
| `removeQuotes(param)` | `string` | `string` | 移除引号 | L1213 |

#### 属性访问表达式

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `getMostLeftNode(prop)` | `ts.PropertyAccessExpression` | `ts.Node` | 获取最左侧节点 | L1074 |
| `collectLeftNames(prop)` | `ts.PropertyAccessExpression` | `ts.Node[]` | 收集左侧名称 | L1081 |
| `isSimplePropertyAccessExpression(prop)` | `ts.Node` | `boolean` | 判断是否为简单属性访问 | L1106 |

#### 文件操作

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `getSegment(fileName, beginLine, endLine)` | `string, number, number` | `string` | 获取文件片段 | L1123 |
| `getContent(fileName)` | `string` | `string` | 获取文件内容 | L1160 |
| `isBlackFile(file)` | `string` | `boolean` | 判断是否为黑名单文件 | L1213 |

#### 配置和框架

| 函数 | 参数 | 返回类型 | 说明 | 行号 |
|------|------|---------|------|------|
| `isFramework(name)` | `string` | `boolean` | 判断是否为指定框架 | — |
| `getConfigString(configKey)` | `string` | `string` | 获取配置字符串 | L802 |
| `getMemberValue(memberName, locationNode)` | `string, ts.Node` | `string` | 获取成员变量的值 | L452 |
| `handleSubject(subject, keyValues)` | `string, Map` | `string` | 处理主题字符串替换 | L94 |
| `isMethodCallShouldExpand(node)` | `ts.CallExpression` | `boolean` | 判断方法调用是否应展开 | L163 |
| `findFunctionBodyWithExpression(node)` | `ts.Node` | `ts.Node` | 查找函数体 | — |
| `addVertexFlag(vex, flag)` | `Vertex, string` | `void` | 添加顶点标志 | L119 |

> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7022/csrfTs_7022.js:L133 — `util.findReplaceStrings(text, node)`]

### 6.5 `../../visitor` — TypeScriptVisitorAdapter

> [来源: visitor.ts:L1-L2597]

提供 AST 遍历的基类，包含 100+ 个 `visit*` 方法，覆盖所有 TypeScript AST 节点类型。

**使用方式**：继承 `TypeScriptVisitorAdapter` 并覆盖感兴趣的 `visit*` 方法。

```javascript
const visitor = require("../../visitor");

class FunctionDeclarationFinder extends visitor.TypeScriptVisitorAdapter {
    constructor() {
        super(...arguments);
        this.results = [];
    }
    visitFunctionDeclaration(node) {
        this.results.push(node);
        super.visitFunctionDeclaration(node);
    }
    getResult() { return this.results; }
}

let finder = new FunctionDeclarationFinder();
finder.visit(sourceFileNode);
let allFunctions = finder.getResult();
```

> [实际使用: resources/capability_taint/hsf_summary/online_dsl_rules/extend-file/7021/NodeJS_backend_common_source.js — FunctionDeclarationFinder 模式]

### 6.6 `../InterApp/MapofVariable` — 变量映射工具

> [来源: src/InterApp/MapofVariable.ts]

`MapOfVariable` 用于表示 AST 中的变量引用，是污点分析中标识变量的核心数据结构。

**常用静态方法**：

| 方法 | 说明 |
|------|------|
| `MapOfVariable.getVarFromNode(node)` | 从 AST 节点创建变量引用 |

> [实际使用: src/utils/prototypePollutionUtil.ts:L260 — `MapOfVariable.getVarFromNode(param)`]

### 6.7 `typescript` — TypeScript 编译器 API

```javascript
const ts = require("typescript");
```

提供完整的 TypeScript 编译器 API，包括：
- **`ts.SyntaxKind`** — 节点类型枚举
- **`ts.is*()` 系列** — 类型守卫函数（见 §4.3）
- **`ts.forEachChild()`** — 子节点遍历
- **`ts.createSourceFile()`** — 创建源文件

### 6.8 `hashmap` — HashMap 数据结构

```javascript
const HashMap = require("hashmap");
let map = new HashMap();
map.set(key, value);
map.get(key);
map.has(key);
```

> [实际使用: resources/benchmark/prototype_pollution/rule/extend-file/assignment/prototypePollutionAssignment_assignment.js:L5]

### 6.9 路径解析规则

`require()` 路径相对于 extend-file 中 `.js` 文件所在的目录。例如：

```
extend-file/6991/XssTs_6991.js 中：
  require("../logger")     → src/logger.ts (编译后)
  require("../global")     → src/global.ts (编译后)
  require("../util")       → src/util.ts (编译后)
  require("../../visitor")  → visitor.ts (编译后)
  require("typescript")     → node_modules/typescript
  require("hashmap")        → node_modules/hashmap
```

由于引擎运行在 Node.js 中，标准 Node.js 内置模块（`fs`、`path`、`module`、`vm` 等）均可使用，但**不建议在规则扩展中使用文件系统操作**。

---

## §7. 除 userDefineFunc 外的其他扩展点

### 7.1 扩展点总览

> [来源: src/dsl/RuleUtil.ts:L2027-L2450 — transformSingleDslToJs 函数]

除 `userDefineFunc` 外，引擎还支持以下扩展点：

| 扩展点名称 | 适用分析模式 | 说明 | 来源 |
|-----------|-------------|------|------|
| `customSourceFunc` | Taint | 自定义 source 判定函数 | Rule.ts:L29 |
| `validateFunction` | Taint / FSM | 规则验证函数（后处理） | Rule.ts:L76 |
| `entranceEvalFun` | FSM | FSM 入口判定函数 | interface.ts:L124, CollectEntranceVisitor.ts:L62 |
| `evalFun` | FSM | FSM 条件评估函数 | interface.ts:L118, FsmAnalysisVisitor.ts:L279 |
| `helperFunctions` | Taint / FSM | 辅助函数集合 | RuleUtil.ts — DSL `helper` 块 |

### 7.2 `customSourceFunc` — 自定义 Source 函数

> [来源: src/rule/Rule.ts:L29]

```typescript
customSourceFunc: Function | Function[];
```

用于自定义判断某个 AST 节点是否为污点源（source）。在 DSL 中通过 `general.userDefinePatternClass` 或 `source` 块中的 `loadclass()` 引用。

**函数签名**（从调用处推断）：

```javascript
rule.customSourceFunc = function(rule, node, context) {
    // 判断 node 是否为自定义 source
    // 返回 true 表示该节点是 source
    return false;
};
```

> [来源: src/dsl/RuleUtil.ts:L5778 — customSourceFunc 合并逻辑与 userDefineFunc 类似]

### 7.3 `validateFunction` — 规则验证函数

> [来源: src/rule/Rule.ts:L76]

```typescript
validateFunction: RuleValidateFunctionType[];
```

验证函数在分析完成后执行，用于对检测结果进行后处理（如过滤误报）。

**函数签名**（从 DSL 生成代码推断）：

```javascript
rule.validateFunction = [function(rule, bugList) {
    // bugList 是检测到的缺陷列表
    // 可以过滤、修改或补充缺陷信息
    return filteredBugList;
}];
```

### 7.4 `entranceEvalFun` — FSM 入口函数

> [来源: src/interface.ts:L124 — FsmMachine 接口定义]
> [来源: src/taintAnalysis/CollectEntranceVisitor.ts:L56-L63 — 调用处]

FSM 规则中，`entranceEvalFun` 定义了状态机的入口条件，用于判断某个源文件是否为 FSM 分析的入口。

**接口定义**：

```typescript
// src/interface.ts:L122-L128
export interface FsmMachine {
    ruleName: string,
    entranceEvalFun: any,   // FSM 入口判定函数
    extraParams: [],
    states: FsmState[],
    transitions: FsmTransition[],
    conditions: FsmCondition[],
    // ...
}
```

**函数签名**（从调用处确认）：

```javascript
// 调用处: CollectEntranceVisitor.ts:L62
// this.rule.fsm.entranceEvalFun(this.rule, sourceFile, this.rule.fsm.extraParams)

rule.fsm.entranceEvalFun = function(rule, sourceFile, extraParams) {
    // rule: Rule 实例
    // sourceFile: ts.SourceFile — 当前源文件的 AST 根节点
    // extraParams: [] — FSM 配置中的额外参数
    // 返回 true 表示该文件是 FSM 的入口
    return true;
};
```

> [来源: src/taintAnalysis/CollectEntranceVisitor.ts:L62 — `return this.rule.fsm.entranceEvalFun(this.rule, sourceFile, this.rule.fsm.extraParams)`]

### 7.5 `evalFun` — FSM 条件评估函数

> [来源: src/interface.ts:L116-L120 — FsmCondition 接口定义]
> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts:L279, L524 — 调用处]

FSM 规则中，每个 `FsmCondition` 包含一个 `evalFun`，用于评估状态转换条件是否满足。

**接口定义**：

```typescript
// src/interface.ts:L116-L120
export interface FsmCondition {
    beforeDestroyFlag?: boolean,
    transName: string,
    evalFun: any,       // 条件评估函数
    extraParams: [],
}
```

**函数签名**（从调用处确认，有两种调用形式）：

```javascript
// 标准调用: FsmAnalysisVisitor.ts:L279
// condition.evalFun(this.rule, node, condition.extraParams)

// beforeDestroy 调用: FsmAnalysisVisitor.ts:L524
// condition.evalFun(this.rule, node, condition.extraParams, this.fsmAnalysisContext, true)

rule.conditionEvalFunc = function(rule, node, extraParams, context, beforeDestroyFlag) {
    // rule: Rule 实例
    // node: ts.Node — 当前 AST 节点
    // extraParams: [] — 条件配置中的额外参数
    // context: FsmAnalysisContext（可选）— 仅在 beforeDestroy 阶段传入
    // beforeDestroyFlag: boolean（可选）— 仅在 beforeDestroy 阶段为 true
    // 返回 true 表示条件满足，允许状态转换
    return false;
};
```

**错误处理**：与 `userDefineFunc` 不同，`evalFun` 的调用**有 try-catch 包裹**：

> [来源: src/taintAnalysis/FsmAnalysisVisitor.ts:L283-L285]

```javascript
try {
    if (!condition.evalFun(this.rule, node, condition.extraParams)) { ... }
} catch (e) {
    this.logger.fatal(`处理状态机转换'${condition.transName}'上条件出错，错误信息：${e.stack}`);
}
```

异常时引擎会记录 fatal 日志，但不会中断分析流程。

### 7.6 `helperFunctions` — 辅助函数

辅助函数不直接作为扩展点被引擎调用，而是供其他扩展函数（如 `userDefineFunc`、`customSourceFunc`）内部调用的工具函数。

**使用方式**：在 extend-file 中定义为 `rule` 对象的属性，然后在 `userDefineFunc` 中通过 `rule.helperFunctionName()` 调用。

```javascript
let rule = {};
module.exports.rule = rule;

// 辅助函数
rule.isDangerousPattern = function(node) {
    // 辅助判断逻辑
    return false;
};

// 主扩展函数引用辅助函数
rule.userDefineFunc = function(rule, node, context) {
    if (rule.isDangerousPattern(node)) {
        // ...
    }
    return false;
};
```

### 7.7 DSL 中引用 extend-file 扩展点的语法

> [来源: src/dsl/RuleUtil.ts:L1641-L1687]

所有扩展点在 DSL 中通过统一的 `loadclass()` 语法引用：

```
# userDefineFunc
general.userDefinePatternClass = loadclass("XssTs_6991.rule.userDefineFunc")

# customSourceFunc
source.customSourceFunc = loadclass("XssTs_6991.rule.customSourceFunc")

# validateFunction
general.validateFunction = loadclass("XssTs_6991.rule.validateFunction")

# FSM entrance (entranceEvalFun)
entrance.entranceFunc = loadclass("csrfTs_7022.rule.entranceEvalFun")

# FSM condition (evalFun)
condition.conditionFunc = loadclass("csrfTs_7022.rule.evalFun_0")
```

**`loadclass` 解析规则**：`loadclass("fileName.property.path")` →
1. `fileName` + `.js` → 在 extend-file 目录下查找文件
2. `require()` 加载文件，获取 `module.exports`
3. 按 `property.path` 逐级访问属性
4. 将函数 `.toString()` 转为字符串嵌入生成的规则代码

---

## §8. 与 Java loadclass 的差异对比

| 维度 | Java loadclass | JS extend-file |
|------|----------------|----------------|
| **扩展文件格式** | `.java`（编译为 `.class`） | `.js`（CommonJS 模块） |
| **入口函数** | `public static Boolean evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)` | `rule.userDefineFunc = (rule, node, context) => { return false; }` |
| **导出方式** | Java class with static method | `module.exports.rule = { userDefineFunc: ... }` |
| **参数数量** | 2-3 个（视签名） | 3 个（`rule`, `node`, `context`） |
| **DSL 关联方式** | `loadclass("com.taobao.customrule.Xxx")` | `loadclass("fileName.rule.userDefineFunc")` [来源: RuleUtil.ts:L1641] |
| **运行时** | JVM 直接执行 | Node.js（引擎本身是 Node.js 应用）[来源: RuleUtil.ts:L1511] |
| **AST 类型** | PMD Java AST (`JavaNode`) | TypeScript 编译器 AST (`ts.Node`) [来源: TaintAnalysisVisitor.ts:L5437] |
| **污点操作** | `addTaintedVariable` 等 | `rule.analysisVisitor.getCurrentTaintVarSet().addMultiTaintVariable()` 等 [来源: prototypePollutionUtil.ts:L293] |
| **缺陷上报** | 通过 `evaluate` 返回值 | `rule.analysisVisitor.addBugReport(sinkName, vertex)` [来源: TaintAnalysisVisitor.ts:L5815] |
| **内置工具** | `InterDataCache`, `ASTUtil`, `CodeUtil` | `require("../logger")`, `require("../util")`, `require("../../visitor")` 等 [来源: csrfTs_7022.js:L1-L18] |
| **多种扩展点** | `userDefinePatternClass` + `userDefineEntranceClass` | `userDefineFunc` + `customSourceFunc` + `validateFunction` + `entranceEvalFun` + `evalFun` [来源: Rule.ts, interface.ts] |
| **返回值语义** | 视签名/扩展类型而异 | `true` = 跳过引擎默认分析；`false` = 继续默认分析 [来源: TaintAnalysisVisitor.ts:L5462] |
| **错误处理** | 视实现而异 | `userDefineFunc`: 无 try-catch；`evalFun`: 有 try-catch [来源: TaintAnalysisVisitor.ts:L5437, FsmAnalysisVisitor.ts:L279] |
| **多函数合并** | 不支持 | 支持数组形式，多个函数依次调用 [来源: RuleUtil.ts:L5778] |
