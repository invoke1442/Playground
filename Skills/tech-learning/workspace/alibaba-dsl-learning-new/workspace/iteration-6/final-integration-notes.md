# Iteration 6 Final Integration Notes

## Goal

Remove the active legacy/non-legacy split from `alibaba-dsl-new`, validate the final reference model, and fold the last reliable operational findings back into the skill.

## Structural Integration

- Deleted `alibaba-dsl-new/references/legacy-verify-notes-policy.md`.
- Removed all routing from `SKILL.md` to a separate legacy-policy file.
- Rewrote `java-dsl-syntax.md` and `javascript-dsl-syntax.md` to present one unified set of verified Rule/Roster facts.
- Kept extension-mechanism authority in `references/java-loadclass/` and `references/javascript-extend-file/`, but no longer described this as a legacy-vs-non-legacy conflict policy.

## Verification Findings

### Local lint

Representative template-derived configs were created under `workspace/iteration-6/verify-runs/`:

- `java-rule`
- `java-roster`
- `js-rule`
- `js-roster`
- `java-bad-sink-methodreturn`
- `js-bad-precise`

Results:

- Positive rule packages (`java-rule`, `js-rule`) passed local lint with no warnings.
- Roster-only packages produced the expected structural warnings:
  - `NO_RULE_FILES`
  - `MISSING_RELATION`
- Negative semantic cases still passed local lint, confirming that lint is only a structural gate and not a substitute for remote verifier semantics.

### Remote verify

Remote verify was attempted with the current helper script and archived under each run's `artifacts/verify-result.json`.

Observed transport failures against the documented default endpoint `http://43.106.136.189:8081/api/v1/verify`:

- `curl: (56) Recv failure: Connection reset by peer` on multipart verify attempts.
- `curl: (7) Failed to connect ... Connection refused` on health checks.

This means the old hard-coded endpoint is no longer a dependable operational truth for the skill. The final integrated lesson is:

- keep remote verify in the workflow;
- do not hard-code trust in one historical host/port;
- make the verify URL configurable.

## Final Skill Changes Driven By Validation

- `scripts/verify_alibaba_dsl.py` now supports `ALIBABA_DSL_VERIFY_URL`.
- `references/verification.md` now documents both `--url` and `ALIBABA_DSL_VERIFY_URL`.
- `references/error-guide.md` now includes live transport failures:
  - `curl: (7) Failed to connect ... Connection refused`
  - `curl: (56) Recv failure: Connection reset by peer`
- `SKILL.md` now tells agents to treat the verify URL as deployment-specific.

## Validation Performed

- `python3 workspace/iteration-1/test_tool_contract.py`
- `python3 workspace/iteration-2/test_api_coverage.py`
- `python3 workspace/iteration-4/test_legacy_notes_integration.py`
- `python3 workspace/iteration-5/test_rule_roster_coverage.py`
- `python3 workspace/iteration-6/test_unified_reference_model.py`
- `python3 /home/nyn/.codex/skills/anthropic-style-skill-creator/scripts/quick_validate.py alibaba-dsl-new`

All listed local tests passed after the integration changes.
