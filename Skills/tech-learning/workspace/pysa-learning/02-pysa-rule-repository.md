# Pysa 规则仓库详解

> **工具版本**: pyre-check 0.9.25  
> **官方文档**: https://pyre-check.org/docs/pysa-basics/  
> **仓库位置**: `pyre-check/stubs/taint/`  
> **适用读者**: 零基础安全工程师、开发者

---

## 一、什么是"规则仓库"？

### 1.1 用一个比喻理解

想象你是一个海关检查员。你的工作是：检查从入境口（source）运来的货物有没有流入禁区（sink）。要完成这个工作，你需要三样东西：

1. **入境口清单**（Sources）：哪些地方会进来"有毒货物"？——比如用户输入、网络请求
2. **禁区清单**（Sinks）：哪些地方不能让"有毒货物"进入？——比如系统命令、SQL 查询
3. **检查规则**（Rules）：把 1 和 2 配对——"如果用户输入流进了系统命令，就报警"

Pysa 的"规则仓库"就是存放这三样东西的地方。它由两类文件组成：
- **`taint.config`**：定义 sources、sinks、features、rules 的 JSON 配置文件
- **`.pysa` 文件**：定义具体哪些 Python 函数是 source/sink/sanitizer 的模型文件

### 1.2 文件组织结构

在 pyre-check 仓库中，内置规则位于 `stubs/taint/` 目录下：

```
stubs/taint/
├── common/                         # 通用模型（与安全规则无关的基础行为）
│   ├── taint.config               # 空基础配置
│   ├── builtin_functions.pysa     # 内置函数的 TITO 模型
│   ├── collection_propagation.pysa # 集合类的污点传播
│   ├── functools.pysa             # functools 相关
│   ├── protocols.pysa             # 协议类相关
│   └── skipped_overrides.pysa     # 跳过的方法重写
│
└── core_privacy_security/          # 安全相关的核心规则
    ├── taint.config               # 主配置：所有 sources/sinks/rules
    ├── general.pysa               # 通用模型（字符串操作、异常、CLI 等）
    ├── rce_sinks.pysa             # 远程代码执行 sink
    ├── django_sources_sinks.pysa  # Django 框架的 source 和 sink
    ├── django_rest_framework.pysa # DRF 模型
    ├── filesystem_sinks.pysa      # 文件系统读写 sink
    ├── filesystem_other_sinks.pysa # 文件系统其他操作 sink
    ├── requests_api_sinks.pysa    # requests 库的 HTTP 请求 sink
    ├── sanitizers.pysa            # 消毒器
    ├── sqlite3_sinks.pysa         # SQLite3 sink
    ├── rce_sinks.pysa             # 远程代码执行 sink
    ├── logging_sinks.pysa         # 日志记录 sink
    ├── user_reach_sinks.pysa      # 邮件发送等用户触达 sink
    ├── format_string_sinks.pysa   # 格式化字符串 sink
    ├── http_server.pysa           # HTTP 服务器 source
    ├── mysql_sources.pysa         # MySQL 数据源
    ├── wsgi_ref.pysa              # WSGI 参考实现 source
    └── server_side_template_injection_sinks.pysa # SSTI sink
```

**目录说明**：
- `common/`：与安全分析无直接关系的"基础设施"模型，定义 Python 内置函数和常用库的数据传播行为
- `core_privacy_security/`：安全分析的核心内容，定义什么是危险的、什么是安全的

---

## 二、taint.config —— 规则配置中枢

### 2.1 文件格式概览

`taint.config` 是一个 JSON 文件，有 5 个顶级字段：

```json
{
  "sources": [...],
  "sinks": [...],
  "features": [...],
  "rules": [...],
  "implicit_sources": {...},
  "implicit_sinks": {...},
  "string_combine_rules": [...]
}
```

### 2.2 Sources（污染源）定义

Sources 描述"有毒数据从哪里来"。每个 source 就是一个名字加注释：

```json
"sources": [
  { "name": "UserControlled", "comment": "用户可控制的输入" },
  { "name": "Cookies", "comment": "HTTP Cookie" },
  { "name": "DataFromInternet", "comment": "来自互联网的数据" },
  { "name": "ServerSecrets", "comment": "服务器密钥" },
  { "name": "CLIUserControlled", "comment": "命令行参数" },
  { "name": "ExceptionMessage", "comment": "异常信息（可能泄露内部细节）" },
  { "name": "HeaderData", "comment": "HTTP 请求头" },
  { "name": "URL", "comment": "请求 URL" }
]
```

**重点理解**：source 名字只是一个"标签"。它本身不做任何事。只有在 `.pysa` 文件中把一个具体的 Python 函数标记为 `TaintSource[UserControlled]` 时，这个标签才有实际意义。

### 2.3 Sinks（汇聚点）定义

Sinks 描述"有毒数据不该流入的地方"：

```json
"sinks": [
  { "name": "RemoteCodeExecution", "comment": "代码执行" },
  { "name": "SQL", "comment": "SQL 查询" },
  { "name": "XSS", "comment": "跨站脚本" },
  { "name": "FileSystem_ReadWrite", "comment": "文件读写" },
  { "name": "FileSystem_Other", "comment": "文件系统其他操作" },
  { "name": "HTTPClientRequest_URI", "comment": "HTTP 请求 URL（SSRF）" },
  { "name": "HTTPClientRequest_DATA", "comment": "HTTP 请求数据" },
  { "name": "HTTPClientRequest_METADATA", "comment": "HTTP 请求元数据" },
  { "name": "Redirect", "comment": "重定向目标" },
  { "name": "ExecDeserializationSink", "comment": "反序列化执行" },
  { "name": "FileContentDeserializationSink", "comment": "文件内容反序列化" },
  { "name": "ResponseHeaderName", "comment": "响应头名称" },
  { "name": "ResponseHeaderValue", "comment": "响应头值" },
  { "name": "EmailSend", "comment": "邮件发送" },
  { "name": "Logging", "comment": "日志记录" },
  { "name": "XMLParser", "comment": "XML 解析器" },
  { "name": "FormatString", "comment": "格式化字符串" },
  { "name": "ReflectedDecoration", "comment": "反射装饰器" },
  { "name": "Authentication", "comment": "认证凭据" },
  { "name": "ServerSideTemplateInjection", "comment": "服务端模板注入" },
  { "name": "LDAPInjection", "comment": "LDAP 注入" },
  { "name": "ThriftReturn", "comment": "Thrift 返回值" },
  { "name": "GetAttr", "comment": "getattr 调用" },
  { "name": "EnvironmentVariable", "comment": "环境变量设置" },
  { "name": "ImportStatement", "comment": "动态导入" }
]
```

### 2.4 Features（特征标记）

Features 不直接影响分析结果，而是给数据流路径打上"标签"，方便后续过滤和理解。

```json
"features": [
  { "name": "string_concat_lhs", "comment": "在字符串拼接的左侧" },
  { "name": "string_concat_rhs", "comment": "在字符串拼接的右侧" },
  { "name": "getattr", "comment": "通过 getattr 访问" },
  { "name": "request_files", "comment": "文件上传相关" },
  { "name": "bytesio", "comment": "BytesIO 操作" },
  { "name": "escape_html", "comment": "经过 HTML 转义" },
  { "name": "shell_escape", "comment": "经过 shell 转义" },
  { "name": "urlencode", "comment": "经过 URL 编码" },
  { "name": "hmac", "comment": "经过 HMAC 处理" },
  { "name": "filesystem_operation", "comment": "文件系统操作" },
  { "name": "external_query", "comment": "外部查询" },
  { "name": "http_query", "comment": "HTTP 查询" },
  { "name": "len", "comment": "len() 操作" },
  { "name": "re_match", "comment": "正则匹配" }
]
```

**用法示例**：假设 Pysa 发现了一条 XSS 路径，带有 `escape_html` feature。审查人员一看就知道——"数据虽然流到了 HTML 输出，但中间经过了 HTML 转义，很可能是误报"。

### 2.5 Rules（规则）定义

Rules 是核心中的核心。每条规则把一组 sources 和一组 sinks 配对，定义了什么样的数据流是"有问题的"。

```json
{
  "name": "Possible shell injection",
  "code": 5001,
  "sources": ["UserControlled"],
  "sinks": ["RemoteCodeExecution"],
  "message_format": "Data from [{$sources}] source(s) may reach [{$sinks}] sink(s)"
}
```

**核心规则速查表**（pyre-check 内置）：

| Code | 名称 | 描述 |
|------|------|------|
| 5001 | Shell injection | 用户输入流入系统命令 |
| 5005 | SQL injection | 用户输入流入 SQL 查询 |
| 5007 | XML parser injection | 用户输入流入 XML 解析器（XXE） |
| 5008 | XSS | 用户输入流入 HTML 响应 |
| 5011 | Filesystem access | 用户输入流入文件操作 |
| 5012 | SSRF | 用户输入流入 HTTP 请求 URL |
| 5018 | Open redirect | 用户输入流入重定向目标 |
| 5027 | Server secrets leak | 服务器密钥泄露 |
| 5029 | Response headers | 用户输入流入响应头 |
| 5034 | Format string | 用户输入流入格式化字符串 |
| 5036 | Email injection | 用户输入流入邮件发送 |
| 5041 | CLI injection | 命令行参数流入代码执行 |
| 5051 | SQL injection (string combine) | 字符串拼接构造 SQL |
| 5052 | XSS (string combine) | 字符串拼接构造 HTML |
| 5053 | SSRF (string combine) | 字符串拼接构造 URL |
| 5067 | Deserialization | 用户输入流入反序列化 |
| 6060 | Filesystem other | 用户输入流入文件系统其他操作 |
| 6064 | Env/Import injection | 用户输入流入环境变量/动态导入 |
| 6065 | CLI args injection | 命令行参数注入 |
| 6066 | Deserialization RCE | 文件内容反序列化导致 RCE |
| 6073 | SSTI | 用户输入流入服务端模板 |
| 6074 | Hardcoded credentials | 硬编码凭据 |
| 6302 | Exception info leak | 异常信息泄露给用户 |
| 6303 | LDAP injection | 用户输入流入 LDAP 查询 |

### 2.6 Implicit Sources（隐式源）

普通 source 需要在 `.pysa` 文件中显式标注。但有些"source"不是来自函数，而是代码中的字面量字符串。Pysa 通过正则匹配来识别这些隐式 source：

```json
"implicit_sources": {
  "literal_strings": [
    {
      "regexp": "AKIA[0-9A-Z]{16}",
      "kind": "AWSAccessKey",
      "description": "AWS 访问密钥"
    },
    {
      "regexp": "AIza[0-9A-Za-z\\-_]{35}",
      "kind": "GoogleAPIKey",
      "description": "Google API 密钥"
    },
    {
      "regexp": ".*SELECT.*FROM.*",
      "kind": "StringMayBeSQL"
    },
    {
      "regexp": ".*<.*>.*",
      "kind": "StringMayBeHTML"
    },
    {
      "regexp": "https?://[a-zA-Z0-9\\-./]+",
      "kind": "StringMayBeURL"
    }
  ]
}
```

**什么意思**：如果代码中有一个字符串 `"AKIAIOSFODNN7EXAMPLE"`，Pysa 会自动把它标记为 `AWSAccessKey` source。如果这个字符串流入了日志记录 sink，就会触发硬编码凭据规则。

### 2.7 String Combine Rules（字符串组合规则）

这是 Pysa 的独特功能。它能检测两个不同来源的字符串拼接后流入 sink 的情况：

```json
"string_combine_rules": [
  {
    "name": "SQL injection via string concatenation",
    "code": 5051,
    "pattern": "{StringMayBeSQL}{UserControlled}",
    "output": "SQL",
    "message_format": "..."
  },
  {
    "name": "XSS via string concatenation",
    "code": 5052,
    "pattern": "{StringMayBeHTML}{UserControlled}",
    "output": "XSS",
    "message_format": "..."
  },
  {
    "name": "SSRF via string concatenation",
    "code": 5053,
    "pattern": "{StringMayBeURL}{UserControlled}",
    "output": "HTTPClientRequest_URI",
    "message_format": "..."
  }
]
```

**直觉理解**：

想象这段代码：
```python
query = "SELECT * FROM users WHERE name = '" + user_input + "'"
cursor.execute(query)
```

普通的规则可能只看到 `user_input`（UserControlled） → `cursor.execute`（SQL），但 string_combine_rule 还能识别到 `"SELECT..."`（StringMayBeSQL）和 `user_input`（UserControlled）被拼接了。

---

## 三、.pysa 文件详解

### 3.1 文件用途

`.pysa` 文件告诉 Pysa："这个具体的 Python 函数是什么角色——是 source、sink 还是 sanitizer？" 
没有 `.pysa` 文件，`taint.config` 中定义的 source/sink 名字就没有落脚点。

### 3.2 核心安全模型文件

#### 3.2.1 general.pysa（通用模型）

这个文件定义了跨框架的基础模型：

```python
# 字符串拼接的 TITO（污点传入传出）+ 特征
@SkipObscure
def str.__add__(
    self: TaintInTaintOut[Via[string_concat_lhs]],
    other: TaintInTaintOut[Via[string_concat_rhs]]
): ...

# XML 解析器 sink（XXE 风险）
def xml.etree.ElementTree.fromstring(text: TaintSink[XMLParser]): ...
def xml.etree.ElementTree.parse(source: TaintSink[XMLParser]): ...
def xml.dom.minidom.parseString(string: TaintSink[XMLParser]): ...
def xml.dom.minidom.parse(file: TaintSink[XMLParser]): ...

# getattr sink（反射攻击）
def getattr(__o, name: TaintSink[GetAttr]): ...

# BytesIO：把 TITO 加上 bytesio feature
def io.BytesIO.__init__(self, initial_bytes: TaintInTaintOut[Via[bytesio]]): ...
def io.BytesIO.getvalue(self: TaintInTaintOut[Via[bytesio]]): ...

# HMAC：加 hmac feature
def hmac.new(key: TaintInTaintOut[Via[hmac]], msg, digestmod): ...

# URL 编码：加 urlencode feature
def urllib.parse.quote_plus(string: TaintInTaintOut[Via[urlencode]]): ...

# 异常作为信息泄露源
def BaseException.__init__(self, *args: TaintSource[ExceptionMessage]): ...
def BaseException.__str__(self: TaintSource[ExceptionMessage]): ...

# 命令行参数作为 source
def argparse.ArgumentParser.parse_args(self) -> TaintSource[CLIUserControlled]: ...
def argparse.ArgumentParser.parse_known_args(self) -> TaintSource[CLIUserControlled]: ...

# 正则验证 feature
def re.fullmatch(pattern, string: TaintInTaintOut[Via[re_match]], flags = ...): ...
def re.match(pattern, string: TaintInTaintOut[Via[re_match]], flags = ...): ...
```

#### 3.2.2 rce_sinks.pysa（远程代码执行 Sink）

这是最重要的 sink 集合之一，定义了所有可能执行任意代码的函数：

```python
# eval/exec —— 直接代码执行
def eval(__source: TaintSink[RemoteCodeExecution]): ...
def exec(__source: TaintSink[RemoteCodeExecution]): ...

# 动态导入
def importlib.import_module(name: TaintSink[RemoteCodeExecution]): ...
def importlib.__import__(
    name: TaintSink[RemoteCodeExecution],
    package: TaintSink[RemoteCodeExecution]
): ...

# pickle 反序列化 —— 带版本条件
if sys.version >= (3, 8, 0):
  def pickle.loads(
    __data: TaintSink[ExecDeserializationSink, FileContentDeserializationSink],
    *, fix_imports, encoding, errors, buffers
  ): ...
else:
  def pickle.loads(
    data: TaintSink[ExecDeserializationSink, FileContentDeserializationSink],
    *, fix_imports, encoding, errors
  ): ...

# yaml.load —— 不安全的 YAML 加载
def yaml.load(
    stream: TaintSink[ExecDeserializationSink, FileContentDeserializationSink],
    Loader
): ...

# subprocess —— 带 ViaTypeOf 和 ViaValueOf 特征
def subprocess.run(
    args: TaintSink[RemoteCodeExecution, ViaTypeOf[args], ViaValueOf[shell]],
    **kwargs
): ...
def subprocess.call(
    args: TaintSink[RemoteCodeExecution, ViaTypeOf[args], ViaValueOf[shell]],
    **kwargs
): ...
def subprocess.Popen.__init__(
    self,
    args: TaintSink[RemoteCodeExecution, ViaTypeOf[args], ViaValueOf[shell]],
    **kwargs
): ...
```

**关于 ViaTypeOf 和 ViaValueOf**：

`ViaValueOf[shell]` 会记录 `shell` 参数的实际值。这让后续审查时能看到：
- `subprocess.run(cmd, shell=True)` → feature `via-shell:True`（高风险）
- `subprocess.run(cmd, shell=False)` → feature `via-shell:False`（较低风险）

#### 3.2.3 django_sources_sinks.pysa（Django 框架模型）

这是最大的单一模型文件之一（148 行），覆盖了 Django 的主要数据入口和出口：

**Sources（用户输入入口）**：
```python
# HttpRequest 的各种属性都是 UserControlled source
django.http.request.HttpRequest.COOKIES: TaintSource[Cookies, UserControlled] = ...
django.http.request.HttpRequest.META: TaintSource[UserControlled] = ...
django.http.request.HttpRequest.FILES: TaintSource[UserControlled, Via[request_files]] = ...
django.http.request.HttpRequest.GET: TaintSource[UserControlled] = ...
django.http.request.HttpRequest.POST: TaintSource[UserControlled] = ...
django.http.request.HttpRequest.body: TaintSource[UserControlled] = ...

# URL 也是 source
django.http.request.HttpRequest.path: TaintSource[URL, UserControlled] = ...
django.http.request.HttpRequest.path_info: TaintSource[URL, UserControlled] = ...

# 请求头
django.http.request.HttpRequest.headers: TaintSource[HeaderData, UserControlled] = ...
django.http.request.HttpRequest.content_type: TaintSource[HeaderData, UserControlled] = ...
```

**Sinks（输出危险点）**：
```python
# HttpResponse 的 content_type 是 ResponseHeaderValue sink
def django.http.response.HttpResponseBase.__init__(
    self,
    content_type: TaintSink[ResponseHeaderValue] = ...,
    headers: TaintSink[ResponseHeaderName, ResponseHeaderValue] = ...
): ...
```

#### 3.2.4 filesystem_sinks.pysa（文件系统操作）

```python
# 文件打开 —— 同时作为 sink 和 TITO（读取文件内容 → 返回值）
def open(
    file: TaintSink[FileSystem_ReadWrite, ViaValueOf[mode, WithTag["file-open-mode"]]],
    mode
): ...
def open(file: TaintInTaintOut[Via[external_query], Via[filesystem_operation]]): ...
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...

# pathlib.Path
def pathlib.Path.open(
    self: TaintSink[FileSystem_ReadWrite, ViaValueOf[mode, WithTag["file-open-mode"]]],
    mode
): ...
def pathlib.Path.read_text(self: TaintSink[FileSystem_ReadWrite]): ...
def pathlib.Path.write_bytes(self: TaintSink[FileSystem_ReadWrite]): ...

# zip/gzip/tar
def zipfile.ZipFile.__init__(
    self, file: TaintSink[FileSystem_ReadWrite, ViaValueOf[mode, WithTag["file-open-mode"]]],
    mode
): ...
```

**注意多重模型**：`open` 函数有 3 个定义！这不是冲突，而是同时声明了：
1. 它是一个 FileSystem_ReadWrite sink（路径可被控制 → 任意文件读写）
2. 它有 TITO 行为（文件路径 → 返回的文件内容，带 filesystem_operation 特征）
3. 它有 Transform[FileOperation]（用于跨规则的变换追踪）

#### 3.2.5 filesystem_other_sinks.pysa（文件系统其他操作）

覆盖了不涉及"读写文件内容"但涉及文件系统操作的函数：

```python
def shutil.copyfile(src: TaintSink[FileSystem_Other], dst: TaintSink[FileSystem_Other]): ...
def os.remove(path: TaintSink[FileSystem_Other]): ...
def os.rename(src: TaintSink[FileSystem_Other], dst: TaintSink[FileSystem_Other]): ...
def os.mkdir(path: TaintSink[FileSystem_Other]): ...
def os.makedirs(name: TaintSink[FileSystem_Other]): ...
def os.rmdir(path: TaintSink[FileSystem_Other]): ...
def os.walk(top: TaintSink[FileSystem_Other]): ...
def os.chmod(path: TaintSink[FileSystem_Other]): ...
def os.chown(path: TaintSink[FileSystem_Other]): ...
def os.chdir(path: TaintSink[FileSystem_Other]): ...
def os.chroot(path: TaintSink[FileSystem_Other]): ...
def os.putenv(__name: TaintSink[FileSystem_Other], __value: TaintSink[FileSystem_Other]): ...
```

#### 3.2.6 requests_api_sinks.pysa（HTTP 请求库）

这是行数最多的模型文件（608行），覆盖了 `requests` 库的所有 API 方法：

```python
@Sanitize(TaintInTaintOut[TaintSource[ServerSecrets]])
def requests.api.request(
    method: TaintSink[HTTPClientRequest_METADATA],
    url: TaintSink[HTTPClientRequest_URI],
    params: TaintSink[HTTPClientRequest_DATA] = ...,
    data: TaintSink[HTTPClientRequest_DATA] = ...,
    headers: TaintSink[HTTPClientRequest_METADATA] = ...,
    cookies: TaintSink[HTTPClientRequest_METADATA] = ...,
    auth: TaintSink[Authentication] = ...,
    json: TaintSink[HTTPClientRequest_DATA] = ...
) -> TaintSource[DataFromInternet]: ...
```

**关键设计**：
1. `url` 参数是 `HTTPClientRequest_URI` sink（SSRF 检测）
2. `data`/`json` 参数是 `HTTPClientRequest_DATA` sink（请求数据注入）
3. 返回值是 `DataFromInternet` source（来自互联网的不可信数据）
4. `@Sanitize(TaintInTaintOut[TaintSource[ServerSecrets]])` 表示：即使请求中带了 ServerSecrets（如 API Key），响应也不会把密钥泄露出去

#### 3.2.7 sanitizers.pysa（消毒器）

```python
# len() 返回数字，不可能包含恶意字符串
@Sanitize
def len(o): ...

# type() 返回类型对象
@Sanitize
def type.__init__(self, o): ...
@Sanitize
def type.__new__(cls, o): ...
```

消毒器告诉 Pysa："数据经过这个函数后就安全了"。`len(user_input)` 返回一个整数，不可能用于 SQL 注入或 RCE。

#### 3.2.8 user_reach_sinks.pysa（用户触达功能）

```python
# 邮件发送
def smtplib.SMTP.sendmail(self, from_addr: TaintSink[EmailSend], to_addrs: TaintSink[EmailSend], msg: TaintSink[EmailSend]): ...
def django.core.mail.send_mail(subject: TaintSink[EmailSend], message: TaintSink[EmailSend], ...): ...

# MIME 消息
def email.mime.text.MIMEText.__init__(self, _text: TaintSink[EmailSend]): ...
def email.mime.image.MIMEImage.__init__(self, _imagedata: TaintSink[EmailSend]): ...
```

### 3.3 通用基础模型文件

#### 3.3.1 builtin_functions.pysa

定义 Python 内置函数的 TITO 行为：

```python
# typing.cast：保持原样传递，不折叠
@SkipObscure
def typing.cast(typ, val: TaintInTaintOut[LocalReturn, NoCollapse]): ...

# copy/deepcopy：保持原样传递
@SkipObscure
def copy.copy(x: TaintInTaintOut[LocalReturn, NoCollapse]): ...
@SkipObscure
def copy.deepcopy(x: TaintInTaintOut[LocalReturn, NoCollapse]): ...

# sorted：集合所有元素 → 返回集合所有元素
@SkipObscure
def sorted(
    __iterable: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[_.all()], NoCollapse]
): ...

# reversed 类似
@SkipObscure
def reversed.__new__(
    cls, sequence: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[_.all()], NoCollapse], /
): ...

# object.__class__：清除污点（类对象本身不携带数据）
@SkipObscure
@Sanitize
@property
def object.__class__(): ...
```

**关键概念**：
- `ParameterPath[_.all()]`：参数的所有元素
- `ReturnPath[_.all()]`：返回值的所有元素
- `NoCollapse`：不折叠深层路径信息
- `@SkipObscure`：不把这个函数当作"不透明"函数

#### 3.3.2 collection_propagation.pysa

这是最大的基础文件（775行），定义了 list、dict、set、tuple 等所有容器类型的污点传播行为。例如：

```python
# list.append：参数流入 list 的元素
def list.append(self, __object: TaintInTaintOut[LocalReturn, ParameterPath[], ReturnPath[_.all()]]): ...

# dict.__getitem__：key 对应的值流出
def dict.__getitem__(self: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[]]): ...

# dict.update：参数的所有键值对流入 dict
def dict.update(self, __m: TaintInTaintOut[LocalReturn, ParameterPath[_.all()], ReturnPath[_.all()]]): ...
```

---

## 四、规则分类体系

### 4.1 注入类漏洞

| 规则 | 代码 | Source → Sink |
|------|------|---------------|
| Shell 注入 | 5001 | UserControlled → RemoteCodeExecution |
| SQL 注入 | 5005 | UserControlled → SQL |
| LDAP 注入 | 6303 | UserControlled → LDAPInjection |
| SSTI | 6073 | UserControlled → ServerSideTemplateInjection |
| 格式字符串 | 5034 | UserControlled → FormatString |

### 4.2 数据泄露类

| 规则 | 代码 | Source → Sink |
|------|------|---------------|
| 密钥泄露 | 5027 | ServerSecrets → 多种 sink |
| 异常信息泄露 | 6302 | ExceptionMessage → XSS/Redirect |
| 硬编码凭据 | 6074 | AWSAccessKey/GoogleAPIKey → Logging |

### 4.3 SSRF/重定向

| 规则 | 代码 | Source → Sink |
|------|------|---------------|
| SSRF | 5012 | UserControlled → HTTPClientRequest_URI |
| 开放重定向 | 5018 | UserControlled → Redirect |

### 4.4 反序列化

| 规则 | 代码 | Source → Sink |
|------|------|---------------|
| 反序列化 | 5067 | UserControlled → ExecDeserializationSink |
| 文件反序列化 RCE | 6066 | DataFromInternet → ExecDeserializationSink |

### 4.5 文件系统

| 规则 | 代码 | Source → Sink |
|------|------|---------------|
| 文件读写 | 5011 | UserControlled → FileSystem_ReadWrite |
| 文件系统其他 | 6060 | UserControlled → FileSystem_Other |
| 文件操作变换 | 6108 | UserControlled → FileSystem_ReadWrite (via Transform) |

### 4.6 DataFromInternet 变体

除了 `UserControlled` 源，Pysa 还有一系列以 `DataFromInternet` 为 source 的"镜像规则"（5301, 5305, 5307...），覆盖"来自互联网的不可信数据"这一场景。这对于 API 集成特别重要——你调用第三方 API 获取的数据也是不可信的。

---

## 五、如何自定义规则

### 5.1 添加新的 Source

1. 在 `taint.config` 的 `sources` 中添加新名字：
```json
{ "name": "DatabaseInput", "comment": "数据库查询结果" }
```

2. 在 `.pysa` 文件中标记具体函数：
```python
def my_db.query(sql) -> TaintSource[DatabaseInput]: ...
```

### 5.2 添加新的 Sink

1. 在 `taint.config` 的 `sinks` 中添加新名字：
```json
{ "name": "CryptoKey", "comment": "加密密钥" }
```

2. 在 `.pysa` 文件中标记具体函数：
```python
def my_crypto.encrypt(key: TaintSink[CryptoKey], data): ...
```

### 5.3 添加新的 Rule

在 `taint.config` 的 `rules` 中配对：
```json
{
  "name": "Untrusted data used as crypto key",
  "code": 9001,
  "sources": ["UserControlled", "DatabaseInput"],
  "sinks": ["CryptoKey"],
  "message_format": "来自 [{$sources}] 的数据流入了加密密钥"
}
```

### 5.4 添加 Sanitizer

```python
# 完全消毒：经过这个函数后，所有污点都被清除
@Sanitize
def my_validator.validate_and_escape(data): ...

# 部分消毒：只清除特定 source/sink
@Sanitize(TaintSource[UserControlled])
def my_filter.remove_user_taint(data): ...
```

### 5.5 使用 ModelQuery 批量生成模型

当你有大量同类函数需要标注时，逐个写 `.pysa` 太麻烦。ModelQuery 允许用规则自动匹配：

```python
ModelQuery(
  name = "mark_all_view_methods_as_entrypoints",
  find = "methods",
  where = [
    cls.extends("django.views.View"),
    name.matches("get|post|put|delete")
  ],
  model = [
    Parameters(TaintSource[UserControlled]),
    Returns(TaintSink[XSS])
  ]
)
```

这一条 ModelQuery 就能自动为所有 Django View 的 HTTP 方法添加模型。

---

## 六、文件统计与覆盖范围

| 类别 | 文件数 | 总行数 | 覆盖的主要库/框架 |
|------|--------|--------|-------------------|
| 安全模型 | 17 | 1658 | Django, requests, pickle, yaml, subprocess, os, sqlite3, xml, smtplib 等 |
| 基础模型 | 5 | 892 | Python 内置函数, list, dict, set, tuple, functools 等 |
| 配置文件 | 2 | ~700 | 30+ sources, 25+ sinks, 30+ features, 40+ rules |
| **合计** | **24** | **~3250** | |

---

## 七、规则仓库的实际使用建议

### 7.1 入门项目：直接使用内置规则

```json
{
  "source_directories": ["."],
  "taint_models_path": "/path/to/pyre-check/stubs/taint"
}
```

指向 pyre-check 仓库的 `stubs/taint` 目录即可获得全部内置规则。

### 7.2 中级项目：内置规则 + 自定义补充

```
stubs/taint/
├── core_privacy_security/    # 拷贝内置规则
├── common/                   # 拷贝基础模型
└── custom/                   # 你的自定义规则
    ├── taint.config          # 扩展的 sources/sinks/rules
    └── my_app.pysa           # 应用特定的函数模型
```

Pysa 会自动合并同一 `taint_models_path` 下所有子目录中的配置和模型。

### 7.3 高级项目：完全自定义

从头构建自己的规则仓库，只定义项目需要的 sources、sinks 和 rules。好处是减少噪音（不相关规则产生的误报），坏处是需要更多前期工作。

---

## 八、理解规则仓库的关键概念

### 8.1 多重标注

同一个函数可以同时是 source 和 sink，或者同时有 TITO 行为：
```python
# open() 既是 sink（路径可控 → 任意文件读写），又有 TITO（路径 → 文件内容）
def open(file: TaintSink[FileSystem_ReadWrite], mode): ...
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...
```

### 8.2 条件模型

基于 Python 版本的条件模型：
```python
if sys.version >= (3, 8, 0):
    def pickle.loads(__data: TaintSink[ExecDeserializationSink], *, fix_imports, encoding, errors, buffers): ...
else:
    def pickle.loads(data: TaintSink[ExecDeserializationSink], *, fix_imports, encoding, errors): ...
```

### 8.3 属性模型

不只是函数，对象属性也可以是 source：
```python
django.http.request.HttpRequest.GET: TaintSource[UserControlled] = ...
email.message.Message.preamble: TaintSink[EmailSend] = ...
```

### 8.4 Transforms（变换）

Transform 是一种特殊的中间标记，用于跟踪数据经过什么操作：
```python
def open(file: TaintInTaintOut[Transform[FileOperation]]): ...
```

配合规则中的 transform 字段，可以构建更精细的检测逻辑——比如"用户输入 → 文件路径 → 文件读取 → 文件内容 → 反序列化"这种多步骤的攻击链。

---

## 九、规则仓库与 OWASP Top 10 的映射

内置规则仓库对 OWASP Top 10 (2021) 的覆盖情况：

| OWASP 类别 | 风险描述 | 对应 Pysa 规则 | 覆盖说明 |
|-----------|----------|---------------|---------|
| A01 访问控制失效 | 越权访问 | 无直接规则 | 需要业务逻辑层面的自定义规则 |
| A02 加密机制失效 | 敏感数据暴露 | 5027(密钥泄露), 6074(硬编码凭据), 6302(异常信息泄露) | 部分覆盖：可检测密钥泄露和信息泄露 |
| A03 注入 | SQL/OS/LDAP 注入 | 5001(RCE), 5005(SQLi), 5008(XSS), 6303(LDAP), 6073(SSTI) | 全面覆盖：这是 Pysa 最擅长的领域 |
| A04 不安全设计 | 设计层面缺陷 | 无直接规则 | 超出静态分析能力范围 |
| A05 安全配置错误 | 错误的安全配置 | 6306(Thrift配置) | 有限覆盖：主要靠人工审查 |
| A06 过时组件 | 使用有漏洞的库 | 无直接规则 | 需要配合依赖扫描工具（如 Safety/pip-audit） |
| A07 认证失效 | 认证机制缺陷 | Authentication sink | 有限覆盖：可追踪认证凭据的数据流 |
| A08 数据完整性失效 | 反序列化攻击 | 5067(反序列化), 6066(文件反序列化RCE) | 良好覆盖：pickle、yaml 等反序列化均有模型 |
| A09 日志和监控不足 | 日志记录不当 | Logging sink | 可检测敏感数据流入日志 |
| A10 SSRF | 服务端请求伪造 | 5012(SSRF), 5053(字符串拼接SSRF) | 良好覆盖：requests 库有完整模型 |

**关键启示**：Pysa 对注入类漏洞（A03）和反序列化（A08）的覆盖最为全面，这正是污点分析的天然优势。对于设计层面（A04）和配置层面（A05）的问题，需要配合其他工具和人工审查。

---

## 十、规则仓库的演进与维护策略

### 10.1 何时需要更新规则仓库

以下场景触发规则仓库更新：

1. **引入新框架**：项目新增了一个 Web 框架（如从 Flask 迁移到 FastAPI），需要添加对应的 source/sink 模型
2. **发现新漏洞模式**：安全审计中发现了一种内置规则未覆盖的漏洞模式
3. **pyre-check 升级**：新版本可能更改内置模型的语法或行为
4. **误报积累**：某类误报频繁出现，需要补充 Sanitizer 模型
5. **Python 版本升级**：标准库的函数签名可能变化，条件模型需要更新

### 10.2 规则仓库的版本管理建议

将规则仓库纳入 Git 管理，每次变更都记录：
- **变更原因**：为什么要改（安全事件/误报/新框架）
- **影响范围**：新增/修改了哪些规则
- **验证方法**：如何确认变更生效（测试用例）

---

## 十一、总结

Pysa 的规则仓库是一个精心组织的安全知识库，将安全专家的经验编码成机器可读的格式。理解它的关键是：

1. **`taint.config` 定义"词汇"**：什么叫 source、什么叫 sink、什么组合是危险的
2. **`.pysa` 文件实现"落地"**：把抽象词汇映射到具体的 Python 函数
3. **两者缺一不可**：只有 `taint.config` 没有 `.pysa` = 有规则但没人执行；只有 `.pysa` 没有 `taint.config` 中的匹配规则 = 标记了但不报警
4. **内置仓库是起点而非终点**：覆盖了 OWASP Top 10 中大部分 Python 相关的漏洞类型，但项目特定的框架和业务逻辑需要通过自定义扩展
5. **维护是持续过程**：随着项目演进、框架更新和新漏洞模式的出现，规则仓库需要不断迭代完善

记住一个核心公式：**检测能力 = 规则全面性 × 模型准确性**。规则定义了"什么是问题"，模型定义了"问题在哪里"——两者的乘积决定了 Pysa 能发现多少真实漏洞。
