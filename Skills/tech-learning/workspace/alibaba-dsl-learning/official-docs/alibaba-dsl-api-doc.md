## 概述

阿里巴巴 DSL API 提供 DSL 规则和名单验证服务，支持 Java 和 JavaScript 两种语言。用户通过上传压缩包（tar格式）来验证规则的正确性。


## API 接口

注意：当前环境下，需要使用类似以下的二进制流方式向api发送数据。对于之后所有 POST /api/v1/verify 的命令，都需要采用以下方式

```
WS_DIR=$(mktemp -d) && mkdir -p "$WS_DIR/rosters" && \
echo "UnVsZSBUZXN0UnVsZSBleHRlbmRzIEFic3RyYWN0VGFpbnRSdWxlIHsKICAgIHR5cGUgPSAiVGVzdCI7CiAgICBzdWJUeXBlID0gIlRlc3RSdWxlIjsKCiAgICAvLyDmupDlrprkuYkKICAgIHNvdXJjZS5tZXRob2RSZXR1cm4gKz0gewogICAgICAgIHByZWNpc2UgPSB0cnVlOwogICAgICAgIHZhbHVlID0gImNvbS5leGFtcGxlLlNvdXJjZS5tZXRob2QiOwogICAgfTsKCiAgICAvLyDmsYflrprkuYkKICAgIHNpbmsubWV0aG9kQXJnICs9IHsKICAgICAgICBwcmVjaXNlID0gdHJ1ZTsKICAgICAgICB2YWx1ZSA9ICJjb20uZXhhbXBsZS5TaW5rLm1ldGhvZCI7CiAgICB9Owp9Cg==" | base64 -d > "$WS_DIR/30001.rul" && \
tar -cf "$WS_DIR/config.tar" -C "$WS_DIR" 30001.rul && \
# 使用 --data-binary 手动发送 Body，避开 curl -F 的复杂特征
(
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"language\""
  echo ""
  echo "java"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"verify_type\""
  echo ""
  echo "rule"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"rule_id\""
  echo ""
  echo "30001"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\""
  echo "Content-Type: application/octet-stream"
  echo ""
  cat "$WS_DIR/config.tar"
  echo ""
  echo "--bound--"
) > "$WS_DIR/payload.bin"

curl -v --noproxy "*" \
  --http1.0 \
  -H "Content-Type: multipart/form-data; boundary=bound" \
  --data-binary "@$WS_DIR/payload.bin" \
  "http://43.106.136.189:8081/api/v1/verify" ; \
rm -rf "$WS_DIR"
```

### 1. 验证接口

**请求**

```Markdown
POST http://43.106.136.189:8081/api/v1/verify
Content-Type: multipart/form-data
```

**参数说明**

|参数名|类型|必填|说明|
|-|-|-|-|
|file|File|是|tar格式的压缩包文件|
|language|String|是|语言类型：`java` 或 `javascript`|
|verify_type|String|是|验证类型：`rule` 或 `roster`|
|rule_id|Integer|条件必填|规则ID，当 `verify_type=rule` 时必填|
|roster_name|String|条件必填|名单名称，当 `verify_type=roster` 时必填|


**请求示例**

```Bash
# Java 规则验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@config.tar" \
  -F "language=java" \
  -F "verify_type=rule" \
  -F "rule_id=6420"

# Java 名单验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@config.tar" \
  -F "language=java" \
  -F "verify_type=roster" \
  -F "roster_name=Java_cmdi_propagate_0"

# JavaScript 规则验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@js-config.tar" \
  -F "language=javascript" \
  -F "verify_type=rule" \
  -F "rule_id=6991"

# JavaScript 名单验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@js-config.tar" \
  -F "language=javascript" \
  -F "verify_type=roster" \
  -F "roster_name=NodeJS_backend_common_source"
```

### 2. 健康检查接口

**请求**

```Http
GET /api/v1/health
```

**响应示例**

```JSON
{
  "code": 0,
  "message": "success",
  "data": {
    "status": "healthy",
    "version": "1.0.0"
  }
}
```

## 响应格式

### 成功响应

```JSON
{
  "code": 0,
  "message": "success",
  "data": {
    "output": "验证结果内容",
    "execution_time_ms": 1500
  }
}
```

### 错误响应

```JSON
{
  "code": 10001,
  "message": "invalid file format",
  "data": null
}
```

## 错误码说明

|错误码|说明|
|-|-|
|0|成功|
|10001|文件格式无效|
|10002|语言类型无效|
|10003|验证类型无效|
|10004|缺少 rule_id|
|10005|缺少 roster_name|
|10006|文件大小超限|
|10007|参数无效|
|20001|tar文件解压失败|
|20002|目录结构无效|
|20003|检测到路径遍历攻击|
|20004|文件未找到|
|30001|临时目录创建失败|
|30002|验证脚本未找到|
|30003|验证脚本执行超时|
|30004|验证结果读取失败|
|40001|内部服务器错误|
|40002|配置加载失败|


---

## 压缩包结构

压缩包必须是 **tar 格式**，内部目录结构根据验证类型有所不同。

### 规则验证 (verify_type=rule)

**必需结构：**

```Markdown
config.tar
├── xxx.rul              # 必需：至少一个 .rul 规则文件
├── extend-file/         # 可选：扩展Java/JS文件目录
│   └── {rule_id}/
│       └── CustomClass.java
├── rosters/             # 可选：名单目录
│   └── xxx.ros
└── relation/            # 可选：关系配置目录
    └── config_roster_relation.json
```

**验证要求：**

- 根目录必须包含至少一个 `.rul` 文件
- `.rul` 文件名应与 `rule_id` 对应（如 `6420.rul`）
- `extend-file/` 目录用于存放自定义扩展类
- `rosters/` 和 `relation/` 目录为可选

### 名单验证 (verify_type=roster)

**必需结构：**

```Markdown
config.tar
├── xxx.rul              # 可选：规则文件
├── rosters/             # 必需：名单目录
│   └── xxx.ros          # 必需：至少一个 .ros 名单文件
└── extend-file/         # 可选：扩展文件目录
    └── rosters/
        └── {roster_name}/
            └── CustomClass.java
```

**验证要求：**

- 必须包含 `rosters/` 目录
- `rosters/` 目录内必须包含至少一个 `.ros` 文件
- `.ros` 文件名应与 `roster_name` 对应

---

## 文件格式详解

### 规则文件 (.rul)

规则文件定义静态分析规则，基本格式如下：

#### Java 规则文件示例

```Java
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";

    // 源定义
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };

    // 汇定义
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.method";
    };

    // 导入名单
    import roster Java_common_source;
    import roster Java_cmdi_propagate;
}
```

#### JavaScript/TypeScript 规则文件示例

```TypeScript
Rule XssTs_6991 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";

    // 导入名单
    import roster NodeJS_backend_common_source;
    import roster NodeJS_backend_XssTs_sanitizer;

    // 源定义 - 支持正则表达式匹配
    source.methodReturn += {
        precise = false;
        value = "\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b";
    };

    // XPath条件表达式
    source.paramDecorator += {
        value = "/@Query\\b/";
    };

    // 分组配置 - 针对不同平台
    group cocktail_handler {
        includePlatforms = "cocktail";
        source.customSourceFunc = loadclass("NodeJS_backend_common_source.customSourceFunc_0");
    };
}
```

### 名单文件 (.ros)

名单文件定义可复用的配置集合，基本格式如下：

#### Java 名单文件示例

```Java
Roster Java_cmdi_propagate {
    // 污点净化器
    sanitizer.methodReturn += {
        value = "com.alibaba.security.SecurityUtil.getSafeCommandLine";
    };

    // 分组配置
    group AllPlatforms {
        includePlatforms = "*";
        excludePlatforms = "legacy";
        sanitizer.methodReturn += {
            value = "com.example.Sanitizer.sanitize";
        };
    };
}
```

#### JavaScript/TypeScript 名单文件示例

```TypeScript
Roster NodeJS_backend_common_source {
    // 源定义 - 支持多种匹配方式
    source.methodReturn += {
        precise = false;
        value = "\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b";
    };

    // 参数装饰器源
    source.paramDecorator += {
        value = "/@Query\\b/|/@Param\\b/";
    };

    // 自定义源函数
    source.customSourceFunc = loadclass("NodeJS_backend_common_source.customSourceFunc_0");

    // 分组配置
    group cocktail_handler {
        includePlatforms = "cocktail";
        source.customSourceFunc = loadclass("NodeJS_backend_common_source.customSourceFunc_0");
    };
}
```

---

## 创建压缩包

### 使用 tar 命令

```Bash
# 从目录创建压缩包
tar -cvf config.tar -C /path/to/config/directory .

# 示例：创建规则验证压缩包
tar -cvf rule-config.tar -C ./resources/stae/Dsl-test/config07 .

# 示例：创建名单验证压缩包
tar -cvf roster-config.tar -C ./resources/stae/Dsl-test/config06 .
```

### 目录结构示例

**Java 规则验证示例 (config07)：**

```Markdown
config07/
├── 6420.rul             # SSRF Hook规则
├── 9736.rul             # 其他规则
├── extend-file/
│   ├── 6420/
│   │   └── SSRFHookWithoutInitSrcTest.java
│   └── rosters/
│       └── Java_common_source_0/
│           └── CarrySource.java
├── rosters/
│   ├── Java_common_source_0.ros
│   └── Java_cmdi_propagate_0.ros
└── relation/
    └── config_roster_relation.json
```

**Java 名单验证示例 (config06)：**

```Markdown
config06/
├── extend-file/
│   └── rosters/
│       └── Java_common_propagate_0/
│           └── ThreadPoolUserDefineInvoke.java
├── rosters/
│   ├── Java_cmdi_propagate_0.ros    # 正确的名单
│   ├── Java_cmdi_propagate_1.ros    # 解析错误示例
│   └── Java_cmdi_propagate_2.ros    # 词法错误示例
└── relation/
    └── config_roster_relation.json
```

**JavaScript 规则验证示例 (backend-subset0)：**

```Markdown
backend-subset0/
├── 6991.rul             # XSS规则
├── 6997.rul             # CSRF规则
├── extend-file/
│   ├── 6991/
│   │   └── XssTs_6991.js            # 自定义验证逻辑
│   └── rosters/
│       └── NodeJS_backend_common_source_0/
│           └── NodeJS_backend_common_source.js
├── rosters/
│   ├── NodeJS_backend_common_source_0.ros
│   └── NodeJS_backend_XssTs_sanitizer_0.ros
└── relation/
    ├── actual_use_config.json
    └── config_addition_relation.json
```

**JavaScript 名单验证示例：**

```Markdown
backend-subset0/
├── extend-file/
│   └── rosters/
│       └── NodeJS_backend_common_source_0/
│           └── NodeJS_backend_common_source.js
├── rosters/
│   ├── NodeJS_backend_common_source_0.ros
│   ├── NodeJS_backend_sqlInjectionTs_sink_0.ros
│   └── NodeJS_backend_ssrfTs_sink_0.ros
└── relation/
    └── config_addition_relation.json
```

---

## 验证结果说明

### 成功验证

当验证通过时，`output` 字段为空或 `[]`：

```JSON
{
  "code": 0,
  "message": "success",
  "data": {
    "output": "",
    "execution_time_ms": 500
  }
}
```

### 验证失败

当验证发现错误时，`output` 返回 JSON 数组格式的错误信息：

```JSON
{
  "code": 0,
  "message": "success",
  "data": {
    "output": "[{\"template_key\":\"stae-java-78\",\"values\":[\"2\",\"2\",\"abc\"],\"default_template\":\"Line {}, Column {}: cannot find field by name: {}\",\"type\":\"error\"}]",
    "execution_time_ms": 500
  }
}
```

**错误信息字段说明：**

|字段|说明|
|-|-|
|template_key|错误模板标识|
|values|模板变量值数组|
|default_template|默认错误消息模板|
|type|错误类型（error/warning）|


### 常见错误消息

|错误类型|示例消息|
|-|-|
|解析错误|`Line 4, Column 2: ParseError`|
|词法错误|`Line 1, Column 1: Lexical error`|
|找不到声明|`can not find rule declaration in rule:9738`|
|找不到名单|`can not find roster declaration in roster:xxx`|
|字段错误|`cannot find field by name: xxx`|
|类型错误|`the value should be string type`|
|必填字段|`the field value is required`|
|配置错误|`configure is not modifiable in parent rule`|
|无效格式|`invalid regular expression` / `invalid xpath` / `invalid json`|


---

## 注意事项

### 通用注意事项

1. **文件格式**：压缩包必须是标准 tar 格式，不支持 tar.gz 或 zip
2. **文件大小**：默认最大支持 100MB
3. **执行超时**：验证脚本默认超时时间为 60 秒
4. **路径安全**：压缩包内不允许包含 `..` 路径，防止路径遍历攻击
5. **编码格式**：规则文件建议使用 UTF-8 编码
6. **命名规范**：
    - 规则文件名应与规则ID对应（如 `6420.rul`）
    - 名单文件名应与名单名称对应（如 `Java_cmdi_propagate_0.ros`）

### Java 规则特有说明

1. **文件扩展名**：
    - 规则文件：`.rul`
    - 名单文件：`.ros`
    - 扩展类：`.java`
2. **扩展文件目录结构**：
    - 规则扩展：`extend-file/{rule_id}/CustomClass.java`
    - 名单扩展：`extend-file/rosters/{roster_name}/CustomClass.java`
3. **loadclass 函数**：使用 `loadclass("com.example.CustomClass")` 加载自定义类

### JavaScript/TypeScript 规则特有说明

1. **文件扩展名**：
    - 规则文件：`.rul`
    - 名单文件：`.ros`
    - 扩展类：`.js`
2. **扩展文件目录结构**：
    - 规则扩展：`extend-file/{rule_id}/RuleName_{rule_id}.js`
    - 名单扩展：`extend-file/rosters/{roster_name}/custom.js`
3. **loadclass 函数**：使用 `loadclass("NodeJS_backend_custom.customFunc_0")` 加载自定义函数
4. **正则表达式**：
    - JavaScript 规则中支持使用正则表达式匹配方法名
    - 使用 `\b` 表示单词边界
    - 多个匹配模式使用 `|` 分隔
5. **XPath 表达式**：
    - 支持 XPath 语法匹配代码结构
    - 示例：`/@Query\b/` 匹配带有 Query 装饰器的参数
6. **平台分组**：
    - 使用 `group` 关键字定义针对不同框架的配置
    - 支持的平台：`express`, `koa`, `egg`, `cocktail`, `midway` 等

---

## 快速demo

```Markdown
# 0. 删除目录
rm -rf my-config
# 1. 准备配置目录
mkdir -p my-config/extend-file my-config/rosters

# 2. 创建规则文件
cat > my-config/6420.rul << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.getMethod";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.process";
    };
}
EOF

# 3. 创建压缩包
tar -cvf test-rule.tar -C my-config .

# 4. 调用API验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@test-rule.tar" \
  -F "language=java" \
  -F "verify_type=rule" \
  -F "rule_id=6420"

# 0. 删除目录
rm -rf my-config

# 1. 准备配置目录
mkdir -p my-config/rosters

# 2. 创建名单文件
cat > my-config/rosters/TestRoster.ros << 'EOF'
Roster TestRoster {
    sanitizer.methodReturn += {
        value = "com.example.Sanitizer.clean";
    };
}
EOF

# 3. 创建压缩包
tar -cvf test-roster.tar -C my-config .

# 4. 调用API验证
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@test-roster.tar" \
  -F "language=java" \
  -F "verify_type=roster" \
  -F "roster_name=TestRoster"



```



```Bash
#!/bin/bash

# =====================================================
# JavaScript/TypeScript DSL 验证示例脚本
# =====================================================

# =====================================================
# 第一部分：名单验证示例
# =====================================================

echo "===== 名单验证示例 ====="

# 0. 删除目录
rm -rf js-config

# 1. 准备配置目录
mkdir -p js-config/rosters js-config/extend-file/rosters/NodeJS_backend_custom_0 js-config/relation

# 2. 创建名单文件
cat > js-config/rosters/NodeJS_backend_custom_0.ros << 'EOF'
Roster NodeJS_backend_custom {
    sanitizer.methodReturn += {
        pattern = "escapeHtml|sanitize";
    };
}
EOF

# 3. 创建扩展文件（可选）
cat > js-config/extend-file/rosters/NodeJS_backend_custom_0/custom.js << 'EOF'
let rule = {};
module.exports.rule = rule;

rule.customSanitize_0 = (rule, node, context) => {
    // 自定义净化检查逻辑
    return true;
};
EOF

# 4. 创建关系配置文件（可选，用于规则依赖检查）
cat > js-config/relation/config_addition_relation.json << 'EOF'
{
    "6991": [
        "NodeJS_backend_custom"
    ]
}
EOF

# 创建实际使用的规则ID列表
cat > js-config/relation/actual_use_config.json << 'EOF'
[6991]
EOF

# 5. 创建压缩包
COPYFILE_DISABLE=1 tar -cvf js-test-roster.tar -C js-config .

# 6. 调用API验证名单
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@js-test-roster.tar" \
  -F "language=javascript" \
  -F "verify_type=roster" \
  -F "roster_name=NodeJS_backend_custom_0"

# =====================================================
# 第二部分：规则验证示例
# =====================================================

echo ""
echo "===== 规则验证示例 ====="

# 0. 删除目录
rm -rf js-config

# 1. 准备配置目录
mkdir -p js-config/extend-file/6991 js-config/rosters js-config/relation js-config/relation

# 2. 创建规则文件
cat > js-config/6991.rul << 'EOF'
Rule XssTs_6991 extends AbstractTaintRule {
    import roster NodeJS_backend_common_source;
    type = "Xss";
    subType = "XssTs";
  source.expression += {
    taintTag = "taint_tag_sql";
    value += "/ctx\\.sql$/";
  };
  source.expression += {
    taintTag = "taint_tag_command";
    value += "/ctx\\.command$/";
  };
  sink.methodArg += {
    pattern += "/require\\(['\"]mysql['\"]\\)\\.createConnection\\(([\\s\\S]*)\\)\\.query$/";
    pattern += "/\\b(mysql|model|db|connection|pool|sequelize|conn)\\.query$/";
    pattern += "/\\bmysql\\.get\\(.*?\\)\\.query$/";
    pattern += "/\\bmysql\\b.+\\.query$/";
    paramIndex = 0;
    taintTag = "taint_tag_sql";
  };
}
EOF

# 3. 创建名单文件
cat > js-config/rosters/NodeJS_backend_common_source_0.ros << 'EOF'
Roster NodeJS_backend_common_source {
  source.methodReturn += { value = "/ctx\\.get$/"; };
}
EOF

# 4. 创建扩展文件（可选）
cat > js-config/extend-file/6991/XssTs_6991.js << 'EOF'
const logger = require("../logger");

let rule = {};
module.exports.rule = rule;

rule.userDefineFunc = (rule, node, context) => {
    // 自定义验证逻辑
    return false;
};
EOF

# 5. 创建关系配置文件（可选，用于规则依赖检查）
cat > js-config/relation/config_addition_relation.json << 'EOF'
{
    "6991": [
        "NodeJS_backend_common_source_0"
    ]
}
EOF

# 6. 创建压缩包
COPYFILE_DISABLE=1 tar -cvf js-test-rule.tar -C js-config .

# 7. 调用API验证规则
curl -X POST http://43.106.136.189:8081/api/v1/verify \
  -F "file=@js-test-rule.tar" \
  -F "language=javascript" \
  -F "verify_type=rule" \
  -F "rule_id=6991"

# 清理
rm -rf js-config


```

## 技术支持

如有问题，请联系开发团队或查看项目文档。



