# 规则仓库怎么理解：SonarQube 平台、Java 分析器、规则元数据、规则实现是怎样连起来的

## 先建立一张“地图”

围绕你现在手头的三个入口：

- SonarQube 服务器源码：`/home/nyn/Desktop/Projects/SAST/sast_tools/sonarqube`
- Java 规则仓库：`/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java`
- 本地可运行二进制：`/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303`

可以把整个体系理解成三层：

1. **平台层**：SonarQube Server
2. **语言分析器层**：如 `sonar-java`
3. **单条规则层**：如 SQL 注入、硬编码凭据、Basic Auth 风险等具体规则

如果你是初学者，最容易犯的错就是直接钻进某条规则代码，却不知道它是怎样被平台发现、注册、执行并显示到 UI 上的。

---

## 第一层：SonarQube 平台仓库在干什么

本地仓库：`/home/nyn/Desktop/Projects/SAST/sast_tools/sonarqube`

这个仓库不是“Java 规则仓库”，它更像平台地基，负责：

- 启动 Web / ES / Compute Engine
- 提供 UI 和 API
- 维护任务队列
- 管理插件
- 存储分析结果
- 显示规则、问题、指标、质量门禁

你可以重点记住几个目录：

### `sonar-application/`

负责应用级启动入口。

`sonar-application/src/main/java/org/sonar/application/App.java` 是很重要的入口文件。它做的事情可以粗略理解为：

- 读取配置
- 初始化日志和文件系统
- 创建调度器
- 拉起各个 SonarQube 进程
- 注册关闭钩子
- 持续等待直到服务终止

这说明 SonarQube 不是一个单 Java 进程小工具，而是一套多进程服务系统。

### `server/`

偏服务端逻辑，和 Web / API / 后台任务处理关系更近。

### `plugins/`

插件相关逻辑。

这非常重要，因为各种语言分析器都是以“插件”形式接入平台的。

### `sonar-scanner-engine/`

偏扫描引擎和分析期协议逻辑。

这部分负责“scanner 和服务器如何说话”的关键链路。

---

## 第二层：`sonar-java` 仓库在干什么

本地仓库：`/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java`

这个仓库不是 SonarQube 全平台，而是 **Java 语言分析器**。它的工作是：

- 解析 Java 源码
- 构建 AST
- 尝试建立符号和类型信息
- 利用字节码和依赖补齐语义
- 运行 Java 规则
- 产出 Java 问题、指标和部分安全检测结论

可以把它理解为“SonarQube 的 Java 大脑”。

### 你最应该认识的目录

#### `java-frontend/`

这是 Java 解析和访问者 API 的基础层。

里面提供：

- 语法树模型
- 访问者机制
- 文件扫描上下文
- 规则开发 API

如果你未来要自己写 Java 自定义规则，这层非常关键。

#### `java-checks/`

这里放了大量 Java 主规则实现。很多常见代码质量和安全规则都在这里。

#### `java-checks-aws/`

这里是偏 AWS 场景或某些安全专向规则。

#### `sonar-java-plugin/`

这是“把 Java 分析器作为 SonarQube 插件接进去”的关键模块。

它负责：

- 插件入口
- 规则仓库定义
- 默认质量配置
- 传感器（sensor）注册
- 把规则类交给分析流程

#### `check-list/`

这个目录很有意思。它会生成 `GeneratedCheckList` 这一类清单代码，把大量规则类组织成统一列表。

#### `docs/`

这里有官方团队给出的自定义规则教程和示例项目。对学习者非常友好。

#### `its/`

Integration Tests，集成测试。这里能看到 analyzer 团队如何验证规则在真实或半真实工程上是否稳定。

这对你理解“规则仓库怎么做工程化”非常有价值。

---

## 第三层：规则仓库在 SonarQube 里到底是什么

“规则仓库”这个词，容易被误解成 Git 仓库。实际上在 SonarQube 语境里，它更像：

- 一组规则的逻辑集合
- 一个规则命名空间
- UI 中可以被展示和启用的规则目录

以 Java 为例，本地 `CheckListGenerator` 生成的 `GeneratedCheckList` 里有：

- `REPOSITORY_KEY = "java"`

这表示：

- Java 这批规则在 SonarQube 里的规则仓库 key 是 `java`

你可以把 `repository key` 想成“规则大类的内部编号”。

---

## 规则是怎样被注册进去的

这是理解规则仓库最关键的链路。

### 第一步：准备规则类清单

在 `check-list` 模块中，`CheckListGenerator` 会生成一个 `GeneratedCheckList` 类，里面集中提供：

- `getChecks()`
- `getJavaChecks()`
- `getJavaTestChecks()`
- `getJavaChecksNotWorkingForAutoScan()`

直白说，它像“规则总名单”。

### 第二步：定义规则仓库元数据

`sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaRulesDefinition.java`

这个类在做的事是：

- 创建一个规则仓库：key 是 `java`
- 仓库名设置为 `SonarAnalyzer`
- 通过 `RuleMetadataLoader` 读取规则元数据
- 把带有 `@Rule` 注解的规则类注册进仓库
- 标记模板规则
- 处理废弃规则 key
- 让自定义 registrar 也能往仓库里加规则

也就是说：

- **规则类本身不够**
- 还要有“把规则解释给 SonarQube 平台”的定义层

### 第三步：插件把规则和传感器装配起来

`sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaPlugin.java`

这个类是 Java 插件总入口。它会往 SonarQube 注册一堆扩展，其中包括：

- `JavaRulesDefinition`
- `JavaSensor`
- 默认质量配置相关类
- 类路径和外部报告支持类
- 过滤器和分析收尾类

你可以把它理解成插件的“总装车间”。

### 第四步：传感器在分析时执行规则

`sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaSensor.java`

它在构造时会把规则注册到 `SonarComponents`：

- 主代码规则
- 测试代码规则

接着在 `execute()` 里：

- 读取 Java 版本
- 准备测量器和上下文
- 创建 `JavaFrontend`
- 扫描源码和测试源码

也就是说，`JavaSensor` 是“把规则清单真正送上分析流水线”的执行入口。

---

## 规则元数据和规则代码为什么要分开

这也是初学者很容易忽略的一点。

一条 Sonar 规则，通常不只有“if 命中就报错”这么简单，它至少包含两部分：

### 1. 规则逻辑

就是 Java 类本身，例如：

- 访问 AST
- 匹配方法调用
- 分析常量或数据流
- 调用 `reportIssue()` 报告问题

### 2. 规则元数据

包括：

- 规则 key
- 名称
- 描述
- 严重级别
- 类型
- 修复建议
- 标签
- 默认配置
- 是否模板规则

为什么要分开？

因为规则逻辑是“机器执行层”，元数据是“平台展示层”。

没有元数据，UI 上就很难以友好方式展示这条规则。

---

## 规则实现有哪些常见风格

在 `sonar-java` 里，规则不只一种写法。

### 风格 1：`IssuableSubscriptionVisitor`

这是最常见的入门写法。

特点：

- 先声明要看哪些 AST 节点类型
- 再在 `visitNode()` 里判断
- 命中后 `reportIssue()`

适合：

- 语法结构清晰的规则
- 针对某类节点的规则
- 自定义规则入门

### 风格 2：`AbstractMethodDetection`

适合“盯某些 API 调用”的规则。

例如：

- 是否调用了危险方法
- 是否调用了不推荐认证方式
- 是否把常量口令传给某方法

`BasicAuthCheck` 就是很好的例子。

### 风格 3：更深的语义 / 安全规则

这类规则会使用：

- 符号信息
- 类型信息
- 常量求值
- 某些数据流或路径辅助机制

例如硬编码凭据、安全敏感 API 使用、框架相关漏洞判断等。

### 风格 4：XPath 自定义规则

官方文档还支持某些语言用 XPath 快速定义规则。这更像“快速筛选器”，适合简单结构匹配，不适合复杂语义分析。

---

## 默认质量配置和规则仓库是什么关系

规则仓库回答的是：

- “系统里有哪些规则？”

质量配置（Quality Profile）回答的是：

- “在这个项目里启用哪些规则？”

这两个概念经常被混淆。

以 Java 为例：

- `JavaRulesDefinition` 定义规则仓库
- `JavaSonarWayProfile` 管理默认质量配置

类比：

- 规则仓库像“药房全部药品目录”
- 质量配置像“这次门诊真正开给病人的处方单”

---

## `GeneratedCheckList` 为什么很重要

它不只是个工具类，而是工程化能力的体现。

它帮团队解决了几个现实问题：

1. 规则数量很多，不能手工到处维护名单。
2. 主代码规则和测试规则要分开。
3. autoscan 模式下，有些规则不适合启用，要单独列出来。
4. 注册规则、测试规则、统计规则数量都需要统一数据源。

这说明一个成熟规则仓库，不是“写几条 if 判断”就完了，而是需要：

- 规则组织
- 规则元数据
- 注册链路
- 测试体系
- 自动清单生成
- 运行模式兼容性控制

---

## 自定义规则仓库怎么长出来

在 `docs/java-custom-rules-example` 里，官方给了一个很清楚的样板工程。

其中两个关键类特别值得看：

### `MyJavaRulesDefinition`

负责创建你自己的规则仓库，例如：

- 仓库 key：`mycompany-java`
- 仓库名：`MyCompany Custom Repository`

它再用 `RuleMetadataLoader` 把你自己的规则类加载进去。

### `MyJavaFileCheckRegistrar`

负责把你的规则类列表注册给这个仓库。

也就是说，自定义规则不是“把一个规则类扔进去就完事”，而是至少要配套：

- 规则实现类
- 规则列表类
- 规则仓库定义类
- check registrar
- 插件打包与安装

---

## 如果你想“递归理解”规则仓库，建议按这个顺序读

### 第 1 层：平台怎么跑起来

读：

- `sonarqube/README.md`
- `sonar-application/.../App.java`

### 第 2 层：Java 插件怎么接进平台

读：

- `sonar-java-plugin/.../JavaPlugin.java`
- `sonar-java-plugin/.../JavaSensor.java`
- `sonar-java-plugin/.../JavaRulesDefinition.java`

### 第 3 层：规则名单怎么组织

读：

- `check-list/.../CheckListGenerator.java`
- 生成后的 `GeneratedCheckList`

### 第 4 层：单条规则怎么写

读：

- `BasicAuthCheck.java`
- `HardCodedCredentialsShouldNotBeUsedCheck.java`
- `MyCustomSubscriptionRule.java`

### 第 5 层：规则怎么测试

读：

- `docs/CUSTOM_RULES_101.md`
- `java-checks-test-sources/`
- `its/`

---

## 初学者最容易误会的 5 件事

### 误会 1：规则仓库 = Git 仓库

不对。SonarQube 里的“规则仓库”是平台内部概念。

### 误会 2：写一条规则 = 完成扩展

不对。还要有元数据、注册、打包、安装、测试。

### 误会 3：规则就是字符串搜索

不对。成熟规则往往结合 AST、符号、字节码和框架知识。

### 误会 4：质量配置和规则仓库是一回事

不对。一个是“全部可选规则”，一个是“当前启用规则集合”。

### 误会 5：平台越大，规则越难找

不一定。只要把“平台层”“分析器层”“单规则层”分开，反而更好理解。

---

## 记忆卡片

- `sonarqube` 是平台，`sonar-java` 是 Java 大脑。
- `JavaRulesDefinition` 定义规则仓库。
- `JavaPlugin` 装配插件扩展。
- `JavaSensor` 在分析时真正执行规则。
- `GeneratedCheckList` 是规则总名单。
- 自定义规则至少要有：规则类 + 元数据 + registrar + 插件。

## 本文涉及的关键本地文件

- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonarqube/sonar-application/src/main/java/org/sonar/application/App.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaPlugin.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaSensor.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaRulesDefinition.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/check-list/src/main/java/org/sonar/java/CheckListGenerator.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/java-custom-rules-example/src/main/java/org/sonar/samples/java/MyJavaRulesDefinition.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/java-custom-rules-example/src/main/java/org/sonar/samples/java/MyJavaFileCheckRegistrar.java`

## 官方文档

- Adding coding rules：<https://docs.sonarsource.com/sonarqube-server/extension-guide/adding-coding-rules>
- Java language docs：<https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/java>
