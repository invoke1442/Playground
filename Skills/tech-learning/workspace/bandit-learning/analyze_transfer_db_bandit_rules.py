#!/usr/bin/env python3
from __future__ import annotations

import csv
import glob
import json
import os
import re
from collections import defaultdict
from difflib import SequenceMatcher
from pathlib import Path


ROOT = Path("/home/nyn/Desktop/Projects/SAST/oh-my-rule/transfer-db/bandit")
IRDB_ROOT = Path("/home/nyn/Desktop/Projects/SAST/oh-my-rule/irdb/bandit")
OUT_CSV = Path(
    "/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/bandit-learning/"
    "bandit-transfer-db-rule-table.csv"
)


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def parse_cwes(raw: str) -> list[str]:
    return re.findall(r"\d{2,4}", raw or "")


def infer_source_rule_path(index_data: dict, manifest: dict) -> str:
    source_rule = manifest.get("source_rule")
    if isinstance(source_rule, dict):
        path = source_rule.get("path")
        if path:
            return path
    elif isinstance(source_rule, str) and source_rule:
        return source_rule

    path = index_data.get("rule_path_snapshot")
    if path:
        return path

    mappings = index_data.get("rule_mappings") or []
    for mapping in mappings:
        if isinstance(mapping, dict) and mapping.get("origin_file"):
            return mapping["origin_file"]

    return ""


def infer_irdb_rule_id(index_data: dict, metadata: dict) -> str:
    content = index_data.get("content") or ""
    match = re.search(r"\b(B\d{3,4})\b", content)
    if match:
        return match.group(1)

    rule = metadata.get("rule") or {}
    for key in ("rule_id", "rule_name", "rule_filename"):
        value = rule.get(key)
        if value:
            return str(value)

    return index_data.get("content_hash") or ""


def read_target_rule_text(target_rule_dir: Path) -> str:
    parts: list[str] = []

    for path in sorted((target_rule_dir / "src").rglob("*.py")):
        if ".egg-info" in path.parts or "__pycache__" in path.parts:
            continue
        try:
            parts.append(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            continue

    for extra in ("README.md", "bandit.yaml"):
        path = target_rule_dir / extra
        if path.exists():
            try:
                parts.append(path.read_text(encoding="utf-8", errors="ignore"))
            except OSError:
                pass

    return "\n".join(parts).lower()


def read_irdb_workspace_text(workspace_dir: Path) -> str:
    parts: list[str] = []

    for path in sorted(workspace_dir.iterdir()):
        if path.is_dir():
            continue
        if path.suffix.lower() not in {".md", ".json"}:
            continue
        try:
            parts.append(path.read_text(encoding="utf-8", errors="ignore"))
        except OSError:
            continue

    return "\n".join(parts).lower()


def classify_vuln(text: str, cwes: list[str]) -> str:
    cwe_set = set(cwes)

    if cwe_set & {"918"} or any(k in text for k in ("ssrf", "server-side request forgery")):
        return "SSTF"

    if cwe_set & {"79", "80", "83", "84", "85", "86", "87"} or any(
        k in text for k in (" xss", "xss_", "_xss", "cross site scripting", "cross-site scripting")
    ):
        return "XSS"

    if cwe_set & {"78", "88"} or any(
        k in text
        for k in (
            "command injection",
            "command-line-injection",
            "cmdi",
            "subprocess",
            "os.system",
            "spawn",
            "shell",
            "exec",
        )
    ):
        return "Cmdi"

    if cwe_set & {"89", "564", "943"} or any(
        k in text
        for k in (
            "sql injection",
            "sqli",
            " rawsql",
            "sqlalchemy",
            "cursor.execute",
            "mysql",
            "postgres",
            "pg8000",
            "psycopg",
            "nosql",
        )
    ):
        return "Sqli"

    if cwe_set & {"22", "23", "36", "73", "99"} or any(
        k in text
        for k in (
            "path traversal",
            "directory traversal",
            "path injection",
            "zip slip",
            "zipslip",
            "tar slip",
            "tarslip",
            "unsafe unpack",
            "unsafeunpack",
        )
    ):
        return "Path Traversal"

    if cwe_set & {"502", "915"} or any(
        k in text for k in ("deserialization", "deserialize", "pickle", "marshal", "yaml.load", "unsafe load")
    ):
        return "不安全反序列化"

    if cwe_set & {"611", "827", "643", "091"} or any(
        k in text for k in ("xxe", "xml external entity", "xslt", "xpath", "xml parser", "xml parsing")
    ):
        return "XML相关"

    if cwe_set & {"601"} or any(k in text for k in ("open redirect", "url redirection", "url redirect", "redirect")):
        return "URL重定向"

    if cwe_set & {"113", "117", "020"} or any(
        k in text
        for k in (
            "header injection",
            "http response splitting",
            "response splitting",
            "cookie injection",
            "log injection",
            "host header",
        )
    ):
        return "响应与协议注入"

    if any(
        k in text
        for k in (
            "meta/alerts/taint-sinks",
            "meta/alerts/remote-flow-sources",
            "remoteflowsource",
            "taint sinks",
            "sources of remote user input",
        )
    ):
        return "污点元规则"

    if any(
        k in text
        for k in (
            "security-sensitive",
            "security hotspot",
            "reading the standard input",
            "using command line arguments",
            "encrypting data",
            "using regular expressions",
            "sending emails",
            "fastapi file upload",
            "locals()",
            "query parameters should not be used",
            "template strings should be processed",
        )
    ):
        return "安全热点与框架误用"

    if any(
        k in text
        for k in (
            "ldap injection",
            "csv injection",
            "email header",
            "email body",
            "twiml",
            "smtp",
        )
    ):
        return "其他注入"

    if any(
        k in text
        for k in (
            "incomplete",
            "validation",
            "sanitization",
            "sanitizer",
            "bad-tag-filter",
            "hostname regexp",
            "overly-large-range",
            "external api",
            "untrusted data",
        )
    ):
        return "输入校验缺陷"

    if (
        any(
            k in text
            for k in (
                "kdf",
                "crypto",
                "cryptograph",
                "padding",
                "nonce",
                "salt",
                "jwt",
                "cipher",
                "block mode",
                "initialization vector",
            )
        )
        or re.search(r"\biv\b", text)
    ):
        return "密码学误用"

    return "其他未归组"


SOURCE_PATTERNS = (
    r"\bsource_apis?\b",
    r"\bsource_call",
    r"\bsource_attr",
    r"\b_is_.*source",
    r"remote_source",
    r"request\.args",
    r"request\.form",
    r"request\.get_json",
    r"os\.environ",
    r"sys\.argv",
    r"os\.getenv",
    r"\btainted_names\b",
    r"\broute_param",
    r"\buser-controlled\b",
    r"\bexternally controlled\b",
)

SINK_PATTERNS = (
    r"\bsink_",
    r"\bsinks?\b",
    r"_match_sink",
    r"_collect_sink",
    r"sink_arg",
    r"sink_vars",
    r"\b_is_sink",
    r"call_function_name_qual",
    r"call_function_name",
    r"make_response",
    r"cursor\.execute",
    r"subprocess_exec",
    r"send_header",
    r"set_cookie",
)

SANITIZER_PATTERNS = (
    r"\bsanitizer\b",
    r"\bsanitize\b",
    r"\bbarrier\b",
    r"safe_exclusion",
    r"_is_replace_",
    r"replace\(",
    r"shlex\.escape",
    r"without .* sanit",
)

PROPAGATION_PATTERNS = (
    r"\bpropagat",
    r"\btaint",
    r"tainted_names",
    r"call_taint",
    r"_expr_is_tainted",
    r"_collect_tainted",
    r"_update_taint",
    r"line_env",
    r"flow",
)


BANDIT_NATIVE_OVERRIDES: dict[str, dict[str, str]] = {
    "B101": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "无"},
    "B102": {"漏洞分类": "Cmdi", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B103": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B104": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B105": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "无"},
    "B108": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B110": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "无"},
    "B112": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "无"},
    "B113": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B201": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B202": {"漏洞分类": "Path Traversal", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2,3"},
    "B324": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B501": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B502": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B505": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B506": {"漏洞分类": "不安全反序列化", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B507": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B508": {"漏洞分类": "密码学误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B601": {"漏洞分类": "Cmdi", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B602": {"漏洞分类": "Cmdi", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B608": {"漏洞分类": "Sqli", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B609": {"漏洞分类": "Cmdi", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B610": {"漏洞分类": "Sqli", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B612": {"漏洞分类": "Cmdi", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B613": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "无"},
    "B614": {"漏洞分类": "不安全反序列化", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B615": {"漏洞分类": "安全热点与框架误用", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B701": {"漏洞分类": "XSS", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B702": {"漏洞分类": "XSS", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B703": {"漏洞分类": "XSS", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
    "B704": {"漏洞分类": "XSS", "规则类型二分类": "简单的pattern-grep审计", "污点节点多分类": "2"},
}

MERGE_TOKEN_STOPWORDS = {
    "py",
    "yaml",
    "ql",
    "pysa",
    "audit",
    "rule",
    "security",
    "lang",
    "python",
    "django",
    "flask",
    "pyramid",
    "aws",
    "lambda",
    "using",
    "use",
    "dangerous",
    "tainted",
    "user",
    "input",
    "direct",
    "unknown",
    "make",
    "response",
    "with",
    "without",
    "of",
    "the",
    "and",
    "or",
    "true",
    "command",
    "sql",
    "xss",
    "ssrf",
    "sqli",
    "cmdi",
    "data",
    "http",
    "request",
    "injection",
    "issue",
    "check",
    "detect",
    "detected",
    "problem",
    "vulnerability",
    "avoid",
    "string",
}

MERGE_REJECTS = {
    ("listen-eval", "eval-injection"),
}


def matches_any(text: str, patterns: tuple[str, ...]) -> bool:
    return any(re.search(pattern, text) for pattern in patterns)


def classify_nodes(text: str) -> list[str]:
    codes: list[str] = []

    if matches_any(text, SOURCE_PATTERNS):
        codes.append("1")
    if matches_any(text, SINK_PATTERNS):
        codes.append("2")
    if matches_any(text, SANITIZER_PATTERNS):
        codes.append("3")
    if matches_any(text, PROPAGATION_PATTERNS):
        codes.append("4")

    return codes


def classify_rule_type(codes: list[str]) -> str:
    code_set = set(codes)
    if {"1", "2"} <= code_set and ({"3"} & code_set or {"4"} & code_set):
        return "有完整漏洞污点逻辑"
    return "简单的pattern-grep审计"


def parse_node_set(text: str) -> set[str]:
    return {item.strip() for item in text.split(",") if item.strip()}


def is_merge_src(row: dict[str, str]) -> bool:
    return row["规则类型二分类"] == "简单的pattern-grep审计" and row["污点节点多分类"] in {"1", "2"}


def is_merge_tgt(row: dict[str, str]) -> bool:
    # 这里按自然解释处理“1,2”：目标规则必须至少同时具备 source 和 sink。
    return row["规则类型二分类"] == "有完整漏洞污点逻辑" and {"1", "2"} <= parse_node_set(row["污点节点多分类"])


def merge_tokens(*parts: str) -> list[str]:
    tokens: list[str] = []
    for part in parts:
        for token in re.split(r"[^a-z0-9]+", (part or "").lower()):
            if token and not token.isdigit() and token not in MERGE_TOKEN_STOPWORDS:
                tokens.append(token)
    return tokens


def merge_signature(row: dict[str, str]) -> list[str]:
    path_base = os.path.splitext(os.path.basename(row["源规则路径"]))[0]
    return merge_tokens(row["rule_id"], path_base)


def merge_score(src: dict[str, str], tgt: dict[str, str]) -> tuple[float, int, float, float]:
    src_sig = merge_signature(src)
    tgt_sig = merge_signature(tgt)
    src_set = set(src_sig)
    tgt_set = set(tgt_sig)
    overlap = len(src_set & tgt_set)
    same_tool = 1 if src["源sast工具"] == tgt["源sast工具"] else 0
    sig_ratio = SequenceMatcher(None, " ".join(src_sig), " ".join(tgt_sig)).ratio()
    path_ratio = SequenceMatcher(
        None,
        os.path.basename(src["源规则路径"]),
        os.path.basename(tgt["源规则路径"]),
    ).ratio()
    score = same_tool * 3 + overlap * 4 + sig_ratio * 2 + path_ratio
    return score, overlap, sig_ratio, path_ratio


def accept_merge_candidate(src: dict[str, str], candidate: tuple[float, int, float, float]) -> bool:
    score, overlap, sig_ratio, path_ratio = candidate
    if overlap >= 2:
        return True
    if src["源sast工具"] and overlap >= 1 and max(sig_ratio, path_ratio) >= 0.7 and score >= 7.0:
        return True
    return False


def assign_merge_targets(rows: list[dict[str, str]]) -> None:
    clusters: dict[tuple[str, str, str], list[dict[str, str]]] = defaultdict(list)
    for row in rows:
        row["merge_target"] = ""
        clusters[(row["语言"], row["CWE"], row["漏洞分类"])].append(row)

    for _, items in clusters.items():
        tgts = [row for row in items if is_merge_tgt(row)]
        if not tgts:
            continue

        for src in (row for row in items if is_merge_src(row)):
            scored: list[tuple[tuple[float, int, float, float], dict[str, str]]] = []
            for tgt in tgts:
                metrics = merge_score(src, tgt)
                scored.append((metrics, tgt))

            scored.sort(
                key=lambda item: (
                    item[0][0],
                    item[0][1],
                    item[0][2],
                    item[0][3],
                    item[1]["rule_id"],
                ),
                reverse=True,
            )
            best_metrics, best_tgt = scored[0]
            if accept_merge_candidate(src, best_metrics) and (src["rule_id"], best_tgt["rule_id"]) not in MERGE_REJECTS:
                src["merge_target"] = best_tgt["rule_id"]


def main() -> None:
    rows: list[dict[str, str]] = []

    manifest_paths = sorted(ROOT.glob("*/*/target_rule/rule_manifest.json"))
    for manifest_path in manifest_paths:
        target_rule_dir = manifest_path.parent
        index_path = target_rule_dir.parent / "index.json"
        index_data = load_json(index_path)
        manifest = load_json(manifest_path)

        combined_meta = " ".join(
            [
                json.dumps(index_data, ensure_ascii=False),
                json.dumps(manifest, ensure_ascii=False),
                infer_source_rule_path(index_data, manifest),
            ]
        ).lower()
        target_text = read_target_rule_text(target_rule_dir)
        combined_text = f"{combined_meta}\n{target_text}"

        cwe_raw = index_data.get("cwe") or ""
        if not cwe_raw:
            for mapping in index_data.get("rule_mappings") or []:
                if isinstance(mapping, dict) and mapping.get("cwe"):
                    cwe_raw = mapping["cwe"]
                    break

        cwes = parse_cwes(cwe_raw)
        node_codes = classify_nodes(target_text)
        if not node_codes and "path-problem" in (index_data.get("content") or "").lower():
            # 对明确 path-problem 但翻译实现未显式命名 source/sink 的规则，
            # 至少按 source+sink 近似归类。
            node_codes = ["1", "2"]

        rows.append(
            {
                "db_index": target_rule_dir.parent.name,
                "rule_id": index_data.get("rule_id")
                or manifest.get("rule_id")
                or ",".join(manifest.get("rule_ids") or []),
                "语言": index_data.get("lang") or "python",
                "源sast工具": index_data.get("src_tool") or "",
                "源规则路径": infer_source_rule_path(index_data, manifest),
                "CWE": ",".join(cwes),
                "漏洞分类": classify_vuln(combined_text, cwes),
                "规则类型二分类": classify_rule_type(node_codes),
                "污点节点多分类": ",".join(node_codes) if node_codes else "无",
                "merge_target": "",
            }
        )

    for index_path in sorted(IRDB_ROOT.glob("*/index.json")):
        db_dir = index_path.parent
        workspace_dir = db_dir / "workspace"
        index_data = load_json(index_path)
        metadata_path = workspace_dir / "metadata.json"
        metadata = load_json(metadata_path) if metadata_path.exists() else {}

        combined_meta = " ".join(
            [
                json.dumps(index_data, ensure_ascii=False),
                json.dumps(metadata, ensure_ascii=False),
                ((metadata.get("rule") or {}).get("rule_path") or ""),
            ]
        ).lower()
        workspace_text = read_irdb_workspace_text(workspace_dir)
        combined_text = f"{combined_meta}\n{workspace_text}"

        cwe_raw = index_data.get("cwe") or ""
        rule = metadata.get("rule") or {}
        if not cwe_raw:
            rule_content = rule.get("rule_content") or ""
            cwe_match = re.findall(r"CWE-(\d{2,4})", rule_content)
            if cwe_match:
                cwe_raw = ",".join(cwe_match)

        cwes = parse_cwes(cwe_raw)
        node_codes = classify_nodes(combined_text)
        if not node_codes and "path-problem" in (index_data.get("content") or "").lower():
            node_codes = ["1", "2"]

        rule_id = infer_irdb_rule_id(index_data, metadata)
        manual = BANDIT_NATIVE_OVERRIDES.get(rule_id, {})
        vuln = manual.get("漏洞分类") or classify_vuln(combined_text, cwes)
        rule_type = manual.get("规则类型二分类") or classify_rule_type(node_codes)
        node_text = manual.get("污点节点多分类") or (",".join(node_codes) if node_codes else "无")

        rows.append(
            {
                "db_index": db_dir.name,
                "rule_id": rule_id,
                "语言": "python",
                "源sast工具": "bandit",
                "源规则路径": rule.get("rule_path") or "",
                "CWE": ",".join(cwes),
                "漏洞分类": vuln,
                "规则类型二分类": rule_type,
                "污点节点多分类": node_text,
                "merge_target": "",
            }
        )

    assign_merge_targets(rows)
    rows.sort(key=lambda r: (r["漏洞分类"], r["源sast工具"], r["rule_id"]))

    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "db_index",
                "rule_id",
                "语言",
                "源sast工具",
                "源规则路径",
                "CWE",
                "漏洞分类",
                "规则类型二分类",
                "污点节点多分类",
                "merge_target",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"wrote {len(rows)} rows to {OUT_CSV}")


if __name__ == "__main__":
    main()
