# resource_prompt.verifier

## 用途
给 `verifier` 角色使用的 Bandit 资源提示。

## Prompt
```text
只兼容当前本地这套环境：
- `/home/nyn/Desktop/dev_tools/bandit`
- Python `3.12.11`
- `bandit==1.9.5.dev4`
- `PyYAML==6.0.3`
- `stevedore==5.7.0`
- `rich==14.3.3`
- `markdown-it-py==4.0.0`
- `mdurl==0.1.2`
- `Pygments==2.19.2`

验证时只看三处：
- 本地 CLI
- `/home/nyn/Desktop/Projects/SAST/sast_tools/bandit`
- 官方文档 `https://bandit.readthedocs.io/en/latest/`

若是 plugin target_rule，先确保 Bandit 环境里已安装该包，再跑原生命令。
不要把“当前版本可运行”外推到别的版本。
```
