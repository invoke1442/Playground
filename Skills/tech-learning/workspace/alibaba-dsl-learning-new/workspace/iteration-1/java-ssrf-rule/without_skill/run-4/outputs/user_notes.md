# Java SSRF Alibaba DSL Rule Package

Created under `outputs/config`.

## Contents

- `90001.rul`: Java SSRF taint rule. The `import roster Java_ssrf_taint;` statement is first in the rule body, before `type` and `subType`.
- `rosters/Java_ssrf_taint_0.ros`: roster with:
  - Source: `javax.servlet.http.HttpServletRequest.getParameter` via `source.methodReturn`
  - Sinks: `java.net.URL.<init>` and `org.springframework.web.client.RestTemplate.getForObject` first argument via `sink.methodArg`
  - Sanitizer: `com.alibaba.security.SecurityUtil.checkSSRF` via `sanitizer.methodReturn`
- `relation/config_roster_relation.json`: maps rule id `90001` to roster file stem `Java_ssrf_taint_0`.

Rule entry point:

```java
Rule JavaSsrfTaintRule extends AbstractTaintRule {
    import roster Java_ssrf_taint;
    type = "SSRF";
    subType = "ssrfJava";
    general.customSubject = "SSRF";
}
```

## Local Lint

Run from this workspace:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/lint_alibaba_dsl.py outputs/config --language java
```

## Remote Verify Commands

Do not run these unless you intend to call the remote verifier:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py outputs/config --language java --verify-type rule --rule-id 90001
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py outputs/config --language java --verify-type roster --roster-name Java_ssrf_taint_0
```

The remote verifier packages the config and uploads it; it was intentionally not called here.
