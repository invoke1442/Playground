# Verification And Packaging

## Current Service Status

The official verify API should be treated as part of the normal validation flow again. Run local lint first, then use `scripts/verify_alibaba_dsl.py` for official verifier acceptance when needed. Prefer the helper script over ad hoc `curl`, because the request uses multipart fields with strict naming and packaging expectations.

## Official Verify API

Documented endpoint in the bundled official docs and current helper default:

```text
POST http://43.106.136.189:8081/api/v1/verify
```

Treat the verify URL as deployment-specific rather than hard-coded truth. If the current deployment has moved, override it with `--url` or `ALIBABA_DSL_VERIFY_URL`.

Required multipart fields:

| Field | Required | Notes |
|---|---|---|
| `file` | yes | Plain `.tar` config archive |
| `language` | yes | `java` or `javascript` |
| `verify_type` | yes | `rule` or `roster` |
| `rule_id` | for rules | Numeric id matching `{rule_id}.rul` |
| `roster_name` | for rosters | File stem such as `Java_web_taint_0` |

Use `verify_type=rule` when validating a `.rul` entry point. Use `verify_type=roster` when validating a standalone `.ros` roster package.

Use `scripts/verify_alibaba_dsl.py` because the local environment needs a manually built binary multipart request:

```bash
python scripts/verify_alibaba_dsl.py config --language java --verify-type rule --rule-id 90001
python scripts/verify_alibaba_dsl.py config --language java --verify-type roster --roster-name Java_web_taint_0
```

Override the endpoint when the deployment URL changes:

```bash
ALIBABA_DSL_VERIFY_URL="https://verify.example/api/v1/verify" \
python scripts/verify_alibaba_dsl.py config --language java --verify-type rule --rule-id 90001

python scripts/verify_alibaba_dsl.py config --language java --verify-type rule --rule-id 90001 \
  --url "https://verify.example/api/v1/verify"
```

Exit codes:

| Code | Meaning |
|---|---|
| `0` | API returned success and no verifier output |
| `1` | curl/API-level failure |
| `2` | API succeeded but verifier returned errors or warnings |

Common transport failures during endpoint drift:

- `curl: (7) Failed to connect ... Connection refused`: the documented host/port is stale or the service is down.
- `curl: (56) Recv failure: Connection reset by peer`: the server closed the connection before returning a verifier response; re-check the current deployment URL and protocol assumptions.

## Archive Layout

Rule verification:

```text
config.tar
├── 90001.rul
├── rosters/
│   └── Java_web_taint_0.ros
├── relation/
│   └── config_roster_relation.json
└── extend-file/
    ├── 90001/
    │   └── CustomClass.java
    └── rosters/Java_web_taint_0/
        └── CustomClass.java
```

Roster verification:

```text
config.tar
├── rosters/
│   └── Java_web_taint_0.ros
└── extend-file/
    └── rosters/Java_web_taint_0/
        └── CustomClass.java
```

JavaScript examples often use `relation/config_addition_relation.json` and `relation/actual_use_config.json`; Java production examples use `config_roster_relation.json`.

## Local Lint

Run local lint before remote verify:

```bash
python scripts/lint_alibaba_dsl.py config --language java --json
python scripts/lint_alibaba_dsl.py config --language javascript --json
```

The linter checks:

- `.rul` and `.ros` declarations exist.
- Rule imports precede fields.
- imported roster declarations exist as `rosters/{Name}_0.ros`.
- relation config contains imported rosters with `_0`.
- `loadclass` has a likely extend-file target.

Local lint does not prove official verifier acceptance. Use it as the first-pass structural check, then run remote verify when you need verifier-backed confirmation.
