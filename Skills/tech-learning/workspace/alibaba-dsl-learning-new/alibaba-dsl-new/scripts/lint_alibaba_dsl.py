#!/usr/bin/env python3
"""Local structural lint for Alibaba DSL rule directories."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


RULE_DECL_RE = re.compile(r"\bRule\s+([A-Za-z_][A-Za-z0-9_]*)\s+extends\s+AbstractTaintRule\s*\{", re.S)
ROSTER_DECL_RE = re.compile(r"\bRoster\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{", re.S)
IMPORT_RE = re.compile(r"^\s*import\s+roster\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s+exclude\s+([A-Za-z0-9_,]+))?\s*;", re.M)
FIELD_RE = re.compile(r"^\s*(?:type|subType|source|sink|sanitizer|propagate|general|entrance|condition)\b", re.M)
LOADCLASS_RE = re.compile(r"loadclass\s*\(\s*\"([^\"]+)\"\s*\)")


def add(items: list[dict], code: str, message: str, path: Path | None = None) -> None:
    item = {"code": code, "message": message}
    if path is not None:
        item["path"] = str(path)
    items.append(item)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def find_rule_body(text: str) -> str:
    match = RULE_DECL_RE.search(text)
    if not match:
        return ""
    return text[match.end() :]


def lint_rule_file(path: Path) -> tuple[list[dict], list[dict], set[str]]:
    errors: list[dict] = []
    warnings: list[dict] = []
    imports: set[str] = set()
    text = read_text(path)
    if not RULE_DECL_RE.search(text):
        add(errors, "MISSING_RULE_DECL", "Rule file has no `Rule ... extends AbstractTaintRule` declaration.", path)
    if 'type = "' not in text or 'subType = "' not in text:
        add(errors, "MISSING_TYPE", "Rule file should define both `type` and `subType`.", path)

    body = find_rule_body(text)
    import_matches = list(IMPORT_RE.finditer(body))
    for match in import_matches:
        imports.add(match.group(1))

    if imports:
        first_field = FIELD_RE.search(body)
        first_import = import_matches[0]
        if first_field and first_field.start() < first_import.start():
            add(
                errors,
                "IMPORT_AFTER_FIELD",
                "`import roster` must appear before Rule fields and config blocks.",
                path,
            )
    elif (path.parent / "rosters").exists():
        add(
            warnings,
            "NO_IMPORT_ROSTER",
            "Rule imports no roster. This is valid only for self-contained rules; roster definitions will not affect runtime.",
            path,
        )

    if path.stem and not path.stem.isdigit():
        add(warnings, "RULE_ID_NOT_NUMERIC", "Rule filename is usually a numeric rule id such as `90001.rul`.", path)
    return errors, warnings, imports


def lint_roster_file(path: Path) -> tuple[list[dict], list[dict], str | None]:
    errors: list[dict] = []
    warnings: list[dict] = []
    text = read_text(path)
    match = ROSTER_DECL_RE.search(text)
    if not match:
        add(errors, "MISSING_ROSTER_DECL", "Roster file has no `Roster Name` declaration.", path)
        return errors, warnings, None
    decl = match.group(1)
    expected = f"{decl}_0.ros"
    if path.name != expected:
        add(
            warnings,
            "ROSTER_FILENAME_MISMATCH",
            f"Roster declaration `{decl}` is normally stored as `{expected}`.",
            path,
        )
    return errors, warnings, decl


def load_relation(config_dir: Path, language: str) -> tuple[dict, list[dict], list[dict]]:
    errors: list[dict] = []
    warnings: list[dict] = []
    relation_dir = config_dir / "relation"
    candidates = [relation_dir / "config_roster_relation.json"]
    if language == "javascript":
        candidates.append(relation_dir / "config_addition_relation.json")
    existing = [path for path in candidates if path.exists()]
    if not existing:
        add(warnings, "MISSING_RELATION", "No relation config found; verify may pass, but roster discovery can fail.", relation_dir)
        return {}, errors, warnings
    try:
        data = json.loads(existing[0].read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        add(errors, "INVALID_RELATION_JSON", f"Invalid JSON: {exc}", existing[0])
        return {}, errors, warnings
    if not isinstance(data, dict):
        add(errors, "RELATION_NOT_OBJECT", "Relation config must be a JSON object keyed by rule id.", existing[0])
        return {}, errors, warnings
    return data, errors, warnings


def lint_loadclass_files(config_dir: Path, language: str, texts: list[tuple[Path, str]]) -> tuple[list[dict], list[dict]]:
    errors: list[dict] = []
    warnings: list[dict] = []
    for source_path, text in texts:
        for match in LOADCLASS_RE.finditer(text):
            target = match.group(1)
            if language == "java":
                class_name = target.rsplit(".", 1)[-1]
                found = list((config_dir / "extend-file").glob(f"**/{class_name}.java"))
                if not found:
                    add(warnings, "LOADCLASS_FILE_NOT_FOUND", f"No Java extend-file named `{class_name}.java` found for `{target}`.", source_path)
            elif language == "javascript":
                file_name = target.split(".", 1)[0] + ".js"
                found = list((config_dir / "extend-file").glob(f"**/{file_name}"))
                if not found:
                    add(warnings, "LOADCLASS_FILE_NOT_FOUND", f"No JS extend-file named `{file_name}` found for `{target}`.", source_path)
    return errors, warnings


def lint_config(config_dir: str | Path, language: str = "java") -> dict:
    config_dir = Path(config_dir).resolve()
    errors: list[dict] = []
    warnings: list[dict] = []
    if not config_dir.exists():
        add(errors, "CONFIG_DIR_NOT_FOUND", "Config directory does not exist.", config_dir)
        return {"ok": False, "errors": errors, "warnings": warnings}

    rule_files = sorted(config_dir.glob("*.rul"))
    roster_files = sorted((config_dir / "rosters").glob("*.ros")) if (config_dir / "rosters").is_dir() else []
    if not rule_files:
        add(warnings, "NO_RULE_FILES", "No `.rul` files found. This is only valid for roster-only verification.", config_dir)
    if not (config_dir / "rosters").is_dir():
        add(warnings, "NO_ROSTERS_DIR", "`rosters/` directory is missing.", config_dir)

    all_imports: dict[str, set[str]] = {}
    texts: list[tuple[Path, str]] = []
    for rule_file in rule_files:
        rule_errors, rule_warnings, imports = lint_rule_file(rule_file)
        errors.extend(rule_errors)
        warnings.extend(rule_warnings)
        all_imports[rule_file.stem] = imports
        texts.append((rule_file, read_text(rule_file)))

    roster_decls: dict[str, Path] = {}
    for roster_file in roster_files:
        roster_errors, roster_warnings, decl = lint_roster_file(roster_file)
        errors.extend(roster_errors)
        warnings.extend(roster_warnings)
        if decl:
            roster_decls[decl] = roster_file
            texts.append((roster_file, read_text(roster_file)))

    relation, rel_errors, rel_warnings = load_relation(config_dir, language)
    errors.extend(rel_errors)
    warnings.extend(rel_warnings)
    for rule_id, imported in all_imports.items():
        relation_rosters = set()
        raw_relation_rosters = relation.get(rule_id, [])
        if isinstance(raw_relation_rosters, list):
            relation_rosters = {str(item) for item in raw_relation_rosters}
        elif raw_relation_rosters:
            add(errors, "RELATION_VALUE_NOT_LIST", f"Relation entry for rule `{rule_id}` must be a list.", config_dir / "relation")
        for roster in imported:
            if roster not in roster_decls:
                add(errors, "IMPORTED_ROSTER_MISSING", f"Rule `{rule_id}` imports `{roster}`, but `rosters/{roster}_0.ros` was not found.", config_dir)
            if relation and f"{roster}_0" not in relation_rosters:
                add(errors, "RELATION_MISSING_ROSTER", f"Relation for rule `{rule_id}` should include `{roster}_0`.", config_dir / "relation")

    lc_errors, lc_warnings = lint_loadclass_files(config_dir, language, texts)
    errors.extend(lc_errors)
    warnings.extend(lc_warnings)
    return {"ok": not errors, "errors": errors, "warnings": warnings}


def main() -> int:
    parser = argparse.ArgumentParser(description="Lint an Alibaba DSL config directory before verify upload.")
    parser.add_argument("config_dir", help="Directory containing .rul, rosters/, relation/, extend-file/")
    parser.add_argument("--language", choices=["java", "javascript"], default="java")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    args = parser.parse_args()
    report = lint_config(args.config_dir, args.language)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        status = "OK" if report["ok"] else "FAIL"
        print(f"{status}: {args.config_dir}")
        for kind in ("errors", "warnings"):
            for item in report[kind]:
                path = f" [{item['path']}]" if "path" in item else ""
                print(f"{kind[:-1].upper()} {item['code']}: {item['message']}{path}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
