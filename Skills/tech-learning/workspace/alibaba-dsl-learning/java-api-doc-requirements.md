# Alibaba STC 引擎 Java loadclass 扩展 API 全面文档化

## 角色定义

你是一位源码分析专家。你的唯一任务是从 Alibaba STC 引擎源码中系统性提取 loadclass 扩展可用的 **全部 API**，生成精确、完整、可直接用于编写扩展类的参考文档。

**核心原则**：
- 只输出从源码中确认的信息，**不要猜测**。找不到的明确标注"未找到"+ 记录已搜索的关键词/路径
- 方法签名必须**完整**（返回类型 + 所有参数类型和参数名）
- 对于重载方法，列出**所有**重载版本
- 每个方法必须有一句话功能说明
- **每个结论必须附来源**：`[来源: path/to/File.java:L123]` 或 `[标准PMD]` / `[阿里定制]`

## 背景与动机

Alibaba STC DSL 的 `loadclass` 机制允许通过 Java 扩展类（`com.taobao.customrule.*`）在 evaluate() 方法中使用引擎 API 分析代码。STC 引擎基于 PMD 框架，但阿里做了大量定制扩展。我们已观察到部分 API 用法，但缺乏：
1. 完整的方法签名和参数语义
2. 阿里定制 API 与标准 PMD 的区分
3. 类/接口继承树
4. evaluate() 的生命周期和调用机制

### 已知的扩展类模板

```java
package com.taobao.customrule;

import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.lang.java.rule.AbstractTaintedDataRule;
import net.sourceforge.pmd.lang.java.rule.AbstractTaintedDataRuleData;

public class MyExtension {
    // 签名①: Source/Propagate/SafeFix/PkgHandler/EntryDetector (userDefinePatternClass)
    public static Boolean evaluate(JavaNode treenode,
                                    AbstractTaintedDataRule rule,
                                    AbstractTaintedDataRuleData data) {
        // ... 使用 rule / data / treenode 的 API
        return false;
    }
}
```

### 已知的三种 evaluate() 签名

```java
// ① Source/Propagate/SafeFix/PkgHandler/EntryDetector (userDefinePatternClass)
public static Boolean evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)

// ② Entrance 检测 (userDefineEntranceClass)
public static Boolean evaluate(JavaNode, Rule)

// ③ FSM 规则 (userDefinePatternClass + BaseFSMMachineRule)
public static Boolean evaluate(JavaNode, BaseFSMMachineRule)
```

---

## 🔍 搜索行动手册（按顺序执行）

> **这是整个任务的执行路线图。** 按以下步骤顺序搜索，每步的结果为后续步骤和章节提供基础。

### Step 1: 定位核心类的源码文件

**目标**：找到所有核心类的源码位置，建立文件索引。

**搜索关键词**（每个必须搜索）：
1. `class BaseTaintedDataRule` — 最重要的规则基类
2. `class AbstractTaintedDataRule` — 抽象基类
3. `class AbstractTaintedDataRuleData` — 数据类基类
4. `class BaseTaintedDataRuleData` — 数据类实现
5. `class BaseFSMMachineRule` — FSM 规则基类
6. `class InterDataCache` — 缓存工具
7. `class InterAppTypeInfor` — 类型信息工具
8. `class ASTUtil` — AST 工具
9. `class CodeUtil` — 代码工具
10. `class JavaRuleUtil` — 规则工具
11. `class MapOfVariable` — 变量映射
12. `class TaintedResult` — 污点结果
13. `class InterJavaTracerNode` — 追踪图节点
14. `class IncMethodSummary` — 方法摘要
15. `class PMDConstants` — 常量

**对每个找到的文件，记录**：`类名 → 文件路径 → 包名 → 继承/实现关系`

### Step 2: 定位 evaluate() 的调度入口

**搜索关键词**：
- `userDefinePatternClass` — 找 DSL 字段的解析和调度逻辑
- `userDefineEntranceClass` — 找 Entrance 场景的调度
- `"evaluate"` + `invoke` / `Method.invoke` / `reflection` — 找反射调用 evaluate 的代码
- `loadclass` — 找类加载逻辑

**找到后提取**：
- [ ] 哪个类/方法调用 evaluate()
- [ ] evaluate() 参数的构造方式（rule、treenode、data 从哪里来）
- [ ] treenode 的遍历顺序/触发时机
- [ ] 返回值 true/false 的处理逻辑（直接引用源码）
- [ ] 多个 userDefinePatternClass 的执行顺序
- [ ] 三种签名如何分派（引擎如何选择调用哪个签名）

### Step 3: 逐类提取完整 API

**对 Step 1 找到的每个核心类执行以下操作**：

1. **打开源码文件**，完整阅读
2. **列出所有 `public` 和 `protected` 方法**（含继承的）
3. **对每个方法**：
   - 记录完整签名：`public ReturnType methodName(ParamType1 param1, ParamType2 param2)`
   - 一句话功能说明（从方法体/注释推断）
   - 标注 `[阿里定制]` 或 `[标准PMD]`
4. **对阿里定制的 AST 方法**：
   - 在 `net.sourceforge.pmd.lang.java.ast` 包下搜索被修改/新增的方法
   - 搜索关键词：`getCallString`, `getClassName`, `getFullProfile`, `getFirstNextSibling`
   - 以及该包下所有不属于标准 PMD 的 public 方法

### Step 4: 补充常量和枚举

**搜索关键词**：
- `PMDConstants` — 找所有常量定义
- `TaintedType` — 找枚举/常量值
- `TracerNode.TYPE` / `BaseTracerNode.TYPE` — 找追踪节点类型
- `setFlag(` / `getFlag(` — 找所有已使用的 flag 值

### Step 5: 构建继承树

利用 Step 1 收集的继承关系，画出 Mermaid classDiagram。如果某个类的父类未在核心列表中，追踪到根。

### Step 6: 扩展发现（探索性搜索）

- `com.taobao.stc.pmd` 包下的其他工具类
- `com.taobao.customrule` 包下除 `evaluate()` 外的入口方法
- `net.sourceforge.pmd.trace` 包的结构
- `EncapsulationFeature` / `SinkEncapFeature` — 摘要模型

---

## 输出要求

### 输出文件

输出 **`java-loadclass-api.md`** — Java 规则 loadclass 扩展 API 文档。

> 此文档仅覆盖 Java 规则的 loadclass 扩展 API。JavaScript 规则的 extend-file API 由单独的 prompt 负责。

### 每个 API 条目的标准格式

对于签名已确认的方法：
```markdown
#### `public ReturnType methodName(ParamType1 param1, ParamType2 param2)` `[阿里定制]`

> [来源: com/taobao/stc/pmd/rule/BaseTaintedDataRule.java:L234]

一句话功能说明。

- **param1** (`ParamType1`): 参数说明
- **param2** (`ParamType2`): 参数说明
- **返回值** (`ReturnType`): 说明
- **注意事项**: (如有)
```

对于签名不完整的方法：
```markdown
#### `public ? methodName(?)` `[阿里定制]`

> [推断来源: 调用处 SomeClass.java:L56]

从调用处推断：... 。签名不完整，原因：找不到声明文件 / 方法体不可见 / ...
```

对于重载方法，每个重载单独一个条目，标注 `重载 1/N`。

### 文档结构

```
§0. 类/接口继承树 (Mermaid classDiagram)
§1. evaluate() 生命周期与调用机制
§2. 阿里定制 AST 节点方法 (非标准 PMD)
§3. 规则基类完整 API
§4. 核心工具类完整 API
§5. 数据模型类完整 API
§6. 扩展发现
§A. 自检报告
```

---

## §0. 类/接口继承树

> **本章对应搜索手册 Step 5 的结果。**

用 Mermaid classDiagram 画出以下所有类/接口的**完整继承与实现关系**：

```
规则基类:
  Rule (接口?) → AbstractJavaRule → AbstractTaintedDataRule → BaseTaintedDataRule
  BaseFSMMachineRule 在继承树中的位置？

数据类:
  AbstractTaintedDataRuleData → BaseTaintedDataRuleData 的关系？
  TaintedResult 的继承关系？

AST 节点:
  JavaNode → AbstractJavaNode → 各节点类型的继承关系
  特别是: ASTPrimaryExpression, ASTAllocationExpression, ASTMethodDeclaration 等

工具类:
  InterDataCache, InterAppTypeInfor, ASTUtil, CodeUtil, JavaRuleUtil
  MapOfVariable, InterJavaTracerNode, MethodArgs

摘要模型:
  IncMethodSummary, EncapsulationFeature → SinkEncapFeature
```

**要求**：
- classDiagram 中每个类标注 `<<interface>>` 或 `<<abstract>>` (如适用)
- 标注包名
- 如果某个类的父类不在上述列表中，继续追踪直到一个众所周知的类（如 `Object`）或标准 PMD 基类

---

## §1. evaluate() 生命周期与调用机制

> **本章对应搜索手册 Step 2 的结果。所有结论必须直接引用源码。**

### 必须从源码中回答的问题（每个答案附 `[来源: file:line]`）

1. **调度入口**：evaluate() 是被谁调用的？
   - 找到调用 `evaluate(JavaNode, AbstractTaintedDataRule, ...)` 的源码位置
   - 引用调用代码（前后各 15 行）
   - 是通过反射 `Method.invoke` 还是直接调用？

2. **遍历顺序**：treenode 参数怎么来的？
   - 在什么样的循环/遍历中？DFS？BFS？按语句顺序？
   - **直接引用遍历代码**

3. **调用频率**：一个扩展类的 evaluate() 在一次扫描中被调用多少次？
   - 每个 AST 节点一次？仅特定节点？仅一次？

4. **多扩展类执行顺序**：多个 `userDefinePatternClass` 的执行顺序是什么？
   - 串行？并行？按声明顺序？

5. **返回值语义**：evaluate() 返回 true/false 的精确影响
   - 在 `userDefinePatternClass` 场景下
   - 在 `userDefineEntranceClass` 场景下
   - **直接引用处理返回值的代码**

6. **签名分派**：引擎如何决定调用三种签名中的哪一种？
   - 是反射检查参数类型？还是根据 DSL 字段决定？
   - 是否还有其他签名？

7. **AbstractTaintedDataRuleData 内容**：除了 `result` 字段，还有哪些字段？完整列出。

---

## §2. 阿里定制 AST 节点方法（非标准 PMD）

> **本章对应搜索手册 Step 3 中对 `net.sourceforge.pmd.lang.java.ast` 包的扫描结果。**

以下方法在标准 PMD 中不存在，请从源码中找到实现并文档化。

### 探索步骤

1. 搜索以下已知的阿里定制方法，找到实现文件，提取完整签名和实现逻辑：
   - `getCallString` — 在 ASTPrimaryExpression 中
   - `getClassName` — 在 ASTPrimaryExpression / ASTExpression / ASTClassOrInterfaceDeclaration 中
   - `getFullProfile` — 在 ASTMethodDeclaration 中
   - `getFirstNextSibling` — 在 Node 接口中
   - `getMethodName` — 在 ASTMethodDeclaration 中
2. 在 `net.sourceforge.pmd.lang.java.ast` 包下全局搜索 `@since` / `taobao` / `alibaba` / `stc` 注释，发现更多定制方法
3. 对比标准 PMD 的 AST 节点类，找出所有被修改/新增的方法

### 每个定制方法的必须输出

使用标准 API 条目格式，并额外提供：

- **返回值示例**（至少 3 个不同场景的输入→输出）：
  ```
  输入: `factory.setTrustedPackages(list)` → 返回: ?
  输入: `new ActiveMQConnectionFactory()` → 返回: ?
  输入: `a.b().c()` 链式调用 → 返回: ?
  输入: `Collections.singletonList(x)` 静态调用 → 返回: ?
  输入: `this.field.method()` → 返回: ?
  ```
  （以上为 `getCallString()` 的示例要求，其他方法类似给出场景化示例）

### 全面扫描要求

**搜索 `net.sourceforge.pmd.lang.java.ast` 包下**所有被阿里修改/新增的方法，不限于以上列表。搜索策略：
- 搜索非标准 PMD 的 `public` 方法声明
- 搜索包含 `taobao` / `alibaba` / `stc` 的注释或 import
- 与标准 PMD 7.x 的 AST API 对比（标准 PMD 没有的就是定制的）

---

## §3. 规则基类完整 API

> **本章对应搜索手册 Step 3 中对规则基类的扫描结果。**

### BaseTaintedDataRule（最重要 — 逐方法文档化）

**探索步骤**：
1. 打开 `BaseTaintedDataRule.java` 源码
2. 列出所有 `public` 和 `protected` 方法
3. 对每个方法使用标准 API 条目格式输出
4. 对继承的方法，追踪到声明处确认签名

**已知方法列表（需补全签名、语义、返回值说明）**：

| 方法名 | 待确认内容 |
|--------|-----------|
| `addTaintedVariable(MapOfVariable, boolean, Node)` | 第二个 boolean 参数含义？ |
| `addEdgeToGraph(InterJavaTracerNode, InterJavaTracerNode)` | 返回值？ |
| `addNodeToGraph(InterJavaTracerNode)` | 返回的节点与传入的是同一个吗？ |
| `handleUserDefineInvoke(...)` | 完整参数列表和每个参数语义 |
| `handleUserDefineTaintFlow(TaintedResult, MapOfVariable, Node)` | 精确行为 |
| `handleSingleVar(MapOfVariable, Node)` | 返回 null 的条件？ |
| `visitTreeNode(Node, data)` | 与普通遍历的区别 |
| `isVariableMayTainted(MapOfVariable)` | 是否考虑子路径？ |
| `getMethodArgsForInvoke(ASTPrimaryExpression, int)` | 第二个 int 参数含义？ |
| `setFlag(String)` / `getFlag()` | flag 对引擎行为的影响？ |
| `getCurrentEntrance()` | 返回类型？ |
| `getVisitedMethodContext()` | 返回类型的完整 API？ |
| `getVisitedMethodShortName()` / `getVisitedMethodProfile()` | 格式？ |
| `getExternTaintSummarys()` | Map 结构：外层 key? 内层 key? |
| `getSafeTypesSet()` / `getSafeTypes()` | 区别？ |
| `isArgTypeSafe(ASTType)` | 判断逻辑？ |
| `isEnumType(String)` / `isMatched(String, Set, Node)` | 详细语义 |

**⚠️ 以上仅为已知方法，请从源码中找出所有遗漏的 public/protected 方法。目标：≥ 20 个方法。**

### AbstractTaintedDataRule

- 与 `BaseTaintedDataRule` 的关系？（继承方向、抽象方法列表）
- 完整 API（使用标准条目格式）

### BaseFSMMachineRule

- 完整 API，与 `BaseTaintedDataRule` 的区别
- 为什么某些扩展类同时支持签名①和③？调度逻辑在哪里分叉？
- FSM 相关特有方法（状态机操作）

### Rule 接口（Entrance 场景）

- Entrance 的 `evaluate(JavaNode, Rule)` 中，第二个 `Rule` 实参的实际类型是什么？
- 该类型有哪些可用方法？

---

## §4. 核心工具类完整 API

> **本章对应搜索手册 Step 3 中对工具类的扫描结果。**
>
> **对每个工具类：打开源码 → 列出所有 public 方法 → 使用标准 API 条目格式输出。**

### InterDataCache.getInstance()

**已知方法（需补全签名和语义）**：

| 方法名 | 待确认 |
|--------|--------|
| `findDefinedClassNodeByRootNode(ASTCompilationUnit)` | 返回类型？多个类时？ |
| `findInterfaceByClassName(String)` | 返回 `List<String>`? FQN? |
| `findClassNode(String)` | 参数是 FQN 还是简单名？返回类型？ |
| `findSuperClassesByClassName(String)` | 含自身吗？含 Object 吗？ |
| `findMethodNodes(String)` | 参数格式？`pkg.Class.method` 还是含签名？返回多个的条件？ |
| `getClassToFilter()` | 返回值类型和语义？ |

**⚠️ 以上仅为已知方法，请从源码中找出所有遗漏的 public 方法。**

### InterAppTypeInfor.getInterAppTypeInfor()

- 已知: `isAbstract`, `isInterface`, `isSuperClass`, `isInterface(className, interfaceName)`
- **完整列出所有方法**

### ASTUtil（重点：XPath 能力）

- `findNodes(Node, String xpath)` — xpath 语法是标准 XPath 还是子集？
  - 支持哪些轴？(`self::`, `parent::`, `child::`, `following-sibling::`, `ancestor::` ?)
  - 支持谓词吗？(`[@Image='xxx']`)
  - 支持 `|` 联合吗？
  - **请找到 XPath 引擎的实现代码确认**
- `findFirstNode(Node, String xpath)` — 与 `findNodes` 取第一个的区别？性能差异？
- **完整方法列表**

### CodeUtil

- `getEnclosingClassName(Node)` — 返回 FQN 还是简单名？
- `getClassName(ASTType)` — 返回 FQN？
- `isMatched(Pattern, String)` — 是 `find()` 还是 `matches()`？
- **完整方法列表**

### JavaRuleUtil

- `getMethodName(ASTMethodDeclaration)` — 与 `ASTMethodDeclaration.getMethodName()` 区别？
- **完整方法列表**

---

## §5. 数据模型类完整 API

> **本章对应搜索手册 Step 3 中对数据模型类的扫描结果。**
>
> **对每个数据类：打开源码 → 列出所有 public 字段和方法 → 使用标准 API 条目格式输出。**

### MapOfVariable（核心数据结构）

**重点问题**：
- `getMapOfVariableFromNode(JavaNode)` — 对 ASTName vs ASTPrimaryExpression 的处理差异？
- `getTempMapOfVariable(String)` — 与 `getMapOfVariableFromNode` 的区别？
- `getDecl()` — 返回类型层次？`VariableNameDeclaration` 有哪些有用方法？
- `copy()` + `normalize(Node)` — normalize 做了什么？
- `getSubPath()` 的 `.add()` 对原对象的影响？（是否 mutable？）
- **完整方法列表**

### TaintedResult

- 完整字段和方法列表
- `isPrecise()` / `getTaintSubPathes()` 的语义
- `PMDConstants.TaintedType`: `INPUT` vs `NONE` vs `OUTPUT` 的精确区别

### InterJavaTracerNode

- 构造器完整参数语义
- `setFlag(String)` — flag 值有约定吗？（搜索所有 `setFlag("` 字符串字面量）
- **完整方法列表**

### IncMethodSummary / EncapsulationFeature / SinkEncapFeature

- 完整 API（使用标准条目格式）

### MethodArgs

- 完整 API，重点 `getArgResult()` 返回什么

### VariableNameDeclaration

- `getDeclaratorId()` 返回什么？还有哪些有用方法？

### PMDConstants

- **完整常量列表**（`TaintedType` 之外还有什么？）
- 每个常量的值和使用场景

---

## §6. 扩展发现

> **本章对应搜索手册 Step 6 的结果。**

### 探索步骤

1. **`com.taobao.stc.pmd` 包扫描**：搜索该包下所有 `public class`，排除已在 §3-§5 文档化的类，列出遗漏的工具类
2. **`com.taobao.customrule` 包扫描**：搜索引擎对该包下类的使用方式，确认除 `evaluate()` 外是否支持其他入口方法名
3. **`net.sourceforge.pmd.trace` 包**：`TracerNode.TYPE` vs `BaseTracerNode.TYPE` 的关系，类型值列表

---

## §A. 自检报告（每轮迭代后必须输出）

```markdown
## 自检报告

### 搜索执行记录
| 搜索手册步骤 | 状态 | 搜索关键词 | 找到的关键文件 |
|-------------|------|-----------|---------------|
| Step 1: 定位核心类 | ✅/❌ | ... | ... |
| Step 2: evaluate 调度入口 | ✅/❌ | ... | ... |
| Step 3: 逐类 API 提取 | ✅/❌ | ... | ... |
| Step 4: 常量和枚举 | ✅/❌ | ... | ... |
| Step 5: 继承树 | ✅/❌ | ... | ... |
| Step 6: 扩展发现 | ✅/❌ | ... | ... |

### 覆盖率统计
| 指标 | 数值 |
|------|------|
| 已文档化的类/接口总数 | ? |
| 已文档化的方法总数 | ? |
| 其中：完整签名 + 功能说明 | ? |
| 其中：仅签名无说明 | ? |
| 其中：签名不完整 | ? |
| 标注为 [阿里定制] 的方法数 | ? |
| 标注为 [标准PMD] 的方法数 | ? |
| 标注为"未找到"的项数 | ? |
| 附有 [来源: file:line] 的结论占比 | ?% |
| 文档总字数 | ? |

### §0-§6 各章完成度
| 章节 | 状态 | 方法数 | 未回答的关键问题 |
|------|------|-------|-----------------|
| §0 继承树 | ✅/⚠️/❌ | N/A | ... |
| §1 evaluate 生命周期 | ✅/⚠️/❌ | N/A | .../?个问题 |
| §2 定制 AST 方法 | ✅/⚠️/❌ | ? | ... |
| §3 规则基类 API | ✅/⚠️/❌ | ? | ... |
| §4 工具类 API | ✅/⚠️/❌ | ? | ... |
| §5 数据模型类 API | ✅/⚠️/❌ | ? | ... |
| §6 扩展发现 | ✅/⚠️/❌ | ? | ... |

### 遗留问题清单
1. ...
2. ...
```

### 自检标准

**硬性指标**：
- [ ] 已文档化方法总数 ≥ 80
- [ ] 其中完整签名 + 功能说明占比 ≥ 90%
- [ ] 签名不完整数 = 0（找不到的标注"未找到"不算不完整）
- [ ] §0 继承树覆盖所有出现的类/接口
- [ ] §1 的 7 个问题全部有明确回答（或标注"源码中未找到"+ 搜索记录）
- [ ] §2 的每个定制方法至少给出 3 个返回值示例
- [ ] §3 BaseTaintedDataRule 列出 ≥ 20 个方法
- [ ] §4 每个工具类列出了"完整方法列表"（而非仅已知方法）
- [ ] 每个结论附 `[来源: file:line]`
- [ ] 每个"未找到"附搜索记录（搜过的关键词 + 搜索范围）
- [ ] 文档总字数 ≥ 5000 字

**迭代要求**：
1. 第一轮：执行搜索手册 Step 1-6，产出所有章节初稿 + 自检报告
2. 第二轮：根据自检报告中的 ❌ 和 ⚠️ 项，补全未达标章节
3. 重复直到所有硬性指标达标或确认无法从源码中获取更多信息
4. 最终轮：文档开头插入"文档状态: ✅ 已完成 / ⚠️ 部分完成"标记

---

## ⛔ 重要约束（违反任一项即为不合格）

1. **不要猜测** — 只输出源码中确认的信息。找不到的写"未找到实现，仅从调用处推断签名为 ..."，每个结论附 `[来源: file:line]`
2. **区分阿里定制与标准 PMD** — 每个方法明确标注 `[阿里定制]` 或 `[标准PMD]`
3. **完整签名** — `public List<String> findInterfaceByClassName(String className)` 而非 `findInterfaceByClassName(String)`
4. **仅 Java** — 本文档仅关注 Java loadclass 扩展 API，不涉及 JavaScript extend-file
5. **继承树必须是 Mermaid classDiagram** — 不是文字描述
6. **自检报告每轮必须更新** — 这是迭代的唯一驱动力
7. **记录搜索路径** — 对于每个"未找到"，记录搜索关键词 + 搜索文件范围
