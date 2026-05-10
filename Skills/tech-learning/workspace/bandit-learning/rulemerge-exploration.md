# Bandit Rule Merge Exploration

## 背景

本轮探索的目标不是直接改写规则，而是先验证一件事：

- 能否把同一 `(语言, CWE, 漏洞分类)` 聚类中的简单 `pattern-grep` 规则，作为 `src`
- 再把它们的 `source/sink` 信息并到同簇的完整污点规则 `tgt` 里

你给出的原始原则是：

- `src`: `简单的pattern-grep审计`，且 `污点节点多分类` 为 `1` 或 `2`
- `tgt`: `有完整漏洞污点逻辑`，且 `污点节点多分类` 为 `1,2`

这里先说明一个关键事实：按当前 CSV 的既有定义，`有完整漏洞污点逻辑` 的规则不会落成严格的 `1,2`，而是落成：

- `1,2,4`
- `1,2,3`
- `1,2,3,4`

我实际统计后，严格按字面执行时：

- `strict_tgts = 0`

也就是说，如果把 `tgt` 理解为“节点值必须严格等于 `1,2`”，那么整张表里一个 `tgt` 都没有，`merge_target` 只能全空，这会让这轮探索失去实用价值。

因此，这次我对 `tgt` 采用了唯一自然、且与现有表结构兼容的解释：

- `tgt = 规则类型二分类为“有完整漏洞污点逻辑”`
- 且 `污点节点集合至少同时包含 1 和 2`

换句话说，不要求节点串字面等于 `1,2`，而要求它“包含 source 和 sink”。

## 当前映射口径

`merge_target` 已经加到 CSV 里。

当前映射流程是：

1. 先按 `(语言, CWE, 漏洞分类)` 聚类。
2. 在簇内找 `src`：
   - `规则类型二分类 == 简单的pattern-grep审计`
   - `污点节点多分类 in {"1", "2"}`
3. 在簇内找 `tgt`：
   - `规则类型二分类 == 有完整漏洞污点逻辑`
   - `污点节点集合包含 {"1","2"}`
4. 若一个 `src` 对应多个 `tgt`，按“就近原则”打分：
   - 同源工具优先
   - `rule_id` 与 `源规则路径` basename 的归一化 token 重叠越多越优先
   - 名称/路径字符串相似度越高越优先
5. 若最近候选仍然太弱，则 `merge_target` 留空，不强配。

我还额外加了一条保守约束：

- 已知明显牵强的映射会被拒绝。例如 `listen-eval -> eval-injection` 已被排除，不写入 `merge_target`。

## 实际结果

基于当前 CSV：

- `src` 候选总数：`99`
- 自然化解释下的 `tgt` 候选总数：`93`
- 最终成功写入 `merge_target` 的 `src`：`10`
- 未映射的 `src`：`89`
- 这些已映射 `src` 全部来自 `semgrep`

这件事本身已经说明一条很重要的结论：

- “同语言 + 同 CWE + 同漏洞分类” 只够做**粗筛**
- 远远不够直接决定“可融合”

## 结论

### 是否可行

可行，但只能**部分可行**。

更准确地说：

- 把这套聚类规则当作“召回候选”的第一步，可行
- 把 `merge_target` 当成“高置信度建议对齐”，部分可行
- 把这些映射直接当成“可以自动融合”的最终结论，不可行

适合直接融合的，通常满足三个条件：

- `src` 和 `tgt` 明显属于同一 sink family
- 两者命名高度接近，常见形态是 `xxx-audit -> xxx`
- `tgt` 只是比 `src` 多了 source / propagation / sanitizer 语义，而不是换了框架、换了 sink、换了漏洞子场景

### 若直接进行融合，会遇到哪些难题

#### 1. 你给的 `tgt` 字段定义与当前表结构不兼容

这是最先暴露出来的问题。

当前表里：

- `有完整漏洞污点逻辑` 不会取值为严格的 `1,2`
- 它一定还会包含 `3` 或 `4`

所以如果不先解释这个口径，`merge_target` 会全部为空。

#### 2. 同一聚类不等于同一 sink family

即使语言、CWE、漏洞分类完全相同，也可能仍然不是同一个规则家族。

例如都在：

- `python`
- `CWE-79`
- `XSS`

也可能分别对应：

- 直接输出 `HttpResponse`
- Jinja2 模板构造
- `mark_safe` / `Markup` 标记安全
- HTML 字符串拼接

这些规则都属于 XSS，但它们不是同一类 sink，不适合机械并入。

#### 3. 同一 CWE 下可能混着 audit 规则和真正 taint 规则

有些 `src` 只是在做“危险 API 使用告警”。

例如：

- `subprocess-shell-true`
- `exec-detected`
- `query-set-extra`

这些规则和完整 taint 规则共享同一个 CWE，并不代表它们表达的是同一个漏洞语义层级。

#### 4. 框架漂移会让融合变形

有些名称相似的规则，来自不同框架：

- Flask
- Django
- Pyramid
- 通用 Python

如果不做框架层约束，最后会出现：

- Flask 的简单规则被并到 Django 的完整污点规则

这不一定错，但风险很高。

#### 5. `src` 的附加约束很容易在融合时丢失

一个简单 sink 规则常常还有额外条件，比如：

- `shell=True`
- `extra()`
- `rawsql`
- 某个特定库的调用方式

如果只把“sink 名字”并进 `tgt`，而忽略这些附加约束，那么融合后的规则可能会：

- 误报上升
- 语义变宽
- 和原始 `src` 不等价

#### 6. “一个 src 只对应一个 tgt” 在现实里经常太强

实际统计里，有 `8` 个聚类同时存在多个 `tgt`，涉及 `38` 个 `src`。

也就是说，“一对一”不是天然存在的，需要人工决策。

## 正例

下面这些是支持你当前融合思路的**实际正例**。它们的共同特点是：命名接近、sink family 清晰、`src` 与 `tgt` 的关系接近“audit 版 -> 完整 taint 版”。

### 1. `dangerous-asyncio-create-exec-audit -> dangerous-asyncio-create-exec`

`src`:

- `rule_id = dangerous-asyncio-create-exec-audit`
- `源规则路径 = python/lang/security/audit/dangerous-asyncio-create-exec-audit.yaml`
- `污点节点多分类 = 2`

`tgt`:

- `rule_id = dangerous-asyncio-create-exec`
- `源规则路径 = python/aws-lambda/security/dangerous-asyncio-create-exec.yaml`
- `污点节点多分类 = 1,2,3,4`

为什么这是正例：

- 两者共享核心 sink：`asyncio.create_exec`
- `src` 是 audit 风格的 sink 告警
- `tgt` 是同一 sink family 的完整 taint 扩展
- 命名上几乎是一对标准的 `-audit -> full-taint`

这类规则最适合做融合。

### 2. `dangerous-os-exec-audit -> dangerous-os-exec`

`src`:

- `python/lang/security/audit/dangerous-os-exec-audit.yaml`

`tgt`:

- `python/lang/security/dangerous-os-exec.yaml`

为什么这是正例：

- sink family 完全一致
- 词面高度接近
- 都在 semgrep 家族内部
- 不存在框架漂移

这类规则直接支持你“简单 sink 规则补进完整污点规则”的思路。

### 3. `ssrf-requests -> ssrf-injection-requests`

`src`:

- `rule_id = ssrf-requests`
- `CWE = 918`
- `漏洞分类 = SSTF`
- `污点节点多分类 = 1`

`tgt`:

- `rule_id = ssrf-injection-requests`
- `污点节点多分类 = 1,2,4`

为什么这是正例：

- 两者都聚焦于 `requests` 家族
- `src` 提供了轻量 source/sink 线索
- `tgt` 已经具备完整 taint 骨架
- 从“source-only 审计”补到“source->sink”规则，方向合理

### 4. `direct-use-of-httpresponse -> reflected-data-httpresponse`

`src`:

- `python/django/security/audit/xss/direct-use-of-httpresponse.yaml`

`tgt`:

- `python/django/security/injection/reflected-data-httpresponse.yaml`

为什么这是正例：

- 两者都围绕 `HttpResponse` 输出 sink
- 都在 Django/XSS 家族里
- `src` 更像“危险 sink 提示”
- `tgt` 更像“带 source 的 reflected XSS 规则”

这说明在同一 framework family 内，sink audit 规则并入 taint 规则是可行的。

## 负例

下面这些是**实际反例**，它们直接说明“只靠同语言 + 同 CWE + 同漏洞分类”还不够。

### 1. 按字面定义，`tgt` 实际上不存在

这是最根本的反例。

如果把 `tgt` 严格理解为：

- `规则类型二分类 = 有完整漏洞污点逻辑`
- 且 `污点节点多分类 = 1,2`

那么当前表里 `tgt = 0`。

这说明原则本身在落地前就需要先修正解释。

### 2. `B102` 没法稳定对应任何 `tgt`

`B102`:

- `rule_id = B102`
- `源规则路径 = .../bandit/plugins/exec.py`
- `CWE = 78`
- `漏洞分类 = Cmdi`
- `污点节点多分类 = 2`

看上去它和一堆命令执行 taint 规则在同一簇里，但它没有被映射到任何 `tgt`。

原因是：

- `B102` 的语义更接近“禁止使用 exec”
- 同簇里的完整规则多数围绕：
  - `os.system`
  - `subprocess`
  - `asyncio exec`
  - `spawn process`

也就是说：

- 同簇，不代表同 sink family

### 3. `avoid-query-set-extra` 没法稳定落到现有 SQLi `tgt`

`avoid-query-set-extra`:

- `rule_id = avoid-query-set-extra`
- `CWE = 89`
- `漏洞分类 = Sqli`
- `污点节点多分类 = 2`

同簇里虽然有很多完整 SQLi 规则，但它最终没有被映射。

原因是现有 `tgt` 主要是：

- `sql-injection-using-raw`
- `sql-injection-using-rawsql`
- `avoid-sqlalchemy-text`
- `pyramid-sqlalchemy-sql-injection`

而 `QuerySet.extra()` 是另一类 Django 特有 sink family。

这说明：

- 即使同为 `CWE-89`，不同 ORM API 之间也不该盲目合并

### 4. `direct-use-of-jinja2` 不应被强配到别的 XSS `tgt`

`direct-use-of-jinja2`:

- `CWE = 79`
- `漏洞分类 = XSS`
- `污点节点多分类 = 2`

它和 `direct-use-of-httpresponse` 在同一个大类里，但我最后把它留空了。

原因是：

- 它的核心对象是 Jinja2 模板渲染
- 现有高置信度 `tgt` 更多是 `HttpResponse` / response output 家族

所以：

- 同是 XSS，不等于可以互相融合

### 5. `listen-eval -> eval-injection` 是一个“看起来能配上，但不该直接融合”的反例

我一开始的启发式确实把它配上了，后来又把它显式剔除了。

`src`:

- `rule_id = listen-eval`
- `源规则路径 = python/lang/security/audit/logging/listeneval.yaml`

`候选 tgt`:

- `rule_id = eval-injection`

它之所以会被误配，是因为两边都出现了 `eval`。

但实际问题在于：

- `listen-eval` 的语义是 `logging.config.listen` 这类配置监听/eval 风险
- `eval-injection` 的语义是更一般的用户输入到 `eval`

两者不是同一个 sink family。

这正是一个很典型的“字段对齐没问题，语义对齐失败”的反例。

### 6. `insecure-deserialization -> avoid-insecure-deserialization` 是边界例，不应自动放行

当前启发式把它映射出来了，因为：

- 名称非常接近
- 都落在 `CWE-502`
- 都指向反序列化风险

但这仍然是边界例。

原因是：

- `src` 来自 Flask 侧语境
- `tgt` 来自 Django audit 侧语境
- 名称对齐很好，不代表 source model、sink API、框架约束完全一致

因此：

- 这类映射可以进入人工复审队列
- 不建议直接自动融合

## 对“直接融合”的判断

### 可以直接做的

适合直接融合的，基本是这些模式：

- 同一工具族内部
- 规则名仅有 `-audit` / `-tainted-env-args` / 轻微后缀差异
- sink family 明确相同
- `src` 本质上只是 `tgt` 的 sink-only 或 source-only 子集

### 不适合直接做的

以下情况不应该直接融合：

- 只是 CWE 一样，但 sink family 不一样
- 框架不同，且 API 语义不同
- `src` 有特殊附加条件，融合后会丢失
- 候选 `tgt` 有多个且没有明显最近者
- 只是名字里有共同词，例如 `eval`、`exec`、`response`

## 建议

如果后续真的要做“规则融合”，建议把当前流程分成两层：

### 第 1 层：粗召回

继续用：

- 同语言
- 同 CWE
- 同漏洞分类

做候选簇。

### 第 2 层：人工/半自动复核

至少再检查四项：

- sink family 是否一致
- framework family 是否一致
- `src` 的附加约束是否能在 `tgt` 中保留
- `tgt` 是否真的是 `src` 的超集，而不是另一个子场景

若没有这第二层，直接融合的风险会很高。

## 最后结论

你的“规则融合”思路本身是有价值的，但它更像：

- 一个**候选召回与对齐**方案

而不是：

- 一个可直接自动执行的**最终融合**方案

当前数据上，最稳妥的结论是：

- 这套思路对“明显同家族规则”有效
- 对“同 CWE 但不同 sink family”的规则无效
- 对边界场景必须人工复核

因此，`merge_target` 适合作为：

- “优先人工审查的推荐目标”

而不适合作为：

- “可以无条件自动融合的目标”
