# Runtime Scan Lab

This lab prepares runtime-focused cases for four semantics that cannot be validated with the public verify API alone:

1. `param.value`
2. empty-string `value`
3. `flag`
4. `excludeTag`

Each case contains:

- `config/`: Alibaba DSL rule, roster, relation files, and `config.tar`
- `app/src/`: minimal Java source to be scanned

Recommended comparison points once a real scanner is available:

- `case01_param_value`: `HeaderSink.setHeader("Location", tainted)` should differ from `HeaderSink.setHeader("X-Other", tainted)` if `param.value` is effective at runtime.
- `case02_empty_value`: compare whether `sink.allocArg += { value = ""; }` behaves like a wildcard sink for `new WildA(tainted)` and `new WildB(tainted)`.
- `case03_flag_without` vs `case03_flag_with`: compare alert counts on identical source/sink code to see whether `flag` affects runtime semantics or is metadata only.
- `case04_exclude_tag_without` vs `case04_exclude_tag_with_exclude`: compare whether `TaggedSink.consume(tainted)` disappears only when `import roster Runtime_exclude_tag exclude SkipTagged;` is used.

The current public environment exposes only `POST /api/v1/verify`, not a scan endpoint. These cases are therefore prepared for an internal scanner or another environment that can execute Alibaba DSL against source code.
