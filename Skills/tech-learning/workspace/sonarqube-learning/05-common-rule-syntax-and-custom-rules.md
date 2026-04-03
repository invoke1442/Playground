# SonarQube 常用规则语法：从“看 AST”到“自己写一条 Java 规则”

## 先说结论

在 SonarJava 里，最常见、最值得新手先学的规则写法是：

- `@Rule` 标识规则身份
- 继承 `IssuableSubscriptionVisitor`
- 声明 `nodesToVisit()` 指定关注哪些语法节点
- 在 `visitNode()` 里检查条件
- 命中后 `reportIssue()`

如果你只想先学会“自己写一条能工作的规则”，这条路线最短。

但成熟规则仓库里还会见到：

- API 调用匹配类规则
- 基于方法匹配器 `MethodMatchers` 的规则
- 带符号 / 类型分析的规则
- 安全规则
- XPath 模板规则

---

## 第一部分：一条 Sonar Java 规则最小长相

### 1. `@Rule`

作用：给规则一个 key。

它相当于规则身份证。

例如概念上你会看到类似：

```java
@Rule(key = "MyRule")
```

这个 key 会被规则仓库、UI、测试和问题结果引用。

### 2. 规则类

最常见做法是继承：

- `IssuableSubscriptionVisitor`

为什么叫这个名字？

可以拆成三层理解：

- `Visitor`：访问 AST
- `Subscription`：只订阅你关心的节点类型
- `Issuable`：可以上报 issue

它很适合入门，因为你不用自己控制整棵树怎么遍历，框架已经帮你做了。

### 3. `nodesToVisit()`

作用：声明你想关注哪些节点。

例如你只关心方法声明，就返回 `METHOD`；只关心方法调用，就返回 `METHOD_INVOCATION`。

这一步很重要，因为它直接决定：

- 规则性能
- 规则逻辑复杂度
- 规则误报范围

经验法则：**只订阅必要节点，不要贪多**。

### 4. `visitNode()`

作用：真正写判断逻辑。

这里通常会做：

- 把通用 `Tree` 强转成具体节点类型
- 读取节点内容
- 看名字、参数、返回类型、调用目标、常量值等
- 符合条件就报问题

### 5. `reportIssue()`

作用：把问题交给 SonarQube。

`IssuableSubscriptionVisitor` 提供了多个重载版本，可以：

- 报某一行
- 报某个节点
- 报一个范围
- 带 secondary locations
- 带 remediation cost

这说明 SonarQube 规则不只是“红线标一下”，还可以表达更丰富的上下文。

---

## 第二部分：官方示例规则怎么教你入门

在 `sonar-java/docs/CUSTOM_RULES_101.md` 和 `docs/java-custom-rules-example` 里，官方给了非常适合初学者的例子。

其中 `MyCustomSubscriptionRule.java` 是关键示例。

它展示了这样一套思路：

1. 订阅方法节点
2. 拿到 `MethodTree`
3. 通过 `MethodSymbol` 和类型 API 读取返回类型、参数类型
4. 如果满足规则条件，就 `reportIssue()`

这个示例的重要意义不是“具体规则是什么”，而是它告诉你：

- SonarJava 规则不是只看字符串
- 你可以拿到语义信息
- 规则可以基于方法签名而不是表面文本判断

---

## 第三部分：常见规则写法 1，基于 AST 节点订阅

这是最基础也最常见的一类。

### 适合什么场景

- 某语法结构本身就可疑
- 某节点出现方式不符合规范
- 只靠局部 AST 就能判断

### 常见订阅节点

- `METHOD`
- `METHOD_INVOCATION`
- `CLASS`
- `VARIABLE`
- `IF_STATEMENT`
- `TRY_STATEMENT`
- `STRING_LITERAL`
- `NEW_CLASS`

### 思维模板

可以把它抽象成：

```text
当我看到某类节点时：
  1. 先确认它是不是我关心的形态
  2. 再确认上下文是否危险
  3. 最后在最准确的位置报 issue
```

### 这类规则的优点

- 好写
- 好测
- 性能通常不错
- 适合入门和内部规范类规则

### 缺点

- 对跨方法、跨文件、跨层传播问题能力有限

---

## 第四部分：常见规则写法 2，基于 API 匹配

例如 `BasicAuthCheck` 这类规则，典型思路是：

1. 先定义“哪些 API 是危险关注点”
2. 再判断它们的参数长什么样
3. 命中时报告问题

这类规则经常用到：

- `MethodMatchers`
- 方法名匹配
- 所属类型匹配
- 参数类型匹配
- 常量字符串判断

### 为什么这类规则很常见

因为现实世界很多安全问题，本质上就是：

- 某个 API 被不安全地调用了
- 某个框架入口用了错误参数
- 某个认证、加密、网络调用方式不推荐

### 这类规则适合什么

- 发现危险 API 调用
- 发现废弃安全方案
- 发现硬编码策略
- 发现框架误用

---

## 第五部分：常见规则写法 3，结合符号和类型信息

这类规则比单纯 AST 更进一步。

在官方示例里，`MethodSymbol`、返回类型和参数类型分析已经体现了这一点。

你可以用它回答这类问题：

- 这个方法返回的是不是某个敏感类型
- 这个参数是不是指定类的实例
- 这个调用到底是不是重载版本 A 而不是 B
- 这个类是不是实现了某接口

### 为什么这很重要

只看源码文本时，下面两行可能看起来一样：

```java
foo(bar)
foo(bar)
```

但实际可能：

- 属于不同类
- 调用不同重载
- 参数类型不同
- 安全意义完全不同

所以类型和符号信息会显著提高规则精度。

---

## 第六部分：常见规则写法 4，安全规则

安全规则往往不是“看一个点”，而是“看一条危险链”。

例如：

- 输入来源是否可控
- 数据有没有被拼接
- 最终是否流入 SQL / 文件系统 / 命令执行 / 认证 API
- 中间有没有被安全处理

你在 `HardCodedCredentialsShouldNotBeUsedCheck.java` 里可以看到一种很典型的安全风格：

- 订阅危险节点，例如方法调用、对象创建
- 加载一批安全相关元数据
- 对参数表达式做专门判断
- 发现硬编码秘密后报 issue

这类规则往往比普通风格更依赖：

- 框架知识
- 调用目标识别
- 常量求值
- 安全语义

---

## 第七部分：`IssuableSubscriptionVisitor` 具体给了你什么能力

从源码可以看出，它最核心的价值是：

- 提供 analysis context
- 提供 `addIssue()` / `addIssueOnFile()` / `reportIssue()`
- 明确告诉你：它自己不负责驱动 AST 遍历，遍历由框架调度

这点非常重要。

也就是说，写规则的人主要关心：

- 我订阅哪些节点
- 我在这些节点上怎么判断
- 我在哪里报问题

而不是关心“整棵树怎么深搜、何时进栈、何时出栈”。

这降低了自定义规则的心智负担。

---

## 第八部分：一条规则除了代码，还需要什么

很多新手写完规则类，发现 SonarQube 里看不到。原因通常是少了外围配套。

至少还需要：

### 1. 规则元数据

由 `RuleMetadataLoader` 读取。

### 2. 规则仓库定义

例如 `MyJavaRulesDefinition`。

### 3. 规则注册器

例如 `MyJavaFileCheckRegistrar`。

### 4. 规则列表

例如 `RulesList`。

### 5. 插件打包和安装

最后要变成 jar 丢到：

`<sonarqubeHome>/extensions/plugins`

然后重启 SonarQube。

官方文档“Adding coding rules”写得很明确，这是一条完整六步流程。

---

## 第九部分：自定义规则开发的最短实践路径

### 第一步：先照官方样例跑通一条最简单规则

不要一上来就写复杂安全规则。

先写一个简单规则，例如：

- 禁止某方法名
- 禁止某类硬编码字符串
- 检查某注解使用方式

### 第二步：给它写测试

官方教程很强调这一点。推荐的规则开发方式是接近 TDD 的。

通常会有三类文件：

- 规则实现类
- 测试类
- 测试样例源码

### 第三步：在本地插件中注册

确认：

- 规则 key 对得上
- 仓库 key 对得上
- 元数据路径正确

### 第四步：装到本地 SonarQube 测试

把插件 jar 放进：

`<sonarqubeHome>/extensions/plugins`

然后重启。

### 第五步：在 UI 中确认规则已出现

看：

- Rules 页面
- Quality Profile 中是否可激活
- 扫描后是否产出 issue

---

## 第十部分：常见规则语法速查表

| 语法 / 组件 | 作用 | 适合场景 |
| --- | --- | --- |
| `@Rule(key = ...)` | 声明规则身份 | 所有规则 |
| `IssuableSubscriptionVisitor` | 最常见基础规则父类 | 入门、自定义规则 |
| `nodesToVisit()` | 指定关注节点类型 | 控制范围和性能 |
| `visitNode()` | 规则判断主逻辑 | 所有订阅式规则 |
| `reportIssue()` | 上报问题 | 所有会出 issue 的规则 |
| `MethodMatchers` | 匹配方法调用模式 | API 误用、安全规则 |
| `MethodSymbol` / 类型 API | 读取语义信息 | 提高精度 |
| XPath 自定义规则 | 快速结构匹配 | 简单规则 |

---

## 第十一部分：初学者最常犯的错误

### 错误 1：订阅节点太多

结果：

- 规则变慢
- 逻辑变乱
- 误报增加

### 错误 2：只看字符串，不看类型和符号

结果：

- 重载方法判断错
- 框架调用判断错
- 误报多

### 错误 3：报问题的位置不精准

用户体验会很差。最好报在“最能代表问题根源”的节点上。

### 错误 4：写完规则，不写测试

规则仓库最怕的不是“规则没写出来”，而是“写出来但到处崩”。

### 错误 5：没有区分生产代码规则和测试代码规则

有些规则只适用于主代码，不适合测试代码。

---

## 第十二部分：怎么把这套东西讲给非科班同学

你可以这样解释：

> SonarJava 规则像一个个巡检员。每个巡检员会提前说“我只检查哪几种语法结构”，比如只看方法调用。框架把对应节点送到它面前，它再按自己的规则判断有没有问题，发现了就把位置和说明上报给 SonarQube 页面。

---

## 记忆卡片

- 入门写法：`@Rule` + `IssuableSubscriptionVisitor`。
- 先用 `nodesToVisit()` 缩小目标，再在 `visitNode()` 判断。
- `reportIssue()` 决定问题怎么落到 UI。
- 简单规则看 AST，复杂规则看类型、符号、API 和数据流。
- 自定义规则要配套仓库定义、注册器、元数据和测试。

## 本文使用的本地参考

- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/CUSTOM_RULES_101.md`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/java-custom-rules-example/src/main/java/org/sonar/samples/java/checks/MyCustomSubscriptionRule.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/java-custom-rules-example/src/main/java/org/sonar/samples/java/MyJavaRulesDefinition.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/docs/java-custom-rules-example/src/main/java/org/sonar/samples/java/MyJavaFileCheckRegistrar.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/java-frontend/src/main/java/org/sonar/plugins/java/api/IssuableSubscriptionVisitor.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/java-checks/src/main/java/org/sonar/java/checks/BasicAuthCheck.java`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonar-java/java-checks-aws/src/main/java/org/sonar/java/checks/security/HardCodedCredentialsShouldNotBeUsedCheck.java`

## 官方文档

- Adding coding rules：<https://docs.sonarsource.com/sonarqube-server/extension-guide/adding-coding-rules>
- Java docs：<https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/java>
