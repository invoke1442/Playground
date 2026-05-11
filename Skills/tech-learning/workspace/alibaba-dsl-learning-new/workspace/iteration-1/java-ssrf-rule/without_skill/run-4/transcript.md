## Codex Final Message

Local lint still passes and the helper now sees all expected content. I noticed the helper wrote its own grading artifacts outside `outputs`, so I’m checking and cleaning only those artifacts from this run to keep the requested deliverables confined to `outputs`.

## Codex Stderr

## Eval Prompt
Use Alibaba DSL to create a Java SSRF taint rule package. Source: HttpServletRequest.getParameter. Sink: new URL(String) and RestTemplate.getForObject first argument. Include a sanitizer for SecurityUtil.checkSSRF, relation config, and commands to lint and verify it.
## Timeout
Reading prompt from stdin...
