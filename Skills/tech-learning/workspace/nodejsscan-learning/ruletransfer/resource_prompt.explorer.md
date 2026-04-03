# resource_prompt.explorer

以下资源是当前本地 **已安装且允许直接使用** 的 nodejsscan 相关事实。你是 `explorer`，请优先基于这些本地资源取证，而不是重新发明环境假设。

## 固定本地资源

- `nodejsscan_BIN=/home/nyn/Desktop/dev_tools/nodejsscan`
- `nodejsscan_REPO=/home/nyn/Desktop/Projects/SAST/sast_tools/njsscan`
- nodejsscan CLI 实际版本：`njsscan 0.4.3`
- `libsast 3.1.6`
- `semgrep 1.86.0`
- Python：`3.12.11`

## 本地源码位置

- CLI 源码仓库：`/home/nyn/Desktop/Projects/SAST/sast_tools/njsscan`
- Web 仓库：`/home/nyn/Desktop/Projects/SAST/sast_tools/nodejsscan`

## 你应优先查看的本地文件

- `njsscan/njsscan/__main__.py`
- `njsscan/njsscan/njsscan.py`
- `njsscan/njsscan/settings.py`
- `njsscan/njsscan/utils.py`
- `njsscan/njsscan/rules/semantic_grep/`
- `njsscan/njsscan/rules/pattern_matcher/`
- `njsscan/njsscan/rules/missing_controls.yaml`

## 对 explorer 的提醒

- 不要把 `nodejsscan` Web UI 仓库误当成自定义规则的主要入口
- 真正与目标规则迁移直接相关的是 `njsscan` CLI 仓库
- 自定义规则能力要从源码/API 层理解，不能只看 CLI 帮助
