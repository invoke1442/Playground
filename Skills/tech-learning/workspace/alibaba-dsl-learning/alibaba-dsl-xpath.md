# Alibaba DSL XPath 遍历笔记

> 更新时间：2026-04-07
>
> 范围：遍历 `official-docs/configs_v3.3/rosters/` 下全部 23 个官方 Java roster，用它们反推 Alibaba DSL 中 XPath 的真实落点、语义边界，以及从 Java 到 JavaScript 的可迁移性。

---

## 0. 方法与证据

- 官方样本：`official-docs/configs_v3.3/rosters/*.ros` 共 23 个
- 当前学习笔记：`alibaba-dsl-learning-notes.md`
- 外部 skill：`/home/nyn/Desktop/Projects/SAST/oh-my-rule/packages/skills/alibaba-dsl/SKILL.md`
- 外部 skill 参考：`/home/nyn/Desktop/Projects/SAST/oh-my-rule/packages/skills/alibaba-dsl/references/java-syntax.md`
- 本轮实验脚本：`workspace/run-xpath-iteration-experiments.sh`
- 本轮实验结果：`workspace/xpath-iteration-lab/results/summary.tsv`

**注意**：verify API 主要验证语法、字段名与部分字段 schema；它**不等于运行时引擎语义验证**。因此本文的结论分为两类：

- **生产规则确认**：官方 roster 真实使用过，可信度最高
- **语法实验确认**：verify API 接受，但运行时效果仍需真实扫描引擎验证

---

## 1. 总结论

### 1.1 官方 roster 中，生产级 XPath 只出现在一个 roster 里

全部 23 个官方 roster 扫描后，**所有显式 XPath 用法都集中在 `Java_common_source_0.ros`**。生产规则中真正出现的 XPath 载体只有 3 类：

1. `general.entranceFileXpath`
2. `source.methodParam += { xpath = "..."; }`
3. `general.methodRedirect += { value = "..."; xpath = "..."; }`

也就是说，**从官方用例本身出发，Alibaba DSL 并没有大面积把 XPath 暴露给所有 source/sink/sanitizer/propagate 字段**。

### 1.2 但语法实验发现了两个“隐藏点”

本轮实验又补出两个仅靠官方 roster 看不出来的点：

1. `Java sink.methodArg += { ...; xpath = "..."; }` 在 verify API 中**语法通过**
2. `JavaScript general.entranceFileXpath += "..."` 在 verify API 中**语法通过**

这两个点都还**没有官方生产规则背书**，尤其 `sink.methodArg.xpath` 需要后续做运行时扫描验证。

### 1.3 当前最稳的边界

到这一轮为止，可以把 XPath 支持边界写成：

- **Java 生产规则确认支持**：`general.entranceFileXpath`、`source.methodParam.xpath`、`general.methodRedirect.xpath`
- **Java 语法实验额外确认**：`sink.methodArg.xpath`
- **Java 语法实验确认不支持**：`source.methodReturn.xpath`、`source.methodArg.xpath`、`source.paramAnnotation.xpath`、`source.mvcMapping.xpath`、`sanitizer.methodReturn.xpath`、`sanitizer.methodArg.xpath`、`sink.methodObject.xpath`、`sink.methodArgJws.xpath`、`sink.methoArgUpcast.xpath`、`sink.responseBody.xpath`
- **JavaScript 语法实验确认支持**：`general.entranceFileXpath`
- **JavaScript 语法实验确认不支持**：`source.methodReturn.xpath`、`source.paramDecorator.xpath`、`sink.methodArg.xpath`

---

## 2. 23 个官方 roster 遍历摘要

下面按 roster 逐个记录“它贡献了什么新信息”，直到信息增益耗尽为止。

### 2.1 Source 相关 roster

- `Java_common_source_0.ros`
	- **本轮最关键的 roster**
	- 覆盖了 `general.entranceFileXpath`、`source.methodParam(xpath)`、`general.methodRedirect(xpath)` 三类 XPath 位置
	- 同时还展示了 `source.velocityReference`、`source.allocReturn`、`source.annotationJWS`、`source.paramAnnotation`、`source.mvcMapping`、`source.methodReturnJws` 等 source 侧真实扩展字段
	- 结论：官方生产规则中的 XPath 能力几乎都集中在这里

- `Java_second_package_source_0.ros`
	- 没有 XPath
	- 提供的是 `includePlatforms` / `excludePlatforms` / `general.scanAllFiles` / `propagate.bAllPublicMethod`
	- 结论：平台过滤与“扫全文件”属于 source 发现策略，不属于 XPath 发现策略

### 2.2 Common / propagate / sanitizer 相关 roster

- `Java_common_propagate_0.ros`
	- 无 XPath
	- 新增信息在 propagate / sanitizer / general 组合能力上
	- 特别重要的字段：`general.blackFieldMatch`、`general.handlePolymorphism`、`general.polyHandleNum`、`general.taintOnlyBySummary`、`propagate.methodObjectToFirstArg`、`sanitizer.safeVarNames`

- `Java_cmdi_propagate_0.ros`
	- 无 XPath
	- 基本只补 `sanitizer.methodReturn`

- `Java_network_io_sanitizer_0.ros`
	- 无 XPath
	- 强化 `sanitizer.safeTypes`、`excludeTag`

- `Java_pathtraversal_propagate_0.ros`
	- 无 XPath
	- 主要展示 `general.userDefinePatternClass` + `sanitizer.methodReturn`

- `Java_sqli_propagate_0.ros`
	- 无 XPath
	- 主要展示 `sanitizer.methodArg`、`sanitizer.methodObject`、`sanitizer.safeTypes`

- `Java_ssrf_propagate_0.ros`
	- 无 XPath
	- 主要价值在 SSRF 专有字段：`propagate.bPreSanitizerParam`、`propagate.bSanitizerParamTransmit`、`sanitizer.methodArgWithRedirectCheck`、`sanitizer.methodRedirectCheck`、`sanitizer.methodUnSafeState`

- `Java_stream_io_sanitizer_0.ros`
	- 无 XPath
	- 仅补 `sanitizer.safeTypes`

- `Java_urlredirect_propagate_0.ros`
	- 无 XPath
	- 主要展示 URLRedirect 传播组合：`propagate.methodArgToObjectAndReturn`、`propagate.methodObjectToReturn`

- `Java_xss_propagate_0.ros`
	- 无 XPath
	- 主要价值在 `propagate.noTaintNoSourceFile` 与 `propagate.vmContext`

- `Java_xxe_propagate_0.ros`
	- 无 XPath
	- 主要价值在 XXE 专有字段：`propagate.bUseStreamReader`、`propagate.bUseXXEFlags`、`propagate.methodStreamReader`、`propagate.xxeMethod`、`propagate.xxeType`

### 2.3 Vulnerability sink 相关 roster

- `Java_Param_new_callbackxss_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`sink.applicationJsonAnnotation`、`sink.applicationJsonProduces`、`sink.contextJws`

- `Java_Param_new_commandInjectionJava_sink_0.ros`
	- 无 XPath
	- 展示 `sink.methodArg` + `sink.methodObject`

- `Java_Param_new_groovyShell_sink_0.ros`
	- 无 XPath
	- 与命令执行 sink 类似

- `Java_Param_new_javaDeserialization_sink_0.ros`
	- 无 XPath
	- 与 `sink.methodObject` 家族相关

- `Java_Param_new_pathTraversalJava_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`propagate.bUseCritical`、`propagate.criticalType`、`propagate.methodArgToReturnCritical`、`propagate.methodObjectToFirstArgCritical`、`propagate.methodObjectToReturnCritical`、`sink.methodCritical`

- `Java_Param_new_sqlInjectionAnnotation_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`sink.mybatisProvider`

- `Java_Param_new_sqlInjectionJava_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`propagate.bUseSqlSpecial`、`sink.methodSqlSpecial`

- `Java_Param_new_sqlInjectionXBatis_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`sink.methodXbatis`、`sink.methodXbatisExclude`

- `Java_Param_new_ssrfJava_sink_0.ros`
	- 无 XPath
	- 主要展示 `sink.allocArg`

- `Java_Param_new_urlRedirectJava_sink_0.ros`
	- 无 XPath
	- 主要展示 `sink.allocArg`、`sink.methodArgJws`

- `Java_Param_new_xmlentitiyinjectionjava_sink_0.ros`
	- 无 XPath
	- 关键新增字段：`sink.bUseSinkFilter`、`sink.filter`

### 2.4 遍历停止条件

对 23 个官方 roster 全部扫描后：

- 生产级 XPath 落点没有扩散到第二个 roster
- 新增信息主要变成“更多 sink / propagate / sanitizer 特殊字段”，不再是新的 XPath 语法位置
- 因而**继续遍历这些 roster 已无法提供新的 XPath 位置知识**

后续如果还要继续深挖 XPath，信息源应切换到：

- 运行时扫描验证
- Java loadclass 扩展实现
- 官方 JavaScript roster（如果后续拿得到）

---

## 3. 当前学习笔记 vs 外部 skill 的覆盖差异

### 3.1 当前学习笔记

`alibaba-dsl-learning-notes.md` 已经覆盖了绝大多数官方 roster 字段，尤其生产规则里扩展出来的 `source.*`、`sink.*`、`sanitizer.*`、`propagate.*`、`general.*` 真实子字段，基本已被吸收。

### 3.2 外部 skill / java-syntax 仍偏窄

对照 `/home/nyn/Desktop/Projects/SAST/oh-my-rule/packages/skills/alibaba-dsl/SKILL.md` 与外部 `references/java-syntax.md` 后，本轮确认外部 skill / ref 仍未充分吸收下面这些**官方 roster 已存在**的字段：

- `general.blackFieldMatch`
- `general.handlePolymorphism`
- `general.userDefineEntranceClass`
- `general.userDefinePatternClass`
- `propagate.bOnlyTaintedByObject`
- `propagate.bSanitizerParamTransmit`
- `propagate.bTaintedStart`
- `propagate.bUnkownAsSafe`
- `propagate.bUseCritical`
- `propagate.bUseSafeState`
- `propagate.bUseStreamReader`
- `propagate.criticalType`
- `propagate.definiteNoSourceFile`
- `propagate.methodArgToReturnCritical`
- `propagate.methodObjectToFirstArgCritical`
- `propagate.methodObjectToReturnCritical`
- `propagate.methodReturnUpcast`
- `propagate.methodStreamReader`
- `propagate.xxeMethod`
- `sanitizer.methodUnSafeState`
- `sink.applicationJsonAnnotation`
- `sink.applicationJsonProduces`
- `sink.contextJws`
- `sink.methodCritical`
- `sink.methodSqlSpecial`

**结论**：当前学习笔记的生产规则覆盖面已经明显超过外部 skill / java-syntax 参考；本轮 XPath 笔记需要把“官方 roster 全量扫描结论”单独沉淀，避免外部 skill 的窄口径影响判断。

---

## 4. 哪些字段可以使用 PMD XPath

## 4.1 生产规则确认支持

| 字段 | 语言 | 形式 | 证据 | 作用 |
|------|------|------|------|------|
| `general.entranceFileXpath` | Java | `= "xpath"` / `+= "xpath"` | `Java_common_source_0.ros` + `xp01` | 文件 / 编译单元级预过滤 |
| `source.methodParam` | Java | `+= { xpath = "..."; tag = "..."; }` | `Java_common_source_0.ros` + `xp03` | 直接选中“满足条件的形参节点” |
| `general.methodRedirect` | Java | `+= { value = "..."; xpath = "..."; }` | `Java_common_source_0.ros` + `xp02` | 在入口模式命中后，继续从局部 AST 中取目标子节点 |

## 4.2 语法实验额外支持

| 字段 | 语言 | 形式 | 证据 | 可信度 |
|------|------|------|------|------|
| `sink.methodArg` | Java | `+= { precise; value; xpath; }` | `xp06 PASS` + `xp11 bogus FAIL` | **中**，语法明确支持，但暂无官方生产样本 |
| `general.entranceFileXpath` | JavaScript | `+= "xpath"` | `xp08 PASS` + `xp19 general.notARealField FAIL` | **中**，语法明确接受，但暂无官方 JS roster 背书 |

### 4.3 语法实验确认不支持

| 字段 | 语言 | 结果 | 实验 |
|------|------|------|------|
| `source.methodReturn.xpath` | Java | 不支持 | xp04 |
| `source.methodArg.xpath` | Java | 不支持 | xp05 |
| `sanitizer.methodReturn.xpath` | Java | 不支持 | xp07 |
| `sanitizer.methodArg.xpath` | Java | 不支持 | xp12 |
| `sink.methodObject.xpath` | Java | 不支持 | xp13 |
| `source.paramAnnotation.xpath` | Java | 不支持 | xp14 |
| `source.mvcMapping.xpath` | Java | 不支持 | xp15 |
| `sink.methodArgJws.xpath` | Java | 不支持 | xp20 |
| `sink.methoArgUpcast.xpath` | Java | 不支持 | xp21 |
| `sink.responseBody.xpath` | Java | 不支持 | xp22 |
| `source.methodReturn.xpath` | JavaScript | 不支持 | xp09 |
| `source.paramDecorator.xpath` | JavaScript | 不支持 | xp10 |
| `sink.methodArg.xpath` | JavaScript | 不支持 | xp16 |
| `general.methodRedirect` block | JavaScript | 不支持 | xp18 |

### 4.4 当前最可信的“XPath 支持矩阵”

| 字段族 | Java | JavaScript | 备注 |
|------|------|------|------|
| `general.entranceFileXpath` | ✅ | ✅(语法级) | JS 仍缺官方生产样本 |
| `general.methodRedirect.xpath` | ✅ | ❌ | Java 生产规则真实存在 |
| `source.methodParam.xpath` | ✅ | 不适用 | Java source 的核心 XPath 入口 |
| `source.methodReturn.xpath` | ❌ | ❌ | 等位推理失败 |
| `source.methodArg.xpath` | ❌ | 不适用 | 等位推理失败 |
| `source.paramAnnotation.xpath` | ❌ | 不适用 | block source 字段不自动继承 XPath |
| `source.mvcMapping.xpath` | ❌ | 不适用 | block source 字段不自动继承 XPath |
| `sink.methodArg.xpath` | ✅(语法级) | ❌ | Java 的隐藏例外 |
| 其他 sink / sanitizer block 字段的 `xpath` | ❌ | ❌ | 当前实验都失败 |

---

## 5. XPath 在对应字段中到底起什么作用

### 5.1 `general.entranceFileXpath`

**作用**：把一个 Java / JS 文件先过滤成“值得进一步分析的入口文件”。

它不是直接声明 source / sink，而是**文件级 gate**。只有文件满足这个 XPath，后续同 group 里的 source / userDefinePatternClass / 其他入口发现逻辑才有意义。

典型例子：

```java
general.entranceFileXpath += "./self::CompilationUnit/ImportDeclaration/Name[matches(@Image,'com.aliyun.odps.udf.UDF|com.aliyun.odps.udf.UDTF|com.aliyun.odps.udf.Aggregator')]";
```

这条的作用不是“把 import 节点本身当 source”，而是：

- 当前文件如果 import 了这些 ODPS 类型
- 则它属于 ODPS handler 场景
- 后续 `source.methodParam` 的几条 XPath 规则才会在这个文件里挑形参 source

### 5.2 `source.methodParam += { xpath = "..."; }`

**作用**：直接从 AST 中选出“满足某些上下文条件的形参节点”，并把这些形参当成 source。

这是最像 Semgrep 局部 `pattern-inside` 的位置，但它的锚点固定在**FormalParameter**，不是任意节点。

这里的 XPath 常用来表达：

- 当前节点自己必须是某个形参：`self::FormalParameter`
- 其所属方法名、public/static/void 属性
- 祖先类的继承关系：`ancestor::ClassOrInterfaceDeclaration[...]`
- 排除某些注解：`not(...)`
- 形参顺序：`@ChildIndex = 1`

### 5.3 `general.methodRedirect += { value; xpath; }`

**作用**：先命中一个“入口值模式”，再用 XPath 把真正的目标节点从局部结构里取出来。

官方例子：

```java
general.methodRedirect += {
		precise = true;
		value = "me.ele.napos.vine.processor.aop.Redirected";
		xpath = "./self::Annotation/NormalAnnotation/MemberValuePairs/MemberValuePair[@Image='to']/MemberValue/PrimaryExpression/PrimaryPrefix/ResultType";
};
```

它的语义更像：

- 先识别某类注解
- 再从注解参数 `to = ...` 中抽出被重定向的方法目标

因此它不是“匹配一个节点”，而是“在匹配到入口后再导航”。

### 5.4 `sink.methodArg += { ...; xpath = "..."; }`

**作用当前还不敢下最终结论**。

本轮只能确认：

- `xpath` 在这个字段里**不是随便乱塞都过**，因为 `bogus` 会报错（xp11）
- 说明 `xpath` 对 `sink.methodArg` 来说是**被识别的合法子字段**

但它在运行时到底是：

- 用来二次过滤 sink 命中的 AST 上下文
- 还是用来定位具体参数子节点
- 还是 verify API 接受、但运行时未必生效

目前都还没有生产规则或真实扫描结果能最终定性。

---

## 6. 从一个字段推理到等位字段 / JavaScript 的假设与验证

| 假设 | 结论 | 证据 |
|------|------|------|
| H1. `general.entranceFileXpath` 在 Java 中既支持 `=` 也支持 `+=` | **成立** | 官方 roster + xp01 |
| H2. `general.methodRedirect` 的 `xpath` 是合法子字段 | **成立** | 官方 roster + xp02 |
| H3. `source.methodParam.xpath` 支持复杂谓词 (`ancestor::`, `not`, `isExtends`, `@ChildIndex`) | **成立** | 官方 roster + xp03 |
| H4. Java source 的 block 字段会普遍继承 `xpath` | **不成立** | xp04, xp05, xp14, xp15 |
| H5. Java sink / sanitizer 的 `methodArg` 系字段会普遍继承 `xpath` | **不成立** | xp06 成立，但 xp12, xp13, xp20, xp21, xp22 均失败 |
| H6. `sink.methodArg.xpath` 只是“未知字段被忽略” | **不成立** | xp06 PASS，但 xp11 bogus FAIL |
| H7. Java 的 XPath 能力可以平移到 JS `source.methodReturn` / `source.paramDecorator` / `sink.methodArg` | **不成立** | xp09, xp10, xp16 |
| H8. JavaScript 完全没有 XPath 入口 | **不成立** | xp08 PASS |
| H9. JavaScript 也有 `general.methodRedirect` | **不成立** | xp18 FAIL |

**本轮最重要的新发现**：

1. Java 的 `sink.methodArg.xpath` 是一个真实存在的隐藏语法点
2. 这个特性**没有自动扩散**到 `sink.methodObject`、`sanitizer.methodArg`、`sink.methodArgJws` 等等位字段
3. JavaScript 目前只确认了 `general.entranceFileXpath` 这一个 XPath 入口；source/sink block 上的 `xpath` 迁移不成立

---

## 7. XPath 语法速记（结合 Alibaba DSL / PMD AST）

这部分只记最常用、也是官方 roster 真正用到的语法。

| 语法 | 含义 | 例子 |
|------|------|------|
| `self::NodeType` | 当前节点自己必须是某种 AST 节点 | `self::FormalParameter` |
| `ancestor::NodeType` | 往上找祖先节点 | `ancestor::ClassOrInterfaceDeclaration[...]` |
| `/` | 走到直接子节点 | `CompilationUnit/ImportDeclaration/Name` |
| `//` | 后代任意层 | `ancestor::ClassOrInterfaceBodyDeclaration//Annotation` |
| `[]` | 谓词过滤 | `Name[@Image='X']` |
| `@Attr` | 取节点属性 | `@Image`, `@MethodName`, `@ClassName` |
| `.` | 当前节点 | `./self::CompilationUnit/...` |
| `..` | 父节点 | `../../..` |
| `matches(x, 'regex')` | 正则匹配 | `matches(@Image, 'UDF|UDTF')` |
| `isExtends(@ClassName, 'FQN')` | 判断继承关系（扩展函数） | `isExtends(@ClassName, 'com.aliyun.odps.udf.UDF')` |
| `and` / `or` / `not(...)` | 谓词内部布尔逻辑 | `[A and B and not(C)]` |

**要点**：这些 XPath 逻辑只在**单个字段内部**生效，不等于 Alibaba DSL 存在通用 `patterns AND` 或通用 `pattern-inside`。

---

## 8. 为什么这里可以先停止继续扫 roster

我按“官方 roster -> 假设 -> 实验 -> 继续扩展同族字段”的流程，已经把目前能从官方 roster 中榨出来的 XPath 信息基本榨干了：

1. 23 个 roster 已全部扫描
2. 生产规则里的显式 XPath 位置已经穷尽
3. 对这些位置做了 Java / JS 的等位推理与验证
4. 只发现两个隐藏点：`Java sink.methodArg.xpath`、`JavaScript general.entranceFileXpath`
5. 再往同族字段扩展时，信息增益已经快速下降，绝大部分都报 `cannot find field by name: xpath`

因此，**继续遍历现有官方 roster，已经很难再带来新的 XPath 语法信息**。

后续更值得投入的方向是：

- 用真实扫描任务验证 `sink.methodArg.xpath` 的运行时语义
- 验证 JavaScript `general.entranceFileXpath` 是否在运行时真生效
- 进入 loadclass / PMD AST API，研究官方 roster 之外的复杂上下文逻辑

---

## 9. 本轮最终结论（一句话版）

**Alibaba DSL 的 XPath 不是“全局通用能力”，而是“极少数字段上的局部能力”**；官方生产规则里它几乎只落在 `general.entranceFileXpath`、`source.methodParam.xpath`、`general.methodRedirect.xpath` 三处，实验额外发现 `Java sink.methodArg.xpath` 与 `JavaScript general.entranceFileXpath` 两个隐藏语法点，但运行时语义仍需后续验证。
