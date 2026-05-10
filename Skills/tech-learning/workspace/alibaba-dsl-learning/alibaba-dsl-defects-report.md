# Alibaba DSL 纯 Rule/Roster 表达能力缺陷报告

## 一页版摘要

如果只允许使用 Alibaba DSL 的 rule、roster、relation，而不允许使用 extend-file 与 PMD Java 扩展，那么它最核心的问题可以用一句话概括：

**它更像“方法级 taint 配置语言”，而不是“结构搜索 / 状态机 / CFG 规则语言”。**

因此，凡是源规则依赖下面这些能力，translator 都只能降级近似，做不到 1:1 翻译：

| 问题 | 通俗解释 | 最简证据 |
|------|----------|----------|
| 不能做同一节点上的 AND 逻辑 | 不能像 Semgrep `patterns` 那样，对同一个调用点同时叠加多个条件 | `raw-html-join` 的 analyzer 明确把 `patterns (AND)` 列为必需能力；translator 最终只能把多个条件压成一条大正则，见 `RawHtmlJoinBrowserXss_0.ros` |
| 不能精确排除“字面量参数 / 安全特例” | 能匹配 `html(...)`，但很难继续表达“第一个参数不是字面量字符串”或“同方法里存在补偿调用则不报” | `prohibit-jquery-html` 原规则有两条 `pattern-not`；JS 额外验证里 `sink.methodArg.xpath` 直接报 `cannot find field by name: xpath` |
| 不能精确表达 JS 函数入参 source | 想表达“导出函数的第一个参数是污点源”，pure DSL 没有稳定入口 | 额外验证 `source.methodArg += {...}` 在 JS 中失败：`custom define config: source.methodArg can only be string value` |
| 不能表达 tag 组合与优先级降级 | 只能表达“净化/不净化”，不能表达“CR 和 LF 都编码了才安全”或“只降级到 LOW” | 额外验证 `priority = "LOW"`、`tag = "CR_ENCODED"` 都失败：`cannot find field by name` |
| 不能表达多状态传播 / CFG 聚合 | 不能表达“先是普通 taint，流经某节点后升级成另一种风险状态”，也不能表达“4 个条件同时满足才算安全” | 额外验证 `propagate.methodReturn` 在 JS 中失败；`XxeDetector` 只能拆规则 + 保留局部安全调用，无法表达“多条件全部成立才 suppress” |

### 最简结论

1. **Alibaba DSL 纯 rule/roster 适合写 source、sink、sanitizer 这类“方法级 taint 规则”。**
2. **一旦源规则依赖结构匹配、同节点多条件 AND、实参字面量判断、tag 组合、状态机、CFG 聚合，translator 就只能降级近似。**
3. **所以问题不在 translator 偷懒，而在 pure DSL 的表达上限。**

### 最简证据包

如果只保留 5 条最小证据，建议引用下面这些：

1. `raw-html-join` analyzer：明确写出 `patterns (AND)` 是 fidelity 所必需的能力。
2. `RawHtmlJoinBrowserXss_0.ros`：translator 把多条件 AND 压成了一条大正则，而不是保留为独立条件序列。
3. JS 额外验证：`sink.methodArg.xpath` -> `cannot find field by name: xpath`。
4. JS 额外验证：`source.methodArg += {...}` -> `custom define config: source.methodArg can only be string value`。
5. Java 额外验证：`priority` / `tag` 字段都报 `cannot find field by name`。


## 范围说明

本报告只讨论一个前提：

- 只使用 Alibaba DSL 的 rule、roster、relation
- 不使用 extend-file
- 不使用 PMD Java 扩展 / loadclass 自定义代码

抽样来源限定为以下四批 ruletransfer 结果中的 translator 工作区：

- /home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260408-122245
- /home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-214357
- /home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-221326
- /home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-230129

抽样时重点读取了每个任务的：

- workspaces/2-translator/translation_plan.md
- workspaces/2-translator/target_engine_safe_approximation_report.md
- workspaces/2-translator/target_rule

结论聚焦“由于 DSL 表达能力不足而被迫降级”的典型模式，而不是翻译器实现细节。

---

## 1. 无法表达“结构匹配 + 否定过滤 + 实参字面量约束”

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/jquery/security/audit/prohibit-jquery-html.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/sqli/jdbc-sqli.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/xxe/documentbuilderfactory-disallow-doctype-decl-false.yaml

#### 源规则语义

这类源规则的核心不是 taint，而是“结构搜索 + 负向排除”。

典型语义包括：

- 命中 `.html(...)`，但排除 `.html()`
- 命中 `.html(...)`，但排除 `.html("字面量")`
- 命中 `Statement.execute*(sql)`，但排除纯常量拼接
- 命中 `setFeature(...)`，但只在第一个实参是指定 URL、第二个实参是 `false` 时触发
- 如果同一方法里又出现一组补偿性安全调用，则整体不报

这类规则对 SAST 语法的要求是：

- 能看到调用点的 AST 结构
- 能表达 `pattern-not` / `pattern-not-inside`
- 能约束某个实参是不是字面量、是不是某个具体常量
- 能表达“同一方法中同时存在 A 且不存在 B”的组合条件

#### alibaba-dsl缺陷

纯 Alibaba DSL 的 source/sink/sanitizer 模型本质上是“方法级污点规则”，不是“结构搜索规则”。

只用 rule/roster 时，DSL 可以比较稳定表达的是：

- 某个方法是否是 source
- 某个方法的第几个参数是否是 sink
- 某个方法是否是 sanitizer

但它表达不了下面这些更细的结构语义：

- 对 sink 的实参 AST 形态做否定过滤
- 对调用实参的字面量值做精确匹配
- 同一方法体内的 `pattern-inside + pattern-not-inside` 差集
- 同时要求多个补偿调用存在后再整体 suppress

换句话说，源规则要的是“局部结构逻辑”，Alibaba DSL 纯 rule/roster 给的是“全局 taint 框架”。二者不是一个层级。

#### 降级策略

translator 的典型降级策略是：

- 把 search 规则改写成 taint 规则
- 用 `sink.methodArg + paramIndex` 近似“存在第一个参数”
- 用 `source.expression` 的正则近似“动态表达式”
- 放弃 `pattern-not` / `pattern-not-inside` 的严格 AST 语义
- 在报告中显式承认 literal-only exclusion 与补偿调用差集逻辑丢失

这不是偷懒，而是因为纯 DSL 没有对应语法槽位。

### 缺陷验证

#### 验证样例

```javascript
// 原规则应该命中
$("#out").html(userInput);

// 原规则应该排除：无参 getter
$("#out").html();

// 原规则应该排除：纯字面量写入
$("#out").html("<b>static</b>");
```

如果只用 Alibaba DSL 纯 rule/roster，最多只能把 `.html` 建成 sink，并用 `paramIndex = 0` 排除无参调用；但无法继续表达“第一个参数必须不是字面量字符串”。

#### 额外语法验证

为了验证 DSL 是否存在隐藏的 sink 侧 AST 条件入口，额外设计了一个 JS roster：

```javascript
Roster Rep02_js_sink_method_arg_xpath {
	sink.methodArg += {
		pattern += "/\\bhtml\\b/";
		xpath = "//CallExpression/Arguments/*[1][self::Literal]";
	};
}
```

verify 返回：

- `cannot find field by name: xpath`

这说明在 JS 纯 DSL 中，连“给 sink.methodArg 增加一个 AST 条件子字段”的入口都没有，更不用说等价复刻 `pattern-not`、`pattern-not-inside`、字面量排除和同方法体差集逻辑。

### 最终结论

对 Semgrep/结构搜索类规则而言，Alibaba DSL 纯 rule/roster 最大的短板不是“少几个库函数”，而是**根本缺少局部 AST 逻辑表达能力**。translator 只能把 search 规则硬转成 taint 规则，因此必然出现：

- 误报增加：literal-only exclusion 丢失
- 漏报增加：某些仅靠结构关系才能识别的场景丢失
- 规则语义从“结构检测”漂移为“近似污点检测”

---

## 1.1 无法在“同一节点”上表达通用 AND 逻辑（类似 Semgrep `patterns` 序列）

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/browser/security/raw-html-join.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/jquery/security/audit/prohibit-jquery-html.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/sax/security/audit/sax-xxe.yaml

#### 源规则语义

这类规则需要的不是“多个候选点的并集”，而是**同一个候选节点必须同时满足多条约束**。

以 `raw-html-join` 为例，analyzer 已明确识别出它依赖：

- `patterns (AND)`
- `pattern-either (OR)`
- `metavariable-pattern`
- `pattern-not`

而且这些条件不是分散作用在不同节点上，而是要叠加到**同一个 `.join(...)` 候选**上：

1. 它必须是数组 `.join(...)`
2. 数组中的某个绑定元素 `$STRING` 必须再满足“含 HTML 片段”这个二次约束
3. 整个候选还必须同时不落入“全常量 join”排除分支

这正是 Semgrep `patterns` 的典型能力：**先锁定一个候选节点，再在这个候选节点上叠加多个 pattern 序列做 AND**。

`prohibit-jquery-html` 也是同类问题：

- 主命中：`$X.html(...)`
- 同一候选节点上同时叠加两条否定过滤：不是 `.html()`，也不是 `.html("...")`

`sax-xxe` 体现的是同一类缺陷的另一种形态：

- 需要先有 `require('sax')`
- 再有 `ondoctype = ...` 或 `on('doctype', ...)`
- 本质上是同一风险候选上的“顺序 + 联合条件”

#### alibaba-dsl缺陷

纯 Alibaba DSL 没有与 Semgrep `patterns` 对应的“候选节点级布尔组合器”。

在 pure rule/roster 里，最常见的写法是：

- 多条 `source.* += { ... }`
- 多条 `sink.* += { ... }`
- 多条 `sanitizer.* += { ... }`

这些条目的语义本质是**候选集合并集（OR）**，不是“同一个节点必须同时满足多条子条件（AND）”。

translator 因此只能做两类退化：

1. 把多个同节点条件**手工压扁**到一条大正则里
2. 把其中一部分条件改写成 source/sink/sanitizer 三段 taint 近似

例如 `raw-html-join` 的实际目标 roster 就明显体现了这种压扁策略：

- 原来的“join 主模式 + `$STRING` 二次约束 + 常量排除”没有以三条独立 AND 条件存在
- 而是被硬塞进 `source.expression` 的大正则与 `sanitizer.expression` 的近似过滤里

这不是实现偷懒，而是因为 pure DSL 没有一个类似：

```text
candidate node satisfies A
AND same candidate node satisfies B
AND same candidate node does not satisfy C
```

的通用规则容器。

#### 降级策略

translator 对这类规则的典型降级策略是：

- 若多个约束还能文本拼接，就压成一条更复杂的正则
- 若有些约束无法正则化，就拆成 source/sink/sanitizer 的 taint 近似
- 若还包含 `pattern-not`，再额外用 sanitizer 或后处理模拟排除逻辑

`raw-html-join` 的 translation_plan 已明确把源规则归类为“结构匹配（search 模式）+ 组合约束（AND/OR/NOT）”，并在 engine capability analysis 中把 `patterns (AND)` 列为 fidelity 所必需的能力。这说明 translator 自己也把问题定位成“目标引擎缺少同级布尔组合能力”。

### 缺陷验证

#### 验证样例

下面是一个最小化的 same-node AND 需求：

```javascript
// 目标：只匹配同一个 join 调用，同时满足两个条件
// 条件 A：这是数组 .join(...)
// 条件 B：数组元素里同时出现 HTML 片段 和 动态变量
let s = ["<div>", userInput, "</div>"].join("");
```

如果用 Semgrep，可以把 A、B 拆成两个 pattern，再通过 `patterns` 让它们共同约束同一个 `.join(...)` 节点。

但 Alibaba DSL 纯 rule/roster 没有地方可以写出这种“候选节点级 AND”；translator 最终只能像 `raw-html-join` 一样，把 A+B 压成一条长正则：

```javascript
source.expression += {
	 taintTag = "raw_html_join";
	 value += "/\\[[^\\]]*<\\s*[A-Za-z][^\\]]*,[^\\]]*\\b[A-Za-z_$][A-Za-z0-9_$]*[^\\]]*\\]\\s*\\.join\\s*\\(/";
};
```

这已经不是“两个独立条件的 AND”，而是“一个人工拼接的单条件近似”。

#### 额外语法验证

这次专项调研得到的更细边界是：

1. **JS 侧没有通用 same-node AND 入口**
	- `sink.methodArg.xpath` 在 JS 中直接失败：`cannot find field by name: xpath`
	- 说明连“方法命中 + 局部 AST 二次约束”这样的字段内 AND 都没有

2. **Java 侧存在极少数“字段内局部 AND”例外，但不是通用解法**
	- `sink.methodArg += { value = "..."; xpath = "..."; }` 可以通过 verify（xp06）
	- 同一字段里塞一个不存在的子字段 `bogus` 会失败（xp11）
	- 这证明 Java 某些字段确实支持“字段值 + XPath 谓词”的局部联合约束

3. **但这个例外不能等价替代 Semgrep `patterns`**
	- 它只发生在极少数字段上
	- 不能平移到 JS
	- 不能做任意多个独立 pattern 的布尔组合
	- 不能表达 metavariable 绑定后再做通用二次 pattern 约束
	- 不能表达跨多个独立语法点的 pattern 序列

所以更准确的结论不是“Ali DSL 完全没有 AND”，而是：

- **没有通用的、候选节点级的 AND 逻辑容器**
- 只有极少数 Java 字段支持“字段内 value + xpath”的局部联合过滤

### 最终结论

如果把问题限定为“像 Semgrep `patterns` 一样，对同一个候选节点叠加一个 pattern 序列做 AND”，那么 Alibaba DSL 纯 rule/roster **确实不具备这种通用表达能力**。

它当前能做到的最好情况只是：

- Java 的个别字段上做 very local 的 `value + xpath` 联合过滤
- 或者把多个条件压扁成一条更复杂的 regex / taint 近似

但这两者都不等价于 Semgrep 的 `patterns`：

- 不能复用到任意节点
- 不能表达 metavariable 二次约束
- 不能稳定表达 A AND B AND NOT C 这种同节点逻辑链

因此，在面向结构搜索规则翻译时，“缺少同节点 AND 逻辑”应当被视为 Alibaba DSL pure rule/roster 的一条**独立核心缺陷**，而不是“局部 AST 表达能力不足”的附属症状。

---

## 2. 无法精确表达 JavaScript 的“函数入参 / 库导出入参 / 绑定变量”source 边界

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/src/Security/CWE-078/UnsafeShellCommandConstruction.ql
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/aws-lambda/security/tainted-eval.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/puppeteer/security/audit/puppeteer-evaluate-arg-injection.yaml

#### 源规则语义

这类 JS 规则的 source 不是“任意 Web 输入”，而是更精确的：

- 仅库对外导出的 API 入参
- 仅 AWS Lambda handler 的事件参数
- 仅 Puppeteer evaluate 闭包里的特定形参绑定值
- 还会排除某些明显是命令本体的参数名
- 需要沿导出图、绑定图、参数访问路径去识别“哪个参数才算真正的外部输入”

这种语义对规则语法的要求是：

- 能直接把“函数参数”建模为 source
- 能约束 source 仅出现在特定导出边界
- 最好还能叠加参数名排除、导出图递归等结构条件

#### alibaba-dsl缺陷

在不使用 extend-file 的前提下，JS 纯 DSL 实际可用的 source 入口很有限：

- `source.methodReturn`
- `source.expression`
- `source.paramDecorator`

它没有一个可稳定使用的 `source.methodArg` 或“函数参数 source”能力来表达“导出函数第 N 个参数是 source”。

于是 translator 只能把这些更精确的 source 语义降级成更宽的 `source.expression` 正则近似，比如去匹配：

- `arguments[i]`
- `argv`
- `options`
- `input`
- `module.exports` / `exports.*`

在 `tainted-eval` 中，原本“Lambda handler 的事件参数”也只能被转写成表达式级 source；在 `puppeteer-evaluate-arg-injection` 中，原本“函数形参 `$INPUT` 与 evaluate 参数中的 `$INPUT` 是同一绑定”这件事，也无法以 pure DSL 的 source 语法稳定复刻。

这会导致 source 边界明显变宽，既可能多报，也可能漏掉复杂导出绑定。

#### 降级策略

translator 在 `UnsafeShellCommandConstruction`、`tainted-eval`、`puppeteer-evaluate-arg-injection` 这类任务中采用的共同策略是：

- 不再试图精确恢复 CodeQL 的 library input 参数模型
- 不再试图精确恢复 Lambda handler / 回调函数 / 闭包形参的绑定边界
- 改用 `source.expression` 捕获导出上下文和参数访问痕迹
- sink 侧继续保留高价值命令执行 API
- barrier 只保留函数级 sanitizer，不保留导出图/参数名过滤

### 缺陷验证

#### 验证样例

```javascript
module.exports.run = function (userArg, cmd) {
  child_process.exec(userArg);
};
```

源规则真正想表达的是：`userArg` 这种“对外导出函数的入参”才是 source，而且还可能需要排除 `cmd` 这种命令本体参数名。

#### 额外语法验证

为了验证 JS 纯 DSL 是否存在可用的参数 source 字段，额外设计了：

```javascript
Roster Rep01b_js_source_method_arg {
	source.methodArg += {
		value = "arguments0";
	};
}
```

verify 返回：

- `custom define config: source.methodArg can only be string value`

这说明 JS 纯 DSL 并没有一个可稳定拿来建“函数参数 source”的块字段入口。对 translator 来说，不用 extend-file 时，就只能退化到 `source.expression` 这类更宽的近似。

### 最终结论

只用 rule/roster 时，Alibaba DSL 在 JS 侧**缺少精确的参数源建模能力**。因此凡是依赖“导出函数入参”“库 API 入口”“参数名过滤”的规则，都会被迫降级成更宽的表达式 source 近似。这是纯 DSL 的边界，不是翻译器实现选择问题。

---

## 3. 无法表达“tag 组合判定 / 优先级降级”这类非二元净化语义

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/injection/smtp/SmtpHeaderInjectionDetector.java
- /home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/injection/sql/SqlInjectionDetector.java
- /home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/injection/sql/AndroidSqlInjectionDetector.java

#### 源规则语义

FindSecBugs 这类 detector 里的“净化”并不是简单的“安全 / 不安全”二元决策，而是更细的状态机。以 SMTP、SQLi、Android SQLi 三类 detector 为代表，常见语义包括：

- `CR_ENCODED && LF_ENCODED` 同时满足才 `IGNORE`
- `URL_ENCODED` 可以 suppress
- `SQL_INJECTION_SAFE` 直接降到 `IGNORE`
- `APOSTROPHE_ENCODED` 不是完全安全，只是降到 `LOW_PRIORITY`

这类语义对规则语法的要求是：

- 能给数据流附加 tag / state
- 能做 tag 组合判定（AND / OR）
- 能表达“降级但不消除”的优先级模型

#### alibaba-dsl缺陷

纯 Alibaba DSL 的 sanitizer 语义基本是二元的：

- 命中 sanitizer，视为被清洗
- 不命中 sanitizer，继续传播

它没有与 FindSecBugs 对齐的这些能力：

- 给 sanitizer 结果挂 `CR_ENCODED` / `LF_ENCODED` 这种 tag
- 在规则层写 `CR && LF` 才 suppress
- 把路径从 HIGH 降成 LOW，而不是直接消除

因此 translator 只能把“复杂编码语义”降级成“若干已知 API 名单型 sanitizer”。

#### 降级策略

translator 的典型降级策略是：

- 把常见编码 API 直接映射为 `sanitizer.methodReturn` / `sanitizer.methodArg`
- 放弃 tag 组合逻辑
- 放弃 LOW / NORMAL / HIGH 这类优先级模型
- 在近似报告中承认：原来只是“降级”的路径，在 Alibaba DSL 里无法等价表达

### 缺陷验证

#### 验证样例

```java
String tainted = request.getParameter("x");

// 原 detector 语义：若同时具备 CR_ENCODED 与 LF_ENCODED，则 IGNORE
String safe1 = encodeCR(tainted);
String safe2 = encodeLF(safe1);
message.addHeader("X-Test", safe2);

// 原 detector 语义：若只是 APOSTROPHE_ENCODED，则 LOW，而不是完全安全
String low = tainted.replace("'", "''");
statement.executeQuery(low);
```

#### 额外语法验证

为了确认纯 DSL 是否存在对应的 tag / priority 表达能力，额外设计了两个 Java roster：

```java
Roster Rep03_java_sanitizer_priority {
	sanitizer.methodReturn += {
		value = "com.example.Safe.escape";
		priority = "LOW";
	};
}
```

verify 返回：

- `cannot find field by name: priority`

以及：

```java
Roster Rep04_java_sanitizer_tag {
	sanitizer.methodReturn += {
		value = "com.example.Safe.escape";
		tag = "CR_ENCODED";
	};
}
```

verify 返回：

- `cannot find field by name: tag`

这说明在纯 rule/roster 层面，Alibaba DSL 根本没有与“tag 组合判定”或“优先级降级”对齐的原生语法位。

### 最终结论

对于 FindSecBugs 这类 heavily tag-driven 的 detector，Alibaba DSL 纯 rule/roster 只能把它们降级成“方法名级 sanitizer 名单”。SMTP Header Injection、SqlInjectionDetector、AndroidSqlInjectionDetector 三个样本都体现了同一个问题：

- 引擎原本有 tag
- tag 还会参与优先级决策
- pure DSL 最终只能保留一个“是否命中 sanitizer API”的简化版本

凡是：

- 多 tag 组合
- 条件 suppress
- 降级但不消除

这三类语义，纯 DSL 都不能 1:1 表达。

---

## 4. 无法表达“多状态流转 / 自定义传播边”

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/src/Security/CWE-915/PrototypePollutingAssignment.ql
- /home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/src/Security/CWE-915/PrototypePollutingMergeCall.ql
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/lang/security/audit/prototype-pollution/prototype-pollution-assignment.yaml

#### 源规则语义

`PrototypePollutingAssignment`、`PrototypePollutingMergeCall` 以及 Semgrep 版 `prototype-pollution-assignment` 这类规则，不只是“source 到 sink 的一条污点线”，而是一个状态机：

- `key` 污染时只是普通 taint
- 当它进入 `obj[key]` 这种动态属性访问后，语义会转成 `object-prototype` 风险状态
- 某些 guard / barrier 只对特定状态生效
- 某些三方库路径需要被忽略

这类规则要求语法能够表达：

- 多种流状态
- 状态转移
- 自定义传播边
- 对状态敏感的 barrier

#### alibaba-dsl缺陷

纯 Alibaba DSL 没有这样的状态机模型。它能表达的是：

- 某些 source 打上同一个 taintTag
- 某些 sink 接收 taintTag

但它表达不了：

- 流经某个节点后状态从 A 变成 B
- `key -> obj[key]` 这种“动态属性访问触发状态升级”
- barrier 只在某个 state 下生效

#### 降级策略

translator 在这三类样本中的共同降级策略是：

- 用 `taintTag = "proto_key"` 做一个弱近似标签
- 用高风险 merge / assign / set / unset API 作为 sink
- 用常见过滤键名函数作为弱 sanitizer
- 放弃真正的状态转移和 state-sensitive barrier

### 缺陷验证

#### 验证样例

```javascript
let key = req.query.key;     // 仅是“可控属性名”
let obj = {};
obj[key] = value;            // 这里才升级成原型污染风险
```

原规则真正需要的是：`key` 在进入 `obj[key]` 之后，语义发生变化；而纯 DSL 只能看到“source 和 sink 都沾了同一个 taintTag”。

#### 额外语法验证

为了验证 JS 纯 DSL 是否存在可用的 propagation 入口，额外设计了：

```javascript
Roster Rep05b_js_propagate_method_return {
	propagate.methodReturn += {
		value = "Object.assign";
	};
}
```

verify 返回：

- `custom define config: propagate.methodReturn can only be string value`

这说明在 JS 纯 rule/roster 中，translator 连一个可稳定使用的 `propagate.*` 通道都没有，更不可能实现 CodeQL 那种“多状态流 + 自定义传播边 + 状态敏感 barrier”。

### 最终结论

凡是依赖“状态机会升级”“传播边是自定义的”“guard 对状态敏感”的规则，Alibaba DSL 纯 rule/roster 都只能做很粗的弱近似。PrototypePollutingAssignment、PrototypePollutingMergeCall、prototype-pollution-assignment 这三个样本已经足够说明：prototype pollution 类规则在不使用 extend-file 的前提下，几乎不可能做到语义等价迁移。

---

## 5. 无法表达“字节码级 CFG 聚合 / 多条件同时成立才安全”

### case回顾

抽样任务：

- /home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/xml/XxeDetector.java
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/xxe/documentbuilderfactory-disallow-doctype-decl-false.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/xxe/saxparserfactory-disallow-doctype-decl-missing.yaml
- /home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/xml/TransformerFactoryDetector.java

#### 源规则语义

这类 FindSecBugs / Semgrep XXE 规则经常不是“看到一个危险 API 就报”，而是：

- 先识别某个 XML 解析入口
- 再在方法内检查多个安全配置是否都到位
- 还可能回溯前序常量加载、区分具体重载、区分不同分支 bug type
- 只有若干布尔条件全部满足时，才认为是安全的

`XxeDetector`、`documentbuilderfactory-disallow-doctype-decl-false`、`saxparserfactory-disallow-doctype-decl-missing`、`TransformerFactoryDetector` 这几类样本，本质上都依赖这种“多条件 simultaneously 成立”的安全判定。

这要求规则语法具备：

- 方法内 CFG / 时序聚合
- 多条件 all-of 逻辑
- 对常量实参值的精确约束
- 对重载/签名/前序指令的精细建模

#### alibaba-dsl缺陷

纯 Alibaba DSL 没有“方法内状态聚合器”。它能做的是：

- 把若干安全 API 建成 sanitizer
- 把若干危险 API 建成 sink

但它不能表达：

- 只有四个安全调用都出现才 suppress
- 某个安全调用必须出现在另一个调用之前
- 某个实参必须是 `true` / `false` / 特定 URL 常量
- 只对某个重载签名生效

#### 降级策略

translator 的典型降级策略是：

- 把多分支 detector 拆成多条规则，减少一条规则过度泛化
- 用 `sink.methodArg` 保留高价值风险参数位
- 用 `sanitizer.methodArg` / `sanitizer.methodReturn` 保留可观察的安全配置调用痕迹
- 放弃“多条件同时满足才安全”的强语义，只保留可见的局部安全调用

### 缺陷验证

#### 验证样例

```java
SAXParserFactory factory = SAXParserFactory.newInstance();
factory.setEntityResolver(new DefaultHandler());
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
factory.setFeature("http://javax.xml.XMLConstants/feature/secure-processing", true);
factory.setXIncludeAware(false);
parser.parse(userXml);
```

源 detector 需要的是：四个条件都满足，才认为这条路径安全。

但纯 DSL 里，translator 最多只能把前面几条安全配置方法各自建成 sanitizer；它无法再写一个“all of the above must hold”条件来控制最终 parse 是否 suppress。

#### 额外论证

这一缺陷的关键不在某一个字段 parse fail，而在于**整个 pure DSL 语法里不存在方法内聚合控制结构**。换句话说：

- 没有 `allOf`
- 没有 `if`
- 没有 branch guard
- 没有方法内时序 / CFG 条件

因此这类 detector 的降级不是“字段没找全”，而是“规则语义模型本身不在一个层级”。

### 最终结论

对于 XXE 这类 heavily context-sensitive 的规则，Alibaba DSL 纯 rule/roster 可以保留“高价值 API 面”，但无法保留“多条件同时成立才安全”的精细判定。translator 能做的最佳策略，就是拆规则、保留高价值 sink、保留显式安全 API，并在报告里透明披露精度损失。

---

## 总体结论

结合本次四批 ruletransfer 抽样，可以把 Alibaba DSL 在“只用 rule/roster，不用 extend-file 与 PMD Java 扩展”前提下的典型表达能力不足，归纳为五类：

1. 不能表达局部 AST 结构逻辑，尤其是 `pattern-not`、`pattern-not-inside`、实参字面量约束、同方法体差集。
2. 不能精确表达 JS 的函数参数 / 库导出入参 source 边界，只能退化成更宽的 expression source。
3. 不能表达 tag 组合判定、条件 suppress、LOW/HIGH/IGNORE 这类优先级降级语义。
4. 不能表达多状态流、自定义传播边、状态敏感 barrier。
5. 不能表达字节码级 CFG 聚合、时序条件、多条件 simultaneously 成立才安全的判定。

这五类问题的共同点是：

- 不是翻译器漏写几个字段
- 不是 analyzer 没抽到语义
- 而是 pure DSL 只擅长“方法级 taint 规则”，不擅长“结构搜索 / 状态机 / CFG / 优先级系统”

因此，面对 Semgrep 高级 search 规则、CodeQL 状态流规则、FindSecBugs detector 级规则时，translator 的“安全近似 / 降级策略”是必然产物，不是实现偷懒。
