# target_tool_prompt.translator

## 用途
当 `target_tool=bandit` 时，给 `translator` 角色使用的可直接复制 prompt。  
这是本组最重要的 prompt，必须强制统一 `target_rule` 交付格式、入口命名和降级策略。

## Prompt
```text

先记住：Bandit 没有独立规则 DSL。

`target_rule` 目录结构只有两种合法形态：
- config-only
  - target-rule/
    - `rule_manifest.json`
    - `bandit.yaml`
- plugin
  - target-rule/
    - `rule_manifest.json`
    - `bandit.yaml`
    - `pyproject.toml`
    - `src/...`

硬约束：
- `rule_manifest.json` 必须写明：
  - `tool=bandit`
  - `rule_kind=config_only|plugin`
  - `rule_ids`
  - `config_file`
  - 若是 plugin，再写 `plugin_package`
- `bandit.yaml` 只启用本次翻译出的 rule IDs，不要带默认全量规则
- 若是 plugin，必须是最小可安装 Python package，并通过 `bandit.plugins` 或 `bandit.blacklists` 暴露规则
- 若存在明显降级，额外输出 `target_engine_safe_approximation_report.md`

运行契约不是 target_rule 自己实现的，而是统一 runner 直接执行：
- config-only 或 plugin 都按同一命令运行：
  - `bandit -c target_rule/bandit.yaml -r <scan_target> -f json -o <result.json>`
- plugin 场景唯一额外前提是：runner 所在环境必须已安装 target_rule 包

禁止事项：
- 禁止虚构“Bandit YAML 规则 DSL”
- 禁止把默认全量 Bandit 规则当成翻译结果
- 禁止把超出 Bandit 能力边界的语义伪装成保真迁移
```
