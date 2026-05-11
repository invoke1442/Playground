# Java SSRF Alibaba DSL Rule Package

Created package: `outputs/config`

Modeling:
- Source: `javax.servlet.http.HttpServletRequest.getParameter` return value.
- Sinks: `java.net.URL.<init>` argument 0 and `org.springframework.web.client.RestTemplate.getForObject` argument 0.
- Sanitizer: `com.alibaba.security.SecurityUtil.checkSSRF` return value.
- Relation config: `outputs/config/relation/config_roster_relation.json` maps rule `90001` to roster `Java_ssrf_taint_0`.

Lint:
```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/lint_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-3/outputs/config --language java --json
```

Verify rule:
```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-3/outputs/config --language java --verify-type rule --rule-id 90001
```

Verify roster:
```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-3/outputs/config --language java --verify-type roster --roster-name Java_ssrf_taint_0
```

`outputs/SampleController.java` contains vulnerable and sanitized sample paths for both sinks.
