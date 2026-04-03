# Pysa 静态分析原理与工作流

> **工具版本**: pyre-check 0.9.25  
> **官方文档**: https://pyre-check.org/docs/pysa-basics/ · https://pyre-check.org/docs/pysa-implementation-details/  
> **适用读者**: 零基础安全工程师、开发者，无需编译器或程序分析背景知识

---

## 一、为什么需要"静态"分析？

### 1.1 两种找漏洞的方法

想象你是一个安全检查员，要检查一栋大楼（你的 Python 项目）是否安全。你有两种方法：

**方法 A：动态测试（像消防演习）**
- 真的点一把火（发送恶意请求），看楼里会不会烧起来
- 优点：发现的问题一定是真实的
- 缺点：不可能覆盖所有房间（代码路径），而且可能真的把楼烧了（生产事故）

**方法 B：静态分析（像看建筑图纸）**
- 不点火，而是看图纸（源代码），检查消防通道（数据流路径）是否合理
- 优点：可以检查所有房间，不需要实际运行
- 缺点：可能会误判——图纸上看起来有问题但实际没事（误报）

Pysa 就是方法 B。它 **不运行你的代码**，而是读取源代码，分析数据可能的流向，判断是否存在安全风险。

### 1.2 Pysa 的分析类型：污点分析

静态分析有很多种（类型检查、数据流分析、控制流分析……），Pysa 专注于 **污点分析（Taint Analysis）**。

**核心思想**：
1. 某些数据是"脏的"（被污染的），比如用户输入
2. 某些操作是"敏感的"，比如执行系统命令
3. 如果"脏数据"能流到"敏感操作"，就是一个潜在的安全漏洞

用更学术的话说：**如果存在一条从 source（污染源）到 sink（汇聚点）的数据流路径，且中间没有经过 sanitizer（消毒器），则报告一个安全问题**。

---

## 二、污点分析的基本概念

### 2.1 Source（污染源）

Source 是"脏数据"的起点。在 Web 应用中，常见的 source 包括：

```python
# 标准输入
user_input = input("请输入：")          # ← UserControlled source

# HTTP 请求参数
name = request.GET["name"]              # ← UserControlled source

# Cookie
token = request.COOKIES["session"]      # ← Cookies source

# 命令行参数
args = parser.parse_args()              # ← CLIUserControlled source

# 网络响应（第三方 API）
response = requests.get("https://...")  # ← DataFromInternet source
```

### 2.2 Sink（汇聚点）

Sink 是"敏感操作"的位置。如果脏数据到达这里，就可能被利用：

```python
# 系统命令执行
os.system(user_input)                   # ← RemoteCodeExecution sink

# SQL 查询
cursor.execute(query)                   # ← SQL sink

# HTML 响应
return HttpResponse(content)            # ← XSS sink

# 文件操作
open(user_path, "r")                    # ← FileSystem_ReadWrite sink

# HTTP 请求（SSRF）
requests.get(user_url)                  # ← HTTPClientRequest_URI sink
```

### 2.3 Sanitizer（消毒器）

Sanitizer 是"清洗数据"的操作。数据经过 sanitizer 后被认为是安全的：

```python
# 类型转换：字符串变成数字，不可能包含恶意代码
safe_id = int(user_input)               # int() 是天然的 sanitizer

# 转义函数
safe_html = html.escape(user_input)     # 转义 HTML 特殊字符

# 长度检查
length = len(user_input)                # len() 返回数字
```

### 2.4 TITO（Taint-In-Taint-Out）

TITO 描述的是"污点传递"行为：一个函数接收了被污染的参数，返回的结果也应该被认为是被污染的。

```python
def add_prefix(data):           # data 是脏的
    return "Hello, " + data     # 返回值也是脏的 → TITO

result = add_prefix(user_input)  # result 仍然是脏的
os.system(result)                # 漏洞！
```

**如果没有 TITO**，Pysa 会认为 `add_prefix` 是一个"黑盒"，不知道返回值是否受参数影响。TITO 告诉 Pysa："是的，参数的污点会传递到返回值"。

---

## 三、Pysa 的工作流：从代码到报告

### 3.1 概览

Pysa 的工作流可以分为 7 个阶段：

```
┌──────────────┐
│ 1. 加载配置   │  读取 .pyre_configuration、taint.config
└──────┬───────┘
       ▼
┌──────────────┐
│ 2. 构建类型   │  Pyre 类型检查器构建类型环境
│    环境       │
└──────┬───────┘
       ▼
┌──────────────┐
│ 3. 解析模型   │  加载 .pysa 文件，将 source/sink/sanitizer 应用到函数
└──────┬───────┘
       ▼
┌──────────────┐
│ 4. 构建调用图  │  确定"谁调用了谁"
└──────┬───────┘
       ▼
┌──────────────┐
│ 5. 不动点迭代  │  反复分析函数，直到所有污点信息稳定
│   （核心！）   │
└──────┬───────┘
       ▼
┌──────────────┐
│ 6. 生成问题   │  匹配 source-sink 对，生成安全报告
└──────┬───────┘
       ▼
┌──────────────┐
│ 7. 输出结果   │  JSON / SARIF / SAPP 数据库
└──────────────┘
```

### 3.2 阶段 1：加载配置

Pysa 首先读取两类配置：

1. **`.pyre_configuration`**：告诉 Pysa 去哪里找代码和模型
2. **`taint.config`**：定义 sources、sinks、features、rules

这一步还会做基本的合法性验证——比如规则中引用的 source 名字必须在 `sources` 中定义过。

从实际运行日志可以看到：
```
ƛ  Initializing and verifying taint configuration...
ƛ  Initialized and verified taint configuration: 0.002s
```

### 3.3 阶段 2：构建类型环境

Pysa 构建在 Pyre 类型检查器之上。在做污点分析之前，它需要先理解代码的类型结构：

- 每个变量的类型是什么
- 每个函数的参数和返回值类型是什么
- 类之间的继承关系是什么（这决定了方法覆盖和虚调用）

```
ƛ  Building module tracker...
ƛ  Starting type checking...
ƛ  Found 917 modules
ƛ  Collecting all definitions...
ƛ  Found 20291 functions
ƛ  Checking 20291 functions...
```

**为什么要类型信息？** 因为污点分析需要知道"数据流经了哪些函数"，而函数调用的解析需要类型信息。例如：

```python
obj.process(data)  # obj 是什么类型？process 是哪个类的方法？
```

有了类型信息，Pysa 才能准确地找到 `process` 方法的定义，并追踪数据流。

### 3.4 阶段 3：解析模型

Pysa 加载所有 `.pysa` 文件，并检查：
1. 模型文件中的函数签名是否与实际代码匹配
2. 引用的 source/sink 名字是否在 `taint.config` 中定义

```
ƛ  Verifying model syntax...
ƛ  Finding taint models in `stubs/taint`.
ƛ  Verified model syntax: 0.000s
```

如果有不匹配，会报告 model verification error（除非加了 `--no-verify`）。

### 3.5 阶段 4：构建调用图

调用图（Call Graph）记录了"函数 A 在代码的第 X 行调用了函数 B"。

```python
def main():
    data = input("name: ")     # main → input (行 2)
    result = process(data)     # main → process (行 3)
    os.system(result)          # main → os.system (行 4)
```

调用图：
```
main → input (line 2)
main → process (line 3)
main → os.system (line 4)
```

**高阶调用图**：Pysa 还会构建"高阶调用图"，处理回调、装饰器等复杂情况：

```python
def apply(func, data):
    return func(data)          # func 是什么？需要根据调用处推断

result = apply(os.system, user_input)  # 高阶调用：func = os.system
```

```
ƛ  Computed higher order call graphs: 0.446s
ƛ  Computing dependencies from higher order call graphs...
ƛ  Computed dependencies from higher order call graphs: 0.023s
```

### 3.6 阶段 5：不动点迭代（核心算法）

这是 Pysa 最核心的部分。让我们慢慢来理解。

#### 3.6.1 什么是"不动点"？

想象你在给一栋大楼的每个房间贴标签——"这个房间可能有毒"或"安全"。

- 第一轮：你从入口开始，凡是能从有毒入口直接到达的房间，都贴"有毒"
- 第二轮：你再检查一遍，发现有些房间虽然不直接连接入口，但连接了第一轮标为"有毒"的房间，所以它们也应该标"有毒"
- 第三轮：继续……
- 直到某一轮，你发现没有新的标签需要贴了——**这就是不动点**

用程序分析的术语说：**不动点是一个状态，在这个状态下继续应用分析规则不会产生新的信息**。

#### 3.6.2 Pysa 的不动点迭代过程

从日志中可以清楚看到迭代过程：

```
ƛ  Analysis fixpoint started for 4197 overrides and 6 functions......
ƛ  Iteration #0. 3 callables [source.$toplevel, source.get_image, source.convert]
ƛ  Processed 3 of 3 callables
ƛ  Iteration #0, 3 callables, heap size 0.031GB took 0.05s
ƛ  Iteration #1. 2 callables [source.get_image, source.convert]
ƛ  Processed 2 of 2 callables
ƛ  Iteration #1, 2 callables, heap size 0.031GB took 0.05s
ƛ  Found 1 issues
ƛ  Analysis fixpoint complete: 0.418s
```

解读：
- **Iteration #0**：分析 3 个函数，为每个函数生成初始的"摘要"（summary）
- **Iteration #1**：发现有 2 个函数的摘要需要更新（因为它们依赖的函数在上一轮有了新信息）
- **完成**：没有更多函数需要更新，达到不动点

#### 3.6.3 函数摘要（Summary）

Pysa 不会把整个程序展开成一条直线来分析。那样对于有几万个函数的项目来说太慢了。相反，它为 **每个函数生成一个"摘要"**——一种压缩的描述，记录了：

**Source Summary（源摘要）**：这个函数的返回值是否包含某种 source。

```python
def get_user_name():
    return input("name: ")  # 返回值包含 UserControlled
```
Source summary: `返回值 = {UserControlled}`

**Sink Summary（汇摘要）**：这个函数的哪些参数会流入某种 sink。

```python
def run_command(cmd):
    os.system(cmd)  # 参数 cmd 流入 RemoteCodeExecution
```
Sink summary: `cmd → {RemoteCodeExecution}`

**TITO Summary（传入传出摘要）**：哪些参数的污点会传递到返回值。

```python
def add_prefix(data):
    return "hello_" + data  # data 的污点传递到返回值
```
TITO summary: `data → 返回值`

#### 3.6.4 摘要如何传播？

当 Pysa 分析一个调用了其他函数的函数时，它使用被调用函数的摘要，而不是重新分析被调用函数：

```python
def outer():
    name = get_user_name()   # 查看 get_user_name 的 source summary
                             # → name 被标记为 UserControlled
    run_command(name)        # 查看 run_command 的 sink summary
                             # → name 流入 RemoteCodeExecution
                             # → 发现：UserControlled → RemoteCodeExecution → 触发规则 5001！
```

这种基于摘要的方法叫 **过程间分析（Inter-procedural Analysis）**，它的关键优势是：
- 只需要分析每个函数的"接口"（参数和返回值），不需要内联所有代码
- 可以处理递归和相互调用的情况

#### 3.6.5 为什么需要多轮迭代？

考虑这种情况：

```python
def step1():
    return input("data: ")    # source

def step2(data):
    return "prefix_" + data   # TITO

def step3(data):
    os.system(data)            # sink

def main():
    d = step1()
    d2 = step2(d)
    step3(d2)
```

**第 0 轮**：
- 分析 step1 → 得到 source summary: 返回值 = {UserControlled}
- 分析 step2 → 得到 TITO summary: data → 返回值
- 分析 step3 → 得到 sink summary: data → {RemoteCodeExecution}
- 分析 main → 还没有足够信息把它们串起来

**第 1 轮**：
- 重新分析 main：
  - `step1()` 返回 UserControlled（查 step1 摘要）
  - `step2(d)` → d 的 UserControlled 传递到返回值（查 step2 摘要）
  - `step3(d2)` → d2 的 UserControlled 流入 RemoteCodeExecution（查 step3 摘要）
  - **发现问题！** UserControlled → RemoteCodeExecution

**第 2 轮**：
- 没有新变化 → 不动点达到 → 分析结束

### 3.7 阶段 6：生成问题

在不动点迭代完成后，Pysa 检查所有函数的 source summary 和 sink summary，寻找匹配规则的 source-sink 对：

```
对于每条规则 R（如 code=5001, sources=[UserControlled], sinks=[RemoteCodeExecution]）：
  对于每个函数 F：
    如果 F 的 source summary 包含 UserControlled
    且 F 的 sink summary 包含 RemoteCodeExecution
    且两者之间存在数据流路径
    且路径上没有 Sanitizer
    → 生成一个 issue
```

### 3.8 阶段 7：输出结果

最终结果是一个 JSON 列表，每个 issue 包含：
- 代码位置（文件、行号、列号）
- 规则信息（规则名、编号、描述）
- 数据流路径（从 source 到 sink 经过了哪些函数）

---

## 四、核心算法深入

### 4.1 正向分析 vs 反向分析

Pysa 同时进行两个方向的分析：

**正向分析（Forward Analysis）**：从 source 开始，追踪数据往哪里流。
```
input() → name → add_prefix(name) → result → os.system(result)
   ↑ source                                        ↑ sink
```

**反向分析（Backward Analysis）**：从 sink 开始，追踪数据从哪里来。
```
os.system(result) ← result ← add_prefix(name) ← name ← input()
   ↑ sink                                              ↑ source
```

**为什么两个方向都要？** 因为只做正向分析可能会追踪大量与 sink 无关的数据流（效率低）；只做反向分析可能会追踪大量与 source 无关的数据流。两个方向结合，可以精确找到 source-to-sink 的路径。

### 4.2 上下文敏感分析

考虑这个例子：

```python
def process(data):
    return data.upper()

# 调用处 1：安全
clean = process("hello")

# 调用处 2：危险
dirty = process(user_input)
```

如果 Pysa 把两次调用混在一起（上下文不敏感），就会认为 `process` 的返回值总是被污染的 → 导致误报。

Pysa 是 **上下文敏感** 的（部分），它会区分不同调用处的污点状态。具体策略是：
- 对于 TITO 函数：通过摘要来传递准确的污点信息
- 对于 source/sink 函数：直接标记

### 4.3 Widening（加宽）

在循环中，分析可能永远不收敛：

```python
x = user_input
for i in range(100):
    x = {"key": x}       # 每次循环，嵌套加深一层
    # 第 1 次：{"key": user_input}
    # 第 2 次：{"key": {"key": user_input}}
    # ...
```

如果 Pysa 精确追踪每一层，访问路径会无限增长。**Widening** 是一种"放弃精度换取收敛"的技术：当树的深度超过阈值时，Pysa 会把深层的路径"折叠"成一个统一的标记。

这就是 `--maximum-tree-depth-after-widening` 参数控制的行为。

### 4.4 Collapsing（折叠）

类似于 widening，但应用于树的宽度。当一个数据结构有太多字段时：

```python
data = {
    "a": user_input,
    "b": "safe",
    "c": "safe",
    "d": "safe",
    # ... 100 个字段
}
```

Pysa 可能会折叠成"整个 data 都被污染了"，而不是精确追踪每个字段。这会增加误报但保证分析能完成。

### 4.5 Obscure Models（不透明模型）

当 Pysa 遇到没有源代码、没有 `.pysa` 模型、且不在 typeshed 中的函数时（通常是 C 扩展模块），它不知道这个函数对数据做了什么。

**默认策略（保守）**：假设函数是 TITO 的——输入被污染，输出也被污染。

**`@SkipObscure` 注解**：告诉 Pysa "我知道这个函数是什么，不要当它是不透明的"。

```python
# 在 .pysa 文件中
@SkipObscure
def str.__add__(self: TaintInTaintOut, other: TaintInTaintOut): ...
```

没有 `@SkipObscure`，Pysa 可能会用自己的保守估计来处理 `str.__add__`。加上后，它会严格按照 `.pysa` 文件中的定义来处理。

---

## 五、方法重写与继承处理

### 5.1 问题

面向对象编程中，子类可以重写父类的方法：

```python
class Base:
    def process(self, data):
        pass

class SubA(Base):
    def process(self, data):
        os.system(data)        # 危险！

class SubB(Base):
    def process(self, data):
        print(len(data))       # 安全
```

当代码这样写时：
```python
def handler(obj: Base, data):
    obj.process(data)          # obj 可能是 SubA 或 SubB
```

Pysa 需要考虑 **所有可能的 process 实现**。

### 5.2 Override Graph

Pysa 构建了一个"方法重写图"（Override Graph），记录每个方法有多少个子类重写：

```
Base.process → [SubA.process, SubB.process]
```

在分析 `handler` 时，Pysa 会合并所有重写版本的摘要。如果任何一个版本有 sink，就认为调用处可能到达 sink。

### 5.3 性能影响

如果一个基类方法有 100 个子类重写，Pysa 需要合并 100 个摘要。这就是 `--maximum-overrides-to-analyze` 参数的用途——如果重写数量超过阈值，Pysa 会用保守估计代替精确分析。

---

## 六、Features（特征）的作用

### 6.1 Features 不影响分析结果

Features 不会导致 Pysa 多报或少报问题。它们只是给数据流路径打上标签，方便后续的人工审查和自动分类。

### 6.2 Feature 类型

**Via Feature**：手动在 `.pysa` 模型中标注的特征。
```python
def urllib.parse.quote_plus(string: TaintInTaintOut[Via[urlencode]]): ...
```
如果数据经过了 `quote_plus`，路径上会带有 `via-urlencode` 标签。

**ViaValueOf Feature**：记录某个参数的实际值。
```python
def subprocess.run(args: TaintSink[RemoteCodeExecution, ViaValueOf[shell]]): ...
```
如果 `shell=True`，路径上会带有 `via-shell:True`。

**ViaTypeOf Feature**：记录某个参数的类型。
```python
def subprocess.run(args: TaintSink[RemoteCodeExecution, ViaTypeOf[args]]): ...
```
如果 `args` 是字符串，带有 `via-type:str`；如果是列表，带有 `via-type:list`。

**Automatic Features**：Pysa 自动生成的。比如当数据经过字符串拼接时，自动添加 `string_concat_lhs` 或 `string_concat_rhs`。

### 6.3 实际用途

在 SAPP 中查看结果时，可以用 features 过滤：
- "只显示 `via-shell:True` 的 RCE"（高危）
- "排除有 `via-urlencode` 的 SSRF"（可能是误报，URL 已编码）

---

## 七、Transforms（变换）

### 7.1 为什么需要 Transform？

有些攻击链需要数据经过特定的"变换步骤"：

```python
path = user_input                          # 用户输入
content = open(path, "r").read()           # 文件读取（变换）
obj = pickle.loads(content)                # 反序列化（sink）
```

如果没有 Transform，Pysa 看到的是 `UserControlled → ExecDeserializationSink`。但实际上 **不是所有用户输入直接反序列化都是问题——只有先读了文件再反序列化才是问题**。

Transform 让 Pysa 可以追踪"数据经过了文件读取操作"这个中间步骤。

### 7.2 定义 Transform

在 `.pysa` 文件中：
```python
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...
```

在 `taint.config` 的规则中：
```json
{
  "name": "File content deserialization",
  "code": 6108,
  "sources": ["UserControlled"],
  "transforms": ["FileOperation"],
  "sinks": ["FileSystem_ReadWrite"],
  "message_format": "..."
}
```

---

## 八、Entrypoints（入口点）

### 8.1 什么是入口点？

在 Web 应用中，"入口点"通常是视图函数（view）：

```python
@app.route("/search")
def search(request):                       # ← 这是入口点
    query = request.GET["q"]
    results = db.execute(query)
    return render(results)
```

当使用 `--limit-entrypoints` 时，Pysa 只分析从入口点可达的函数，跳过工具函数、测试代码等。

### 8.2 定义入口点

在 `.pysa` 文件中：
```python
def my_app.views.search(request): Entrypoint: ...
```

或使用 ModelQuery 批量标记：
```python
ModelQuery(
  name = "django_views_entrypoints",
  find = "methods",
  where = [cls.extends("django.views.View")],
  model = [Entrypoint]
)
```

---

## 九、处理 false positives 和 false negatives

### 9.1 False Positive（误报）

Pysa 报告了一个不是真正漏洞的问题。常见原因：

1. **数据已被验证但 Pysa 不知道**：
```python
user_id = int(request.GET["id"])  # 安全的，但 Pysa 可能不认识 int() 作为 sanitizer
```
解决：给 `int()` 添加 `@Sanitize` 标注。

2. **条件判断排除了危险路径**：
```python
if user_input in allowed_list:    # 只允许白名单内的值
    os.system(user_input)
```
解决：Pysa 不做条件分析。需要用 `@Sanitize` 标注或接受这个误报。

3. **不透明函数的保守估计**：
解决：为相关函数写精确的 `.pysa` 模型。

### 9.2 False Negative（漏报）

Pysa 没有报告实际存在的漏洞。常见原因：

1. **缺少模型**：某个框架的输入函数没有被标记为 source。
解决：添加 `.pysa` 模型。

2. **trace 长度限制**：数据流路径太长，被 `--maximum-trace-length` 截断。
解决：增大限制值。

3. **方法重写过多**：被 `--maximum-overrides-to-analyze` 截断。
解决：增大限制值或为特定方法添加模型。

### 9.3 调试工具：reveal_taint()

Pysa 提供了一个特殊函数 `reveal_taint()`，类似于类型检查中的 `reveal_type()`：

```python
x = input("data: ")
reveal_taint(x)        # Pysa 会在输出中显示 x 当前的污点状态
os.system(x)
```

运行 Pysa 后，日志中会显示 `x` 被标记了哪些 source/sink 的污点。

---

## 十、性能与可扩展性

### 10.1 Pysa 如何处理大型项目

Pysa 在 Meta 内部用于分析数百万行 Python 代码。它的可扩展性来源于：

1. **摘要机制**：不内联所有函数，只使用摘要
2. **并行分析**：多个工作线程同时分析不同函数
3. **缓存**：`--use-cache` 避免重复计算
4. **增量分析**：只重新分析变化的部分

### 10.2 实测数据

在我们的小型测试项目中（2 个源文件，~60 行代码）：
- 类型检查：发现 918 模块、20302 函数（大部分是 typeshed 中的标准库）
- 不动点迭代：2 轮，共分析 14 个 callable
- 分析时间：约 5-10 秒（主要是类型检查时间）
- 内存：约 0.031GB

对于大型项目，分析时间可能是几分钟到几十分钟，内存可能需要几 GB 到几十 GB。

### 10.3 性能调优策略

1. **减少分析范围**：`--limit-entrypoints`、`--rule`
2. **使用缓存**：`--use-cache`（首次慢，后续快）
3. **控制精度**：降低 `--maximum-trace-length` 和 `--maximum-tito-depth`
4. **增加资源**：`--number-of-workers`、更多内存

---

## 十一、与其他工具的对比

### 11.1 Pysa vs Bandit

| 维度 | Pysa | Bandit |
|------|------|--------|
| 分析类型 | 过程间污点分析 | 基于模式匹配的 AST 分析 |
| 能追踪数据流？ | 是（跨函数、跨文件） | 否（只看单个表达式） |
| 需要配置？ | 是（模型文件） | 最小配置 |
| 误报率 | 较低 | 较高（没有数据流信息） |
| 支持自定义规则？ | 是（`.pysa` + `taint.config`） | 是（Python 插件） |
| 适合场景 | 中大型项目、需要精确分析 | 快速扫描、轻量级检查 |

### 11.2 Pysa vs CodeQL

| 维度 | Pysa | CodeQL |
|------|------|--------|
| 分析类型 | 专用污点分析 | 通用查询语言 |
| 支持 Python？ | 原生 | 是（Python extractor） |
| 规则灵活性 | 中等（声明式模型） | 极高（Turing-complete 查询语言） |
| 学习曲线 | 较低 | 较高 |
| 性能 | 优秀（为 Python 优化） | 优秀（有数据库索引） |

---

## 十二、总结

Pysa 的静态分析原理可以用几句话概括：

1. **污点分析**：追踪"脏数据"（source）是否能流到"危险操作"（sink）
2. **基于摘要的过程间分析**：为每个函数生成 source/sink/TITO 摘要，通过摘要传播污点
3. **不动点迭代**：反复分析直到所有摘要不再变化
4. **正向+反向双向分析**：正向追踪 source，反向追踪 sink
5. **Widening/Collapsing**：在精度和性能之间取平衡

理解了这些原理，你就能：
- 更好地写 `.pysa` 模型（理解模型为什么这样写）
- 更好地调参（理解参数影响的是算法的哪一步）
- 更好地理解分析结果（理解为什么报了这个问题、为什么漏了那个问题）
- 更好地处理误报和漏报（知道该在哪里加 sanitizer、在哪里调模型）
