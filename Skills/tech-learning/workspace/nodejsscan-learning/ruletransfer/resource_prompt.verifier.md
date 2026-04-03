# resource_prompt.verifier

以下是当前本地 verifier 应直接使用的 nodejsscan 资源与约束。你要把它们当成固定前提，而不是可选建议。

## 固定资源

- `nodejsscan_BIN=/home/nyn/Desktop/dev_tools/nodejsscan`
- `nodejsscan_REPO=/home/nyn/Desktop/Projects/SAST/sast_tools/njsscan`
- `njsscan 0.4.3`
- `libsast 3.1.6`
- `semgrep 1.86.0`
- 配套脚本：`./run-nodejsscan-target-rules.sh`

## verifier 的执行前提

- translator 产物应位于 `target_rule/`
- verifier 需要先做契约检查，再做实际运行
- 若 translator 未遵守固定文件名和目录结构，verifier 先做最小改造

## 统一运行契约

优先通过以下方式调用：

```bash
./run-nodejsscan-target-rules.sh \
  --target-rule ./target_rule \
  --output-dir ./nodejsscan-out \
  <scan_paths...>
```

## verifier 的重点

- 不是只看“能不能跑”，还要看：
  - 是否命中 TP
  - 是否误报 TN
  - 是否因过度降级导致语义跑偏
  - 是否因大而散的规则导致性能失控
