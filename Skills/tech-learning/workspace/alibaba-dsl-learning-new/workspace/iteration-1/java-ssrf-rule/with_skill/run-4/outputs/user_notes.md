# Java SSRF Alibaba DSL Rule Package

Deliverables are under `outputs/config`.

- Rule: `90001.rul`
- Roster: `rosters/Java_ssrf_taint_0.ros`
- Relation config: `relation/config_roster_relation.json`
- Source: return value of `javax.servlet.http.HttpServletRequest.getParameter`
- Sinks: argument 0 of `java.net.URL.<init>` and `org.springframework.web.client.RestTemplate.getForObject`
- Sanitizer: argument passed to `com.alibaba.security.SecurityUtil.checkSSRF`

Local lint:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/lint_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-4/outputs/config --language java --json
```

Remote verify commands, not run here:

```bash
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-4/outputs/config --language java --verify-type rule --rule-id 90001
python /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/alibaba-dsl-new/scripts/verify_alibaba_dsl.py /home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning-new/workspace/iteration-1/java-ssrf-rule/with_skill/run-4/outputs/config --language java --verify-type roster --roster-name Java_ssrf_taint_0
```
