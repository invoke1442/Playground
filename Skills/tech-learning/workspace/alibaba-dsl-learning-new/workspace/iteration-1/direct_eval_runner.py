#!/usr/bin/env python3
"""Direct Codex eval runner that avoids nested Codex instructions."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import time
from pathlib import Path


def parse_events(stdout: str) -> list[dict]:
    events = []
    for line in stdout.splitlines():
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            events.append(item)
    return events


def collect_text(value):
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        out = []
        for item in value:
            out.extend(collect_text(item))
        return out
    if isinstance(value, dict):
        out = []
        for key in ("text", "content", "message", "output"):
            if key in value:
                out.extend(collect_text(value[key]))
        return out
    return []


def final_text(events: list[dict], stdout: str) -> str:
    for event in reversed(events):
        if event.get("type") == "item.completed":
            item = event.get("item", {})
            if isinstance(item, dict) and item.get("type") == "agent_message":
                text = "\n".join(part for part in collect_text(item) if part.strip()).strip()
                if text:
                    return text
    return stdout.strip()


def extract_usage(events: list[dict]) -> dict:
    totals = {
        "input_tokens": 0,
        "cached_input_tokens": 0,
        "output_tokens": 0,
        "reasoning_output_tokens": 0,
    }
    for event in events:
        usage = event.get("usage")
        if not isinstance(usage, dict):
            continue
        for key in totals:
            value = usage.get(key, 0)
            if isinstance(value, int):
                totals[key] += value
    return totals


def build_codex_command(run_dir: Path) -> list[str]:
    return [
        "codex",
        "-a",
        "never",
        "exec",
        "--json",
        "--ephemeral",
        "--dangerously-bypass-approvals-and-sandbox",
        "--skip-git-repo-check",
        "-C",
        str(run_dir),
    ]


def record_result(
    *,
    run_dir: Path,
    outputs_dir: Path,
    stdout: str,
    stderr: str,
    returncode: int,
    started: float,
    ended: float,
    timed_out: bool = False,
) -> dict:
    events = parse_events(stdout)
    (run_dir / "codex_events.jsonl").write_text(stdout, encoding="utf-8")
    transcript = "\n".join(
        [
            "## Codex Final Message",
            "",
            final_text(events, stdout),
            "",
            "## Codex Stderr",
            "",
            stderr,
        ]
    )
    (run_dir / "transcript.md").write_text(transcript, encoding="utf-8")
    (outputs_dir / "transcript.md").write_text(transcript, encoding="utf-8")
    metrics = {
        "returncode": returncode,
        "total_steps": len(events),
        "usage": extract_usage(events),
        "files_created": [str(path.relative_to(outputs_dir)) for path in outputs_dir.rglob("*") if path.is_file()],
        "errors_encountered": 0 if returncode == 0 and not timed_out else 1,
        "timed_out": timed_out,
        "output_chars": sum(path.stat().st_size for path in outputs_dir.rglob("*") if path.is_file()),
        "transcript_chars": len(transcript),
    }
    (outputs_dir / "metrics.json").write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    (run_dir / "timing.json").write_text(
        json.dumps({"total_duration_seconds": round(ended - started, 3)}, indent=2),
        encoding="utf-8",
    )
    return {"returncode": returncode, "run_dir": str(run_dir), "outputs_dir": str(outputs_dir)}


def run_eval(task: str, run_dir: Path, skill_path: Path | None) -> dict:
    run_dir.mkdir(parents=True, exist_ok=True)
    outputs_dir = run_dir / "outputs"
    outputs_dir.mkdir(parents=True, exist_ok=True)
    prompt = [
        "Complete this task directly in the current workspace.",
        f"Task: {task}",
        f"Write all deliverables under: {outputs_dir}",
        "Do not start another Codex process.",
        "Do not ask questions; make reasonable assumptions.",
        "Run local lint if possible. Do not call remote verify endpoints; include verify commands for the user instead.",
    ]
    if skill_path:
        prompt.extend(
            [
                f"Skill path: {skill_path}",
                "Read that SKILL.md first, then read only the referenced files needed for this task.",
            ]
        )
    else:
        prompt.append("No skill is provided; use general knowledge only.")
    prompt.append("Write a concise user_notes.md under the outputs directory.")

    env = dict(os.environ)
    env.update(
        {
            "CODEX_HOME": "/tmp/codex-home-eval",
            "TMPDIR": "/tmp/alibaba-dsl-codex-runtime/tmp",
            "XDG_CACHE_HOME": "/tmp/alibaba-dsl-codex-runtime/cache",
            "XDG_RUNTIME_DIR": "/tmp/alibaba-dsl-codex-runtime/runtime",
        }
    )
    for name in ("CODEX_HOME", "TMPDIR", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"):
        Path(env[name]).mkdir(parents=True, exist_ok=True)

    cmd = build_codex_command(run_dir)
    started = time.time()
    try:
        completed = subprocess.run(
            cmd,
            input="\n".join(prompt),
            text=True,
            capture_output=True,
            timeout=240,
            env=env,
        )
        ended = time.time()
        return record_result(
            run_dir=run_dir,
            outputs_dir=outputs_dir,
            stdout=completed.stdout,
            stderr="\n".join(["## Eval Prompt", task, "## Process Stderr", completed.stderr]),
            returncode=completed.returncode,
            started=started,
            ended=ended,
        )
    except subprocess.TimeoutExpired as exc:
        ended = time.time()
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        return record_result(
            run_dir=run_dir,
            outputs_dir=outputs_dir,
            stdout=stdout,
            stderr="\n".join(["## Eval Prompt", task, "## Timeout", stderr]),
            returncode=124,
            started=started,
            ended=ended,
            timed_out=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--task", required=True)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--skill-path", type=Path)
    args = parser.parse_args()
    print(json.dumps(run_eval(args.task, args.run_dir, args.skill_path), indent=2))


if __name__ == "__main__":
    main()
