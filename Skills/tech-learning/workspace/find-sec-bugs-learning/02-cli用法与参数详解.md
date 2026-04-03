# Find Security Bugs CLI 用法与参数详解

## 这份文档回答什么

这份文档讲的是:

1. 本地 `findsecbugs` 命令到底是什么
2. 它和 `SpotBugs` 是什么关系
3. 常见参数怎么写
4. 每类参数的实际作用是什么
5. 在真实扫描工程里，应该怎样组合这些参数

如果你只想先记一个最短结论:

`findsecbugs` 不是一套完全独立的扫描引擎，它本质上是“SpotBugs 命令行 + Find Security Bugs 插件 + 只看 SECURITY 类问题的过滤器”。`

## 本地入口确认

你要求以本地 PATH 中的二进制为入口。我已经确认当前 PATH 可直接调用:

```bash
findsecbugs -textui -version
```

本地实测返回版本:

`4.9.8`

这里显示的是底层 `SpotBugs` 版本。Find Security Bugs 插件本身是附着在 SpotBugs 上运行的。

## 这个命令背后到底做了什么

在源码仓库 `cli/findsecbugs.sh` 中，命令行脚本的关键逻辑是:

1. 找到最新的 `findsecbugs-plugin-*.jar`
2. 组装所有 jar 到 classpath
3. 启动 `edu.umd.cs.findbugs.LaunchAppropriateUI`
4. 自动带上 `-pluginList`
5. 自动带上 `-include include.xml`

`include.xml` 只保留 `SECURITY` 类问题，所以这个 CLI 默认关注安全问题，而不是 SpotBugs 的全部通用代码质量问题。

换句话说，`findsecbugs` 干的是这件事:

1. 用 SpotBugs 扫描字节码
2. 加载 Find Security Bugs 的安全规则插件
3. 把输出过滤到安全类告警

## 先建立一个使用心智模型

把命令分成三层最容易理解:

### 第一层: 启动层

这些参数控制 Java 进程怎么启动。

1. `-jvmArgs`
2. `-maxHeap`
3. `-javahome`

### 第二层: SpotBugs CLI 层

这些参数和子命令由 SpotBugs 本体提供。

1. `analyze`
2. `help`
3. `list`
4. `filter`
5. `errors`
6. `version`

### 第三层: Find Security Bugs 扩展层

这些不是独立“命令参数”，而是通过 JVM 系统属性注入给插件的行为开关，例如:

1. `findsecbugs.taint.customconfigfile`
2. `findsecbugs.taint.taintedsystemvariables`
3. `findsecbugs.injection.customconfigfile.SqlInjectionDetector`

这类开关通常通过 `-jvmArgs '-Dxxx=yyy'` 传入。

## 本机实际能看到的顶层帮助

我实测:

```bash
findsecbugs -textui -help
```

可以看到 SpotBugs 顶层帮助，包含:

1. `fb analyze`
2. `fb errors`
3. `fb filter`
4. `fb gui`
5. `fb help`
6. `fb list`
7. `fb set`
8. `fb version`
9. `fb history`
10. `fb merge`
11. `fb union`
12. `fb addMessages`
13. `fb dis`

以及通用选项:

1. `-jvmArgs args`
2. `-maxHeap size`
3. `-javahome <dir>`

需要注意:

`findsecbugs` 这个包装脚本走的是 `LaunchAppropriateUI` 路径，所以某些 `help analyze` 风格的帮助在本机上表现并不稳定。写自动化时，优先使用已经验证过的实际调用方式，不要过度依赖它的子帮助输出。

## 最常用的启动参数

### `-textui`

作用:

强制使用文本界面模式，而不是 GUI。

什么时候用:

1. 终端里手动跑
2. CI/CD
3. 批量扫描
4. SSH 远程环境

不加会怎样:

在某些环境下，SpotBugs 可能尝试走图形界面分支，不适合服务器。

### `-jvmArgs`

作用:

把参数直接传给 Java 虚拟机。

最常见的用途:

1. 打开 FindSecBugs 的自定义开关
2. 调整编码或系统属性
3. 传入自定义规则配置

例子:

```bash
findsecbugs -textui -jvmArgs '-Dfindsecbugs.taint.taintedsystemvariables=true' ...
```

### `-maxHeap`

作用:

设置 SpotBugs 进程最大堆内存，单位 MB。

为什么重要:

大型 Java 单体、胖 jar、多模块项目扫描时，默认内存往往不够。

经验建议:

1. 小项目先用默认值
2. 中型项目可以尝试 `-maxHeap 2048`
3. 大型项目经常需要 `-maxHeap 4096` 甚至更高

### `-javahome`

作用:

指定 JRE/JDK 路径。

什么时候有用:

1. 机器上装了多套 Java
2. 系统默认 Java 太老或不兼容
3. CI 节点环境混乱

## 最常用的实际扫描写法

### 扫描 class 目录

```bash
findsecbugs -textui -maxHeap 2048 target/classes
```

适合:

Maven 或 Gradle 已经编译完成的项目。

### 扫描 jar 包

```bash
findsecbugs -textui -maxHeap 2048 build/libs/app.jar
```

适合:

扫描交付物或第三方组件。

### 扫描多个输入

```bash
findsecbugs -textui target/classes other-module/target/classes libs/app.jar
```

适合:

多模块合并检查。

## 输出和结果处理

FindSecBugs CLI 本质继承自 SpotBugs CLI，所以结果处理能力主要来自 SpotBugs。

在工程里，最常见的是三类用途:

1. 终端直接看文本输出
2. 输出为 XML 供平台继续处理
3. 后续再用 `list`、`filter` 等命令做整理

即使你暂时不用高级格式，先记住一个原则:

`FindSecBugs 更擅长扫“编译后的 Java 字节码”，不是直接扫 .java 源码文本。`

所以你通常要先有:

1. `target/classes`
2. `build/classes`
3. `jar/war/ear`

## FindSecBugs 专有的常用系统属性

下面这些能力，是从仓库源码里能直接确认的。

### `findsecbugs.taint.customconfigfile`

作用:

加载自定义 taint 配置文件。

它解决的问题:

默认规则不认识你的内部框架、公司 SDK 或自定义封装 API。

典型场景:

1. 自定义 Web 输入封装
2. 自定义模板输出函数
3. 自定义 SQL 执行层

用法示意:

```bash
findsecbugs -textui \
  -jvmArgs '-Dfindsecbugs.taint.customconfigfile=/path/to/custom-taint.txt' \
  target/classes
```

### `findsecbugs.taint.taintedsystemvariables`

作用:

把系统变量也视为污染源。

适合:

扫描那些会从环境变量、系统属性拼接命令、URL、文件路径的程序。

### `findsecbugs.taint.taintedmainargument`

作用:

控制 `main(String[] args)` 的命令行参数是否视为 tainted。

默认理解:

CLI 程序的入参通常是不可信的，所以这项很合理。

### `findsecbugs.taint.reportpotentialxsswrongcontext`

作用:

允许报告一些“可能是上下文不匹配的 XSS 风险”。

适合:

你更关注“宁可多看一点，也别漏掉危险点”的审计场景。

### `findsecbugs.injection.customconfigfile.<DetectorSimpleName>`

作用:

给某个具体注入类检测器追加自定义 sink 文件。

最经典的是:

`findsecbugs.injection.customconfigfile.SqlInjectionDetector`

Linux/macOS 示例格式大意:

`文件路径|漏洞类型:文件路径|漏洞类型`

Windows 则因为路径分隔符不同，分隔方式会有差异。源码注释里已经给了例子。

## 初学者最容易踩的 8 个坑

### 1. 扫源码目录而不是字节码目录

错误心态:

“我把 `src/main/java` 扔进去就能扫。”

更准确的理解:

FindSecBugs 主要分析编译后的类文件。

### 2. 依赖类不全

如果 classpath 缺失太多，检测器可能因为父类、接口、框架类型解析不完整而降低效果。

### 3. 以为它只靠正则

不是。很多规则基于字节码和数据流分析，不是 grep。

### 4. 以为 `PreparedStatement` 一定完全安全

项目里可能有字符串先拼再传给 `prepareStatement` 的情况，规则仍可能报。

### 5. 堆内存太小

大型项目很容易 OOM 或性能糟糕。

### 6. 不区分 SpotBugs 参数与 FindSecBugs 系统属性

记忆技巧:

1. SpotBugs 参数写在命令行外层
2. FindSecBugs 扩展开关大多写成 `-D...`

### 7. 误把“没报”理解成“绝对安全”

静态分析永远不是数学证明。它只能提升发现概率，不能代替安全设计和人工审计。

### 8. 直接在生产流水线里把所有告警都当阻断项

正确做法通常是先分级、基线化、白名单化，再逐步提高门槛。

## 推荐的命令模板

### 模板 1: 本地快速扫描

```bash
findsecbugs -textui -maxHeap 2048 target/classes
```

### 模板 2: 增强 taint 扫描

```bash
findsecbugs -textui \
  -maxHeap 4096 \
  -jvmArgs '-Dfindsecbugs.taint.taintedsystemvariables=true' \
  target/classes
```

### 模板 3: 加企业自定义规则

```bash
findsecbugs -textui \
  -maxHeap 4096 \
  -jvmArgs '-Dfindsecbugs.taint.customconfigfile=/opt/rules/custom-taint.txt' \
  -jvmArgs '-Dfindsecbugs.injection.customconfigfile.SqlInjectionDetector=/opt/rules/sql-sinks.txt|SQL_INJECTION_JDBC' \
  target/classes
```

## 一句话理解 CLI 工作方式

你可以把 `findsecbugs` 看成一个“专门扫描 Java 安全问题的 SpotBugs 启动器”:

1. `SpotBugs` 负责跑分析引擎
2. `Find Security Bugs` 负责提供安全规则
3. `include.xml` 负责把焦点收敛到安全类问题

## 参考与核验入口

本地:

1. `/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/cli/findsecbugs.sh`
2. `/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/cli/include.xml`
3. `/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/FindSecBugsGlobalConfig.java`
4. `/home/nyn/Desktop/dev_tools/findsecbugs`

官方:

1. https://github.com/find-sec-bugs/find-sec-bugs
2. https://github.com/find-sec-bugs/find-sec-bugs/tree/master/cli
3. https://spotbugs.readthedocs.io/
4. https://spotbugs.github.io/
