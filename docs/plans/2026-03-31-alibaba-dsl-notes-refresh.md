# Alibaba DSL Notes Refresh Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Re-verify the updated Alibaba DSL API documentation against the live verification service, expand the experiment matrix with more passing and failing samples, and refresh the learning notes so every operational claim is backed by current evidence.

**Architecture:** Keep the work centered in `Skills/tech-learning/workspace/alibaba-dsl-learning/`. Extend the existing experiment harness instead of replacing it, save every HTTP response artifact, then rewrite the notes to separate documented facts from inferred rules. Mermaid stays as a generated artifact tied to the final note structure.

**Tech Stack:** Bash, curl, tar, Markdown, Mermaid CLI, local official docs

---

### Task 1: Refresh Current Context

**Files:**
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/run-validations.sh`
- Review: `Skills/tech-learning/workspace/alibaba-dsl-learning/official-docs/alibaba-dsl-api-doc.md`
- Review: `Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-learning-notes.md`

**Step 1: Inspect the updated API doc**

Run: `rg -n '43\.106\.136\.189|47\.243\.76\.86|localhost:8080|/api/v1/verify|/api/v1/health' Skills/tech-learning/workspace/alibaba-dsl-learning/official-docs/alibaba-dsl-api-doc.md`

Expected: Find the live host references and any leftovers like `localhost:8080`.

**Step 2: Inspect stale conclusions in the note**

Run: `rg -n '502|47\.243\.76\.86|43\.106\.136\.189|health=200|verify' Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-learning-notes.md`

Expected: List every section that must be revised after fresh verification.

**Step 3: Update the validation harness requirements**

Expand the script so it can run a larger matrix and persist:
- HTTP status
- headers
- response body
- sample metadata

**Step 4: Re-run the baseline matrix**

Run the validation script and confirm which current assumptions still hold.

### Task 2: Add Verified Success Samples

**Files:**
- Create: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/experiments/valid-java-roster/config/...`
- Create: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/experiments/valid-js-roster/config/...`
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/run-validations.sh`

**Step 1: Create a minimal Java roster sample**

Include a single `.ros` under `rosters/` with the least syntax needed for roster validation.

**Step 2: Create a minimal JavaScript roster sample**

Use the documented JS/TS roster style with the least moving parts.

**Step 3: Add these samples to the validation script**

Ensure each sample is packed into its own tar and uploaded with explicit parameters.

**Step 4: Run validation and capture outputs**

Expected: Determine whether roster validation succeeds, and whether any naming constraints differ from the docs.

### Task 3: Add Stable Failure Samples

**Files:**
- Create: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/experiments/error-*`
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/run-validations.sh`

**Step 1: Add request-level failure cases**

Cover cases like:
- invalid `language`
- missing `rule_id`
- missing `roster_name`

**Step 2: Add archive/content failure cases**

Cover cases like:
- rule tar with missing `.rul`
- roster tar with missing `rosters/`
- filename mismatch against `rule_id` or `roster_name`

**Step 3: Add syntax/semantic failure cases**

Cover cases like:
- invalid field name
- parse or lexical style error if it can be reproduced from the docs

**Step 4: Run validation and record which failures are stable**

Expected: Keep only the failure patterns that produce consistent responses.

### Task 4: Derive Field and Naming Rules

**Files:**
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-learning-notes.md`
- Review: `Skills/tech-learning/workspace/alibaba-dsl-learning/workspace/results/*`

**Step 1: Compare documented rules with observed behavior**

Create a short matrix of:
- documented
- observed
- inferred
- unresolved

**Step 2: Extract field-level patterns**

Examples:
- where `value` appears
- where `pattern` appears
- where `precise`, `paramIndex`, `taintTag`, `xpath` appear

**Step 3: Extract naming rules**

Examples:
- declaration name vs file name
- `rule_id` vs file stem
- roster declaration name vs roster file stem vs request parameter

### Task 5: Rewrite the Learning Notes

**Files:**
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-learning-notes.md`

**Step 1: Replace stale service conclusions**

Every statement tied to the old IP mismatch or `502` result must be replaced with current evidence.

**Step 2: Expand the examples section**

Add passing and failing samples with exact file references and observed outputs.

**Step 3: Expand the troubleshooting and best-practice sections**

Separate:
- documented errors
- observed errors
- pending verification items

**Step 4: Refresh source mapping and conflict resolution**

Update the official chapter mapping and note any remaining doc inconsistencies.

### Task 6: Rebuild Mermaid and Final Verification

**Files:**
- Modify: `Skills/tech-learning/workspace/alibaba-dsl-learning/.mermaid-check/alibaba-dsl-learning-notes.mmd`
- Generate: `Skills/tech-learning/workspace/alibaba-dsl-learning/.mermaid-check/alibaba-dsl-learning-notes.svg`

**Step 1: Update Mermaid to match the new note structure**

Keep the graph aligned with the final learning path and observed validation workflow.

**Step 2: Compile Mermaid**

Run: `npm_config_cache=/tmp/npm-cache npx -y @mermaid-js/mermaid-cli -p /tmp/puppeteer-mermaid.json -i Skills/tech-learning/workspace/alibaba-dsl-learning/.mermaid-check/alibaba-dsl-learning-notes.mmd -o Skills/tech-learning/workspace/alibaba-dsl-learning/.mermaid-check/alibaba-dsl-learning-notes.svg`

Expected: Exit 0 and regenerated SVG.

**Step 3: Run final evidence checks**

Run commands that prove:
- notes file exists
- Mermaid SVG exists
- result artifacts exist
- latest statuses match the claims made in the note

**Step 4: Report completion with evidence**

State only claims directly supported by the final command outputs.
