# Java Loadclass Evaluate Lifecycle

Loadclass entrypoints are invoked reflectively. Use `public static Boolean evaluate(...)` unless an official extension point explicitly requires another shape.

## Signatures

| Signature | Use |
|---|---|
| `evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)` | Standard Java taint user-defined pattern |
| `evaluate(JavaNode, BaseFSMMachineRule, BaseTaintedDataRuleData)` | FSM rule custom condition; engine may fall back to two-arg FSM evaluate |
| `evaluate(JavaNode, BaseFSMMachineRule)` | FSM fallback when the three-arg signature is absent |
| `evaluate(JavaNode, Rule)` | Entrance-file user define; requires `treenode instanceof ASTCompilationUnit` |
| `evaluate(SSANode, AbstractSSARule, SSARuleData)` | SSA custom extension |
| `evaluate(JavaNode, BaseLLMScanRule, BaseLLMScanRuleData)` | LLM scan custom extension |

## Return Semantics

- `Boolean.TRUE`: custom condition matches.
- `Boolean.FALSE`: non-match; let the engine continue.
- `null`: treated as false; avoid it.

## Trace Types And Flags

`TracerNode.TYPE` values are `NONE`, `INPUT`, and `OUTPUT`.

Confirmed flags include:

- `PMDConstants.HSFDBIDU` (`"hsfdbidu"`)
- `"My_Dynamic_Process"`
- call-string flags
- UIC field-path flags
