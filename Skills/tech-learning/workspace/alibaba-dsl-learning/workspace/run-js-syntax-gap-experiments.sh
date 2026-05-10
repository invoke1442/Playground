#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$ROOT_DIR/js-syntax-gap-lab"
RESULTS_DIR="$LAB_DIR/results"
VERIFY_SCRIPT="${VERIFY_SCRIPT:-/home/nyn/Desktop/Projects/SAST/oh-my-rule/packages/skills/alibaba-dsl/scripts/verify.sh}"

mkdir -p "$LAB_DIR" "$RESULTS_DIR"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "verify.sh not found or not executable: $VERIFY_SCRIPT" >&2
  exit 1
fi

write_roster() {
  local dir="$1"
  local roster_file="$2"
  rm -rf "$dir"
  mkdir -p "$dir/rosters"
  cat > "$dir/rosters/$roster_file"
}

write_extend_file() {
  local dir="$1"
  local rel_path="$2"
  mkdir -p "$dir/$(dirname "$rel_path")"
  cat > "$dir/$rel_path"
}

run_roster_case() {
  local case_id="$1"
  local roster_name="$2"
  local hypothesis="$3"
  local note="$4"
  local dir="$LAB_DIR/$case_id"
  local out_json="$RESULTS_DIR/$case_id.json"

  bash "$VERIFY_SCRIPT" roster javascript "$roster_name" "$dir" 2>/dev/null | sed -n '1p' > "$out_json"

  python3 - "$case_id" "$hypothesis" "$note" "$out_json" <<'PY'
import json
import pathlib
import sys

case_id, hypothesis, note, path = sys.argv[1:]
text = pathlib.Path(path).read_text(errors="replace").strip()
actual = "ERROR"
output = text.replace("\n", " ")[:220]

try:
    data = json.loads(text)
    raw_output = data.get("data", {}).get("output", "")
    actual = "PASS" if raw_output in ("", "[]") else "FAIL"
    output = (raw_output or "[]").replace("\n", " ")[:220]
except Exception:
    pass

print("\t".join([case_id, hypothesis, actual, note, output]))
PY
}

SUMMARY_FILE="$RESULTS_DIR/summary.tsv"
printf 'case\thypothesis\tactual\tnote\toutput\n' > "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap01_source_custom_loadclass" "NodeJS_jsgap01_0.ros" <<'EOF'
Roster NodeJS_jsgap01 {
    source.customSourceFunc = loadclass("NodeJS_jsgap01.customSourceFunc_0");
}
EOF
write_extend_file "$LAB_DIR/jsgap01_source_custom_loadclass" "extend-file/rosters/NodeJS_jsgap01_0/NodeJS_jsgap01.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => false;
EOF
run_roster_case "jsgap01_source_custom_loadclass" "NodeJS_jsgap01_0" "loadclass-with-equals-should-pass" "source.customSourceFunc accepts class type values" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap02_source_custom_string" "NodeJS_jsgap02_0.ros" <<'EOF'
Roster NodeJS_jsgap02 {
    source.customSourceFunc = "NodeJS_jsgap02.customSourceFunc_0";
}
EOF
run_roster_case "jsgap02_source_custom_string" "NodeJS_jsgap02_0" "string-should-fail" "source.customSourceFunc rejects plain strings and expects class type" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap03_source_custom_pluseq_loadclass" "NodeJS_jsgap03_0.ros" <<'EOF'
Roster NodeJS_jsgap03 {
    source.customSourceFunc += loadclass("NodeJS_jsgap03.customSourceFunc_0");
}
EOF
write_extend_file "$LAB_DIR/jsgap03_source_custom_pluseq_loadclass" "extend-file/rosters/NodeJS_jsgap03_0/NodeJS_jsgap03.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => false;
EOF
run_roster_case "jsgap03_source_custom_pluseq_loadclass" "NodeJS_jsgap03_0" "loadclass-with-pluseq-should-pass" "source.customSourceFunc also accepts += loadclass" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap04_sink_custom_loadclass" "NodeJS_jsgap04_0.ros" <<'EOF'
Roster NodeJS_jsgap04 {
    sink.customSinkFunc = loadclass("NodeJS_jsgap04.customSink_0");
}
EOF
write_extend_file "$LAB_DIR/jsgap04_sink_custom_loadclass" "extend-file/rosters/NodeJS_jsgap04_0/NodeJS_jsgap04.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSink_0 = (rule, node, context) => false;
EOF
run_roster_case "jsgap04_sink_custom_loadclass" "NodeJS_jsgap04_0" "sink-loadclass-should-fail" "sink.customSinkFunc is string-valued, not class-valued" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap05_sink_custom_string" "NodeJS_jsgap05_0.ros" <<'EOF'
Roster NodeJS_jsgap05 {
    sink.customSinkFunc = "NodeJS_jsgap05.customSink_0";
}
EOF
run_roster_case "jsgap05_sink_custom_string" "NodeJS_jsgap05_0" "sink-string-should-pass" "sink.customSinkFunc accepts string assignment" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap06_sanitizer_custom_loadclass" "NodeJS_jsgap06_0.ros" <<'EOF'
Roster NodeJS_jsgap06 {
    sanitizer.customSanitizerFunc = loadclass("NodeJS_jsgap06.customSanitizer_0");
}
EOF
write_extend_file "$LAB_DIR/jsgap06_sanitizer_custom_loadclass" "extend-file/rosters/NodeJS_jsgap06_0/NodeJS_jsgap06.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSanitizer_0 = (rule, node, context) => false;
EOF
run_roster_case "jsgap06_sanitizer_custom_loadclass" "NodeJS_jsgap06_0" "sanitizer-loadclass-should-fail" "sanitizer.customSanitizerFunc is string-valued, not class-valued" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap07_sanitizer_custom_string" "NodeJS_jsgap07_0.ros" <<'EOF'
Roster NodeJS_jsgap07 {
    sanitizer.customSanitizerFunc = "NodeJS_jsgap07.customSanitizer_0";
}
EOF
run_roster_case "jsgap07_sanitizer_custom_string" "NodeJS_jsgap07_0" "sanitizer-string-should-pass" "sanitizer.customSanitizerFunc accepts string assignment" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap08_sink_function_arg" "NodeJS_jsgap08_0.ros" <<'EOF'
Roster NodeJS_jsgap08 {
    sink.functionArg += {
        pattern += "/\\bexec\\b/";
    };
}
EOF
run_roster_case "jsgap08_sink_function_arg" "NodeJS_jsgap08_0" "block-should-fail" "sink.functionArg is not a block field in JS" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap09_sanitizer_param_decorator" "NodeJS_jsgap09_0.ros" <<'EOF'
Roster NodeJS_jsgap09 {
    sanitizer.paramDecorator += {
        pattern += "/@Sanitized\\b/";
    };
}
EOF
run_roster_case "jsgap09_sanitizer_param_decorator" "NodeJS_jsgap09_0" "block-should-fail" "sanitizer.paramDecorator is not a block field in JS" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap10_group_custom_source_loadclass" "NodeJS_jsgap10_0.ros" <<'EOF'
Roster NodeJS_jsgap10 {
    group express_handler {
        includePlatforms = "express";
        source.customSourceFunc = loadclass("NodeJS_jsgap10.customSourceFunc_0");
    };
}
EOF
write_extend_file "$LAB_DIR/jsgap10_group_custom_source_loadclass" "extend-file/rosters/NodeJS_jsgap10_0/NodeJS_jsgap10.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => false;
EOF
run_roster_case "jsgap10_group_custom_source_loadclass" "NodeJS_jsgap10_0" "group-loadclass-should-pass" "group can contain source.customSourceFunc loadclass entries" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap11_general_scan_all_files" "NodeJS_jsgap11_0.ros" <<'EOF'
Roster NodeJS_jsgap11 {
    general.scanAllFiles = true;
}
EOF
run_roster_case "jsgap11_general_scan_all_files" "NodeJS_jsgap11_0" "bare-bool-should-fail" "JS general.* rejects bare boolean literals" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap12_sink_function_arg_string" "NodeJS_jsgap12_0.ros" <<'EOF'
Roster NodeJS_jsgap12 {
    sink.functionArg = "/\\bexec\\b/";
}
EOF
run_roster_case "jsgap12_sink_function_arg_string" "NodeJS_jsgap12_0" "string-should-pass" "sink.functionArg is a JS string field" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap13_sanitizer_param_decorator_string" "NodeJS_jsgap13_0.ros" <<'EOF'
Roster NodeJS_jsgap13 {
    sanitizer.paramDecorator = "/@Sanitized\\b/";
}
EOF
run_roster_case "jsgap13_sanitizer_param_decorator_string" "NodeJS_jsgap13_0" "string-should-pass" "sanitizer.paramDecorator is a JS string field" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap14_sink_custom_string_pluseq" "NodeJS_jsgap14_0.ros" <<'EOF'
Roster NodeJS_jsgap14 {
    sink.customSinkFunc += "NodeJS_jsgap14.customSink_0";
}
EOF
run_roster_case "jsgap14_sink_custom_string_pluseq" "NodeJS_jsgap14_0" "pluseq-string-should-pass" "sink.customSinkFunc supports += string as well as = string" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap15_sanitizer_custom_string_pluseq" "NodeJS_jsgap15_0.ros" <<'EOF'
Roster NodeJS_jsgap15 {
    sanitizer.customSanitizerFunc += "NodeJS_jsgap15.customSanitizer_0";
}
EOF
run_roster_case "jsgap15_sanitizer_custom_string_pluseq" "NodeJS_jsgap15_0" "pluseq-string-should-pass" "sanitizer.customSanitizerFunc supports += string as well as = string" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap16_source_custom_string_pluseq" "NodeJS_jsgap16_0.ros" <<'EOF'
Roster NodeJS_jsgap16 {
    source.customSourceFunc += "NodeJS_jsgap16.customSourceFunc_0";
}
EOF
run_roster_case "jsgap16_source_custom_string_pluseq" "NodeJS_jsgap16_0" "pluseq-string-should-fail" "source.customSourceFunc remains class-valued even under +=" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap17_source_custom_double_loadclass" "NodeJS_jsgap17_0.ros" <<'EOF'
Roster NodeJS_jsgap17 {
    source.customSourceFunc += loadclass("NodeJS_jsgap17.customSourceFunc_0");
    source.customSourceFunc += loadclass("NodeJS_jsgap17.customSourceFunc_1");
}
EOF
write_extend_file "$LAB_DIR/jsgap17_source_custom_double_loadclass" "extend-file/rosters/NodeJS_jsgap17_0/NodeJS_jsgap17.js" <<'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => false;
rule.customSourceFunc_1 = (rule, node, context) => false;
EOF
run_roster_case "jsgap17_source_custom_double_loadclass" "NodeJS_jsgap17_0" "repeat-pluseq-loadclass-should-pass" "source.customSourceFunc accepts multiple += loadclass entries at verify level" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap18_general_scan_all_files_string" "NodeJS_jsgap18_0.ros" <<'EOF'
Roster NodeJS_jsgap18 {
    general.scanAllFiles = "true";
}
EOF
run_roster_case "jsgap18_general_scan_all_files_string" "NodeJS_jsgap18_0" "string-should-pass" "JS general.* accepts string assignments where bare bool fails" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap19_general_desc_string" "NodeJS_jsgap19_0.ros" <<'EOF'
Roster NodeJS_jsgap19 {
    general.desc = "rule description";
}
EOF
run_roster_case "jsgap19_general_desc_string" "NodeJS_jsgap19_0" "string-should-pass" "general.desc also passes with string value" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap20_general_scan_all_files_pluseq_string" "NodeJS_jsgap20_0.ros" <<'EOF'
Roster NodeJS_jsgap20 {
    general.scanAllFiles += "true";
}
EOF
run_roster_case "jsgap20_general_scan_all_files_pluseq_string" "NodeJS_jsgap20_0" "pluseq-string-should-pass" "general.* also accepts += string assignments" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap21_general_not_real_string" "NodeJS_jsgap21_0.ros" <<'EOF'
Roster NodeJS_jsgap21 {
    general.notARealField = "x";
}
EOF
run_roster_case "jsgap21_general_not_real_string" "NodeJS_jsgap21_0" "unknown-general-string-also-passes" "JS verify is permissive on string-valued general.* names" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap22_general_taint_only_summary_string" "NodeJS_jsgap22_0.ros" <<'EOF'
Roster NodeJS_jsgap22 {
    general.taintOnlyBySummary = "true";
}
EOF
run_roster_case "jsgap22_general_taint_only_summary_string" "NodeJS_jsgap22_0" "known-looking-general-string-passes" "specific Java-style general field also passes in JS when string-valued" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap23_general_handle_poly_string" "NodeJS_jsgap23_0.ros" <<'EOF'
Roster NodeJS_jsgap23 {
    general.handlePolymorphism = "true";
}
EOF
run_roster_case "jsgap23_general_handle_poly_string" "NodeJS_jsgap23_0" "known-looking-general-string-passes" "general.handlePolymorphism passes as string" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap24_general_poly_num_string" "NodeJS_jsgap24_0.ros" <<'EOF'
Roster NodeJS_jsgap24 {
    general.polyHandleNum = "1";
}
EOF
run_roster_case "jsgap24_general_poly_num_string" "NodeJS_jsgap24_0" "numeric-looking-general-string-passes" "general.polyHandleNum passes only as string" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap25_general_poly_num_number" "NodeJS_jsgap25_0.ros" <<'EOF'
Roster NodeJS_jsgap25 {
    general.polyHandleNum = 1;
}
EOF
run_roster_case "jsgap25_general_poly_num_number" "NodeJS_jsgap25_0" "bare-number-should-fail" "JS general.* rejects bare numeric literals" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap26_group_general_scan_all_files_string" "NodeJS_jsgap26_0.ros" <<'EOF'
Roster NodeJS_jsgap26 {
    group express_handler {
        includePlatforms = "express";
        general.scanAllFiles = "true";
    };
}
EOF
run_roster_case "jsgap26_group_general_scan_all_files_string" "NodeJS_jsgap26_0" "group-general-should-fail" "group rejects general.* even when top-level roster accepts string general.*" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap27_sink_function_arg_pluseq_string" "NodeJS_jsgap27_0.ros" <<'EOF'
Roster NodeJS_jsgap27 {
    sink.functionArg += "/\\bexec\\b/";
}
EOF
run_roster_case "jsgap27_sink_function_arg_pluseq_string" "NodeJS_jsgap27_0" "pluseq-string-should-pass" "sink.functionArg supports += string" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/jsgap28_sanitizer_param_decorator_pluseq_string" "NodeJS_jsgap28_0.ros" <<'EOF'
Roster NodeJS_jsgap28 {
    sanitizer.paramDecorator += "/@Sanitized\\b/";
}
EOF
run_roster_case "jsgap28_sanitizer_param_decorator_pluseq_string" "NodeJS_jsgap28_0" "pluseq-string-should-pass" "sanitizer.paramDecorator supports += string" >> "$SUMMARY_FILE"

echo "Wrote results to $SUMMARY_FILE"