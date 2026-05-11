#!/usr/bin/env python3
"""Build benchmark.json for the Alibaba DSL skill eval iteration."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SKILL = ROOT.parents[1] / "alibaba-dsl-new"
EVALS = ["java-ssrf-rule", "js-xss-rule"]
MODES = ["with_skill", "without_skill"]
RUN = "run-4"


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def run_record(eval_id: str, mode: str, run_dir: Path) -> dict:
    grading = load_json(run_dir / "grading.json")
    metrics = load_json(run_dir / "outputs" / "metrics.json")
    timing = load_json(run_dir / "timing.json")
    usage = metrics.get("usage", {})
    total_tokens = sum(
        value for key, value in usage.items()
        if key in {"input_tokens", "output_tokens", "reasoning_output_tokens"} and isinstance(value, int)
    )
    return {
        "eval_id": eval_id,
        "configuration": mode,
        "run_number": int(RUN.split("-")[1]),
        "result": {
            "pass_rate": grading.get("summary", {}).get("pass_rate", 0.0),
            "passed": grading.get("summary", {}).get("passed", 0),
            "failed": grading.get("summary", {}).get("failed", 0),
            "total": grading.get("summary", {}).get("total", 0),
            "time_seconds": timing.get("total_duration_seconds", 0.0),
            "tokens": total_tokens,
            "returncode": metrics.get("returncode"),
            "timed_out": metrics.get("timed_out", False),
            "errors": metrics.get("errors_encountered", 0),
            "output_chars": metrics.get("output_chars", 0),
        },
        "expectations": grading.get("expectations", []),
        "notes": [],
    }


def stats(values: list[float]) -> dict:
    if not values:
        return {"mean": 0.0, "min": 0.0, "max": 0.0}
    return {
        "mean": round(sum(values) / len(values), 4),
        "min": round(min(values), 4),
        "max": round(max(values), 4),
    }


def summarize(runs: list[dict]) -> dict:
    summary = {}
    for mode in MODES:
        mode_runs = [item["result"] for item in runs if item["configuration"] == mode]
        summary[mode] = {
            "pass_rate": stats([item["pass_rate"] for item in mode_runs]),
            "time_seconds": stats([item["time_seconds"] for item in mode_runs]),
            "tokens": stats([item["tokens"] for item in mode_runs]),
            "timeouts": sum(1 for item in mode_runs if item.get("timed_out")),
            "errors": sum(item.get("errors", 0) for item in mode_runs),
        }
    summary["delta"] = {
        "pass_rate": round(summary["with_skill"]["pass_rate"]["mean"] - summary["without_skill"]["pass_rate"]["mean"], 4),
        "time_seconds": round(summary["with_skill"]["time_seconds"]["mean"] - summary["without_skill"]["time_seconds"]["mean"], 4),
        "tokens": round(summary["with_skill"]["tokens"]["mean"] - summary["without_skill"]["tokens"]["mean"], 4),
        "timeouts": summary["with_skill"]["timeouts"] - summary["without_skill"]["timeouts"],
    }
    return summary


def main() -> None:
    runs = []
    for eval_id in EVALS:
        for mode in MODES:
            run_dir = ROOT / eval_id / mode / RUN
            runs.append(run_record(eval_id, mode, run_dir))
    benchmark = {
        "metadata": {
            "skill_name": "alibaba-dsl-new",
            "skill_path": str(SKILL),
            "executor_model": "codex configured model",
            "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "evals_run": EVALS,
            "runs_per_configuration": 1,
            "selected_run": RUN,
        },
        "runs": runs,
        "run_summary": summarize(runs),
        "notes": [
            "run-4 is the first fully harness-fixed with-skill/baseline pair; earlier runs are retained as harness debugging artifacts.",
            "Remote verify was intentionally not called during subprocess evals; local lint and verify commands were required outputs.",
        ],
    }
    (ROOT / "benchmark.json").write_text(json.dumps(benchmark, ensure_ascii=False, indent=2), encoding="utf-8")
    lines = [
        "# Alibaba DSL Skill Benchmark",
        "",
        "| Metric | With Skill | Without Skill | Delta |",
        "|---|---:|---:|---:|",
    ]
    for metric in ("pass_rate", "time_seconds", "tokens"):
        with_value = benchmark["run_summary"]["with_skill"][metric]["mean"]
        without_value = benchmark["run_summary"]["without_skill"][metric]["mean"]
        delta = benchmark["run_summary"]["delta"][metric]
        lines.append(f"| {metric} | {with_value} | {without_value} | {delta} |")
    lines.append(f"| timeouts | {benchmark['run_summary']['with_skill']['timeouts']} | {benchmark['run_summary']['without_skill']['timeouts']} | {benchmark['run_summary']['delta']['timeouts']} |")
    (ROOT / "benchmark.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(benchmark["run_summary"], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
