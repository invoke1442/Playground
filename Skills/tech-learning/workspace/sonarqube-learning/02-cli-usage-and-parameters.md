# SonarQube CLI 用法：把“服务端启动命令”和“代码扫描命令”分开看

## 先给结论

很多人说“SonarQube 的 CLI”，其实混了两套命令：

1. **SonarQube 服务器二进制启动脚本**
   作用：启动、停止、查看服务状态。
   你本地入口：`/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303/bin/linux-x86-64/sonar.sh`

2. **SonarScanner CLI**
   作用：对某个项目执行静态分析，并把分析报告提交给 SonarQube 服务器。
   常见命令：`sonar-scanner`

直白地说：

- `sonar.sh` 管的是“平台是不是活着”
- `sonar-scanner` 管的是“代码是不是被扫了”

如果把这两者混在一起，你会一直搞不清楚自己到底是在“开服务器”还是“扫项目”。

---

## 第一部分：SonarQube 服务器脚本 `sonar.sh`

### 1. 它是什么

你本地安装好的二进制里，Linux 启动脚本是：

`/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303/bin/linux-x86-64/sonar.sh`

这个脚本最后只接受一组固定动作：

- `console`
- `start`
- `stop`
- `force-stop`
- `restart`
- `status`
- `dump`

脚本源码里直接有用法提示：

`Usage: sonar.sh { console | start | stop | force-stop | restart | status | dump }`

### 2. 每个动作到底干什么

#### `console`

前台启动。

特点：

- 当前终端会被占住
- 日志直接打印到控制台
- 最适合第一次安装、调试启动失败、看报错

你本地之前验证可用时，用的就是这种方式。

示例：

```bash
cd /home/nyn/Desktop/dev_tools
SONAR_JAVA_PATH=/home/nyn/Desktop/dev_tools/jdk-21/bin/java \
./sonarqube-26.2.0.119303/bin/linux-x86-64/sonar.sh console
```

#### `start`

后台启动。

特点：

- 用 `nohup` 在后台拉起 SonarQube
- 适合长期运行
- 标准输出会写到 `logs/nohup.log`

示例：

```bash
cd /home/nyn/Desktop/dev_tools
SONAR_JAVA_PATH=/home/nyn/Desktop/dev_tools/jdk-21/bin/java \
./sonarqube-26.2.0.119303/bin/linux-x86-64/sonar.sh start
```

#### `stop`

优雅停机。

特点：

- 先读 PID 文件
- 发送正常结束信号
- 等待进程退出
- 比强杀更安全

适用场景：

- 正常重启
- 升级前停机
- 维护前停机

#### `force-stop`

强制停机。

特点：

- 走 `sonar-shutdowner-*.jar`
- 用于普通 `stop` 卡住时
- 比直接乱用 `kill -9` 更符合官方设计

适用场景：

- 服务无响应
- 正常停机一直等不下来

#### `restart`

先停再起。

适合：

- 改配置后重启
- 插件更新后重启

#### `status`

检查是否运行。

成功时会输出类似：

- `SonarQube is running (pid)`

失败时会输出：

- `SonarQube is not running.`

#### `dump`

向 Java 进程发 `kill -3`，让 JVM 输出线程栈。

这个命令对初学者最陌生，但排查“卡死、假死、线程阻塞”很有用。

你可以把它理解成：

- 不是为普通使用准备的
- 是为故障诊断准备的

---

## 3. `sonar.sh` 的关键环境变量

### `SONAR_JAVA_PATH`

最重要。

作用：指定 SonarQube 启动时用哪个 Java 可执行文件。

如果不设，脚本会默认去 PATH 里找 `java`。

这在实战里非常关键，因为：

- SonarQube 对 Java 版本有要求
- 机器系统自带 Java 可能过旧
- 你可能想用项目专用 JDK 启动 SonarQube

你本地这次安装就是典型案例：

- 系统 `java` 是 17
- 实际启动测试使用了本地 JDK 21

### `PIDDIR`

作用：指定 PID 文件目录。

默认值是当前目录 `.`。

PID 文件用于记录进程号，供 `status`、`stop`、`restart` 使用。

如果 PID 文件丢了或脏了，就会出现“明明在跑却说没跑”“明明没跑却说已启动”这类问题。脚本内部也做了“清理 stale pid file”的处理。

---

## 4. 服务器 CLI 的实际最佳用法

### 初装调试

优先用：

```bash
sonar.sh console
```

因为你需要直接看日志。

### 稳定运行

优先用：

```bash
sonar.sh start
sonar.sh status
```

### 停机维护

优先用：

```bash
sonar.sh stop
```

### 卡死排查

按顺序：

1. `sonar.sh status`
2. `sonar.sh dump`
3. `sonar.sh stop`
4. `sonar.sh force-stop`

不要一上来就 `kill -9`。

---

## 第二部分：SonarScanner CLI `sonar-scanner`

## 1. 它是什么

官方文档给出的定义很直接：**当你的构建系统没有专用 scanner 时，就用 SonarScanner CLI**。

也就是：

- Maven 项目优先 `SonarScanner for Maven`
- Gradle 项目优先 `SonarScanner for Gradle`
- 其他普通项目、脚本项目、非标准构建项目，常用 `sonar-scanner`

## 2. 最常见的两种用法

### 用 `sonar-project.properties`

在项目根目录写配置文件：

```properties
sonar.projectKey=my:project
sonar.sources=src
sonar.host.url=http://127.0.0.1:9000
sonar.token=你的token
```

然后运行：

```bash
sonar-scanner
```

这是最适合初学者的方式。

### 直接命令行传参

```bash
sonar-scanner \
  -Dsonar.projectKey=my:project \
  -Dsonar.sources=src \
  -Dsonar.host.url=http://127.0.0.1:9000 \
  -Dsonar.token=你的token
```

优点：

- 临时试跑方便
- 适合 CI

缺点：

- 参数多了难维护
- 容易把 token 暴露在命令历史里

官方也明确建议：**不要把密码或 token 明文写进文件或命令行**，优先用环境变量或 CI secret。

---

## 3. 参数优先级

官方参数层级非常重要。

从低到高大致是：

1. SonarQube UI 里的全局 / 项目设置
2. 扫描器配置文件
3. 命令行参数 `-D...`

命令行参数优先级最高。

但有一个容易忽略的点：

- **只有在 UI 里设置的参数会被服务器持久保存**
- 你在命令行临时传的参数，只对这一次分析生效

这意味着：

你今天命令行里加了 `-Dsonar.exclusions=**/legacy/**`，明天不带这个参数再跑，排除规则就没了。

---

## 4. 最常用参数，按初学者视角解释

下面不是“全部参数百科”，而是你最常碰到、最值得先掌握的一批。

### 4.1 连接和认证类

#### `sonar.host.url`

作用：告诉 scanner 结果要发到哪台 SonarQube 服务器。

例子：

```properties
sonar.host.url=http://127.0.0.1:9000
```

也可以用环境变量：

```bash
export SONAR_HOST_URL=http://127.0.0.1:9000
```

如果不配对，你的扫描结果根本发不出去。

#### `sonar.token`

作用：认证。

等于“你有权把这个项目的扫描结果上传到服务器”。

也可以用环境变量：

```bash
export SONAR_TOKEN=xxxx
```

官方说明它替代旧的 `sonar.login`，后者已经 deprecated。

---

### 4.2 项目标识类

#### `sonar.projectKey`

作用：项目唯一 ID。

你可以把它想成 SonarQube 里的“身份证号”。

特点：

- 一个实例内必须唯一
- 常见写法：`team:service-name`

如果这个 key 变了，SonarQube 往往会把它当成另一个新项目。

#### `sonar.projectName`

作用：UI 上显示的人类可读名称。

它更像“昵称”。

#### `sonar.projectVersion`

作用：告诉 SonarQube 这次分析对应哪个版本。

常见用途：

- 发布版本对齐
- 观察某个版本前后的质量变化

---

### 4.3 分析范围类

#### `sonar.sources`

作用：哪些目录里的源码要参与分析。

例子：

```properties
sonar.sources=src/main/java,src/main/resources
```

#### `sonar.tests`

作用：哪些目录被视为测试代码。

为什么要分开？

因为 SonarQube 对“生产代码”和“测试代码”使用的指标、规则、覆盖率逻辑不完全一样。

#### `sonar.exclusions`

作用：排除某些文件或目录。

典型用途：

- 排除生成代码
- 排除第三方代码
- 排除历史遗留临时目录

#### `sonar.inclusions`

作用：只保留某些文件进入分析。

适合特殊场景，不如 `sonar.exclusions` 常用。

#### `sonar.projectBaseDir`

作用：改变分析根目录。

适合：

- CI 工作目录和实际源码目录不一致
- monorepo 子目录扫描

官方文档特别提醒：如果你用这个参数，那个目录里应该包含 `sonar-project.properties`，除非你在命令行里显式传了 `sonar.projectKey`。

---

### 4.4 Java 项目特别重要的参数

这部分是 Java 项目最容易踩坑的核心。

#### `sonar.java.binaries`

作用：告诉 Java 分析器编译后的 `.class` 文件在哪。

对多文件 Java 项目，这个参数几乎是“能不能正确分析”的分水岭。

官方文档非常明确：

- 多于一个 Java 文件时，需要 `.class`
- 如果没有，分析会失败或严重降级

例子：

```properties
sonar.java.binaries=target/classes
```

为什么它这么重要？

因为 Java 分析不只是看文本，还要看：

- 类型解析
- 方法绑定
- 继承关系
- 库调用
- 某些安全规则的数据流判断

没有字节码，分析器就像“只看病历，不看 CT 片”。能看一部分，但很多关键问题看不准。

#### `sonar.java.libraries`

作用：告诉分析器第三方依赖 jar 在哪。

例如 Spring、Guava、Apache Commons。

没有它，分析器会经常提示类不可访问，规则精度下降。

#### `sonar.java.test.binaries`

作用：测试代码编译产物位置。

#### `sonar.java.test.libraries`

作用：测试依赖 jar 位置，比如 JUnit。

#### `sonar.java.jdkHome`

作用：指定“项目本身”使用的 JDK 目录，而不是“scanner 运行时”使用的 JDK。

这个区别非常重要。

比如：

- scanner 本身用 Java 17 跑
- 你的项目实际是 Java 11 编译的

这时如果不设 `sonar.java.jdkHome`，有些关于 JDK API 的规则可能误报，因为分析器会按 Java 17 的类库语义理解代码。

---

### 4.5 日志与调试类

#### `sonar.log.level`

作用：控制日志级别。

常见值：

- `INFO`
- `DEBUG`
- `TRACE`

#### `sonar.verbose`

作用：打开更详细的扫描日志。

但官方提醒：它可能暴露敏感信息，尤其在环境变量里有秘密时要谨慎。

#### `SONAR_SCANNER_JAVA_OPTS`

作用：给 scanner JVM 调大内存。

典型场景：

- 项目大
- 规则多
- 出现 `OutOfMemoryError`

例子：

```bash
export SONAR_SCANNER_JAVA_OPTS="-Xmx512m"
```

官方文档说明：SonarScanner CLI 6.0 及以上推荐用这个变量；更老版本用 `SONAR_SCANNER_OPTS`。

---

### 4.6 流水线治理类

#### `sonar.qualitygate.wait`

作用：让扫描命令等待服务器处理完成，并拿到质量门禁结果。

如果设为 `true`：

- scanner 不会只“上传完就走”
- 它会等 CE 处理结果
- 质量门禁失败时可直接让 CI 失败

这在 DevSecOps 流水线里很常用。

#### `sonar.qualitygate.timeout`

作用：等待质量门禁结果的秒数。

默认 300 秒。

---

### 4.7 外部报告导入类

#### `sonar.externalIssuesReportPaths`

作用：导入通用格式外部问题报告。

#### `sonar.sarifReportPaths`

作用：导入 SARIF 报告。

这很适合把其他安全工具结果统一汇总到 SonarQube 页面里看。

---

## 5. 一套推荐的 Java 项目最小示例

### 方式 A：Maven / Gradle 项目

优先使用各自专用 scanner，不要先硬上 CLI。

原因：

- 字节码、依赖、源码目录自动推断更好
- Java 项目最容易因为 classpath 配错导致分析质量下降

### 方式 B：普通 Java 项目，用 SonarScanner CLI

```properties
sonar.projectKey=demo:java-app
sonar.projectName=demo-java-app
sonar.sources=src/main/java
sonar.tests=src/test/java
sonar.java.binaries=target/classes
sonar.java.test.binaries=target/test-classes
sonar.java.libraries=target/dependency/*.jar
sonar.java.test.libraries=target/dependency/*.jar
sonar.host.url=http://127.0.0.1:9000
```

运行前设置 token：

```bash
export SONAR_TOKEN=你的token
sonar-scanner
```

---

## 6. 你本地二进制入口与 CLI 的关系

你本地已经安装好的 SonarQube 二进制只是**服务端**。它本身不会替你去扫描某个业务工程。

完整链路是：

1. 启动 SonarQube 服务器：`sonar.sh start`
2. 登录 Web UI，创建 token、项目、质量配置
3. 在待扫描工程中运行 `sonar-scanner` 或 Maven/Gradle scanner
4. scanner 把结果传给服务器
5. 服务器 Compute Engine 处理后，Web UI 展示问题

所以初学者要记住：

- `sonar.sh` 不是扫描项目的命令
- `sonar-scanner` 也不是启动服务器的命令

---

## 7. 初学者最容易犯的错误

### 错误 1：SonarQube 启动了，就以为代码已经被扫了

不对。服务器只是“平台在线”。还要单独运行 scanner。

### 错误 2：Java 项目只配 `sonar.sources`，不配 `sonar.java.binaries`

这是最常见的大坑。

### 错误 3：把 token 明文写进 Git 仓库里的 `sonar-project.properties`

非常危险。应该用 CI secret 或环境变量。

### 错误 4：所有项目都强行用 `sonar-scanner`

Maven / Gradle 项目优先专用 scanner，更省事也更准。

### 错误 5：为了临时绕过问题，把 `sonar.exclusions` 配得过大

会造成“系统看起来很绿，但其实没扫到关键代码”。

---

## 8. 记忆卡片

- `sonar.sh` 管服务器生命周期。
- `sonar-scanner` 管代码分析提交。
- Java 项目最关键参数：`sonar.java.binaries`。
- 安全认证优先 `SONAR_TOKEN`，不要明文硬编码。
- CI 想卡质量门禁，用 `sonar.qualitygate.wait=true`。

## 参考来源

### 本地源码 / 二进制

- `/home/nyn/Desktop/dev_tools/sonarqube-26.2.0.119303/bin/linux-x86-64/sonar.sh`
- `/home/nyn/Desktop/Projects/SAST/sast_tools/sonarqube/README.md`

### 官方文档

- SonarScanner CLI：<https://docs.sonarsource.com/sonarqube-server/2025.3/analyzing-source-code/scanners/sonarscanner>
- Analysis parameters：<https://docs.sonarsource.com/sonarqube-server/2025.3/analyzing-source-code/analysis-parameters>
- Java analysis：<https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/languages/java>
