# resource_prompt.translator

## 用途
给 `translator` 角色使用的 Bandit 资源提示。

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

资源入口只看三处：
- 本地 CLI
- `/home/nyn/Desktop/Projects/SAST/sast_tools/bandit`
- 官方文档 `https://bandit.readthedocs.io/en/latest/`

不要设计脚本接口。只围绕 `bandit.yaml`、entry point package 和原生命令写产物。
```
