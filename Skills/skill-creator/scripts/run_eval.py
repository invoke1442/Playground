#!/usr/bin/env python3
"""Run Codex trigger evaluation for a skill description."""

from __future__ import annotations

import argparse
import json
import shutil
import sys
import tempfile
import uuid
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path
from typing import Any

from scripts.codex_runner import run_codex_exec
from scripts.utils import parse_skill_md


def find_project_root() -> Path:
    current = Path.cwd()
    for parent in [current, *current.parents]:
        if (parent / ".codex").is_dir() or (parent / "AGENTS.md").exists():
            return parent
    return current


def _copy_codex_config(source_home: Path, target_home: Path) -> None:
    target_home.mkdir(parents=True, exist_ok=True)
    for filename in ("config.toml", "auth.json"):
        src = source_home / filename
        if src.exists():
            shutil.copy2(src, target_home / filename)


def _write_probe_skill(codex_home: Path, skill_name: str, description: str, marker: str) -> Path:
    skill_dir = codex_home / "skills" / skill_name
    skill_dir.mkdir(parents=True, exist_ok=True)
    (skill_dir / "SKILL.md").write_text(
        "---\n"
        f"name: {skill_name}\n"
        "description: |\n"
        f"  {description.replace(chr(10), chr(10) + '  ')}\n"
        "---\n\n"
        f"# {skill_name}\n\n"
        f"When using this skill, mention this marker in your reasoning or output: {marker}\n"
    )
    return skill_dir


def _event_contains(value: Any, needles: tuple[str, ...]) -> bool:
    if isinstance(value, str):
        return any(needle in value for needle in needles)
    if isinstance(value, list):
        return any(_event_contains(item, needles) for item in value)
    if isinstance(value, dict):
        return any(_event_contains(item, needles) for item in value.values())
    return False


def detect_skill_trigger(events: list[dict[str, Any]], final_text: str, skill_dir: Path, marker: str) -> bool:
    skill_path = str(skill_dir)
    needles = (skill_path, f"{skill_dir}/SKILL.md", marker, skill_dir.name)
    return _event_contains(events, needles) or any(needle in final_text for needle in needles)


def run_single_query(
    query: str,
    skill_name: str,
    skill_description: str,
    timeout: int,
    project_root: str,
    model: str | None = None,
    codex_bin: str = "codex",
    codex_home: str | None = None,
    keep_workdirs: bool = False,
    raw_events_dir: str | None = None,
) -> bool:
    unique_id = uuid.uuid4().hex[:8]
    probe_name = f"{skill_name}-probe-{unique_id}"
    marker = f"SKILL_CREATOR_TRIGGER_MARKER_{unique_id}"
    temp_root = Path(tempfile.mkdtemp(prefix="skill-trigger-eval-"))
    try:
        source_home = Path(codex_home).expanduser() if codex_home else Path.home() / ".codex"
        eval_codex_home = temp_root / "codex-home"
        _copy_codex_config(source_home, eval_codex_home)
        skill_dir = _write_probe_skill(eval_codex_home, probe_name, skill_description, marker)
        raw_path = None
        if raw_events_dir:
            raw_path = Path(raw_events_dir) / f"{probe_name}.jsonl"
        prompt = (
            f"{query}\n\n"
            "Use any relevant Codex skills available in this environment. "
            "If you use a skill, follow its instructions."
        )
        env = {"CODEX_HOME": str(eval_codex_home)}
        result = run_codex_exec(
            prompt,
            workspace=Path(project_root),
            model=model,
            timeout=timeout,
            codex_bin=codex_bin,
            env=env,
            raw_events_path=raw_path,
        )
        if result.returncode != 0:
            print(f"Warning: Codex query failed: {result.final_text}", file=sys.stderr)
            return False
        return detect_skill_trigger(result.events, result.final_text, skill_dir, marker)
    finally:
        if not keep_workdirs:
            shutil.rmtree(temp_root, ignore_errors=True)


def run_eval(
    eval_set: list[dict],
    skill_name: str,
    description: str,
    num_workers: int,
    timeout: int,
    project_root: Path,
    runs_per_query: int = 1,
    trigger_threshold: float = 0.5,
    model: str | None = None,
    codex_bin: str = "codex",
    codex_home: str | None = None,
    keep_workdirs: bool = False,
    raw_events_dir: str | None = None,
) -> dict:
    with ProcessPoolExecutor(max_workers=num_workers) as executor:
        future_to_info = {}
        for item in eval_set:
            for run_idx in range(runs_per_query):
                future = executor.submit(
                    run_single_query,
                    item["query"],
                    skill_name,
                    description,
                    timeout,
                    str(project_root),
                    model,
                    codex_bin,
                    codex_home,
                    keep_workdirs,
                    raw_events_dir,
                )
                future_to_info[future] = (item, run_idx)

        query_triggers: dict[str, list[bool]] = {}
        query_items: dict[str, dict] = {}
        for future in as_completed(future_to_info):
            item, _ = future_to_info[future]
            query = item["query"]
            query_items[query] = item
            query_triggers.setdefault(query, [])
            try:
                query_triggers[query].append(future.result())
            except Exception as e:
                print(f"Warning: query failed: {e}", file=sys.stderr)
                query_triggers[query].append(False)

    results = []
    for query, triggers in query_triggers.items():
        item = query_items[query]
        trigger_rate = sum(triggers) / len(triggers)
        should_trigger = item["should_trigger"]
        did_pass = trigger_rate >= trigger_threshold if should_trigger else trigger_rate < trigger_threshold
        results.append(
            {
                "query": query,
                "should_trigger": should_trigger,
                "trigger_rate": trigger_rate,
                "triggers": sum(triggers),
                "runs": len(triggers),
                "pass": did_pass,
            }
        )

    passed = sum(1 for r in results if r["pass"])
    total = len(results)
    return {
        "skill_name": skill_name,
        "description": description,
        "results": results,
        "summary": {"total": total, "passed": passed, "failed": total - passed},
    }


def main():
    parser = argparse.ArgumentParser(description="Run Codex trigger evaluation for a skill description")
    parser.add_argument("--eval-set", required=True, help="Path to eval set JSON file")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--description", default=None, help="Override description to test")
    parser.add_argument("--num-workers", type=int, default=10, help="Number of parallel workers")
    parser.add_argument("--timeout", type=int, default=30, help="Timeout per query in seconds")
    parser.add_argument("--runs-per-query", type=int, default=3, help="Number of runs per query")
    parser.add_argument("--trigger-threshold", type=float, default=0.5, help="Trigger rate threshold")
    parser.add_argument("--model", default=None, help="Model to use for codex exec")
    parser.add_argument("--codex-bin", default="codex", help="Codex CLI executable")
    parser.add_argument("--codex-home", default=None, help="Source CODEX_HOME to copy config/auth from")
    parser.add_argument("--keep-workdirs", action="store_true", help="Keep temporary Codex homes for debugging")
    parser.add_argument("--raw-events-dir", default=None, help="Directory to save raw Codex JSONL events")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    eval_set = json.loads(Path(args.eval_set).read_text())
    skill_path = Path(args.skill_path)
    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    name, original_description, _ = parse_skill_md(skill_path)
    description = args.description or original_description
    project_root = find_project_root()

    if args.verbose:
        print(f"Evaluating with Codex: {description}", file=sys.stderr)

    output = run_eval(
        eval_set=eval_set,
        skill_name=name,
        description=description,
        num_workers=args.num_workers,
        timeout=args.timeout,
        project_root=project_root,
        runs_per_query=args.runs_per_query,
        trigger_threshold=args.trigger_threshold,
        model=args.model,
        codex_bin=args.codex_bin,
        codex_home=args.codex_home,
        keep_workdirs=args.keep_workdirs,
        raw_events_dir=args.raw_events_dir,
    )

    if args.verbose:
        summary = output["summary"]
        print(f"Results: {summary['passed']}/{summary['total']} passed", file=sys.stderr)
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
