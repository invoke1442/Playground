---
name: alibaba-dsl
description: \"Use when writing, debugging, or verifying Alibaba DSL taint-analysis rules (.rul/.ros) for Java or JavaScript SAST scanning. Rule imports Roster via import roster + relation config.\"
---

# Alibaba DSL — Taint Rule Authoring Skill

## Core Principle

**Rule = thin entry point** (type + subType + import). **Roster = ALL source/sink/sanitizer definitions**. `import roster X;` = 运行时链接（必需），`relation config` = verify 文件发现（必需）。两者缺一不可。

## Workflow

```
1. Determine language (java/javascript) and vuln type
2. Create Roster(s) with source/sink/sanitizer → rosters/{Name}_0.ros
3. Create Rule with type + subType + import roster → {rule_id}.rul
4. Create relation/config_roster_relation.json → {"rule_id": ["Roster_0"]}
5. Package: tar -cf config.tar -C config/ .
6. Verify: bash scripts/verify.sh rule java {rule_id} config/
7. Fix errors → repeat
```

## Tar Structure

```
config/
├── {rule_id}.rul                      # Rule entry point
├── rosters/                           # REQUIRED dir (even if empty)
│   └── {RosterName}_0.ros             # Core semantics
├── relation/
│   └── config_roster_relation.json    # {"rule_id": ["Roster_0"]}
└── extend-file/                       # loadclass 扩展文件
    ├── {rule_id}/                     # Rule 的扩展类 (.java)
    │   └── CustomClass.java
    └── rosters/{RosterName}_0/*.js     # JS Roster loadclass
```

**Rules**: tar only (NOT tar.gz/zip). `.ros` filename = `{Name}_0.ros`, declaration = `Roster {Name}` (no `_0`). `rule_id` must match `.rul` filename.

## Java — Roster + Rule Pattern

```java
// rosters/Java_ssrf_config_0.ros
Roster Java_ssrf_config {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    source.methodArg += { precise = true; value = "javax.servlet.http.HttpServletRequest.getInputStream"; };
    sink.methodArg += { precise = true; value = "java.net.URL.<init>"; };
    sanitizer.methodReturn += { value = "org.apache.commons.validator.routines.UrlValidator.isValid"; };
    group SpringBoot {
        includePlatforms = "*";
        sanitizer.methodReturn += { value = "org.springframework.web.util.HtmlUtils.htmlEscape"; };
    };
}
```

```java
// 70001.rul — Entry point + import
Rule SSRFEntry extends AbstractTaintRule {
    import roster Java_ssrf_config;
    type = "SSRF";
    subType = "SSRFHook";
}
```

```json
// relation/config_roster_relation.json
{ "70001": ["Java_ssrf_config_0"] }
```

**Java fields (block)**: `source.methodReturn`, `source.methodArg`, `sink.methodArg`, `sanitizer.methodReturn`, `sanitizer.methodArg` — `precise` + `value`. **String (Roster)**: `{source|sink|sanitizer}.expression/.param_annotation/.method_annotation/.method_param`, `sink.methodReturn`, `sink.customSinkFunc`, `sanitizer.customSanitizerFunc` (仅string). **loadclass (Java)**: 通过 `general.userDefinePatternClass += { userDefineClass = loadclass("pkg.Class"); };` 实现 (NOT via customSinkFunc). **propagate**: 产品规则支持 26 种子字段 (methodObjectToReturn, customMethodPropagate, bAllPublicMethod 等). **import roster** 支持 `exclude tagName` 按 `excludeTag` 排除已标记条目（非 group 级，而是 entry 级标签排除）。`group` Roster only. `import roster` 必须写在 Rule 体最前面 [imp2✅ imp14❌]。

### 匹配能力边界 ⭐

**可匹配的标识符类型**：方法 FQN、方法名 regex、类名/类型名、变量名 regex、注解 FQN、**形参名**（通过 xpath）、propagate 方法名。

**关键**：形参名匹配通过 `source.methodParam += { xpath = "//FormalParameter/VariableDeclaratorId[@Image='paramName']"; tag = "..."; };` 实现。

**不可匹配**：方法调用的实参字面量值（如 `Pattern.compile(".*")` 中的 `".*"`）。Ali DSL 的 value 字段匹配的是代码结构标识符（方法名、类名），而非代码中的字符串常量值。

**字段命名规则**：camelCase 字段 (paramAnnotation, methodParam) 可通过 `+=` block 在子规则/roster 中扩展；snake_case 字段 (param_annotation, method_param) 在 AbstractTaintRule 子规则中 NOT modifiable。`sink.xpath` 不可直接赋值，xpath 只能作为 source.methodParam block 内的子字段使用。

## JavaScript — Roster + Rule Pattern

```javascript
// rosters/NodeJS_xss_config_0.ros
Roster NodeJS_xss_config {
    source.methodReturn += { value += "/\\breq\\.query\\b|\\breq\\.body\\b/"; };
    source.expression += { taintTag = "xss_tag"; value += "/ctx\\.request\\.body$/"; };
    sink.methodArg += { pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/"; };
    sanitizer.methodReturn += { pattern += "/\\bescapeHtml\\b/"; };
    group express_handler {
        includePlatforms = "express";
        source.methodReturn += { value += "/\\breq\\.headers\\b/"; };
    };
}
```

```javascript
// 70002.rul
Rule XssEntry_70002 extends AbstractTaintRule {
    import roster NodeJS_xss_config;
    type = "Xss";
    subType = "XssTs";
}
```

**JS key rules**: No `precise`. Source block fields use `value`, sink/sanitizer block use `pattern` — exclusive. **Block**: `source.methodReturn/expression/paramDecorator`(value), `sink.methodArg`(pattern), `sanitizer.methodReturn`(pattern). **String (Roster)**: `{sink|sanitizer}.expression/.param_annotation/.method_annotation/.method_param`, `sink.methodReturn/.paramDecorator`, `sanitizer.methodArg`(⚠️ string in JS, block in Java). `loadclass` JS Roster only.

## Common Errors

| Error | Fix |
|-------|-----|
| `ruleDir has no roster sub directory` | Add `rosters/` dir |
| `ParseError: import` | import 必须在 Rule 体最开头，且用声明名 |
| `cannot find field: precise` | JS: remove `precise` |
| `field pattern is required` | JS sink/sanitizer: use `pattern` |
| `type and subType is required` | Add both to Rule |
| `content is null` | `rule_id` ≠ `.rul` filename |
| `not modifiable in parent rule` | 该字段不可在子规则中修改。snake_case字段 (param_annotation, method_annotation, method_param) 和 sink.xpath 均不可修改。用 camelCase 等价字段 (paramAnnotation, methodParam) 替代 |
| `custom define config: propagate.X` | 检查子字段名拼写 (参考真实字段: methodObjectToReturn, customMethodPropagate 等；注意 methodArgToReturn 不存在，应为 methodArgToReturnCritical) |
| `custom define config: X can only be string` | loadclass 用 `=` (非 `+=`); customSinkFunc/customSanitizerFunc 中 Java 不能用 loadclass (用 `general.userDefinePatternClass` 代替) |

See `references/error-guide.md` for full list.

## References

- `references/java-syntax.md` — Java field matrix
- `references/javascript-syntax.md` — JS field matrix
- `references/error-guide.md` — Error catalog
- `references/roster-centric-patterns.md` — Vuln examples
