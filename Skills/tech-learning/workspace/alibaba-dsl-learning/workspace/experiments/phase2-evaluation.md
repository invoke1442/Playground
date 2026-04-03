# Phase 2: Skill 评测报告

## 1. SKILL.md 内容评估

### 1.1 Description 触发评估
**当前 description**:
```
Use when writing, debugging, or validating Alibaba DSL taint-analysis rules (.rul/.ros) for Java or JavaScript SAST scanning. Core pattern: Roster holds all source/sink/sanitizer semantics, Rule is entry point only, linked via relation/config_roster_relation.json.
```

**评估**:
- ✅ 明确的 trigger 关键词: "Alibaba DSL", ".rul/.ros", "taint-analysis rules", "SAST scanning"
- ✅ 行为动词明确: "writing, debugging, validating"
- ✅ 核心模式一句话总结: Roster-centric + relation config
- ✅ 语言范围限定: Java, JavaScript
- ⚠️ 可加强: 可加入 "verify API" 关键词以覆盖用户提到 verify 时的触发

**Under-trigger 风险**: 用户说 "阿里巴巴规则" / "alibaba rule" 可能不触发 → description 有 "Alibaba DSL" 和 "rules" 覆盖
**Over-trigger 风险**: 用户说 "DSL rule" (非 Alibaba) 可能误触发 → 有 "Alibaba" 前缀限定，风险低

### 1.2 渐进式披露
- ✅ Core Principle 开头 (2句), 最高优先
- ✅ Workflow 7步, 可执行
- ✅ Tar Structure 结构化展示
- ✅ Java/JS 各有完整示例 (Roster + Rule + relation)
- ✅ 错误表 → 指向 references/error-guide.md
- ✅ References 列表在末尾
- ✅ description 部分简短 (1句)

### 1.3 大小合规
- SKILL.md: 4952 bytes ✅ (< 5000)
- 详细内容已移至 references/

### 1.4 具体可执行性
- ✅ Workflow 有具体命令 (tar -cf, bash scripts/verify.sh)
- ✅ Java/JS 示例可直接复制使用
- ✅ 文件命名规范有示例
- ✅ 错误表有具体修复建议

### 1.5 错误处理
- ✅ 8 条常见错误 + 修复方案
- ✅ 指向 error-guide.md 完整目录
- ✅ 关键 ⚠️ 标记: import 不工作

---

## 2. Triggering Tests

### 2.1 应触发场景 (Under-trigger 检测)

| # | 测试任务 | 预期触发 | 关键词覆盖 |
|---|---------|----------|-----------|
| T1 | "帮我写一个检测 SSRF 的 Alibaba DSL 规则" | ✅ | Alibaba DSL, 规则 |
| T2 | "这个 .rul 文件验证失败了，帮我看看" | ✅ | .rul |
| T3 | "写一个 Java taint analysis roster" | ✅ | taint analysis, roster |
| T4 | "如何用 verify API 测试我的规则" | ✅ | verify, 规则 |
| T5 | "Alibaba DSL 的 source.methodReturn 怎么写" | ✅ | Alibaba DSL, source.methodReturn |
| T6 | "帮我把这个 CodeQL 规则转换成阿里 DSL" | ✅ | 阿里 DSL |
| T7 | "roster 里怎么定义 sanitizer" | ⚠️ | roster, sanitizer (可能不够具体) |
| T8 | "relation/config_roster_relation.json 怎么配置" | ✅ | relation, config_roster_relation |

### 2.2 不应触发场景 (Over-trigger 检测)

| # | 测试任务 | 预期不触发 | 理由 |
|---|---------|-----------|------|
| T9 | "写一个 SQL 查询" | ❌ 不触发 | 无 DSL/规则 关键词 |
| T10 | "帮我写 CodeQL dataflow query" | ❌ 不触发 | CodeQL 有独立 skill |
| T11 | "什么是 SSRF 漏洞" | ❌ 不触发 | 知识类问题，无 DSL |
| T12 | "写一个 JSON DSL 配置文件" | ❌ 不触发 | 无 Alibaba/taint |
| T13 | "帮我 debug 一个 Python 脚本" | ❌ 不触发 | 无关领域 |

---

## 3. Functional Tests

### 3.1 verify.sh 功能测试

测试 verify.sh 能否正确打包并验证:

| # | 测试 | 配置 | 结果 |
|---|------|------|------|
| F1 | Java Rule + Roster + relation (SSRF) | s19 示例 | ✅ PASSED (635ms) |
| F2 | JS Rule + Roster + relation (XSS) | s04 示例 | ✅ PASSED (295ms) |
| F3 | Java 多 Roster (SQLi) | s03 示例 | ✅ PASSED (660ms) |
| F4 | 错误情况: 缺少 rosters/ 目录 | 无 rosters/ | ✅ 正确报错 "no roster sub directory" |

所有功能测试通过。verify.sh 正确处理了成功和失败场景。

---

## 4. 发现的问题 & 修复

### 4.1 Description 优化 ✅ 已修复
- 添加了 "verify" 和 "verify API" 关键词到 description
- 原: "validating" → 新: "verifying ... via verify API"

### 4.2 漏洞类型 "Xss" vs "XSS" 大小写
- 实验中 type 用 "Xss" 而非 "XSS" — 需确保用户知道正确大小写
- SKILL.md 已在 JS 示例中用 "Xss" ✅
- java-syntax.md 常见漏洞表已列出正确大小写 ✅

### 4.3 Java Rule 命名缺少 rule_id 后缀
- Java 示例: `Rule SSRFEntry extends ...` (无 rule_id)
- JS 示例: `Rule XssEntry_70002 extends ...` (有 rule_id) 
- 两种命名均通过验证，不影响功能，保持现状

## 5. 最终 Skill 结构

```
alibaba-dsl-skill/
├── SKILL.md                          # 4952→~4980 bytes (核心文档)
├── references/
│   ├── java-syntax.md                # 3905 bytes (Java 字段支持矩阵)
│   ├── javascript-syntax.md          # 4556 bytes (JS 字段支持矩阵)
│   ├── error-guide.md                # 4224 bytes (错误排查指南)
│   └── roster-centric-patterns.md    # 7941 bytes (实战漏洞模式)
├── templates/
│   ├── java-rule-basic.rul           # Rule 入口模板
│   ├── js-rule-basic.rul             # Rule 入口模板
│   ├── java-roster.ros               # Roster 完整模板
│   ├── js-roster.ros                 # Roster 完整模板
│   └── relation-config.json          # relation 配置模板
└── scripts/
    └── verify.sh                     # 验证脚本
```

## 6. 评测结论

| 维度 | 评分 | 说明 |
|------|------|------|
| Description 触发 | ★★★★☆ | 覆盖主要场景，"roster"/"sanitizer" 在无 Alibaba 上下文时存在轻微 under-trigger 风险 |
| 渐进式披露 | ★★★★★ | 核心原则→工作流→示例→错误表→引用，层次清晰 |
| 大小合规 | ★★★★★ | 4952 bytes < 5000 |
| 具体可执行 | ★★★★★ | 所有示例经 verify API 验证，可直接复制使用 |
| 错误处理 | ★★★★★ | 8 条常见错误 + 完整 error-guide.md 引用 |
| 功能测试 | ★★★★★ | 4/4 测试通过 (3 成功 + 1 正确报错) |
| 实验支撑 | ★★★★★ | 80+ 实验验证，每条结论有实验 ID 支撑 |

