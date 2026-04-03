# Pysa CLI 用法详解

> **工具版本**: pyre-check 0.9.25 · fb-sapp 0.5.9  
> **官方文档**: https://pyre-check.org/docs/pysa-quickstart/  
> **适用读者**: 零基础安全工程师、开发者，无需编译器或静态分析背景知识

---

## 一、Pysa 是什么？为什么要用命令行？

### 1.1 一句话定义

Pysa（Python Static Analyzer）是 Meta（Facebook）开源的 **Python 污点分析工具**。它的核心功能是：自动追踪数据从 **"用户可控输入"** 流向 **"危险操作"** 的路径，帮你在代码还没上线时发现安全漏洞。

打个比喻：如果你的 Python 项目是一栋大楼，Pysa 就像一个安检系统——它检查"有毒物质"（用户输入）是否能从大门（input 函数）流到关键设施（数据库查询、系统命令执行等），中间有没有经过"消毒站"（sanitizer）。

### 1.2 Pysa 和 Pyre 的关系

Pysa 不是一个独立的程序，而是 **Pyre 类型检查器** 的一个子命令。安装 `pyre-check` 包后，你得到的主程序叫 `pyre`，而运行 Pysa 的方式是：

```bash
pyre analyze
```

也就是说，`pyre` 是"瑞士军刀"，`analyze` 是军刀上那把专门做安全分析的刀片。其他刀片包括 `check`（类型检查）、`infer`（类型推导）等。

### 1.3 为什么是命令行？

Pysa 没有图形界面。所有操作都通过终端命令完成。这看起来"原始"，但好处很明显：
- **可自动化**：可以嵌入 CI/CD 流水线，每次代码提交自动扫描
- **可脚本化**：扫描参数可以写在脚本里，团队共享
- **可复现**：同样的命令在任何机器上跑出同样的结果

---

## 二、安装与环境准备

### 2.1 安装 Pysa

```bash
# 创建虚拟环境（推荐）
python3 -m venv .venv
source .venv/bin/activate

# 安装 pyre-check（包含 Pysa）
pip install pyre-check

# 安装 SAPP（结果查看工具，可选但推荐）
pip install fb-sapp
```

安装完成后验证：
```bash
pyre --version
# 输出类似：Client version: 0.9.25
```

### 2.2 初始化项目

Pysa 需要一个配置文件 `.pyre_configuration` 才能知道要分析哪些代码。有两种初始化方式：

**方式 A：通用初始化**
```bash
pyre init
```
这会创建一个基础的 `.pyre_configuration` 文件。

**方式 B：Pysa 专用初始化**
```bash
pyre init-pysa
```
除了配置文件，还会自动下载 Pysa 需要的污点模型文件（后面会详细讲）。如果你只想跳过环境设置：
```bash
pyre init-pysa --skip-environment-setup
```

### 2.3 .pyre_configuration 文件详解

这是一个 JSON 文件，核心字段如下：

```json
{
  "source_directories": ["."],
  "taint_models_path": "stubs/taint",
  "search_path": ["/path/to/additional/stubs"]
}
```

| 字段 | 含义 | 示例 |
|------|------|------|
| `source_directories` | 要分析的源代码目录 | `["."]` 表示当前目录 |
| `taint_models_path` | 污点模型所在目录 | `"stubs/taint"` |
| `search_path` | 额外的模块搜索路径 | 第三方库的 stub 位置 |
| `exclude` | 排除的路径正则 | `[".*test.*", "setup.py"]` |
| `typeshed` | typeshed 路径（通常自动检测） | 默认使用内置 typeshed |

---

## 三、核心命令：pyre analyze

### 3.1 基本用法

```bash
cd /your/project
pyre analyze
```

这是最简单的运行方式。Pysa 会：
1. 读取 `.pyre_configuration`
2. 加载污点模型（`.pysa` 文件和 `taint.config`）
3. 构建类型环境
4. 执行污点分析
5. 输出发现的问题（JSON 格式）

### 3.2 典型输出

```json
[
  {
    "line": 9,
    "column": 22,
    "stop_line": 9,
    "stop_column": 32,
    "path": "source.py",
    "code": 5001,
    "name": "Possible shell injection",
    "description": "Possible shell injection [5001]: Data from [UserControlled] source(s) may reach [RemoteCodeExecution] sink(s)",
    "define": "source.convert"
  }
]
```

每个字段的含义：

| 字段 | 说明 |
|------|------|
| `line` / `column` | 问题所在的代码行列号 |
| `path` | 源文件路径 |
| `code` | 规则编号（如 5001 = shell 注入） |
| `name` | 规则名称 |
| `description` | 发现的问题描述 |
| `define` | 问题所在的函数（完全限定名） |

---

## 四、全部命令行参数详解

### 4.1 模型与配置相关

#### `--taint-models-path DIRECTORY`
**作用**：指定污点模型文件（`.pysa` 和 `taint.config`）的位置。

**什么时候用**：当你的模型文件不在 `.pyre_configuration` 指定的路径时，或者想临时使用另一套模型。

```bash
pyre analyze --taint-models-path /path/to/custom/models
```

**实际场景**：你有一套"严格模式"模型和一套"宽松模式"模型，可以通过这个参数切换。

#### `--no-verify`
**作用**：跳过模型验证步骤，不检查 `.pysa` 文件中的函数签名是否与实际代码匹配。

**什么时候用**：
- 快速迭代时，模型可能还没完善
- 分析第三方库时，部分签名可能无法精确匹配
- 减少分析时间

```bash
pyre analyze --no-verify
```

**注意**：虽然跳过验证能更快运行，但可能导致某些模型无效而你不知道。建议正式运行时去掉此选项。

**实际测试**：在我们的实验中，不加 `--no-verify` 时 Pysa 会报告 model verification errors：
```
Model signature parameters for `pickle.loads` do not match implementation...
Reason: unexpected named parameter: `data`.
```
这说明模型文件中写的参数名和 Python 标准库实际签名不一致。加上 `--no-verify` 后，Pysa 会忽略这些不匹配，继续分析。

#### `--verify-dsl`
**作用**：验证 DSL 模型查询（ModelQuery）的语法正确性。

```bash
pyre analyze --verify-dsl
```

#### `--verify-taint-config-only`
**作用**：只验证 `taint.config` 文件的格式是否正确，不执行实际分析。

```bash
pyre analyze --verify-taint-config-only
```

**什么时候用**：修改了 `taint.config` 后，想快速确认格式没写错。这比跑完整分析快得多（通常只需不到 1 秒）。

### 4.2 结果输出相关

#### `--save-results-to PATH`
**作用**：将分析结果保存到指定目录，而不仅仅打印到标准输出。

```bash
pyre analyze --no-verify --save-results-to ./pysa_results
```

**保存的文件**：

| 文件名 | 内容 |
|--------|------|
| `taint-output.json` | 所有污点分析结果（JSONL 格式，非标准 JSON） |
| `taint-metadata.json` | 分析元数据 |
| `call-graph.json` | 调用图 |
| `higher-order-call-graph.json` | 高阶调用图 |
| `dependency-graph.json` | 依赖图 |
| `override-graph.json` | 方法覆盖图 |
| `functions.json` | 所有函数列表 |
| `modules.json` | 所有模块列表 |
| `errors.json` | 分析错误 |
| `decorator-counts.json` | 装饰器统计 |

**重要**：`taint-output.json` 是 **JSONL 格式**（每行一个 JSON 对象），不是标准 JSON 数组。读取时需要逐行解析：

```python
import json
with open("pysa_results/taint-output.json") as f:
    for line in f:
        obj = json.loads(line.strip())
        if obj.get("kind") == "issue":
            print(obj["data"]["message"])
```

#### `--output-format [json|sharded-json]`
**作用**：控制输出格式。

- `json`：单个文件（默认）
- `sharded-json`：分片输出，大型项目时更高效

```bash
pyre analyze --save-results-to ./results --output-format sharded-json
```

#### `--dump-call-graph TEXT`
**作用**：将调用图导出到指定文件。

```bash
pyre analyze --no-verify --dump-call-graph ./call-graph.json
```

调用图记录了"函数 A 调用了函数 B"的关系。输出格式为 JSONL，每行包含一个函数的调用信息：

```json
{
  "kind": "higher_order_call_graph",
  "data": {
    "filename": "source.py",
    "callable": "source.sql_injection",
    "calls": {
      "19:17-19:38": {
        "call": {
          "calls": [{"target": "input", "index": 0}]
        }
      },
      "23:4-23:25": {
        "call": {
          "calls": [{"target": "sqlite3.Cursor.execute", "index": 0}]
        }
      }
    }
  }
}
```

**什么时候用**：想理解 Pysa 是如何追踪数据流的，或者调试为什么某个路径没被检测到。

#### `--dump-model-query-results TEXT`
**作用**：将 ModelQuery DSL 查询匹配到的模型导出到文件。

```bash
pyre analyze --no-verify --dump-model-query-results ./mq-results.json
```

**什么时候用**：你写了 ModelQuery（自动生成模型的 DSL），想检查它到底匹配了哪些函数。

### 4.3 规则过滤相关

#### `--rule INTEGER`
**作用**：只追踪指定规则编号的数据流。可以多次使用以指定多条规则。

```bash
# 只检测 shell 注入（5001）和 SQL 注入（5005）
pyre analyze --no-verify --rule 5001 --rule 5005
```

**什么时候用**：
- 大项目全量分析太慢，先集中检测最重要的漏洞类型
- 新增了一条自定义规则，只想验证这条规则是否生效

**实际测试**：当我们只指定 `--rule 5005`（SQL 注入）时，输出 `Found 0 issues`，因为我们的模型文件中 `sqlite3.Cursor.execute` 的签名不匹配（`self` 参数问题）。这验证了模型精确性的重要性。

#### `--source TEXT`
**作用**：只追踪指定 source（污染源）类型的数据流。

```bash
pyre analyze --no-verify --source UserControlled
```

#### `--sink TEXT`
**作用**：只追踪指定 sink（汇聚点）类型的数据流。

```bash
pyre analyze --no-verify --sink RemoteCodeExecution
```

#### `--transform TEXT`
**作用**：只追踪涉及指定 transform（转换）的数据流。

```bash
pyre analyze --no-verify --transform FileOperation
```

### 4.4 性能调优相关

#### `--maximum-trace-length INTEGER`
**作用**：限制污点追踪路径的最大长度（即从 source 到 sink 中间经过的函数调用层数）。

```bash
pyre analyze --no-verify --maximum-trace-length 10
```

**影响**：
- 值越小：分析越快，但可能漏报那些经过多层函数调用的深层漏洞
- 值越大：覆盖更全面，但分析时间和内存消耗增加
- 不设置：无限制（默认行为）

**实际场景**：在有 10 万行代码的项目中，设置为 20 通常是一个合理的平衡。

#### `--maximum-tito-depth INTEGER`
**作用**：限制"污点传入传出"（Taint-In-Taint-Out, TITO）的推断深度。

TITO 是指：一个函数接收了被污染的参数，返回的结果也被认为是污染的。例如：

```python
def add_prefix(data):          # data 被污染
    return "prefix_" + data    # 返回值也被污染（TITO）
```

```bash
pyre analyze --no-verify --maximum-tito-depth 5
```

#### `--maximum-overrides-to-analyze INTEGER`
**作用**：限制在一个调用点考虑的方法重写（override）数量。

**什么时候用**：面向对象代码中，一个基类方法可能有几十甚至上百个子类重写。分析所有重写的代价很高。

```bash
pyre analyze --no-verify --maximum-overrides-to-analyze 50
```

#### `--maximum-model-source-tree-width INTEGER`
**作用**：限制模型中 source 树的宽度。

#### `--maximum-model-sink-tree-width INTEGER`
**作用**：限制模型中 sink 树的宽度。

#### `--maximum-model-tito-tree-width INTEGER`
**作用**：限制模型中 TITO 树的宽度。

#### `--maximum-tree-depth-after-widening INTEGER`
**作用**：在循环中限制 source/sink/TITO 树的深度。

#### `--maximum-return-access-path-width INTEGER`
**作用**：限制返回值访问路径树的宽度。

#### `--maximum-return-access-path-depth-after-widening INTEGER`
**作用**：循环中限制返回值访问路径树的深度。

#### `--maximum-tito-collapse-depth INTEGER`
**作用**：限制 TITO 应用后污点树的折叠深度。

#### `--maximum-tito-positions INTEGER`
**作用**：限制 TITO 位置的数量。

**树宽度和深度参数的直觉理解**：

Pysa 内部用树形结构表示数据的污点状态。比如一个字典 `{"a": {"b": user_input}}` 中，污点存在于 `["a"]["b"]` 这条路径上。如果代码中有非常深或非常宽的数据结构操作，分析可能会爆炸式增长。这些参数就是"安全阀"，防止分析失控。

对于大多数项目，**默认值就够用**。只有在遇到性能问题时才需要调整。

### 4.5 缓存相关

#### `--use-cache`
**作用**：使用 `.pyre/pysa.cache` 缓存中间结果，加速后续运行。

```bash
pyre analyze --no-verify --use-cache
```

首次运行会创建缓存（稍微慢一点），后续运行会读取缓存（明显加速）。

**缓存内容**：
- 类型环境
- 类层次图
- 类区间图
- 调用图
- 全局变量映射

**什么时候用**：在开发过程中频繁运行 Pysa 时。每次修改代码后，只有改动部分需要重新分析。

#### `--build-cache-only`
**作用**：只构建缓存，不执行分析。

```bash
pyre analyze --build-cache-only
```

**什么时候用**：在 CI 流水线中，可以先在一步构建缓存，然后在多个并行步骤中使用缓存运行不同规则。

### 4.6 高级分析选项

#### `--find-missing-flows [obscure|type]`
**作用**：查找通过"不透明模型"（obscure models）的数据流。

- `obscure`：找到所有经过未建模函数的流
- `type`：基于类型信息查找

```bash
pyre analyze --no-verify --find-missing-flows obscure
```

**什么是不透明模型？** 当 Pysa 遇到没有 `.pysa` 文件描述、也不在源代码中的函数（通常是 C 扩展），它不知道数据是否会被传递（TITO）。默认情况下 Pysa 会保守地假设数据可能传递。这个选项帮你找到那些依赖这种"保守假设"的路径。

#### `--limit-entrypoints`
**作用**：只分析在入口点模型调用图内的函数。

```bash
pyre analyze --no-verify --limit-entrypoints
```

**什么时候用**：大型项目中的很多代码可能是死代码或测试代码。如果你定义了 `@Entrypoint` 模型，使用这个选项可以大幅减少分析范围。

#### `--infer-self-tito / --no-infer-self-tito`
**作用**：是否自动推断所有方法中参数到 `self` 的污点传播。

```bash
pyre analyze --no-verify --infer-self-tito
```

**直觉理解**：`obj.set_name(user_input)` 之后，`obj` 是否应该被认为也被污染了？打开此选项，Pysa 会自动推断这种传播。

#### `--infer-argument-tito / --no-infer-argument-tito`
**作用**：是否自动推断参数到其他参数的污点传播。

#### `--check-invariants`
**作用**：执行额外的分析不变量断言，用于调试 Pysa 自身。

#### `--compact-ocaml-heap`
**作用**：在分析过程中压缩 OCaml 堆内存，节省内存。

**什么时候用**：分析超大型项目时内存不够用。

#### `--compute-coverage`
**作用**：计算文件、种类（kind）和规则的覆盖率。

#### `--higher-order-call-graph-max-iterations INTEGER`
**作用**：限制构建高阶调用图时的不动点迭代次数。

#### `--maximum-target-depth INTEGER`
**作用**：限制高阶调用图构建中参数化目标的深度。

#### `--maximum-parameterized-targets-at-call-site INTEGER`
**作用**：限制每个调用点创建的参数化目标数量。

### 4.7 通用 Pyre 选项

这些选项适用于所有 `pyre` 子命令，包括 `analyze`：

#### `-n, --noninteractive`
**作用**：启用详细的非交互式日志。

```bash
pyre -n analyze --no-verify
```

**什么时候用**：需要详细的运行日志来排查问题时。日志会包含时间戳和更详细的进度信息。

#### `--output [text|json|sarif]`
**作用**：控制输出格式。

- `text`：人类可读的文本格式
- `json`：JSON 格式（默认，推荐用于自动化处理）
- `sarif`：SARIF 格式（Static Analysis Results Interchange Format，可导入 GitHub Security 等平台）

```bash
pyre --output sarif analyze --no-verify > results.sarif
```

#### `--sequential / --no-sequential`
**作用**：单线程运行 Pyre。

```bash
pyre --sequential analyze --no-verify
```

**什么时候用**：调试时，单线程的输出更易理解。正常使用不推荐。

#### `--number-of-workers INTEGER`
**作用**：指定并行工作线程数。

```bash
pyre --number-of-workers 8 analyze --no-verify
```

默认值根据 CPU 核心数自动计算。

#### `--log-level [CRITICAL|ERROR|WARNING|INFO|DEBUG]`
**作用**：设置日志级别。

```bash
pyre --log-level DEBUG analyze --no-verify
```

#### `--dot-pyre-directory TEXT`
**作用**：设置 Pyre 的日志和缓存目录。

```bash
pyre --dot-pyre-directory /tmp/pyre-logs analyze --no-verify
```

默认是项目根目录下的 `.pyre/` 目录。

#### `--source-directory TEXT`
**作用**：指定源代码目录（可多次使用）。

```bash
pyre --source-directory src --source-directory lib analyze --no-verify
```

#### `--search-path TEXT`
**作用**：添加额外的模块搜索路径。

```bash
pyre --search-path /path/to/stubs analyze --no-verify
```

---

## 五、SAPP：结果后处理工具

### 5.1 SAPP 是什么？

SAPP（Static Analysis Post Processor）是配合 Pysa 使用的结果处理工具。Pysa 的原始输出是大量 JSON 数据，SAPP 把这些数据导入数据库，提供交互式查询和 Web 界面。

### 5.2 核心命令

#### 导入结果

```bash
sapp analyze ./pysa_results
```

这会将 `--save-results-to` 产生的结果文件导入 SQLite 数据库（默认 `sapp.db`）。

输出示例：
```
Parsed 5 issues (5 new), 2 preconditions with 2 keys, and 4 postconditions with 4 keys
Saving 5 issues, 13 trace frames, 17 trace frame leaf assocs
Created run: 1
```

#### 启动 Web 界面

```bash
sapp server
```

打开浏览器访问 `http://localhost:13337`，可以：
- 按规则编号筛选问题
- 查看完整的数据流路径
- 标记误报
- 追踪修复进度

#### 交互式探索

```bash
sapp explore
```

进入 IPython 式的交互界面，可以用 Python 代码查询问题。

#### 导出为 lint 格式

```bash
sapp lint
```

以 lint 友好的格式输出结果，方便集成到代码审查工具。

### 5.3 SAPP 常用选项

```bash
sapp --database-name custom.db analyze ./results    # 指定数据库文件名
sapp --tool pysa analyze ./results                    # 指定工具类型
sapp -v DEBUG analyze ./results                       # 详细日志
```

---

## 六、其他相关命令

### 6.1 pyre validate-models

验证模型文件是否正确，不执行分析。

```bash
pyre validate-models
```

### 6.2 pyre init-pysa

初始化 Pysa 运行环境，下载内置模型。

```bash
pyre init-pysa
pyre init-pysa --skip-environment-setup  # 跳过环境设置
```

### 6.3 pyre query

查询运行中的 Pyre 服务器，可以获取类型信息等。

```bash
pyre start    # 先启动服务器
pyre query "type('source.py', 9, 22)"
```

---

## 七、实战：一个完整的命令行工作流

以下演示从零开始使用 Pysa 扫描一个有漏洞的 Python 项目：

### 步骤 1：创建项目结构

```
my_project/
├── .pyre_configuration
├── stubs/
│   └── taint/
│       └── core_privacy_security/
│           ├── taint.config
│           └── models.pysa
└── app.py
```

### 步骤 2：编写配置文件

`.pyre_configuration`：
```json
{
  "source_directories": ["."],
  "taint_models_path": "stubs/taint"
}
```

### 步骤 3：编写污点模型

`taint.config`：
```json
{
  "sources": [
    {"name": "UserControlled", "comment": "用户输入"}
  ],
  "sinks": [
    {"name": "RemoteCodeExecution", "comment": "代码执行"}
  ],
  "features": [],
  "rules": [
    {
      "name": "Shell 注入",
      "code": 5001,
      "sources": ["UserControlled"],
      "sinks": ["RemoteCodeExecution"],
      "message_format": "[{$sources}] 流向 [{$sinks}]"
    }
  ]
}
```

`models.pysa`：
```python
def input(__prompt) -> TaintSource[UserControlled]: ...
def os.system(command: TaintSink[RemoteCodeExecution]): ...
```

### 步骤 4：运行分析

```bash
# 第一次运行，验证配置
pyre analyze --verify-taint-config-only

# 正式分析
pyre analyze --no-verify --save-results-to ./results

# 只检查特定规则
pyre analyze --no-verify --rule 5001

# 使用缓存加速
pyre analyze --no-verify --use-cache

# 导出调用图（调试用）
pyre analyze --no-verify --dump-call-graph ./callgraph.json
```

### 步骤 5：查看结果

```bash
# 直接查看 JSON 输出
pyre analyze --no-verify 2>/dev/null

# 用 SAPP 导入并分析
sapp analyze ./results
sapp server    # 启动 Web 界面
```

---

## 八、常见问题与解决方案

### Q1：运行时报 "No binary specified, looking for pyre.bin in PATH"
这是正常的信息级日志，不是错误。Pysa 在自动寻找二进制文件。

### Q2：Model verification errors
```
Model signature parameters for `pickle.loads` do not match implementation
```
**解决方案**：修正 `.pysa` 文件中的函数签名，或者加 `--no-verify` 跳过检查。

### Q3：分析时内存不足
**解决方案**：
- 使用 `--compact-ocaml-heap` 压缩内存
- 调低 `--maximum-overrides-to-analyze`
- 使用 `--limit-entrypoints` 收窄分析范围
- 增加机器内存

### Q4：分析太慢
**解决方案**：
- 使用 `--use-cache` 启用缓存
- 使用 `--rule` 只分析重要规则
- 降低 `--maximum-trace-length` 和 `--maximum-tito-depth`
- 增加 `--number-of-workers`

### Q5：输出中没有发现任何问题
**可能原因**：
1. 模型文件没有正确配置（source、sink、rule 缺失）
2. 模型函数签名与实际不匹配（去掉 `--no-verify` 检查）
3. 数据流路径太长（尝试增大 `--maximum-trace-length`）
4. `taint_models_path` 路径错误

---

## 九、参数速查表

| 参数 | 类别 | 简要作用 |
|------|------|----------|
| `--taint-models-path` | 配置 | 指定模型目录 |
| `--no-verify` | 配置 | 跳过模型验证 |
| `--verify-dsl` | 配置 | 验证 DSL 查询 |
| `--verify-taint-config-only` | 配置 | 只验证配置 |
| `--save-results-to` | 输出 | 保存结果到目录 |
| `--output-format` | 输出 | json 或 sharded-json |
| `--dump-call-graph` | 输出 | 导出调用图 |
| `--dump-model-query-results` | 输出 | 导出模型查询结果 |
| `--rule` | 过滤 | 只追踪指定规则 |
| `--source` | 过滤 | 只追踪指定 source |
| `--sink` | 过滤 | 只追踪指定 sink |
| `--transform` | 过滤 | 只追踪指定 transform |
| `--maximum-trace-length` | 性能 | 限制追踪路径长度 |
| `--maximum-tito-depth` | 性能 | 限制 TITO 深度 |
| `--maximum-overrides-to-analyze` | 性能 | 限制方法重写数量 |
| `--use-cache` | 缓存 | 启用缓存 |
| `--build-cache-only` | 缓存 | 只构建缓存 |
| `--find-missing-flows` | 高级 | 查找不透明模型流 |
| `--limit-entrypoints` | 高级 | 限制分析入口 |
| `--infer-self-tito` | 高级 | 推断 self 传播 |
| `--infer-argument-tito` | 高级 | 推断参数间传播 |
| `--compact-ocaml-heap` | 高级 | 压缩堆内存 |
| `--compute-coverage` | 高级 | 计算覆盖率 |
| `-n` | 通用 | 详细日志 |
| `--output` | 通用 | text/json/sarif |
| `--number-of-workers` | 通用 | 并行线程数 |
| `--log-level` | 通用 | 日志级别 |

---

## 十、总结

Pysa 的 CLI 设计遵循"合理默认 + 精细控制"的原则：

- **入门只需 `pyre analyze`**：一条命令搞定
- **调参有 30+ 选项**：从规则过滤到性能调优，应有尽有
- **配合 SAPP**：把原始 JSON 变成可视化的交互界面

掌握这些命令行参数后，你可以：
1. 快速验证配置（`--verify-taint-config-only`）
2. 迭代开发模型（`--no-verify` + `--rule`）
3. 大项目性能调优（`--use-cache` + `--limit-entrypoints`）
4. CI/CD 集成（`--save-results-to` + `--output sarif`）
5. 调试分析过程（`--dump-call-graph` + `--dump-model-query-results`）
