# Pysa 常用规则语法详解

> **工具版本**: pyre-check 0.9.25  
> **官方文档**: https://pyre-check.org/docs/pysa-basics/ · https://pyre-check.org/docs/pysa-advanced/ · https://pyre-check.org/docs/pysa-model-dsl/  
> **适用读者**: 零基础安全工程师、开发者

---

## 一、两类文件，两种语法

Pysa 的规则体系由两类文件共同构成：

| 文件类型 | 语法 | 作用 |
|----------|------|------|
| `taint.config` | JSON | 定义 source/sink/feature/rule 的"词汇表" |
| `.pysa` | 类似 Python 类型注解 | 告诉 Pysa "哪个函数扮演什么角色" |

**比喻**：`taint.config` 像字典——定义了"有毒"和"安全"这些词的含义。`.pysa` 像标签——贴在每个函数上，说明这个函数是"有毒源头"还是"危险终点"。

**理解要点**：初学者最常犯的错误是只写了 `.pysa` 模型却忘了在 `taint.config` 中定义对应的名称，或者只定义了名称却没有编写规则来连接它们。这两类文件必须协同工作：先在配置中注册名称和规则，再在模型文件中把名称绑定到具体函数。

---

## 二、taint.config 语法

### 2.1 整体结构

```json
{
  "sources": [...],
  "sinks": [...],
  "transforms": [...],
  "features": [...],
  "rules": [...],
  "implicit_sources": {...},
  "implicit_sinks": {...},
  "string_combine_rules": [...]
}
```

所有字段都是可选的（但空文件必须有 `{}` 且至少有空数组）。

### 2.2 Sources 定义

```json
"sources": [
  {
    "name": "UserControlled",        // 唯一标识，在 .pysa 中引用
    "comment": "用户控制的输入"       // 说明文字（可选）
  },
  {
    "name": "Cookies",
    "comment": "HTTP Cookie 数据"
  }
]
```

**规则**：
- `name` 必须唯一
- `name` 是大小写敏感的（`UserControlled` ≠ `usercontrolled`）
- 名字中不能包含空格，推荐用 PascalCase

### 2.3 Sinks 定义

```json
"sinks": [
  {
    "name": "RemoteCodeExecution",
    "comment": "可能导致代码执行的接收点"
  },
  {
    "name": "SQL",
    "comment": "SQL 查询接收点"
  }
]
```

### 2.4 Transforms 定义

```json
"transforms": [
  {
    "name": "FileOperation",
    "comment": "文件操作变换"
  }
]
```

Transform 是 source 和 sink 之间的"中间步骤"标记，用于表示数据在传播过程中经历了某种中间操作。后面会详细介绍。

**使用场景举例**：用户输入先写入文件，再从文件读出后传入危险函数。这种间接传播需要通过 Transform 来建模，否则 Pysa 可能无法追踪跨越文件读写的数据流。

### 2.5 Features 定义

```json
"features": [
  {
    "name": "string_concat_lhs",
    "comment": "字符串拼接左侧"
  },
  {
    "name": "urlencode",
    "comment": "URL 编码"
  }
]
```

Features 不影响分析结果，只给数据流路径打标签。

### 2.6 Rules 定义

```json
"rules": [
  {
    "name": "Possible shell injection",       // 规则名称
    "code": 5001,                              // 唯一编号
    "sources": ["UserControlled"],             // 哪些 source 触发此规则
    "sinks": ["RemoteCodeExecution"],          // 哪些 sink 触发此规则
    "message_format": "Data from [{$sources}] source(s) may reach [{$sinks}] sink(s)"
  }
]
```

**关键细节**：
- `code` 必须是唯一的正整数
- `sources` 和 `sinks` 是数组，支持"任意匹配"——只要数据的 source 在数组中、sink 在数组中
- `message_format` 中的 `{$sources}` 和 `{$sinks}` 会被实际触发的 source/sink 名字替换

**多 source/多 sink 的规则**：
```json
{
  "name": "Any user data to any code execution",
  "code": 5100,
  "sources": ["UserControlled", "CLIUserControlled", "Cookies"],
  "sinks": ["RemoteCodeExecution", "ExecDeserializationSink"],
  "message_format": "..."
}
```
这条规则匹配：UserControlled→RemoteCodeExecution, UserControlled→ExecDeserializationSink, CLIUserControlled→RemoteCodeExecution... 等所有组合。

**带 Transform 的规则**：
```json
{
  "name": "File content deserialization RCE",
  "code": 6108,
  "sources": ["UserControlled"],
  "transforms": ["FileOperation"],
  "sinks": ["FileSystem_ReadWrite"],
  "message_format": "..."
}
```

### 2.7 Implicit Sources 定义

```json
"implicit_sources": {
  "literal_strings": [
    {
      "regexp": "AKIA[0-9A-Z]{16}",
      "kind": "AWSAccessKey",
      "description": "AWS 访问密钥"
    },
    {
      "regexp": ".*SELECT.*FROM.*",
      "kind": "StringMayBeSQL"
    }
  ]
}
```

**原理**：Pysa 扫描代码中的字符串字面量，如果匹配正则表达式，自动标记为对应的 source。这不需要 `.pysa` 文件标注。

### 2.8 String Combine Rules

```json
"string_combine_rules": [
  {
    "name": "SQL injection via string concatenation",
    "code": 5051,
    "pattern": "{StringMayBeSQL}{UserControlled}",
    "output": "SQL",
    "message_format": "..."
  }
]
```

**`pattern` 语法**：`{A}{B}` 表示 A 类型的字符串和 B 类型的字符串被拼接。
**`output`**：拼接结果会被标记为此类型的 taint（进入后续的 source→sink 追踪）。

---

## 三、.pysa 文件语法

### 3.1 基本格式

`.pysa` 文件看起来像 Python 的函数签名声明加上特殊的类型注解。但它 **不是 Python 代码**——它是 Pysa 专有的声明式语言。

基本格式：
```python
def 模块.函数名(参数: 注解, ...): ...
def 模块.函数名(参数: 注解, ...) -> 返回值注解: ...
```

注意末尾的 `...`——表示"这不是函数实现，只是声明"。

### 3.2 TaintSource（标记 Source）

将函数的返回值标记为某种 source：

```python
# 基本语法
def input(__prompt) -> TaintSource[UserControlled]: ...

# 多个 source 标签
def get_request() -> TaintSource[UserControlled, Cookies]: ...
```

将对象的属性标记为 source：
```python
# 属性 source（不需要 def）
django.http.request.HttpRequest.GET: TaintSource[UserControlled] = ...
django.http.request.HttpRequest.COOKIES: TaintSource[Cookies, UserControlled] = ...
django.http.request.HttpRequest.body: TaintSource[UserControlled] = ...
```

**注意**：属性 source 的语法是 `类名.属性名: TaintSource[...] = ...`，末尾是 `= ...` 而不是 `: ...`

### 3.3 TaintSink（标记 Sink）

将函数的参数标记为某种 sink：

```python
# 基本语法
def os.system(command: TaintSink[RemoteCodeExecution]): ...

# 多个参数都是 sink
def subprocess.run(
    args: TaintSink[RemoteCodeExecution],
    **kwargs
): ...

# 多个 sink 标签
def pickle.loads(
    data: TaintSink[ExecDeserializationSink, FileContentDeserializationSink]
): ...
```

**参数名必须匹配**：`.pysa` 中写的参数名必须和 Python 代码中的参数名一致。如果不一致，Pysa 会报 model verification error（除非用 `--no-verify`）。

### 3.4 TaintInTaintOut（TITO，污点传递）

声明"参数的污点会传递到返回值"：

```python
# 基本 TITO
def str.upper(self: TaintInTaintOut): ...

# 多个参数都有 TITO
def str.__add__(
    self: TaintInTaintOut,
    other: TaintInTaintOut
): ...

# 带 Feature 的 TITO
def str.__add__(
    self: TaintInTaintOut[Via[string_concat_lhs]],
    other: TaintInTaintOut[Via[string_concat_rhs]]
): ...
```

#### 3.4.1 TITO 路径控制

对于容器类型，可以精确控制污点在结构中的流向：

```python
# 参数的所有元素 → 返回值的所有元素
def sorted(
    __iterable: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[_.all()]]
): ...

# 无路径控制（参数整体 → 返回值整体）
def copy.copy(x: TaintInTaintOut[LocalReturn]): ...
```

**路径元素**：
| 路径 | 含义 |
|------|------|
| `ParameterPath[]` | 参数整体 |
| `ParameterPath[_.all()]` | 参数的所有子元素 |
| `ParameterPath[_.keys()]` | 参数的所有键 |
| `ReturnPath[]` | 返回值整体 |
| `ReturnPath[_.all()]` | 返回值的所有子元素 |
| `ReturnPath[_.all()[1]]` | 返回值中每个子元素的第 1 个元素 |

**示例**：`enumerate()` 接收 `[a, b, c]` 返回 `[(0,a), (1,b), (2,c)]`：
```python
def enumerate.__new__(
    cls,
    iterable: TaintInTaintOut[
        LocalReturn,
        ParameterPath[_.all()],           # 输入：iterable 的每个元素
        ReturnPath[_.all()[1]],           # 输出：结果元组的第 1 个元素（value）
        NoCollapse
    ]
): ...
```

#### 3.4.2 TITO 修饰符

| 修饰符 | 含义 |
|--------|------|
| `LocalReturn` | 污点只传递到返回值（不传到 self 或其他参数） |
| `NoCollapse` | 保持路径精度，不折叠 |
| `Collapse` | 强制折叠路径 |

### 3.5 Sanitize（消毒器）

消毒器是污点分析中极其重要的概念。当数据经过某个函数后变得"安全"（例如经过类型转换、编码转义、白名单验证），就需要用消毒器告诉 Pysa："到这里为止，污点可以被清除了"。不正确地使用消毒器会导致大量误报或漏报，因此需要谨慎设置。

#### 3.5.1 完全消毒

```python
# 通过这个函数的所有数据都被清洗
@Sanitize
def len(o): ...
```

#### 3.5.2 只消毒特定 Source

```python
# 只清除 UserControlled 标签，其他 source 标签保留
@Sanitize(TaintSource[UserControlled])
def my_filter(data): ...
```

#### 3.5.3 只消毒特定 Sink

```python
# 经过这个函数后，数据不再能到达 SQL sink
@Sanitize(TaintSink[SQL])
def sql_escape(data): ...
```

#### 3.5.4 只消毒 TITO 方向的特定 Source

```python
# 阻止 ServerSecrets 通过这个函数泄露
@Sanitize(TaintInTaintOut[TaintSource[ServerSecrets]])
def requests.api.request(url, ...): ...
```

#### 3.5.5 参数级消毒

```python
# 只有第一个参数被消毒
def my_func(
    safe_param: Sanitize[TaintSink[RemoteCodeExecution]],
    unsafe_param
): ...
```

### 3.6 ViaValueOf 和 ViaTypeOf（值/类型特征）

```python
# 记录 shell 参数的实际值
def subprocess.run(
    args: TaintSink[RemoteCodeExecution, ViaValueOf[shell]],
    **kwargs
): ...
# 如果调用 subprocess.run(cmd, shell=True)，issue 会带有 via-shell:True

# 记录 args 参数的类型
def subprocess.run(
    args: TaintSink[RemoteCodeExecution, ViaTypeOf[args]],
    **kwargs
): ...
# 如果 args 是 str 类型，issue 会带有 via-type:str

# 带标签的 ViaValueOf
def open(
    file: TaintSink[FileSystem_ReadWrite, ViaValueOf[mode, WithTag["file-open-mode"]]],
    mode
): ...
# issue 会带有 via-file-open-mode:r 或 via-file-open-mode:w
```

### 3.7 Transform（变换标记）

```python
# 标记数据经过了文件操作变换
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...
```

### 3.8 条件模型（版本分支）

当不同 Python 版本的函数签名不同时：

```python
if sys.version >= (3, 8, 0):
    def pickle.loads(
        __data: TaintSink[ExecDeserializationSink],
        *, fix_imports, encoding, errors, buffers
    ): ...
else:
    def pickle.loads(
        data: TaintSink[ExecDeserializationSink],
        *, fix_imports, encoding, errors
    ): ...
```

### 3.9 多重模型定义

同一个函数可以有多个 `.pysa` 定义，Pysa 会合并它们：

```python
# 定义 1：open 是 sink
def open(file: TaintSink[FileSystem_ReadWrite, ViaValueOf[mode, WithTag["file-open-mode"]]], mode): ...

# 定义 2：open 有 TITO（文件路径 → 文件内容）
def open(file: TaintInTaintOut[Via[external_query], Via[filesystem_operation]]): ...

# 定义 3：open 有 Transform
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...
```

三个定义同时生效，Pysa 内部会合并为一个完整的模型。

### 3.10 Entrypoint（入口点）

```python
# 标记函数为分析入口点
def my_app.views.home(request): Entrypoint: ...
```

使用 `--limit-entrypoints` 时，Pysa 只分析从 entrypoint 可达的函数。

### 3.11 @SkipObscure

```python
@SkipObscure
def str.__add__(self: TaintInTaintOut, other: TaintInTaintOut): ...
```

告诉 Pysa："不要把这个函数当作不透明的（obscure），严格使用我定义的模型"。

### 3.12 class 级别注解

```python
# 跳过整个类的方法重写分析
class enumerate(SkipOverrides): ...
class reversed(SkipOverrides): ...

# 在类的属性上标注
class django.http.request.HttpRequest(TaintSource[UserControlled]):
    GET: TaintSource[UserControlled] = ...
    POST: TaintSource[UserControlled] = ...
```

### 3.13 @property

```python
# 属性 getter 消毒
@SkipObscure
@Sanitize
@property
def object.__class__(): ...
```

---

## 四、ModelQuery DSL（模型查询语言）

### 4.1 为什么需要 ModelQuery？

手动写 `.pysa` 文件时，如果你的项目有 200 个 Django View，你需要逐个编写 200 行模型声明，这不仅费时费力，而且容易遗漏新增的视图函数。ModelQuery 就是为了解决这个规模化问题而设计的：它让你用一条"查询规则"自动匹配并批量生成模型。你只需要描述"匹配什么样的函数"和"生成什么样的模型"，Pysa 就会在分析前自动展开为具体的函数级模型。这有点像数据库中的视图——你定义一次查询，每次运行都自动获取最新结果。

### 4.2 基本语法

```python
ModelQuery(
  name = "查询名称",              # 唯一标识
  find = "查找目标",              # "functions" | "methods" | "attributes" | "globals"
  where = [...],                  # 匹配条件
  model = [...]                   # 生成的模型
)
```

### 4.3 find 子句

| 值 | 含义 |
|----|------|
| `"functions"` | 查找顶层函数 |
| `"methods"` | 查找类方法 |
| `"attributes"` | 查找类属性 |
| `"globals"` | 查找全局变量 |

### 4.4 where 子句：匹配条件

#### 按名字匹配
```python
where = [name.matches("get_.*")]    # 名字以 get_ 开头
where = [name.equals("process")]    # 名字精确为 process
```

#### 按全限定名匹配
```python
where = [fully_qualified_name.matches("my_app\\.views\\..*")]
```

#### 按类继承匹配
```python
where = [cls.extends("django.views.View")]            # 继承自 View
where = [cls.extends("django.views.View", is_transitive=True)]  # 包括间接继承
```

#### 按装饰器匹配
```python
where = [Decorator(fully_qualified_name.matches("app\\.route"))]
```

#### 按参数匹配
```python
where = [AnyOf(
    any_parameter.annotation.is_annotated_type(),
    any_parameter.annotation.equals("HttpRequest")
)]
```

#### 组合条件
```python
# AND（所有条件都满足）
where = [
    cls.extends("django.views.View"),
    name.matches("get|post|put|delete")
]

# OR（任一条件满足）
where = [AnyOf(
    name.matches("handle_.*"),
    Decorator(fully_qualified_name.equals("app.route"))
)]

# NOT
where = [Not(name.matches("test_.*"))]
```

### 4.5 model 子句：生成的模型

#### 标记返回值为 Source
```python
model = Returns(TaintSource[UserControlled])
```

#### 标记所有参数为 Sink
```python
model = Parameters(TaintSink[RemoteCodeExecution])
```

#### 标记特定参数为 Sink
```python
model = NamedParameter(name="url", taint=TaintSink[HTTPClientRequest_URI])
```

#### 标记所有参数为 Source
```python
model = Parameters(TaintSource[UserControlled])
```

#### 组合多个模型
```python
model = [
    Parameters(TaintSource[UserControlled]),
    Returns(TaintSink[XSS])
]
```

#### 标记为入口点
```python
model = [Entrypoint]
```

### 4.6 完整示例

**示例 1：自动标记所有 Django View 方法**
```python
ModelQuery(
  name = "django_view_methods",
  find = "methods",
  where = [
    cls.extends("django.views.View"),
    name.matches("get|post|put|delete|patch|head|options")
  ],
  model = [
    Parameters(TaintSource[UserControlled]),
    Entrypoint
  ]
)
```

**示例 2：自动标记所有 route 装饰的函数**
```python
ModelQuery(
  name = "flask_route_handlers",
  find = "functions",
  where = [
    Decorator(fully_qualified_name.matches("flask\\.app\\.Flask\\.route"))
  ],
  model = [
    Parameters(TaintSource[UserControlled]),
    Returns(TaintSink[XSS])
  ]
)
```

**示例 3：自动标记名字含 "execute" 的方法为 Sink**
```python
ModelQuery(
  name = "execute_methods_as_sinks",
  find = "methods",
  where = [name.matches("execute.*")],
  model = Parameters(TaintSink[SQL])
)
```

**示例 4：使用 cache 提升性能**
```python
ModelQuery(
  name = "cached_query",
  find = "methods",
  where = [cls.extends("BaseModel")],
  model = Parameters(TaintSource[UserControlled]),
  cache = True    # 缓存匹配结果，加速后续分析
)
```

### 4.7 调试 ModelQuery

使用 `--dump-model-query-results` 查看 ModelQuery 匹配了哪些函数：

```bash
pyre analyze --no-verify --dump-model-query-results ./mq-results.json
```

输出格式：
```json
[
  {
    "path/to/model_query.pysa/query_name": [
      {
        "callable": "fileinput.input",
        "sources": [{"port": "result", "taint": [{"kinds": [{"kind": "UserControlled"}]}]}]
      },
      ...
    ]
  }
]
```

---

## 五、常见模式与配方

### 5.1 模式 1：标记 Web 框架的请求参数

```python
# Flask
def flask.wrappers.Request.__init__(self) -> TaintSource[UserControlled]: ...
flask.wrappers.Request.args: TaintSource[UserControlled] = ...
flask.wrappers.Request.form: TaintSource[UserControlled] = ...
flask.wrappers.Request.json: TaintSource[UserControlled] = ...
flask.wrappers.Request.data: TaintSource[UserControlled] = ...
flask.wrappers.Request.cookies: TaintSource[Cookies, UserControlled] = ...
flask.wrappers.Request.headers: TaintSource[HeaderData, UserControlled] = ...
```

### 5.2 模式 2：标记数据库查询为 Sink

```python
# SQLAlchemy
def sqlalchemy.engine.Engine.execute(self, statement: TaintSink[SQL], *args): ...
def sqlalchemy.orm.Session.execute(self, statement: TaintSink[SQL], *args): ...

# PyMySQL
def pymysql.cursors.Cursor.execute(self, query: TaintSink[SQL], args = ...): ...
```

### 5.3 模式 3：标记模板渲染为 Sink

```python
# Jinja2
def jinja2.Environment.from_string(self, source: TaintSink[ServerSideTemplateInjection]): ...

# Django 模板
def django.template.Template.__init__(self, template_string: TaintSink[ServerSideTemplateInjection]): ...
```

### 5.4 模式 4：自定义 Sanitizer

```python
# 自定义 HTML 转义函数
@Sanitize(TaintSink[XSS])
def my_utils.escape_html(text): ...

# 自定义 SQL 参数化
@Sanitize(TaintSink[SQL])
def my_utils.parameterize_query(query, params): ...

# 自定义白名单验证
@Sanitize
def my_utils.validate_in_whitelist(value, allowed): ...
```

### 5.5 模式 5：标记配置读取为 Source

```python
# 环境变量
def os.environ.__getitem__(key) -> TaintSource[EnvironmentConfig]: ...
def os.getenv(key, default = ...) -> TaintSource[EnvironmentConfig]: ...

# 配置文件
def configparser.ConfigParser.get(self, section, option) -> TaintSource[EnvironmentConfig]: ...
```

### 5.6 模式 6：使用 AttachToSource/AttachToSink

给已有模型附加 feature，不改变 source/sink 标记：

```python
# 给所有 requests 调用附加 http_query feature
def requests.api.request(
    method: AttachToTito[Via[http_query], Via[external_query]],
    url: AttachToTito[Via[http_query], Via[external_query]],
    params: AttachToTito[Via[http_query], Via[external_query]],
    data: AttachToTito[Via[http_query], Via[external_query]]
): ...
```

---

## 六、语法细节与注意事项

### 6.1 参数名规则

`.pysa` 中的参数名必须与 Python 实际实现匹配。常见错误：

```python
# ❌ 错误：pickle.loads 在 Python 3.8+ 中第一个参数叫 __data
def pickle.loads(data: TaintSink[ExecDeserializationSink]): ...

# ✅ 正确
def pickle.loads(__data: TaintSink[ExecDeserializationSink]): ...
```

**调试技巧**：不加 `--no-verify` 运行，查看 model verification errors 来发现参数名不匹配。

### 6.2 默认参数

可以用 `= ...` 表示参数有默认值：

```python
def my_func(required_param: TaintSink[SQL], optional_param = ...): ...
```

### 6.3 *args 和 **kwargs

```python
def my_func(*args: TaintSource[UserControlled]): ...
def my_func(**kwargs: TaintSink[SQL]): ...
```

### 6.4 self 参数

对于实例方法，`self` 参数可以用来标记对象自身：

```python
# 正确：HttpRequest 对象的 body 属性
django.http.request.HttpRequest.body: TaintSource[UserControlled] = ...

# 也可以对 self 标注（比如 Path.write_bytes 会消毒路径上的 TITO）
def pathlib.Path.write_bytes(self: Sanitize[TaintInTaintOut[TaintSource[UserControlled]]]): ...
```

### 6.5 类方法和静态方法

```python
# 类方法
def MyClass.from_string(cls, data: TaintSink[SQL]): ...

# 静态方法
def MyClass.validate(data: TaintSink[SQL]): ...
```

### 6.6 注释

`.pysa` 文件支持 `#` 开头的注释：

```python
# 这是对 Django Request 的模型
# 所有 HTTP 相关属性都是 UserControlled source
django.http.request.HttpRequest.GET: TaintSource[UserControlled] = ...
```

---

## 七、高级语法

### 7.1 ParameterPath 和 ReturnPath 深入

这些用于精确描述数据在容器结构中的流向：

```python
# dict.get：字典中所有值 → 返回值
def dict.get(
    self: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[], NoCollapse],
    __key,
    __default: TaintInTaintOut[LocalReturn, NoCollapse] = ...
): ...
```

**路径语法**：
| 语法 | 含义 |
|------|------|
| `_` | 当前对象本身 |
| `_.all()` | 所有子元素（列表的所有项、字典的所有值） |
| `_.keys()` | 所有键（字典专用） |
| `_.all()[0]` | 所有子元素的第 0 个元素 |
| `_.all()[1]` | 所有子元素的第 1 个元素 |

### 7.2 条件污点（Conditional）

```python
# 如果 `request` 参数的类型是 HttpRequest，才标记为 source
def my_view(request: TaintSource[UserControlled, Via[request_type]]): ...
```

### 7.3 多模型组合

一个函数可以同时当 source 和 sink：

```python
# requests.get：url 是 SSRF sink，返回值是 DataFromInternet source
def requests.get(
    url: TaintSink[HTTPClientRequest_URI],
    **kwargs
) -> TaintSource[DataFromInternet]: ...
```

### 7.4 Global 模型

```python
# 全局变量也可以标注
os.environ: TaintSource[EnvironmentConfig] = ...
```

---

## 八、常见错误与排查

### 8.1 Model verification error

**错误**：
```
Model signature parameters for `pickle.loads` do not match implementation.
Reason: unexpected named parameter: `data`.
```

**解决**：检查参数名是否与实际 Python 函数签名匹配。使用 `python3 -c "import inspect; import pickle; print(inspect.signature(pickle.loads))"` 查看实际签名。

### 8.2 Undeclared source/sink

**错误**：taint config 中没有定义你在 `.pysa` 中引用的 source 或 sink 名字。

**解决**：确保 `taint.config` 的 `sources`/`sinks` 数组中包含了所有在 `.pysa` 中使用的名字。

### 8.3 模型不生效

**症状**：明明写了模型，但 Pysa 没有检测到预期的问题。

**排查步骤**：
1. 去掉 `--no-verify`，查看是否有 verification errors
2. 检查 `taint.config` 中是否有匹配的 rule
3. 使用 `reveal_taint()` 检查中间变量的污点状态
4. 检查 `--maximum-trace-length` 是否太小

### 8.4 ModelQuery 没匹配到任何函数

**排查步骤**：
1. 使用 `--dump-model-query-results` 查看匹配结果
2. 检查 `find` 是否正确（`functions` vs `methods`）
3. 检查 `where` 条件是否过于严格
4. 确认目标代码在 `source_directories` 中

---

## 九、语法速查表

### 9.1 .pysa 注解速查

| 注解 | 位置 | 含义 |
|------|------|------|
| `TaintSource[X]` | 返回值/属性 | 此处产生 X 类型的污点 |
| `TaintSink[X]` | 参数 | 此处消费 X 类型的污点 |
| `TaintInTaintOut` | 参数 | 参数污点传递到返回值 |
| `@Sanitize` | 函数 | 清除所有污点 |
| `@Sanitize(TaintSource[X])` | 函数 | 清除 X source 污点 |
| `@Sanitize(TaintSink[X])` | 函数 | 阻止到达 X sink |
| `Via[X]` | 参数 | 添加 X feature 标签 |
| `ViaValueOf[X]` | 参数 | 记录 X 参数的值 |
| `ViaTypeOf[X]` | 参数 | 记录 X 参数的类型 |
| `Transform[X]` | 参数 | 添加 X 变换标记 |
| `LocalReturn` | TITO 修饰 | 污点只传到返回值 |
| `NoCollapse` | TITO 修饰 | 不折叠路径 |
| `Collapse` | TITO 修饰 | 强制折叠路径 |
| `ParameterPath[...]` | TITO 修饰 | 输入路径 |
| `ReturnPath[...]` | TITO 修饰 | 输出路径 |
| `@SkipObscure` | 函数 | 不当作不透明函数 |
| `Entrypoint` | 函数 | 分析入口点 |

### 9.2 taint.config 字段速查

| 字段 | 类型 | 必需 | 含义 |
|------|------|------|------|
| `sources` | array | 是 | source 类型定义 |
| `sinks` | array | 是 | sink 类型定义 |
| `features` | array | 是 | feature 标签定义 |
| `rules` | array | 是 | source→sink 匹配规则 |
| `transforms` | array | 否 | 变换类型定义 |
| `implicit_sources` | object | 否 | 隐式源（字符串匹配） |
| `implicit_sinks` | object | 否 | 隐式汇 |
| `string_combine_rules` | array | 否 | 字符串拼接规则 |

### 9.3 ModelQuery where 子句速查

| 条件 | 含义 |
|------|------|
| `name.matches("regex")` | 函数/方法名正则匹配 |
| `name.equals("exact")` | 函数/方法名精确匹配 |
| `fully_qualified_name.matches("regex")` | 全限定名正则匹配 |
| `cls.extends("ClassName")` | 类继承 |
| `cls.extends("ClassName", is_transitive=True)` | 包含间接继承 |
| `Decorator(...)` | 装饰器匹配 |
| `AnyOf(...)` | OR 条件 |
| `AllOf(...)` | AND 条件 |
| `Not(...)` | NOT 条件 |
| `any_parameter.annotation.equals("Type")` | 参数类型匹配 |

---

## 十、从模型到检测：一个完整的语法实践

### 10.1 需求：检测自定义框架中的 SSRF 漏洞

假设你的项目使用了一个内部 HTTP 客户端框架 `my_http`，Pysa 内置规则没有覆盖它。以下是从零构建检测能力的完整步骤。

#### 第 1 步：在 taint.config 中定义（如果尚未存在）

```json
{
  "sources": [
    {"name": "UserControlled", "comment": "用户可控输入"}
  ],
  "sinks": [
    {"name": "HTTPClientRequest_URI", "comment": "HTTP 请求 URL"}
  ],
  "rules": [
    {
      "name": "SSRF via custom HTTP client",
      "code": 9010,
      "sources": ["UserControlled"],
      "sinks": ["HTTPClientRequest_URI"],
      "message_format": "用户输入 [{$sources}] 可能被用作 HTTP 请求 URL [{$sinks}]"
    }
  ]
}
```

#### 第 2 步：编写 .pysa 模型

```python
# custom_http.pysa

# Source：Web 请求参数
def my_framework.get_param(name) -> TaintSource[UserControlled]: ...

# Sink：HTTP 客户端的 URL 参数
def my_http.client.get(url: TaintSink[HTTPClientRequest_URI], **kwargs): ...
def my_http.client.post(url: TaintSink[HTTPClientRequest_URI], **kwargs): ...

# TITO：URL 构建函数会传递污点
def my_http.utils.build_url(base, path: TaintInTaintOut[Via[url_construction]]): ...

# Sanitizer：URL 白名单验证函数
@Sanitize(TaintSink[HTTPClientRequest_URI])
def my_http.utils.validate_internal_url(url): ...
```

#### 第 3 步：编写 ModelQuery 自动覆盖

```python
# 自动标记所有 my_http.client 中以 HTTP 方法命名的函数
ModelQuery(
  name = "custom_http_sinks",
  find = "methods",
  where = [
    cls.extends("my_http.client.BaseClient"),
    name.matches("get|post|put|delete|patch|head")
  ],
  model = NamedParameter(name="url", taint=TaintSink[HTTPClientRequest_URI])
)
```

#### 第 4 步：验证效果

```bash
# 验证配置合法性
pyre analyze --verify-taint-config-only

# 检查 ModelQuery 匹配情况
pyre analyze --no-verify --dump-model-query-results ./mq-check.json

# 运行分析，只看 SSRF 规则
pyre analyze --no-verify --rule 9010
```

#### 第 5 步：处理结果

如果发现某些报告是误报（因为 URL 已经过白名单验证），就回到第 2 步添加更多 Sanitizer 模型，形成闭环迭代。

### 10.2 语法学习路线图

对于初学者，建议按以下顺序掌握 Pysa 语法：

1. **基础**（第一周）：掌握 `TaintSource`、`TaintSink`、`@Sanitize`，能写简单的单函数模型
2. **进阶**（第二周）：掌握 `TaintInTaintOut`、`Via` feature、多重模型定义
3. **高级**（第三周）：掌握 `ParameterPath`/`ReturnPath`、`Transform`、条件模型
4. **自动化**（第四周）：掌握 `ModelQuery` DSL，能为框架批量生成模型
5. **调优**（持续）：掌握 `@SkipObscure`、`ViaValueOf`、`ViaTypeOf`，能精确控制分析行为

每个阶段都应该配合实际项目练习——写模型、跑分析、查结果、改模型，形成正反馈循环。建议从自己熟悉的框架入手，先尝试检测最常见的注入类漏洞，积累经验后再处理更复杂的数据流场景。遇到分析结果不符合预期时，善用 `reveal_taint()` 和 `--dump-model-query-results` 进行调试定位。

---

## 十一、总结

Pysa 的规则语法设计体现了"声明式 + 可组合"的理念：

1. **taint.config 定义语义**：source/sink/rule 的名字和配对关系
2. **.pysa 文件实现绑定**：把语义绑定到具体的 Python 函数
3. **ModelQuery 实现自动化**：用模式匹配批量生成绑定

掌握这些语法后，你可以：
- 为任何 Python 框架编写安全分析模型
- 定义项目特定的安全规则
- 使用 ModelQuery 减少重复劳动
- 通过 features 和 transforms 实现精细的误报过滤

关键记住：`.pysa` 和 `taint.config` 是互补的——前者定义"是什么"，后者定义"怎么匹配"。两者缺一不可。
