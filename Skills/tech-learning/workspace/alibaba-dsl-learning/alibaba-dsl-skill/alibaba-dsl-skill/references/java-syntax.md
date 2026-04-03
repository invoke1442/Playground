# Alibaba DSL — Java 语法参考

> 所有语法均经 verify API 验证。❌ = 实验证实不支持。

## Roster-Centric 架构

**Rule = 入口 (type + subType + import)**，**Roster = 所有语义 (source/sink/sanitizer)**。Rule 通过 `import roster X;` 引入 Roster（运行时生效），同时需要 `relation/config_roster_relation.json`（verify 阶段文件发现）。

## Rule 语法

```java
Rule <RuleName> extends AbstractTaintRule {
    import roster <RosterName>;  // 必须在最前面，运行时引入 Roster
    import roster <AnotherRoster> exclude <GroupName>;  // 可选: 排除特定 group
    type = "<VulnType>";       // 必填
    subType = "<SubType>";     // 必填

    // 可选: general 配置
    general.userDefinePatternClass += {
        userDefineClass = loadclass("com.taobao.customrule.ClassName");  // Java loadclass
    };

    // 可选: define/delete/modifiable (覆盖场景)
    define myVar = "com.example.Value";
    modifiable source.methodReturn;
    delete source.methodReturn;
}
```

`import roster` 必须写在 Rule 体**最前面**（所有其他字段之前）[imp2✅ imp14❌ imp15❌]。多个 import 可连续写 [imp11✅]。
import 引用 Roster **声明名**（非文件名）[imp4❌ imp10❌]。
import 支持 **exclude** 语法: `import roster X exclude GroupName;` 或 `import roster X exclude A,B;` (逗号分隔) [configs_v3.3 产品规则验证]。
Relation config 仅保证 verify 通过，不等于运行时链接 [imp9✅ verify通过但无 import 则 Roster 不生效]。

Rule 中**不应**内联定义 source/sink/sanitizer — 放入 Roster。

## Roster 语法

```java
// 文件名: {Name}_0.ros, 声明名: Roster {Name} (不带 _0)
Roster <RosterName> {
    // Source — 块语法
    source.methodReturn += { precise = true; value = "pkg.Class.method"; };
    source.methodArg += { precise = true; value = "pkg.Class.method"; };

    // Source — 字符串语法 (Roster 专属, 不能用块)
    source.param_annotation = "pkg.Annotation";           // 注解参数 [w01b]
    source.method_annotation += "pkg.MethodAnnotation";   // 注解方法 [w03b]
    source.method_param = "pkg.Class.method[0]";          // 方法参数 [w05b]
    source.expression = "pkg.Class.method";               // 表达式 [w08b]

    // Source — 产品规则新增 block 字段
    source.paramAnnotation += { precise = true; value = "FQN"; excludeTag = "tag"; };  // camelCase!
    source.mvcMapping += { precise = true; value = "regex"; flag = "flagName"; };

    // Sink — 块语法 (支持 param JSON)
    sink.methodArg += { precise = true; value = "pkg.Class.method"; };
    sink.methodArg += { value = "pkg.Class.method"; param = "[{'position':0,'tainted':true}]"; };
    sink.allocArg += { precise = true; value = "pkg.Class"; };  // 构造器参数
    sink.methodObject += { precise = true; value = "pkg.Class.method"; };  // 方法对象
    // Sink — 字符串语法 (Roster 专属)
    sink.expression = "pkg.Class.evaluate";               // [x01]
    sink.param_annotation = "javax.inject.Inject";        // [x04]
    sink.method_annotation = "org.spring.PostMapping";    // [x05]
    sink.method_param = "pkg.Class.method[0]";            // [x06]
    sink.methodReturn = "pkg.Class.getResult";            // [x08] ⚠️ 仅 string, 块语法报错!
    sink.customSinkFunc = "pkg.Class.customCheck";        // [x09] 仅 string (loadclass 不可用)

    // Sanitizer — 块语法
    sanitizer.methodReturn += { value = "pkg.Class.method"; };
    sanitizer.methodArg += { precise = true; value = "pkg.Class.method"; };
    sanitizer.safeTypes += { precise = true; value = "pkg.SafeType"; excludeTag = "tag"; };
    sanitizer.methodRedirectCheck += { precise = true; value = "pkg.Class.check"; };
    // Sanitizer — 字符串语法 (Roster 专属)
    sanitizer.expression = "pkg.Class.validate";           // [x11]
    sanitizer.param_annotation = "javax.Valid";            // [x13]
    sanitizer.method_annotation = "org.spring.Validated";  // [x14]
    sanitizer.method_param = "pkg.Class.clean[0]";         // [x15]
    sanitizer.customSanitizerFunc = "pkg.Class.sanitize";  // [x17] 仅 string

    // Propagate — 块语法 (产品规则验证)
    propagate.methodObjectToReturn += { value = "regex"; };
    propagate.customMethodPropagate += { value = "Class.method"; from = "0"; to = "return"; };
    propagate.vmContext += { precise = true; value = "Context.put"; };
    propagate.bAllPublicMethod += { value = true; };

    // General — 引擎配置
    general.taintOnlyBySummary = true;
    general.scanAllFiles = true;
    general.userDefinePatternClass += {
        userDefineClass = loadclass("pkg.CustomClass");  // Java loadclass 入口!
    };

    // Group — 平台分组 (Roster 独有, Rule 不支持)
    group <GroupName> {
        includePlatforms = "*";       // "*" = 所有, 或具体平台名
        excludePlatforms = "legacy";  // 可选
        sanitizer.methodReturn += { value = "pkg.Sanitizer.clean"; };
    };
}
```

## 字段支持矩阵 (已验证)

### ✅ 支持

**实验验证通过**:

| 字段 | 语法 | 验证 |
|------|------|------|
| `source.methodReturn` | `+= { precise; value; }` | exp01, r02 |
| `source.methodArg` | `+= { precise; value; }` | g04, g10 |
| `source.param_annotation` | `= "FQN"` 或 `+= "FQN"` (Roster only, 字符串) | w01b, w02b, w26 |
| `source.method_annotation` | `= "FQN"` 或 `+= "FQN"` (Roster only, 字符串) | w03b, w04b, w27 |
| `source.method_param` | `= "Class.method[idx]"` 或 `+= "..."` (Roster only, 字符串) | w05b, w06b, w29 |
| `source.expression` | `= "Class.method"` 或 `+= "..."` (Roster only, 字符串) | w08b, w09b, w28 |
| `sink.methodArg` | `+= { precise; value; param; }` (param 为 JSON 可选) | exp01, r02 |
| `sink.expression` | `= "str"` 或 `+= "str"` (Roster only, 字符串) | x01, x02 |
| `sink.param_annotation` | `= "FQN"` (Roster only, 字符串) | x04 |
| `sink.method_annotation` | `= "FQN"` (Roster only, 字符串) | x05 |
| `sink.method_param` | `= "Class.method[idx]"` (Roster only, 字符串) | x06 |
| `sink.methodReturn` | `= "str"` 或 `+= "str"` (Roster only, ⚠️ 仅字符串!) | x08, y15 |
| `sink.customSinkFunc` | Roster: `= "str"` [x09]; ⚠️ loadclass 不可用 (用 general.userDefinePatternClass 代替) | x09 |
| `sanitizer.methodReturn` | `+= { value; }` (块语法) | g05, r02 |
| `sanitizer.methodArg` | `+= { precise; value; }` (块语法) | x18, r16, s08a |
| `sanitizer.expression` | `= "str"` 或 `+= "str"` (Roster only, 字符串) | x11, x12 |
| `sanitizer.param_annotation` | `= "FQN"` (Roster only, 字符串) | x13 |
| `sanitizer.method_annotation` | `= "FQN"` (Roster only, 字符串) | x14 |
| `sanitizer.method_param` | `= "Class.method[idx]"` (Roster only, 字符串) | x15 |
| `sanitizer.customSanitizerFunc` | Roster: `= "str"` [x17]; ⚠️ loadclass 不可用 (用 general.userDefinePatternClass 代替) | x17 |
| `group` (Roster) | `includePlatforms`, `excludePlatforms` + 内嵌字段 | f06, r06 |
| `define` | `define varName = "value";` | f10, t11 |
| `delete` | `delete field.subfield;` | f11 |
| `modifiable` | `modifiable field.subfield;` | g07 |

**产品规则验证 (configs_v3.3) — 新增字段**:

| 字段 | 语法 | 来源 |
|------|------|------|
| `source.paramAnnotation` | `+= { precise; value; excludeTag; }` (camelCase! 与 param_annotation 不同) | Java_common_source_0 |
| `source.velocityReference` | `+= { value; }` | Java_common_source_0 |
| `source.methodReturnJws` | `+= { value; }` | Java_common_source_0 |
| `source.allocReturn` | `+= { value; }` | Java_common_source_0 |
| `source.mvcMapping` | `+= { precise; value; flag; }` | Java_common_source_0 |
| `source.annotationJWS` | `+= { value; }` | Java_common_source_0 |
| `source.methodParam` | `+= { xpath; tag; }` (camelCase! 与 method_param 不同) | Java_common_source_0 |
| `sink.allocArg` | `+= { precise; value; }` | urlRedirect sink |
| `sink.methodObject` | `+= { precise; value; }` | deserialization sink |
| `sink.methodArgJws` | `+= { value; }` | urlRedirect sink |
| `sink.methoArgUpcast` | `+= { value; }` (⚠️ 官方 typo) | xss sink |
| `sink.responseBody` / `sink.responseClass` | `+= { value; }` | xss sink |
| `sink.mybatisProvider` | `+= { value; }` | sqli annotation sink |
| `sink.methodXbatis` / `sink.methodXbatisExclude` | `+= { value; }` | sqli xbatis sink |
| `sink.bUseSinkFilter` / `sink.filter` | `+= { value; }` | xxe sink |
| `sanitizer.safeTypes` | `+= { precise; value; excludeTag; }` | 多文件 |
| `sanitizer.safeVarNames` | `+= { value; excludeTag; }` | common_propagate |
| `sanitizer.methodObject` | `+= { value; excludeTag; }` | sqli_propagate |
| `sanitizer.methodRedirectCheck` | `+= { precise; value; }` | ssrf_propagate |
| `sanitizer.methodSafeState` / `methodUnSafeState` | `+= { precise; value; }` | ssrf_propagate |
| `sanitizer.methodArgWithRedirectCheck` | `+= { precise; value; }` | ssrf_propagate |
| `propagate.methodObjectToReturn` | `+= { value; }` | ssrf/urlredirect_propagate |
| `propagate.methodObjectToFirstArg` | `+= { value; }` | common_propagate |
| `propagate.methodArgToObjectAndReturn` | `+= { value; }` | ssrf_propagate |
| `propagate.methodArgOrObjectToObjectAndReturn` | `+= { value; excludeTag; }` | ssrf_propagate |
| `propagate.customMethodPropagate` | `+= { value; from; to; accurate; precise; }` | ssrf_propagate |
| `propagate.vmContext` | `+= { precise; value; }` | xss_propagate |
| `propagate.noTaintNoSourceFile` | `+= { value; excludeTag; }` | xss_propagate |
| `propagate.bAllPublicMethod` | `+= { value = true; }` | second_package_source |
| `propagate.bUseSqlSpecial` / `bUseCritical` | `+= { value = true; }` | common_propagate |
| `propagate.bPreSanitizerParam` / `bUseSafeState` / `bUnkownAsSafe` / `bTaintedStart` / `bOnlyTaintedByObject` / `bSanitizerParamTransmit` | `+= { value = true/false; }` | ssrf_propagate |
| `propagate.bUseXXEFlags` / `bUseStreamReader` | `+= { value = true; }` | xxe_propagate |
| `propagate.xxeType` / `xxeMethod` / `methodStreamReader` | `+= { precise; value; }` | xxe_propagate |
| `general.taintOnlyBySummary` / `blackFieldMatch` / `handlePolymorphism` | `= true` | common_propagate |
| `general.polyHandleNum` | `= 1` (integer) | common_propagate |
| `general.scanAllFiles` | `= true` | common_source |
| `general.entranceFileXpath` | `= "xpath"` | common_source |
| `general.userDefinePatternClass` | `+= { userDefineClass = loadclass("..."); }` (**Java loadclass入口**) | 多文件 |
| `general.userDefineEntranceClass` | `+= { userDefineClass = loadclass("..."); }` (**Java loadclass入口**) | 多文件 |
| `general.methodRedirect` | `+= { precise; value; xpath; }` | common_source |
| `general.customSubject` | `= "str"` | 6190.rul |
| `general.genAppSummary` | `= false` | 6192.rul |
| `import roster ... exclude` | `import roster X exclude Group1,Group2;` | 多个 .rul |

**`precise`**: `true` = FQN 精确匹配, `false` = 前缀匹配 (r23✅)

> ⚠️ 字符串字段 (`expression`/`param_annotation`/`method_annotation`/`method_param`/`customSinkFunc`/`customSanitizerFunc`) 只接受字符串赋值，不接受块 `+= { ... }` [w07b❌ w10b❌ x03❌]。且只能在 Roster 中使用，Rule 中即使加 `modifiable` 也报 `not modifiable in parent rule` [w11-w14❌ w22-w25❌]。
>
> ⚠️ `sink.methodReturn` 仅接受字符串语法 [x08✅ y15✅]，块语法 `+= { value = ... }` 报 `custom define config` [x07❌]。
>
> ⚠️ `sanitizer.methodReturn`/`sanitizer.methodArg` 仅接受块语法，字符串语法报 `value should be complex type` [x40❌ x19❌]。
>
> ⚠️ **Java loadclass**: 通过 `general.userDefinePatternClass` / `general.userDefineEntranceClass` 使用 loadclass [configs_v3.3 产品规则验证]。`customSinkFunc`/`customSanitizerFunc` 中 **不能** 使用 loadclass [ast13❌ x10❌]。
>
> ⚠️ **propagate**: 字段名必须精确匹配，如 `propagate.methodObjectToReturn`、`propagate.customMethodPropagate` 等。不存在的字段名 (如 `propagate.customFunctionPropagate`) 会报 "custom define config" 错误 [configs_v3.3 产品规则验证]。
>
> Expression 可与 methodReturn/methodArg 共存于同一 Roster [y19✅ y20✅ y21✅ y22✅]，接受任意格式: FQN、类名、简单名、通配符 [x30-x33✅]。

### ❌ 不支持 / 受限

| 字段 | 错误 | 验证 |
|------|------|------|
| `import roster` | 必须在 Rule 体最前面 + 需 relation config; 运行时链接机制 | imp2✅, imp14❌, w16✅ |
| `loadclass` via `customSinkFunc`/`customSanitizerFunc` | Java 中这两个字段不支持 loadclass, 用 `general.userDefinePatternClass` 代替 | ast13❌, x10❌ (但 general.* 路径可用!) |
| `propagate.customFunctionPropagate` | 该字段名不存在，使用正确字段名如 methodObjectToReturn 等 | s06❌, s07❌ |
| `sink.methodReturn` (块语法) | 块语法不支持, 用字符串 `= "str"` | x07❌, x08✅string |
| `sanitizer.methodReturn` (string) | string 不支持, 用块语法 | x40❌ |
| `sanitizer.methodArg` (string) | string 不支持, 用块语法 | x19❌ |
| `sink.methodArg` (string) | string 不支持, 用块语法 | x38❌, x39❌ |
| `sink.functionArg` | custom define config | s09 |
| `sanitizer.functionArg` | custom define config | s08b |
| `sanitizer.functionReturn` | custom define config | s08c |
| `source.param_annotation` (块语法) | 块语法 `+= { }` 不支持, 用字符串 | s10, w07b |
| `source.method_annotation` (块语法) | 块语法不支持, 用字符串 | s11 |
| `source.method_param` (块语法) | 块语法不支持, 用字符串 | s15, w07b |
| `source.expression` (块语法) | 块语法不支持, 用字符串 | w10b |
| `const` | ParseError | s12 |
| `general.desc` | not modifiable | s16 |

## 操作符

| 操作符 | 用途 | 示例 |
|--------|------|------|
| `=` | 赋值 (type/subType/define) | `type = "SSRF";` |
| `+=` | 追加块 | `source.methodReturn += { ... };` |

## 链接: relation/config_roster_relation.json

```json
{ "rule_id": ["RosterName_0", "AnotherRoster_0"] }
```

一个 Rule 可链接多个 Roster (s03✅)，多个 Rule 可共享同一 Roster (t12✅)。

**import 机制 [w15-w21, imp1-imp15, configs_v3.3]**:
- `import roster X;` 是**运行时链接机制**，Roster 不经 import 无法在 Rule 中生效
- `import roster X exclude GroupName;` 可排除 Roster 中的特定 group [configs_v3.3 产品规则]
- `import roster X exclude A,B;` 逗号分隔排除多个 group [configs_v3.3 产品规则]
- import 必须在 Rule 体**最前面**，所有字段之前 [imp2✅ imp14❌ imp15❌]
- import 引用 Roster **声明名** (不是文件名) [imp10❌ w17❌]
- 多个 import 可连续写 [imp11✅]
- `relation config` 仅保证 verify 通过（文件发现），不等于运行时链接 [imp9✅ verify通过但Roster不生效]
- Roster 中的 source/sink 通过 import 自动合并到 Rule [w21✅]
- verify API **不校验** relation 中的名称值 [w30-w33均✅]

## 文件命名

| 文件 | 格式 | 示例 |
|------|------|------|
| Rule | `{rule_id}.rul` | `70001.rul` |
| Roster | `{Name}_0.ros` | `Java_ssrf_config_0.ros` |
| Relation | `relation/config_roster_relation.json` | — |

## 常见漏洞 type/subType

| type | subType | 说明 |
|------|---------|------|
| `"SSRF"` | `"SSRFHook"` | SSRF |
| `"SQLi"` | `"SQLInjection"` | SQL注入(Java直接执行) |
| `"SQLi"` | `"SQLiAnnotation"` | SQL注入(注解) |
| `"SQLi"` | `"SQLiXBatis"` | SQL注入(XBatis) |
| `"CMDI"` | `"CMDIHook"` | 命令注入 |
| `"Xss"` | `"XssHook"` | XSS |
| `"PathTraversal"` | `"PathTraversalHook"` | 路径遍历 |
| `"Deserialization"` | `"DeserializationHook"` | 反序列化 |
| `"XXE"` | `"XXEHook"` | XXE注入 |
| `"URLRedirect"` | `"URLRedirectHook"` | URL重定向 |
| `"GroovyShell"` | `"GroovyShellHook"` | Groovy注入 |
| `"Test"` | `"TestRule"` | 测试用 |
