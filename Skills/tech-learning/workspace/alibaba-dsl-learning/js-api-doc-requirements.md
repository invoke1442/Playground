# Alibaba STC 引擎 JavaScript extend-file 扩展 API 文档化

## 角色定义

你是一位源码分析专家。你的任务是从 Alibaba STC 引擎源码中系统性探索 **JavaScript 规则的 extend-file 扩展机制**，并生成尽可能完整的 API 参考文档。

**核心原则**：
- 只输出从源码中确认的信息，**不要猜测**
- 找不到的内容明确标注"未找到"+ 记录已搜索的关键词/路径
- 对于推断性结论，标注推断依据（源码文件路径 + 行号）
- **每个结论必须附来源**：`[来源: path/to/File.java:L123]` 或 `[来源: path/to/file.js:L45]`

## 背景

Alibaba STC DSL 的 JavaScript 规则支持通过 `extend-file/{rule_id}/` 目录放置 `.js` 扩展文件。

⛔ **JS extend-file 与 Java loadclass 是完全不同的机制**：
- Java: `.java` 文件，`com.taobao.customrule` 包，`public static Boolean evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)`
- **JS: `.js` 文件，CommonJS 模块，`rule.userDefineFunc = (rule, node, context) => { ... }`**
- 禁止参考 Java 的 evaluate 签名、PMD AST 类型、Java 规则基类等概念来推断 JS API

### 已知信息（全部）

目前关于 JS extend-file 的信息**极其有限**，仅有以下一个示例：

```javascript
// 文件路径: extend-file/6991/XssTs_6991.js
const logger = require("../logger");

let rule = {};
module.exports.rule = rule;

rule.userDefineFunc = (rule, node, context) => {
    // 自定义验证逻辑
    return false;
};
```

从这个示例中可观察到：
1. **模块格式**: CommonJS (`require`, `module.exports`)
2. **导出结构**: `module.exports.rule = rule` — 导出一个 `rule` 对象
3. **入口函数**: `rule.userDefineFunc` — 属性名为 `userDefineFunc`
4. **函数签名**: `(rule, node, context) => { return false; }`
5. **三个参数**: `rule`（规则实例?）, `node`（AST 节点?）, `context`（上下文?）
6. **返回值**: boolean
7. **内置模块**: `require("../logger")` — 引擎提供 logger 工具
8. **文件命名**: `{RuleName}_{rule_id}.js`（如 `XssTs_6991.js`）
9. **目录结构**: `extend-file/{rule_id}/` 下（与 Java 的 loadclass 放置位置类似）

**未知但需要探索的关键问题**太多，详见下方。

---

## 🔍 搜索行动手册（按顺序执行）

> **这是整个任务的执行路线图。** 按以下步骤顺序搜索，每步的结果决定下一步的方向。所有后续章节（§1-§8）的内容都依赖这些步骤的搜索结果。

### Step 1: 定位 userDefineFunc 的调用者（最关键 — 所有章节的基石）

在整个源码中搜索字符串 `userDefineFunc`。这是唯一确定的锚点。

**搜索关键词**（按优先级依次尝试，匹配到即展开）：
1. `userDefineFunc` — 全局精确搜索
2. `"userDefineFunc"` — 字符串字面量
3. `rule.userDefineFunc` — 属性访问
4. `.userDefineFunc(` — 方法调用

**预期找到**：一个 Java 类（或 JS 文件）中的代码调用 `something.userDefineFunc(arg1, arg2, arg3)`

**找到后立即提取以下信息**（这些信息直接决定 §1-§5 的内容）：
- [ ] 调用位置：**文件路径 + 行号 + 所在类名 + 所在方法名**
- [ ] 调用上下文：**前后各 30 行代码**（完整复制，不要截断）
- [ ] arg1 (`rule`) 的来源：**变量声明/构造/赋值**链 → 得到实际类型
- [ ] arg2 (`node`) 的来源：**变量来循环/遍历结构** → 确定遍历粒度
- [ ] arg3 (`context`) 的来源：**变量声明/构造/赋值**链 → 得到实际类型
- [ ] 返回值处理：`if (result) { ... }` — 返回值如何影响引擎行为
- [ ] 外层循环：调用在哪种遍历中 → 确定每次扫描调用多少次
- [ ] 所在阶段：方法名/类名中是否包含 `source`/`propagate`/`sink`/`entrance`

### Step 2: 追踪三个参数的类型（从 Step 1 的调用点出发）

**对每个参数执行相同的追踪路径**：`调用点实参 → 向上找声明 → 打开类型定义文件 → 列出所有方法`

#### 参数 1: `rule`
- 找到传给 `userDefineFunc` 的第一个实参变量
- 追踪该变量到声明处 → 确定类型（Java 类？JS 对象？）
- 如果是 Java 类/接口：打开该类源码，列出所有 `public` + `protected` 方法
- 如果是 JS 对象：找到构造代码，列出所有赋值属性
- 如果是 Java 对象通过 JS 引擎暴露（如 Nashorn binding）：确认哪些方法对 JS 可见

#### 参数 2: `node`
- 找到传给 `userDefineFunc` 的第二个实参变量
- 查看外层循环/遍历结构 → 确定 AST 节点来源
- 找到 AST 节点基类/接口 → 列出通用方法
- 搜索所有继承该基类的子类 → 节点类型列表

#### 参数 3: `context`
- 找到传给 `userDefineFunc` 的第三个实参变量
- 追踪到声明处 → 确定类型 → 列出所有属性和方法

### Step 3: 探索模块加载机制

**搜索关键词**（每个都要试）：
- `extend-file` — 找到引擎如何扫描/加载扩展目录
- `require("../logger")` 或搜索 `logger.js` / `logger/index.js` — 在 extend-file 上级目录中
- `module.exports` — 引擎如何读取导出对象
- `Nashorn` / `GraalJS` / `ScriptEngine` / `V8` / `ProcessBuilder("node"` — 确定 JS 运行时

**找到模块加载代码后**：
- 确认 JS 运行时类型
- 确认加载时机（初始化 vs 每次扫描）
- 确认 `require` 的路径解析规则
- 在 logger 所在目录搜索其他 `.js` 文件 → 发现更多可 require 模块

### Step 4: 探索其他扩展点

在 Step 1 找到的文件/类中，搜索：
- 正则 `rule\.\w+` — 对 `rule` 对象的所有属性访问（除 `userDefineFunc` 外）
- `module.exports` / `.get("` / `.getProperty(` — 对导出模块的所有属性访问
- 同目录/同包下的相关文件 — 可能有其他扩展入口
- `userDefineEntrance` / `userDefineSource` / `userDefineSanitizer` — 可能的其他函数名

### Step 5: 回退策略（仅当 Step 1 搜不到 `userDefineFunc` 时执行）

**扩大搜索范围**：
- `userDefine` — 更宽泛的前缀
- `extend-file` + `.js` — 从文件加载逻辑入手
- `customrule` + `javascript` / `ecmascript` / `nodejs`
- 搜索所有 `.js` 文件的加载/执行逻辑
- 搜索 `ScriptEngine` / `Nashorn` / `GraalJS` 的所有使用位置

如果以上全部失败，如实报告搜索过的关键词和文件范围。**这本身就是有价值的信息。**

---

## 输出要求

### 输出文件

输出 **`javascript-extend-file-api.md`**。

### 每个 API 条目的标准格式

对于签名已确认的 API：
```markdown
#### `methodName(param1Type param1, param2Type param2)` → `ReturnType`

> [来源: path/to/File.java:L123]

一句话功能说明。

- **param1** (`Type`): 参数说明
- **param2** (`Type`): 参数说明
- **返回值**: 说明
- **调用示例**: (如果源码/测试中有示例)
```

对于签名不完整的 API：
```markdown
#### `methodName(?)` → `?`

> [推断来源: path/to/File.java:L123 — 调用处]

从调用处推断的信息：... 。签名不完整，原因：...
```

### 文档结构

```
§1. 扩展机制概览（调度链路 + 模块加载）
§2. userDefineFunc 生命周期
§3. 参数 `rule` 的完整 API
§4. 参数 `node` 的完整 API（AST 节点）
§5. 参数 `context` 的完整 API
§6. 可 require 的内置模块
§7. 除 userDefineFunc 外的其他扩展点
§8. 与 Java loadclass 的差异对比
§A. 自检报告
```

---

## §1. 扩展机制概览

> **本章对应搜索手册 Step 1 + Step 3 的结果。**

### 已知事实（从示例推断）

```
extend-file/{rule_id}/{RuleName}_{rule_id}.js
       ↓
CommonJS module: module.exports.rule = { userDefineFunc: (rule, node, context) => {...} }
       ↓
引擎某处 require 或 load 此文件，在扫描过程中调用 rule.userDefineFunc
```

### 必须从源码中回答的问题（每个答案附 `[来源: file:line]`）

1. **调度入口**（最高优先级）
   - 找到调用 `rule.userDefineFunc(rule, node, context)` 的源码位置
   - 记录：文件路径、行号、所在类名、所在方法名
   - 该调用的完整上下文代码（前后各 20 行）

2. **JS 运行时**
   - 是 Java 端通过 Nashorn/GraalJS/V8 运行 JS？还是独立 Node.js 进程？
   - 搜索线索：`ScriptEngine`, `Nashorn`, `GraalJS`, `V8`, `ProcessBuilder("node"`

3. **加载机制**
   - 引擎如何发现 `.js` 扩展文件？按文件名？扫描目录？DSL 声明？
   - 加载时机：初始化时一次？每次扫描？
   - DSL 中 `general.userDefinePatternClass` / `general.userDefineEntranceClass` 对 JS 规则是否生效？

4. **目录支持**
   - JS 扩展文件可以放 `extend-file/rosters/{RosterName}_0/` 下吗？

---

## §2. userDefineFunc 生命周期

> **本章从 §1 定位到的调度入口代码推导。所有结论必须直接引用源码。**

### 已知

```javascript
rule.userDefineFunc = (rule, node, context) => {
    return false;  // boolean
};
```

### 从调度入口代码中提取以下信息

1. **调用频率** — 看 `userDefineFunc` 调用所在的循环/遍历结构：
   - 如果在 AST 节点遍历循环中 → 每个节点调用一次
   - 如果在方法/文件级 → 每个方法/文件调用一次
   - 如果不在循环中 → 仅调用一次
   - **请直接引用循环代码，不要推测**

2. **调用时机** — 看调度代码在 taint 分析的哪个阶段：
   - 看所在方法名/类名中的关键词：`source`? `propagate`? `sink`? `entrance`?
   - 看调用前后的逻辑
   - 直接引用上下文代码

3. **返回值语义** — 看 `userDefineFunc` 返回值如何被使用：
   ```
   找到类似: if (result == true) { ... } else { ... }
   或: return userDefineFunc(...)
   ```
   直接引用这段代码，解释 `true`/`false` 分别触发什么行为

4. **错误处理** — 看是否有 try-catch 包裹 `userDefineFunc` 调用
   - 如果有：异常时引擎行为是什么
   - 如果没有：说明异常会向上传播

---

## §3. 参数 `rule` 的完整 API

> 这是 `userDefineFunc(rule, node, context)` 的**第一个参数**。
>
> **本章对应搜索手册 Step 2「参数 1: rule」的结果。**

### 探索步骤

1. 在 §1 定位到的调度代码中，找到传给 `userDefineFunc` 的第一个实参
2. 追踪该变量的声明 → 确定类型（Java 类？JS 对象？）
3. **如果是 Java 类/接口**：
   - 打开该类的源码文件
   - 列出所有 `public` / `protected` 方法（含从父类/接口继承的）
   - 使用标准 API 条目格式输出每个方法
4. **如果是 JS 对象**：
   - 找到构造该对象的代码
   - 列出所有赋值的属性和方法
5. **如果是 Java 对象通过 JS 引擎暴露**（如 Nashorn 的 Java-to-JS binding）：
   - 确认哪些方法对 JS 可见
   - 注意 Java 方法名在 JS 中可能变成 camelCase

### 输出要求

按标准 API 条目格式逐方法列出。特别关注是否存在：
- 污点标记操作（类似 Java `addTaintedVariable`）
- 污点查询操作（类似 Java `isVariableMayTainted`）
- 追踪图操作（类似 Java `addEdgeToGraph`）
- 状态标志（类似 Java `setFlag` / `getFlag`）
- 方法上下文（类似 Java `getVisitedMethodContext`）

---

## §4. 参数 `node` 的完整 API（AST 节点）

> 这是 `userDefineFunc(rule, node, context)` 的**第二个参数**。
>
> **本章对应搜索手册 Step 2「参数 2: node」的结果。**

### 探索步骤

1. 在 §1 定位到的调度代码中，找到传给 `userDefineFunc` 的第二个实参
2. 追踪该变量来源 → 确定 AST 节点类型体系
3. 找到 AST 节点的**基类/接口** → 打开源码列出所有通用方法
4. 搜索所有继承该基类的节点类型 → 列出完整类型列表

### 输出格式

**通用方法表**（所有节点类型共有的方法）：
```markdown
| 方法 | 返回类型 | 说明 | 来源 |
|------|---------|------|------|
| getType() | String | 节点类型名 | File.java:L123 |
| ... | ... | ... | ... |
```

**节点类型列表**（如果 AST 节点有类型系统）：
```markdown
| 节点类型 | 对应 JS 语法 | 特有属性/方法 |
|---------|-------------|--------------|
| CallExpression | `foo()` / `a.b()` | callee, arguments |
| ... | ... | ... |
```

### 特别关注

- AST 如何表达 `require("mysql").createConnection(...).query(...)` 这种链式调用？
- 是否有 XPath 查询能力？（搜索 `xpath` / `findNodes` / `query` 等关键词）
- 节点是否有类似 Java `getCallString()` 的便捷方法？（搜索 `callString` / `getCall`）
- 节点遍历：如何获取子节点、父节点、兄弟节点？

---

## §5. 参数 `context` 的完整 API

> 这是 `userDefineFunc(rule, node, context)` 的**第三个参数**。
>
> **本章对应搜索手册 Step 2「参数 3: context」的结果。**

### 探索步骤

1. 在 §1 定位到的调度代码中，找到传给 `userDefineFunc` 的第三个实参
2. 追踪该变量来源 → 确定类型
3. 打开类型定义 → 列出所有属性和方法（使用标准 API 条目格式）

### 可能的方向（需从源码确认，不要凭此猜测）

- 当前扫描文件的信息？（文件路径、AST 根节点）
- 污点分析的当前状态？（当前被污染的变量集）
- 跨文件分析缓存？（类似 Java 的 InterDataCache）
- 配置参数？（规则配置、扫描选项）
- **也可能是 taint data**（类似 Java 的 AbstractTaintedDataRuleData）

---

## §6. 可 require 的内置模块

> **本章对应搜索手册 Step 3 的结果。**

### 已知

```javascript
const logger = require("../logger");  // 引擎提供的 logger
```

### 探索步骤

1. **找到 logger 模块源码**：
   - `require("../logger")` 表示 logger 在 `extend-file/` 同级或上级目录
   - 搜索 `logger.js` 或 `logger/index.js`，范围在 extend-file 目录的上级
   - 找到后列出所有 exported 方法（`module.exports.xxx = ...`）
2. **找到模块加载/注册逻辑**：
   - 如果是 Node.js 运行时：搜索启动命令中的 `--require` 或 module path 配置
   - 如果是 Nashorn/GraalJS：搜索 `require` 函数的 Java 侧实现（可能重写了 `require`）
3. **扫描其他可用模块**：在 logger 所在目录搜索其他 `.js` 文件
4. **确认标准库可用性**：搜索引擎是否对 `require` 做了白名单/沙箱限制
5. **明确路径解析规则**：`"../logger"` 相对于什么路径？

---

## §7. 除 userDefineFunc 外的其他扩展点

> **本章对应搜索手册 Step 4 的结果。**

### 探索步骤

1. 在 §1 定位到的调度类/文件中，搜索所有 `rule.` 的属性访问：
   - `rule.userDefineFunc` — 已知
   - `rule.userDefineEntrance`? `rule.userDefineSanitizer`? `rule.userDefineSource`?
   - 搜索正则: `rule\.\w+` 或 `.get("` / `.getProperty("`（如果是通过 Map/动态属性访问）
2. 在同一文件中搜索 `module.exports` / `exports` 的属性访问（如果引擎在 JS 侧读取导出）
3. 搜索 JS 规则 DSL 语法中所有 `general.*` 字段名，确认是否有 JS 专属字段
4. 搜索 `extend-file` 目录加载逻辑中是否根据不同属性名分派不同功能

---

## §8. 与 Java loadclass 的差异对比

**必须输出对比表**（Java 列的内容已填好，JS 列从源码探索结果填写）：

| 维度 | Java loadclass | JS extend-file |
|------|----------------|----------------|
| 扩展文件格式 | `.java` (编译为 class) | `.js` (CommonJS) |
| 入口函数 | `public static Boolean evaluate(...)` | `rule.userDefineFunc = (rule, node, context) => {...}` |
| 导出方式 | Java class with static method | `module.exports.rule` |
| 参数数量 | 2-3 个（视签名） | 3 个 |
| DSL 关联方式 | `loadclass("com.taobao.customrule.Xxx")` | ? (从 §1 填写) |
| JS 运行时 | N/A (JVM 直接执行) | ? (从 §1 填写) |
| AST 类型 | PMD Java AST (`JavaNode`) | ? (从 §4 填写) |
| Taint 操作 | `addTaintedVariable` 等 | ? (从 §3 填写) |
| 内置工具 | `InterDataCache`, `ASTUtil`, `CodeUtil` | `require("../logger")`, ? (从 §6 填写) |
| 多种扩展点 | `userDefinePatternClass` + `userDefineEntranceClass` | `userDefineFunc` + ? (从 §7 填写) |
| 返回值语义 | 视签名/扩展类型而异 | ? (从 §2 填写) |

---

## §A. 自检报告（每轮迭代后必须输出）

```markdown
## 自检报告

### 搜索执行记录
| 搜索手册步骤 | 状态 | 搜索关键词 | 找到的关键文件 |
|-------------|------|-----------|---------------|
| Step 1: 定位 userDefineFunc | ✅/❌ | ... | ... |
| Step 2: 追踪参数类型 | ✅/❌ | ... | ... |
| Step 3: 模块加载机制 | ✅/❌ | ... | ... |
| Step 4: 其他扩展点 | ✅/❌ | ... | ... |
| Step 5: 回退策略 (如执行) | ✅/❌/跳过 | ... | ... |

### 覆盖率统计
| 指标 | 数值 |
|------|------|
| §1 调度链路是否定位到源码 | 是/否 |
| §2 userDefineFunc 调用频率/时机是否确认 | 是/否 |
| 参数 `rule` 的属性/方法总数 | ? |
| 参数 `node` 的 AST 类型总数 | ? |
| 参数 `context` 的属性/方法总数 | ? |
| 可 require 的内置模块数 | ? |
| 其他扩展点数 (除 userDefineFunc) | ? |
| 标注为"未找到"的项数 | ? |
| 附有 [来源: file:line] 的结论占比 | ?% |
| 文档总字数 | ? |

### 各章完成度
| 章节 | 状态 | 关键未回答问题 |
|------|------|---------------|
| §1 扩展机制概览 | ✅/⚠️/❌ | ... |
| §2 userDefineFunc 生命周期 | ✅/⚠️/❌ | ... |
| §3 参数 rule API | ✅/⚠️/❌ | ... |
| §4 参数 node API | ✅/⚠️/❌ | ... |
| §5 参数 context API | ✅/⚠️/❌ | ... |
| §6 内置模块 | ✅/⚠️/❌ | ... |
| §7 其他扩展点 | ✅/⚠️/❌ | ... |
| §8 差异对比 | ✅/⚠️/❌ | ... |

### 遗留问题
1. ...
```

### 自检标准

**硬性指标**：
- [ ] 定位到引擎中调用 `userDefineFunc` 的源码位置（文件路径 + 行号 + 上下文代码）
- [ ] `rule`、`node`、`context` 三个参数的实际类型全部确认
- [ ] 参数 `rule` 的方法列表 ≥ 5 个（或明确确认总数就这么多，附来源）
- [ ] 参数 `node` 的 AST 节点类型列表（或确认是何种 AST 表示）
- [ ] 参数 `context` 的属性/方法列表
- [ ] §8 差异对比表完整填写
- [ ] logger 模块的方法列表
- [ ] 每个结论附 `[来源: file:line]`
- [ ] 每个"未找到"附搜索记录（搜过的关键词 + 搜索范围）

**迭代要求**：
1. 第一轮：执行搜索手册 Step 1-5，产出所有章节初稿
2. 第二轮：根据自检报告中的 ❌ 和 ⚠️ 项，补全未达标章节
3. 最终轮：文档开头插入"文档状态: ✅ 已完成 / ⚠️ 部分完成"标记

---

## ⛔ 重要约束（违反任一项即为不合格）

1. **不要猜测** — 只输出源码中确认的信息。每个结论附 `[来源: file:line]`
2. **⛔ 禁止参考 Java loadclass 推断 JS API** — JS extend-file 是 `.js` CommonJS 模块，与 Java 的 `evaluate(JavaNode, AbstractTaintedDataRule, ...)` 完全无关。不要用 Java 的类名、方法名、AST 节点类型来推断 JS 的对应物
3. **仅 JavaScript** — 本文档不重复 Java API 内容
4. **记录搜索路径** — 对于每个"未找到"，记录搜索关键词 + 搜索文件范围
5. **自检报告每轮必须更新**
6. **如果 Step 1 完全找不到 `userDefineFunc`** — 不要编造，如实报告搜索过的所有关键词和文件范围，这本身就是有价值的信息
