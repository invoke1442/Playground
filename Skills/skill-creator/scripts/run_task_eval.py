#!/usr/bin/env python3
"""Run a single task eval with Codex and save viewer-compatible outputs."""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

from scripts.codex_runner import run_codex_exec


def build_prompt(task: str, output_dir: Path, skill_path: Path | None, input_files: list[str]) -> str:
    lines = [
        "Execute this eval task in a noninteractive Codex subprocess.",
        f"Task: {task}",
        f"Save all user-relevant outputs under: {output_dir}",
    ]
    if skill_path:
        lines.append(f"Skill path: {skill_path}")
        lines.append("Read that skill before working and follow its instructions.")
    else:
        lines.append("No skill path is provided; solve the task using normal Codex behavior.")
    if input_files:
        lines.append("Input files:")
        lines.extend(f"- {item}" for item in input_files)
    else:
        lines.append("Input files: none")
    lines.append("Also write a concise user_notes.md if anything needs human review.")
    return "\n".join(lines)


def run_task_eval(
    task: str,
    run_dir: Path,
    *,
    skill_path: Path | None = None,
    input_files: list[str] | None = None,
    model: str | None = None,
    codex_bin: str = "codex",
    timeout: int = 600,
) -> dict:
    run_dir.mkdir(parents=True, exist_ok=True)
    outputs_dir = run_dir / "outputs"
    outputs_dir.mkdir(parents=True, exist_ok=True)
    prompt = build_prompt(task, outputs_dir, skill_path, input_files or [])
    started = time.time()
    result = run_codex_exec(
        prompt,
        workspace=run_dir,
        model=model,
        codex_bin=codex_bin,
        timeout=timeout,
        raw_events_path=run_dir / "codex_events.jsonl",
    )
    ended = time.time()
    transcript = [
        "## Eval Prompt",
        "",
        task,
        "",
        "## Codex Final Message",
        "",
        result.final_text,
        "",
        "## Codex Stderr",
        "",
        result.stderr,
    ]
    (run_dir / "transcript.md").write_text("\n".join(transcript))
    (outputs_dir / "transcript.md").write_text("\n".join(transcript))
    metrics = {
        "tool_calls": {},
        "total_tool_calls": 0,
        "total_steps": len(result.events),
        "files_created": [str(p.relative_to(outputs_dir)) for p in outputs_dir.rglob("*") if p.is_file()],
        "errors_encountered": 0 if result.returncode == 0 else 1,
        "output_chars": sum(p.stat().st_size for p in outputs_dir.rglob("*") if p.is_file()),
        "transcript_chars": len("\n".join(transcript)),
    }
    (outputs_dir / "metrics.json").write_text(json.dumps(metrics, indent=2))
    timing = {
        "duration_ms": int((ended - started) * 1000),
        "total_duration_seconds": round(ended - started, 3),
    }
    (run_dir / "timing.json").write_text(json.dumps(timing, indent=2))
    return {
        "returncode": result.returncode,
        "final_text": result.final_text,
        "run_dir": str(run_dir),
        "outputs_dir": str(outputs_dir),
    }


def main():
    parser = argparse.ArgumentParser(description="Run one Codex task eval")
    parser.add_argument("--task", required=True, help="Eval task prompt")
    parser.add_argument("--run-dir", required=True, type=Path, help="Run directory")
    parser.add_argument("--skill-path", type=Path, default=None, help="Optional skill path")
    parser.add_argument("--input-file", action="append", default=[], help="Input file path (repeatable)")
    parser.add_argument("--model", default=None, help="Codex model")
    parser.add_argument("--codex-bin", default="codex", help="Codex CLI executable")
    parser.add_argument("--timeout", type=int, default=600, help="Timeout in seconds")
    args = parser.parse_args()
    output = run_task_eval(
        args.task,
        args.run_dir,
        skill_path=args.skill_path,
        input_files=args.input_file,
        model=args.model,
        codex_bin=args.codex_bin,
        timeout=args.timeout,
    )
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
