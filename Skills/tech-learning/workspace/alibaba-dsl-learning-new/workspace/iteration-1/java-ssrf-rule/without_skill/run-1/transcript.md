## Eval Prompt

Use Alibaba DSL to create a Java SSRF taint rule package. Source: HttpServletRequest.getParameter. Sink: new URL(String) and RestTemplate.getForObject first argument. Include a sanitizer for SecurityUtil.checkSSRF, relation config, and commands to lint and verify it.

## Codex Final Message

Codex CLI failed while writing runtime state. Set writable TMPDIR, XDG_CACHE_HOME, and XDG_RUNTIME_DIR or run through codex_runner.default_codex_env().

## Codex Stderr

WARNING: proceeding, even though we could not update PATH: Read-only file system (os error 30)
Reading prompt from stdin...
Error: failed to initialize in-process app-server client: Read-only file system (os error 30)
