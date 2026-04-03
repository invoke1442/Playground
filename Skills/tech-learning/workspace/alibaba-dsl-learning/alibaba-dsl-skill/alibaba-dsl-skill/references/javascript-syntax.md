# Alibaba DSL — JavaScript/TypeScript 语法参考

> 所有语法均经 verify API 验证。❌ = 实验证实不支持。

## 与 Java 的核心差异

1. **无 `precise`** — 使用 `precise` 报 `cannot find field by name: precise`
2. **source 块字段用 `value`，sink/sanitizer 块字段用 `pattern`** — 两者是不同字段类型的专属属性，不可混用
3. **sink/sanitizer 存在大量 string 字段** — 除 `sink.methodArg` 和 `sanitizer.methodReturn` 用块语法外，其余用 `= "str"` 字符串语法
4. **JS `sanitizer.methodArg` 是 string 语法** — 与 Java 的块语法完全相反！
5. **支持 `taintTag`** — source-sink 标签关联
6. **支持 `paramIndex`** — 指定 sink 参数位置
7. **`loadclass` 仅 Roster 生效** — Rule 中不能用

## `value` vs `pattern` 语义 (v01-v19 实验验证)

**核心规则: `value` 和 `pattern` 是按字段类型分离的，互斥不共存。**

| 字段类型 | 必须用 | 不能用 | 验证 |
|---------|--------|--------|------|
| `source.methodReturn` | `value` | `pattern` ❌ | v01✅ v02❌ v03❌ |
| `source.expression` | `value` | `pattern` ❌ | v10✅ v11❌ v12❌ |
| `source.paramDecorator` | `value` | `pattern` ❌ | v13✅ v14❌ |
| `sink.methodArg` | `pattern` | `value` ❌ | v04✅ v05❌ v06❌ |
| `sanitizer.methodReturn` | `pattern` | `value` ❌ | v08✅ v07❌ v09❌ |

**语义解读**:
- **`value`** = 声明「数据是什么」(source 端: 哪些 API 产生污点数据)
- **`pattern`** = 声明「匹配什么模式」(sink/sanitizer 端: 哪些调用消费/清洗污点)
- 两者底层都用正则表达式，但属于不同的 schema 字段，不可互换
- `=` 和 `+=` 均可 (v15✅ v16✅ v17✅)，`+=` 用于追加多个正则
- `taintTag`/`paramIndex` 可与对应字段组合使用 (v18✅ v19✅)

## Roster-Centric 架构

同 Java: **Rule = 入口 (type + subType + import)**, **Roster = 所有语义**。Rule 通过 `import roster X;` 引入 Roster（运行时生效），同时需要 `relation/config_roster_relation.json`（verify 阶段文件发现）。

## Rule 语法

```javascript
// 命名约定: {Name}_{rule_id}
Rule <RuleName>_<ruleId> extends AbstractTaintRule {
    import roster <RosterName>;  // 必须在最前面
    type = "<VulnType>";
    subType = "<SubType>";
}
```

## Roster 语法

```javascript
Roster <RosterName> {
    // Source — value += "/regex/"
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b/";
    };

    // Source expression — 可带 taintTag
    source.expression += {
        taintTag = "tag_name";
        value += "/ctx\\.request\\.body$/";
    };

    // Source paramDecorator
    source.paramDecorator += {
        value = "/@Query\\b/";
    };

    // Sink — MUST have pattern (块语法)
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
        paramIndex = 0;           // 可选: 参数位置
        taintTag = "tag_name";    // 可选: 匹配特定 source
    };
    // Sink — 字符串语法 (Roster 专属)
    sink.expression = "res.render";                     // [y02]
    sink.methodReturn = "res.redirect";                  // [y04]
    sink.paramDecorator = "@Body";                       // [y05]
    sink.param_annotation = "javax.inject.Inject";       // [y06]
    sink.method_annotation = "org.spring.PostMapping";   // [y07]
    sink.method_param = "Controller.handle[0]";          // [y08]

    // Sanitizer — 块语法 (pattern)
    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b/";
    };
    // Sanitizer — 字符串语法 (Roster 专属)
    sanitizer.expression = "validator.check";             // [y10]
    sanitizer.methodArg = "sanitize.input";               // [y11] ⚠️ JS 是 string! 块语法报错!
    sanitizer.param_annotation = "@Validated";            // [y12]
    sanitizer.method_annotation = "@Sanitized";           // [y13]
    sanitizer.method_param = "Cleaner.clean[0]";          // [y14]

    // loadclass — JS Roster 独有 (s22✅)
    source.customSourceFunc = loadclass("Module.func_0");

    // Group — Roster 独有
    group express_handler {
        includePlatforms = "express";
        source.methodReturn += {
            value += "/\\breq\\.headers\\b/";
        };
    };
}
```

## 字段支持矩阵 (已验证)

### ✅ 支持

**块语法字段** (需 `+= { ... }`):

| 字段 | 块内属性 | 验证 |
|------|---------|------|
| `source.methodReturn` | **`value`** (`=` 或 `+=`) | v01, v15, f03 |
| `source.expression` | **`value`** (`+=`), `taintTag` | v10, v19, exp17 |
| `source.paramDecorator` | **`value`** (`=`) | v13, g09 |
| `sink.methodArg` | **`pattern`** (`=` 或 `+=`), `paramIndex`, `taintTag` | v04, v16, v18 |
| `sanitizer.methodReturn` | **`pattern`** (`=` 或 `+=`) | v08, v17, z02 |

**字符串语法字段** (Roster 专属, `= "str"` 或 `+= "str"`):

| 字段 | 说明 | 验证 |
|------|------|------|
| `sink.expression` | sink 表达式匹配 | y02 `=`, y03 `+=` |
| `sink.methodReturn` | sink 方法返回 | y04 |
| `sink.paramDecorator` | sink 装饰器 | y05 |
| `sink.param_annotation` | sink 注解 | y06 |
| `sink.method_annotation` | sink 方法注解 | y07 |
| `sink.method_param` | sink 方法参数 | y08 |
| `sanitizer.expression` | sanitizer 表达式匹配 | y10 |
| `sanitizer.methodArg` | sanitizer 方法参数 (⚠️ JS 是 string!) | y11 |
| `sanitizer.param_annotation` | sanitizer 注解 | y12 |
| `sanitizer.method_annotation` | sanitizer 方法注解 | y13 |
| `sanitizer.method_param` | sanitizer 方法参数 | y14 |

**其他**:

| 字段 | 说明 | 验证 |
|------|------|------|
| `group` (Roster) | `includePlatforms`, `excludePlatforms` + 内嵌字段 | g01, r10 |
| `loadclass` (Roster) | `= loadclass("Module.func_0")` | s22, g11 |
| `taintTag` | 字符串, source↔sink 关联 | v18, v19, exp17 |
| `paramIndex` | 数字, sink 参数位置 | v18, s05 |

### ❌ 不支持

| 字段 | 错误 | 验证 |
|------|------|------|
| `precise` | cannot find field | exp10, exp11 |
| `import roster` | 必须在 Rule 体最前面 + 需 relation config | t02 |
| `propagate.*` | custom define config | s17 |
| `sink.methodArg` (string) | string 不支持, 用块语法 + pattern | y01❌ |
| `sink.expression` (块) | 块语法不支持, 用字符串 | x20❌, x21❌ |
| `sink.methodReturn` (块) | 块语法不支持, 用字符串 | x22❌ |
| `sink.paramDecorator` (块) | 块语法不支持, 用字符串 | x23❌ |
| `sanitizer.methodReturn` (string) | string 不支持, 用块语法 + pattern | y09❌ |
| `sanitizer.methodArg` (块) | 块语法不支持, 用字符串 | z01❌, z03❌ |
| `sanitizer.expression` (块) | 块语法不支持, 用字符串 | x26❌ |

> ⚠️ JS 中 `sanitizer.methodArg` 仅支持 **string 语法** `= "str"` [y11✅]，块语法报 `simple type` 错误 [z01❌ z03❌]。这与 Java 中必须用 **块语法** [x18✅] **完全相反**！
>
> ⚠️ 所有 sink/sanitizer string 字段不接受块语法 [x20-x29 全❌]，块语法只限 `sink.methodArg` 和 `sanitizer.methodReturn`。
>
> Expression 可与其他字段共存于同一 Roster [y23✅ z04✅]。

## 赋值语法

| 语法 | 适用字段 | 示例 |
|------|---------|------|
| `value = "/regex/"` | source.* (methodReturn, expression, paramDecorator) 块字段 | `value = "/\\breq\\.query\\b/";` [v15✅] |
| `value += "/regex/"` | source.* 块字段 (追加多个正则) | `value += "/\\breq\\.query\\b/";` [v01✅] |
| `pattern = "/regex/"` | sink.methodArg, sanitizer.methodReturn 块字段 | `pattern = "/\\bres\\.send\\b/";` [v16✅, v17✅] |
| `pattern += "/regex/"` | sink.methodArg, sanitizer.methodReturn 块字段 (追加) | `pattern += "/\\bres\\.send\\b/";` [v04✅, v08✅] |
| `= "str"` | sink/sanitizer string 字段 (expression, methodReturn, etc.) | `sink.expression = "res.render";` [y02✅] |
| `= loadclass("...")` | customSourceFunc (Roster 仅) | `source.customSourceFunc = loadclass("...");` |

**关键**: source 类字段只认 `value`, sink/sanitizer 只认 `pattern`。用错会报 `field X is required` 或 `cannot find field`。两者不能共存于同一块中 [v03❌, v06❌, v09❌, v12❌]。

## taintTag 机制

关联特定 source 和 sink，不设 taintTag 时默认全关联:

```javascript
source.expression += { taintTag = "sql_tag"; value += "/ctx\\.sql$/"; };
sink.methodArg += { taintTag = "sql_tag"; pattern += "/\\bdb\\.query$/"; paramIndex = 0; };
```

## 正则语法

值用 `/` 包围: `"/\\breq\\.query\\b/"` — 其中 `\\b` = 单词边界, `\\.` = 字面点, `$` = 行尾, `|` = OR.

## loadclass 扩展文件 (Roster 仅)

路径: `extend-file/rosters/{RosterName}_0/{Name}.js`

```javascript
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => {
    return false; // true=匹配, false=不匹配
};
```

## 文件命名

| 文件 | 格式 | 示例 |
|------|------|------|
| Rule | `{rule_id}.rul` | `70004.rul` |
| Roster | `{Name}_0.ros` | `NodeJS_xss_core_0.ros` |
| Extend | `extend-file/rosters/{Name}_0/*.js` | 见上 |

## 支持平台

`includePlatforms` / `excludePlatforms`:
`express`, `koa`, `egg`, `cocktail`, `midway`, `*` (所有)
