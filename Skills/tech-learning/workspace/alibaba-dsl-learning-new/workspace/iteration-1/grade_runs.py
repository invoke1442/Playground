#!/usr/bin/env python3
"""Lightweight grading for iteration-1 Alibaba DSL eval runs."""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent


EXPECTATIONS = {
    "java-ssrf-rule": [
        ("The Rule imports a roster before type/subType fields.", lambda t: import_before_type(t)),
        ("The roster filename uses _0 while the Rule import omits _0.", lambda t: "_0.ros" in t and re.search(r"import\s+roster\s+Java_[A-Za-z0-9_]+;", t) is not None),
        ("The relation config maps the numeric rule id to the _0 roster name.", lambda t: re.search(r'"9\d{4}"\s*:\s*\[\s*"[^"]+_0"', t) is not None),
        ("The Java SSRF roster includes source.methodReturn, sink.methodArg, and checkSSRF as sanitizer.methodArg.", lambda t: all(x in t for x in ("source.methodReturn", "sink.methodArg", "sanitizer.methodArg", "com.alibaba.security.SecurityUtil.checkSSRF"))),
        ("The answer includes local lint and official verify commands.", lambda t: "lint_alibaba_dsl.py" in t and "verify_alibaba_dsl.py" in t),
    ],
    "js-xss-rule": [
        ("The JavaScript source blocks use value/value +=, not precise.", lambda t: "source.methodReturn" in t and "value" in t and "precise" not in extract_codeish(t)),
        ("The JavaScript sink and sanitizer call blocks use pattern/pattern +=.", lambda t: "sink.methodArg" in t and "sanitizer.methodReturn" in t and "pattern" in t),
        ("The Rule imports a roster before type/subType.", lambda t: import_before_type(t)),
        ("The output explains JS loadclass as fileName.property.path into a CommonJS module.", lambda t: "loadclass" in t and (("CommonJS" in t) or ("module.exports" in t)) and (".rule." in t or "property" in t)),
        ("The output states userDefineFunc should return false unless replacing default analysis.", lambda t: "userDefineFunc" in t and "return false" in t and ("default" in t or "analysis" in t)),
    ],
}


def extract_codeish(text: str) -> str:
    blocks = re.findall(r"```(?:java|javascript|typescript|json|dsl|text)?\n(.*?)```", text, flags=re.S | re.I)
    return "\n".join(blocks) if blocks else text


def import_before_type(text: str) -> bool:
    rule_match = re.search(r"Rule\s+[A-Za-z0-9_]+\s+extends\s+[A-Za-z0-9_]+\s*\{(?P<body>.*?)\n\}", text, flags=re.S)
    code = rule_match.group("body") if rule_match else extract_codeish(text)
    imp = code.find("import roster")
    typ_match = re.search(r"(?m)^\s*type\s*=", code)
    subtype_match = re.search(r"(?m)^\s*subType\s*=", code)
    typ = typ_match.start() if typ_match else -1
    subtype = subtype_match.start() if subtype_match else -1
    return imp >= 0 and typ >= 0 and subtype >= 0 and imp < typ < subtype


def collect_text(run_dir: Path) -> str:
    parts = []
    for path in sorted((run_dir / "outputs").rglob("*")):
        if path.name in {"metrics.json", "transcript.md"}:
            continue
        if path.is_file() and path.suffix.lower() in {".md", ".txt", ".json", ".rul", ".ros", ".js", ".java"}:
            parts.append(str(path.relative_to(run_dir / "outputs")))
            parts.append(path.read_text(encoding="utf-8", errors="replace"))
    transcript = run_dir / "transcript.md"
    if not parts and transcript.exists():
        parts.append(transcript.read_text(encoding="utf-8", errors="replace"))
    return "\n".join(parts)


def grade_run(eval_id: str, run_dir: Path) -> dict:
    text = collect_text(run_dir)
    results = []
    for expectation, predicate in EXPECTATIONS[eval_id]:
        passed = bool(predicate(text))
        results.append(
            {
                "text": expectation,
                "passed": passed,
                "evidence": "Matched expected content in outputs/transcript." if passed else "No matching evidence in outputs/transcript.",
            }
        )
    passed_count = sum(1 for item in results if item["passed"])
    grading = {
        "expectations": results,
        "summary": {
            "passed": passed_count,
            "failed": len(results) - passed_count,
            "total": len(results),
            "pass_rate": round(passed_count / len(results), 2),
        },
    }
    (run_dir / "grading.json").write_text(json.dumps(grading, ensure_ascii=False, indent=2), encoding="utf-8")
    return grading


def main() -> None:
    summary = {}
    for eval_id in EXPECTATIONS:
        for mode in ("with_skill", "without_skill"):
            for run_dir in sorted((ROOT / eval_id / mode).glob("run-*")):
                if not (run_dir / "outputs").exists():
                    continue
                grading = grade_run(eval_id, run_dir)
                summary[str(run_dir.relative_to(ROOT))] = grading["summary"]
    (ROOT / "grading-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
