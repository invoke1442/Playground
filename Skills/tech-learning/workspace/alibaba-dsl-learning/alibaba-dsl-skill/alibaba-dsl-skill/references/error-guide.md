# Alibaba DSL — 错误排查指南

## 错误响应格式

```json
[{"template_key": "stae-java-88", "values": ["行号", "列号", "详细信息"],
  "default_template": "Line {}, Column {}: ParseError, Encountered {}", "type": "error"}]
```

## 1. 语法解析错误 (ParseError)

**template_key**: `stae-java-88`, `stae-ts-3`

| 错误 | 原因 | 修复 |
|------|------|------|
| `Encountered "import"` | import 位置错误或缺少 relation config | import 必须在 Rule 体最前面 [imp2✅ imp14❌]; 需 relation config 否则 cannot find roster [imp3❌]; import 用声明名不用文件名 [imp10❌]; 支持 `exclude GroupName` |
| `Encountered "group"` | Rule 中使用 group | group 仅 Roster 支持 [exp04❌, f06✅] |
| `Was expecting ";"` | 缺少分号 | 每条语句末尾加 `;` |
| `mismatched input 'group' expecting '}'` | JS Rule 中用 group | 移到 Roster [f07❌, g01✅] |
| `mismatched input 'import' expecting '}'` | JS 中 import 位置错误 | import 必须在 Rule 体最前面 [t02❌] |

> ⚠️ `import roster` 是运行时链接机制，Roster 不经 import 无法在 Rule 中生效。import 必须写在 Rule 体最前面 [imp2✅ imp14❌]，引用 Roster 声明名（非文件名）[imp10❌]，且需 relation config 配合才能 verify 通过 [imp3❌]。

## 2. 字段不存在

**template_key**: `stae-java-78`, `stae-ts-32`

| 错误 | 原因 | 修复 |
|------|------|------|
| `cannot find field by name: precise` | JS 不支持 precise | 改用 `value += "/regex/"` [exp10❌] |
| `cannot find field by name: paramIndex` | Java 不支持 paramIndex | 仅 JS 支持 [Java 结构限制] |

## 3. 必填字段缺失

**template_key**: `stae-ts-31`, `stae-java-57`

| 错误 | 原因 | 修复 |
|------|------|------|
| `the field pattern is required` | JS sink/sanitizer 块中用了 `value` (应为 `pattern`) | 改用 `pattern += "/regex/"` 或 `pattern = "/regex/"` [v05❌, v07❌] |
| `the field value is required` | JS source 块中用了 `pattern` (应为 `value`) | 改用 `value += "/regex/"` 或 `value = "/regex/"` [v02❌, v11❌, v14❌] |
| `type and subType is required` | Rule 缺 type/subType | 补全 |

## 4. 自定义配置错误

**template_key**: `stae-java-74`

| 错误模式 | 字段 | 验证 |
|----------|------|------|
| `custom define config: sink.methodReturn` | Java sink.methodReturn 用了块语法, 应用字符串 `= "str"` | g06❌块语法 [x08✅字符串] |
| `custom define config: propagate.X` | propagate 子字段名错误，需使用正确的子字段名如 `methodObjectToReturn`/`customMethodPropagate` 等 | s06❌, s07❌ (使用了不存在的子字段名) |
| `custom define config: source.param_annotation` | 用了块语法 `+= { }`, 应用字符串 `= "str"` | s10❌ [w01b✅ 字符串语法通过] |
| `custom define config: source.method_annotation` | 用了块语法, 应用字符串 | s11❌ [w03b✅] |
| `custom define config: source.method_param` | 用了块语法, 应用字符串 | s15❌ [w05b✅] |
| `custom define config: source.expression` | 用了块语法, 应用字符串 | w10b❌ [w08b✅] |
| `custom define config: sink.functionArg` | 不支持 | s09❌ |
| `custom define config: sanitizer.functionArg` | 不支持 | s08b❌ |
| `custom define config: sanitizer.functionReturn` | 不支持 | s08c❌ |
| `custom define config: X can only be string` | loadclass 用了 `+=` (应用 `=`), 或在 `customSinkFunc`/`customSanitizerFunc` 中用了 loadclass (不支持, 改用 `general.userDefinePatternClass`) | 用 `=`; customSinkFunc 不支持 loadclass [ast13❌]; JS Roster 可用 [s22✅]; Java 用 general.userDefinePatternClass [configs_v3.3] |

**规律**: `custom define config: X can only be string value` = 该字段用了块语法但只支持字符串, 或字段确实不支持。

## 5. 文件/配置错误

| 错误 | 原因 | 修复 |
|------|------|------|
| `content is null` | rule_id 与 .rul 文件名不匹配 | 确保 `rule_id=70001` 对应 `70001.rul` |
| `ruleDir has no roster sub directory` | tar 中缺 rosters/ 目录 | 添加 rosters/ 目录 (可为空) [t07✅, t08❌] |
| `the class file is not exist` | loadclass 扩展文件不存在 | 检查 extend-file/ 目录结构 |
| `not modifiable` (general.desc) | 字段不可修改 | 勿使用 [s16❌] |
| `not modifiable in parent rule: source.X` | Rule 中使用了 Roster 专属字段 | 移到 Roster 中 [w11-w14❌ w22-w25❌] |

## 6. API 参数错误

| code | 错误 | 修复 |
|------|------|------|
| 10002 | `invalid language` | 只能 `java` 或 `javascript` |
| 10003 | `invalid verify type` | 只能 `rule` 或 `roster` |
| 10004 | `rule_id is required` | 补充 rule_id |
| 10005 | `roster_name is required` | 补充 roster_name |

## 调试清单

### Java
- [ ] type + subType 已填写
- [ ] 每条语句末尾 `;`
- [ ] import roster 在 Rule 体最前面（支持 `exclude GroupName` 排除特定 group）
- [ ] Rule 中无 group (移到 Roster)
- [ ] sink.methodArg 用块语法; sink.methodReturn 用字符串语法 [x08✅]
- [ ] loadclass 通过 `general.userDefinePatternClass` 使用 (非 customSinkFunc) [configs_v3.3]
- [ ] propagate 使用正确子字段名 (如 `methodObjectToReturn`, 非 `customFunctionPropagate`)
- [ ] .ros 文件名带 `_0` 后缀
- [ ] rule_id 与 .rul 文件名一致

### JavaScript
- [ ] 无 `precise` (JS 不支持)
- [ ] source 块: 用 `value` (= 或 +=), **不能用 pattern**
- [ ] sink 块: 用 `pattern` (= 或 +=), **不能用 value**
- [ ] sanitizer 块: 用 `pattern` (= 或 +=), **不能用 value**
- [ ] value 和 pattern 不能共存于同一块 [v03❌ v06❌ v09❌ v12❌]
- [ ] Rule 中无 group
- [ ] loadclass 仅在 Roster 中用
- [ ] .ros 文件名带 `_0` 后缀

## 验证成功标志

```json
{"code": 0, "message": "success", "data": {"output": "[]"}}
```

`output` 为 `"[]"` 或 `""` 均表示成功。
