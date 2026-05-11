# Verification And Packaging

## Current Service Status

The official verify API endpoint is currently unavailable from this environment. Do not attempt to access `http://43.106.136.189:8081/api/v1/verify`; do not run curl, health checks, or `verify_alibaba_dsl.py` against the remote service. Treat remote verify as blocked. Validate with local lint, archive layout checks, and package creation only.

## Official Verify API

Endpoint:

```text
POST http://43.106.136.189:8081/api/v1/verify
```

Required multipart fields:

| Field | Required | Notes |
|---|---|---|
| `file` | yes | Plain `.tar` config archive |
| `language` | yes | `java` or `javascript` |
| `verify_type` | yes | `rule` or `roster` |
| `rule_id` | for rules | Numeric id matching `{rule_id}.rul` |
| `roster_name` | for rosters | File stem such as `Java_web_taint_0` |

When the service is restored in a future environment, use `scripts/verify_alibaba_dsl.py` because the local environment needs a manually built binary multipart request. Do not run these commands while the endpoint is unavailable:

```bash
python scripts/verify_alibaba_dsl.py config --language java --verify-type rule --rule-id 90001
python scripts/verify_alibaba_dsl.py config --language java --verify-type roster --roster-name Java_web_taint_0
```

Exit codes:

| Code | Meaning |
|---|---|
| `0` | API returned success and no verifier output |
| `1` | curl/API-level failure |
| `2` | API succeeded but verifier returned errors or warnings |

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

Run local lint instead of remote verify while the service is unavailable:

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

Local lint does not prove official verifier acceptance, but it is the required validation path while the official endpoint is unavailable.
