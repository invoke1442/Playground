# SonarQube 静态分析原理与工作流：从“为什么能发现问题”到“结果怎么进 UI”

## 先讲人话：静态分析到底是什么

静态分析（Static Analysis）就是：

- **不运行你的业务程序**
- 直接分析源码、字节码、依赖关系、配置和结构
- 尝试提前发现 bug、坏味道、安全问题和可维护性风险

它像“看图纸找施工隐患”，而不是“等房子塌了再看监控录像”。

所以 SonarQube 不是动态扫描器，不是 DAST，也不是渗透测试工具。它更擅长在开发阶段回答这类问题：

- 这段代码是不是明显写错了
- 这里会不会空指针
- 这里是不是 SQL 拼接
- 这里是不是把密钥写死了
- 这个 if/else 是否过于复杂
- 测试覆盖率是不是不足

---

## 第一部分：SonarQube 整体工作流

官方“Server components”文档把服务端拆成四个关键进程角色：

1. `Sonar`：管理其他 SonarQube 进程可用性
2. `Web`：提供 UI 和 Web API
3. `Elasticsearch`：维护数据库的索引副本
4. `Compute Engine`：处理扫描报告并写入数据库

可以把它画成一个流水线：

```text
开发者 / CI
   |
   | 运行 scanner
   v
本地源码 + 编译产物 + 参数
   |
   | 生成分析报告并上传
   v
SonarQube Web/API 接收报告
   |
   | 放入任务队列
   v
Compute Engine 处理
   |
   | 写入数据库并更新索引
   v
Web UI / API 展示问题、指标、质量门禁
```

### 每一步在干什么

#### 第 1 步：准备待分析代码

scanner 不会自动替你“知道项目是什么”。它需要：

- 项目源码
- 项目标识
- 分析范围
- 对 Java 来说通常还需要字节码和依赖

#### 第 2 步：scanner 在本地做初步分析

注意：scanner 不是单纯“打包上传源码”。

对于很多语言，scanner 或语言分析器会在本地完成一部分分析工作，例如：

- 读取源码
- 建立文件列表
- 解析项目配置
- 调用对应语言 analyzer
- 生成问题和指标报告

#### 第 3 步：上传报告到服务器

scanner 把分析结果发给 SonarQube 服务器。

这也是为什么 `sonar.host.url`、`sonar.token` 很关键。

#### 第 4 步：Compute Engine 异步处理

上传完成，不代表 UI 立刻出结果。

服务器还要：

- 消费任务队列
- 合并分析结果
- 计算质量门禁
- 持久化到数据库
- 更新索引

所以 CI 里如果你想“等到结果出来再决定过不过”，要配 `sonar.qualitygate.wait=true`。

#### 第 5 步：Web UI 展示

最后你在页面上看到：

- Bugs
- Vulnerabilities
- Code Smells
- Security Hotspots
- Coverage
- Duplications
- Maintainability / Reliability / Security 信息

---

## 第二部分：Java 静态分析在本地到底看什么

只会看源码文本吗？不是。

从官方 Java 文档和 `sonar-java` 实现看，Java 分析至少会综合这些信息：

1. 源代码文本
2. AST（抽象语法树）
3. 符号信息
4. 类型信息
5. 编译后的 `.class` 字节码
6. 第三方依赖 jar
7. 项目使用的 JDK 版本
8. 某些规则需要的框架知识

### 为什么 Java 分析比纯文本 grep 强很多

举个最简单的例子：

```java
query("select * from users where name = '" + name + "'");
```

纯文本工具也许能看出字符串拼接。

但 Java analyzer 还能进一步判断：

- 这个 `query()` 到底是不是数据库 API
- `name` 是不是外部输入
- 这段代码在什么方法、什么类、什么框架上下文里
- 这个调用点对应哪个重载方法

这就是为什么字节码、依赖和 JDK 信息很重要。

---

## 第三部分：Java Analyzer 的源码级工作流

下面用你本地 `sonar-java` 源码串起来看。

### 1. 插件入口把能力注册给 SonarQube

入口：`JavaPlugin.java`

这个类会把下面这些东西注册给平台：

- 规则定义
- 质量配置
- JavaSensor
- 外部报告支持
- 类路径处理
- 分析结束钩子等

也就是说，平台先知道“这里有个 Java 插件”。

### 2. `JavaSensor` 真正开始分析

入口：`JavaSensor.execute()`

它会做几件关键事：

- 把主代码规则和测试规则注册进 `SonarComponents`
- 读取 Java 版本配置
- 记录遥测信息
- 创建 `JavaFrontend`
- 让 frontend 去扫描源码和测试代码

直白点讲：`JavaSensor` 像项目经理，真正把规则、源码和分析器撮合到一起。

### 3. `JavaFrontend` 负责更底层的扫描

虽然你这次主要看到了 `JavaSensor`，但从调用关系能看出：

- `JavaSensor` 不自己亲自遍历每棵语法树
- 它把工作交给 `JavaFrontend`

你可以把 `JavaFrontend` 理解为“Java 文件逐个处理的总调度台”。

### 4. `VisitorsBridge` 把规则访问者真正跑起来

`java-frontend/.../VisitorsBridge.java` 很关键。

它负责：

- 接收所有 JavaCheck
- 过滤 Java 版本不兼容的规则
- 过滤依赖版本不兼容的规则
- 把多个 `IssuableSubscriptionVisitor` 合并进 runner
- 在每个文件上驱动 scanner 执行
- 支持增量分析 / unchanged files 跳过策略

这说明 SonarJava 不是“每个规则都各自从头遍历源码一次”，而是做了访问者层的统一调度和性能优化。

### 5. AST 和符号表在什么时候出现

在 `VisitorsBridge.visitFile()` 里，可以看到它会：

- 处理编译单元（CompilationUnit）
- 创建符号表
- 构造 `JavaFileScannerContext`
- 再依次运行各个 scanner

所以大致顺序是：

1. 解析文件
2. 建树
3. 补符号和语义
4. 创建上下文
5. 执行规则

---

## 第四部分：规则为什么有的能发现“表面问题”，有的能发现“漏洞”

规则能力不是一个层级。

### 层级 1：语法级规则

只看结构，不太依赖语义。

例如：

- `if` 太深
- 命名不规范
- 某语法写法应该替换

这类规则实现相对简单，精度高，成本低。

### 层级 2：语义级规则

要知道：

- 变量类型
- 方法绑定
- 继承结构
- 常量值

例如：

- 调用了哪个重载方法
- 某对象是不是 AutoCloseable
- 某返回值是否为空风险

### 层级 3：安全模式规则

要识别一些已知危险模式。

例如：

- Basic Auth
- 硬编码凭据
- 不安全 TLS
- 弱加密算法

这类规则经常结合 API 匹配、常量分析、框架知识。

### 层级 4：数据流 / 污点传播类规则

这类最接近“漏洞扫描”的核心能力。

它关心：

- 污染源（source）在哪里
- 数据经过哪些传播路径
- 最终流到了哪个危险汇点（sink）
- 中间有没有被安全处理（sanitizer）

比如 SQL 注入：

- 外部输入是 source
- 字符串拼接一路传播
- JDBC / Spring SQL 执行点是 sink
- 如果没有参数化处理，就报风险

不是所有 Sonar 规则都做到完整污点分析，但很多安全规则都在往这个方向靠。

---

## 第五部分：为什么 Java 项目常要求字节码

官方 Java 文档明确写着：

- 多于一个 Java 文件时，通常需要编译后的 `.class` 文件
- 如果缺失，分析可能失败或降级

原因很简单：

源码只告诉分析器“长什么样”，但字节码和 classpath 会帮助它知道：

- 这个类真实能不能访问到
- 这个方法最后绑定到哪里
- 泛型擦除后的行为怎么理解
- 依赖库里的类型和 API 语义是什么

所以对 Java 来说，**先编译，再扫描** 通常比“拿源码直接扫”更靠谱。

---

## 第六部分：SonarQube 不是怎么做的

理解边界同样重要。

### 它不是运行时漏洞利用工具

它不会真的发 HTTP payload 看你系统会不会被注入。

### 它不是 SCA 依赖漏洞库扫描的全部替代品

它会覆盖一部分安全问题，但不是所有 CVE 依赖治理都靠它。

### 它不是人工代码审计的完全替代品

复杂业务授权逻辑、链路级风险、架构设计漏洞，仍然需要人工判断。

### 它不是“报了就一定能被利用”

有些规则是确定性 bug，有些是风险提示，有些是 Security Hotspot，需要人工二次确认。

---

## 第七部分：把整个工作流讲给非科班同学听

你可以这样讲：

> SonarQube 像一个不会运行程序的“代码质检厂”。扫描器先把代码和必要材料送进去，Java 分析器像质检专家，会把代码拆成语法树、看类型、看依赖、看危险 API 用法，然后把发现的问题交给服务器。服务器再把结果整理、排队、入库，最后在网页上显示出来。

这句话基本就把主线讲清楚了。

---

## 第八部分：实战工作流最简版本

### 开发者本地或 CI 中

1. 代码 checkout
2. 编译项目
3. 准备测试覆盖率报告
4. 运行 scanner
5. 上传报告

### SonarQube 服务器中

1. Web 接收任务
2. 任务排队
3. Compute Engine 处理
4. DB 持久化
5. ES 建索引
6. UI 展示

### 开发者回看结果

1. 看问题列表
2. 看新增代码问题
3. 看质量门禁
4. 修复后再提交，再扫描

这就是典型的“持续质量反馈闭环”。

---

## 初学者常见误区

### 误区 1：静态分析就是正则表达式搜代码

不对。成熟 analyzer 会建 AST、类型信息，甚至做数据流分析。

### 误区 2：扫描结束 = 服务器已经算完

不对。很多时候只是上传完，后面还要 CE 异步处理。

### 误区 3：没有编译产物也没关系

对 Java 来说，经常有关系，而且关系很大。

### 误区 4：所有安全问题都能自动精准判断

不对。不同规则层级差异很大，有些是提示，有些是高置信度结论。

### 误区 5：SonarQube 能替代所有安全工具

不对。它很重要，但只是应用安全工程链条的一部分。

---

## 记忆卡片

- 静态分析 = 不运行程序，直接看代码与结构。
- Java 分析不仅看源码，还看字节码、依赖和 JDK。
- scanner 上传结果，Compute Engine 异步处理。
- `JavaSensor` 是 Java 分析执行入口之一。
- `VisitorsBridge` 负责规则访问者调度和部分性能优化。
- 安全规则常涉及 source、sink、sanitizer 思维。

## 本文使用的本地入口

- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonarqube/sonar-application/src/main/java/org/sonar/application/App.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/sonar-java-plugin/src/main/java/org/sonar/plugins/java/JavaSensor.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/java-frontend/src/main/java/org/sonar/java/model/VisitorsBridge.java`
- `/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303/logs/sonar.log`
- `/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303/logs/web.log`

## 官方文档

- Server components：<https://docs.sonarsource.com/sonarqube-server/server-installation/server-components-overview>
- Analysis parameters：<https://docs.sonarsource.com/sonarqube-server/2025.3/analyzing-source-code/analysis-parameters>
- Java language docs：<https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/java>
