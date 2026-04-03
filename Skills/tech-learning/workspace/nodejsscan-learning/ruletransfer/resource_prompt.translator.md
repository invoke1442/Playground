# resource_prompt.translator

以下资源是当前本地 **唯一应被假定存在** 的 nodejsscan 环境。你是 `translator`，请据此输出能在本机直接消费的 `target_rule/`，不要输出任何安装说明。

## 固定环境变量

- `nodejsscan_BIN=/home/nyn/Desktop/dev_tools/nodejsscan`
- `nodejsscan_REPO=/home/nyn/Desktop/Projects/SAST/sast_tools/njsscan`

## 固定版本

- `njsscan 0.4.3`
- `libsast 3.1.6`
- `semgrep 1.86.0`
- Python `3.12.11`

## 对 translator 的硬约束

- 你的产物必须让配套脚本可以直接跑
- 不要输出安装脚本
- 不要假设评测方会替你重命名文件
- 不要假设 CLI 自带自定义规则目录参数

## 你必须记住的 target_rule 目录

```text
target_rule/
  semantic_grep/translated_rule.yaml
  pattern_matcher/translated_rule.yaml
  missing_controls.yaml
```

## 默认策略

- JS/Node Web 漏洞先尝试 `semantic_grep/translated_rule.yaml`
- 模板或弱语义近似再考虑 `pattern_matcher/translated_rule.yaml`
- `missing_controls.yaml` 只给控制缺失类规则使用
