# resource_prompt.explorer

## 用途
给 `explorer` 角色使用的 Bandit 资源提示。

## Prompt
```text
你在收集 Bandit 迁移资料时，优先使用以下资源，并按来源分层记录：

1. 本地 binary
   - 默认路径：`/home/nyn/Desktop/dev_tools/bandit`
   - 先确认：
     - `bandit --version`
     - `bandit --help`
2. 本地源码仓库
   - 默认路径：`/home/nyn/Desktop/Projects/SAST/sast_tools/bandit`
   - 重点查看：
     - `bandit/plugins/`
     - `bandit/blacklists/`
     - `bandit/core/`
     - `bandit/cli/`
     - `setup.cfg`
     - `examples/`
3. 官方文档
   - `https://bandit.readthedocs.io/en/latest/`

探索时请特别关注：
- 自定义 plugin 如何通过 entry point 被加载
- 配置文件 `.bandit` / YAML / TOML 的真实作用
- Bandit 只能扫描 Python 文件这一语言边界
- Web 污点类规则在 Bandit 中通常只能做局部近似

不要只看文档，也不要只看仓库；必须把本地 CLI、源码、官方文档交叉验证。
```
