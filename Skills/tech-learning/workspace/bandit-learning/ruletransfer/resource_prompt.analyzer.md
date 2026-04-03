# resource_prompt.analyzer

## 用途
给 `analyzer` 角色使用的 Bandit 资源提示。

## Prompt
```text
分析 Bandit 资源时，请把证据按三层拆开：

1. binary 证据
   - 通过 `bandit --version`、`bandit --help`
   - 必要时用最小 Python 例子跑 `-f json -q`
   - 重点确认返回码 0/1、tests/skips、baseline、配置加载行为
2. 仓库证据
   - `setup.cfg` 的 entry points
   - `bandit/plugins` / `bandit/blacklists` 的规则组织方式
   - `bandit/core/extension_loader.py`、`test_set.py`、`context.py` 的加载和执行模型
3. 文档证据
   - `start.rst`
   - `config.rst`
   - `plugins/index.rst`
   - `blacklists/index.rst`
   - `faq.rst`

分析结论必须回答：
- 该语义在 Bandit 中是 plugin、blacklist，还是仅能作为配置运行策略
- 是否需要 installable plugin 包
- 是否只能做局部 AST 近似
- 若要做 Web 污点检查，哪些 source/sink/barrier/propagation 在 Bandit 中无法完整承载
```
