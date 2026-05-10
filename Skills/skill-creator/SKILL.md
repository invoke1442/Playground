---
name: skill-creator
description: Create, update, evaluate, benchmark, optimize, and package Codex skills. Use when users want to create a skill from scratch, improve an existing skill, add scripts/references/assets, generate agents/openai.yaml metadata, run Codex-based evals against with-skill and baseline outputs, grade skill performance, optimize a skill description for better Codex triggering, or package a .skill file.
---

# Skill Creator

Use this skill to create Codex skills and iteratively improve them with evidence.

## Core Workflow

1. Capture the skill intent and concrete trigger examples.
2. Plan reusable contents: `scripts/`, `references/`, and `assets/`.
3. Initialize new skills with `scripts/init_skill.py` when creating from scratch.
4. Write or edit `SKILL.md` and bundled resources.
5. Validate with `scripts/quick_validate.py`.
6. Run realistic evals with Codex subprocesses, compare with-skill against baseline, grade results, and show outputs in the eval viewer.
7. Iterate from user feedback and benchmark data.
8. Optimize the `description` field when the skill content is stable.
9. Package with `scripts/package_skill.py`.

Adapt the workflow to the user's stage. If they already have a draft, start at validation or eval. If they only want a quick update, keep the loop small, but still preserve Codex compatibility.

## Creating Or Updating A Skill

### Capture Intent

Extract answers from the conversation before asking questions:

1. What should this skill enable Codex to do?
2. Which user prompts or contexts should trigger it?
3. What output format should it produce?
4. Are objective evals useful for this skill?
5. Where should the skill live? Default to `${CODEX_HOME:-$HOME/.codex}/skills`.

Ask only for details that cannot be discovered from local files or conversation context.

### Skill Structure

```
skill-name/
├── SKILL.md
│   ├── YAML frontmatter with name and description
│   └── concise Markdown instructions
├── agents/
│   └── openai.yaml
├── scripts/
├── references/
└── assets/
```

Use bundled resources only when they remove repeated work:

- `scripts/`: deterministic or repetitive operations.
- `references/`: detailed context Codex should load only when needed.
- `assets/`: templates, images, fonts, examples, or files copied into outputs.

Keep `SKILL.md` lean. Move long schemas, API docs, examples, and variant-specific instructions into one-level-deep reference files and link them clearly from `SKILL.md`.

### Initialize New Skills

For new skills, run:

```bash
python -m scripts.init_skill <skill-name> --path "${CODEX_HOME:-$HOME/.codex}/skills"
python -m scripts.init_skill <skill-name> --path "${CODEX_HOME:-$HOME/.codex}/skills" --resources scripts,references
```

Pass UI metadata through `--interface key=value`. Read `references/openai_yaml.md` before adding optional metadata fields. Generate only fields that are known or intentionally chosen.

### Write SKILL.md

Frontmatter:

- `name`: lowercase letters, digits, and hyphens only; maximum 64 characters.
- `description`: the primary Codex triggering signal. Include what the skill does and when Codex should use it. Put all trigger guidance here, not in the body.

Body:

- Prefer imperative, task-oriented instructions.
- Explain why important steps matter instead of relying on brittle all-caps rules.
- Include examples when they clarify behavior.
- Do not add unrelated README, changelog, installation guide, or process notes.

### Validate And Package

Run:

```bash
python -m scripts.quick_validate <path/to/skill>
python -m scripts.package_skill <path/to/skill> [output-directory]
```

The validator avoids a hard PyYAML dependency so Codex environments with broken libyaml can still validate frontmatter.

## Running And Evaluating Test Cases

Do not use an external testing skill. Use this skill's Codex-based eval loop.

Store results in `<skill-name>-workspace/` beside the skill. Use iteration directories:

```
<skill-name>-workspace/
└── iteration-1/
    └── eval-descriptive-name/
        ├── eval_metadata.json
        ├── with_skill/run-1/outputs/
        └── without_skill/run-1/outputs/
```

### Test Prompts

Save realistic test prompts to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "expectations": []
    }
  ]
}
```

Draft objective expectations while Codex subprocesses run. Good expectations are hard to satisfy without actually completing the work.

### Execution Runs

For each eval, run both configurations in the same batch:

- `with_skill`: tell the Codex subprocess the skill path and task.
- `without_skill`: same task, no skill path.
- `old_skill`: for existing-skill improvements, snapshot the old skill before editing and use it as a baseline when useful.

Use `scripts/codex_runner.py` for subprocess execution. It standardizes `codex exec --json`, runtime directories, raw event capture, and error diagnostics.

Capture:

- outputs under `outputs/`
- raw Codex JSONL events
- `transcript.md`
- `metrics.json`
- `timing.json`

### Grading And Benchmarking

Grade each run using `agents/grader.md` and save `grading.json` beside `outputs/`. The viewer requires:

```json
{
  "expectations": [
    {"text": "The output includes X", "passed": true, "evidence": "Found in output file"}
  ],
  "summary": {"passed": 1, "failed": 0, "total": 1, "pass_rate": 1.0}
}
```

Aggregate:

```bash
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name> --skill-path <path>
```

Then generate the review UI:

```bash
python eval-viewer/generate_review.py \
  <workspace>/iteration-N \
  --skill-name "<name>" \
  --benchmark <workspace>/iteration-N/benchmark.json
```

In headless environments, use:

```bash
python eval-viewer/generate_review.py <workspace>/iteration-N --static /tmp/<name>-review.html
```

Show the user the viewer. The Outputs tab is for qualitative review; the Benchmark tab shows pass rates, time, token, and analyzer notes. When the user submits feedback, read `feedback.json`, improve the skill, and repeat.

## Description Optimization

Optimize the `description` after the skill behavior is stable.

1. Create 20 realistic trigger eval queries:
   - 8-10 should trigger.
   - 8-10 near-miss should not trigger.
2. Review the eval set with the user using `assets/eval_review.html`.
3. Run:

```bash
python -m scripts.run_loop \
  --eval-set <trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <codex-model> \
  --max-iterations 5 \
  --verbose
```

`scripts/run_eval.py` creates isolated temporary `CODEX_HOME` directories, injects a uniquely named probe skill, runs `codex exec --json`, and detects whether Codex used the skill from auditable evidence such as raw events, skill paths, or unique markers.

`scripts/improve_description.py` calls Codex to propose better descriptions from train failures. `run_loop.py` uses a train/test split and selects the best description by held-out score when available.

Apply the final `best_description` to `SKILL.md`, then rerun validation and relevant trigger evals.

## Forward Testing

Forward-test substantial skills with fresh Codex subprocesses or subagents. Treat tests as an evaluation surface:

- Pass raw artifacts and the skill path, not your diagnosis.
- Avoid leaking expected answers or intended fixes.
- Use fresh workspaces and clean temporary artifacts between iterations.
- Review transcripts and outputs, not only final messages.

## Codex Runtime Notes

- Prefer `codex exec --json --ephemeral` for automation.
- Use `-a never` for noninteractive approval policy.
- Use writable `TMPDIR`, `XDG_CACHE_HOME`, and `XDG_RUNTIME_DIR`; `scripts/codex_runner.py` sets isolated defaults.
- If Codex reports a read-only filesystem during initialization, fix runtime/cache directory configuration before trusting eval results.

## Reference Files

- `references/openai_yaml.md`: Codex UI metadata fields.
- `references/schemas.md`: eval, grading, timing, metrics, benchmark, and comparison JSON schemas.
- `agents/grader.md`: assertion grading instructions.
- `agents/comparator.md`: blind A/B comparison instructions.
- `agents/analyzer.md`: benchmark and comparison analysis instructions.
