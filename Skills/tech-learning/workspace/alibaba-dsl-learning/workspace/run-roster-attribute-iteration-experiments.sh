#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$ROOT_DIR/attribute-iteration-lab"
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

run_roster_case() {
  local case_id="$1"
  local lang="$2"
  local roster_name="$3"
  local hypothesis="$4"
  local note="$5"
  local dir="$LAB_DIR/$case_id"
  local out_json="$RESULTS_DIR/$case_id.json"

  bash "$VERIFY_SCRIPT" roster "$lang" "$roster_name" "$dir" 2>/dev/null | sed -n '1p' > "$out_json"

  python3 - "$case_id" "$lang" "$hypothesis" "$note" "$out_json" <<'PY'
import json
import pathlib
import sys

case_id, lang, hypothesis, note, path = sys.argv[1:]
text = pathlib.Path(path).read_text(errors="replace").strip()
actual = "ERROR"
output = text.replace("\n", " ")[:220]

try:
    data = json.loads(text)
    raw_output = data.get("data", {}).get("output", "")
    actual = "PASS" if raw_output in ("", "[]") else "FAIL"
    output = raw_output.replace("\n", " ")[:220]
except Exception:
    pass

print("\t".join([case_id, lang, hypothesis, actual, note, output]))
PY
}

SUMMARY_FILE="$RESULTS_DIR/summary.tsv"
printf 'case\tlanguage\thypothesis\tactual\tnote\toutput\n' > "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr01_java_propagate_bool_direct" "Attr01_java_propagate_bool_direct_0.ros" <<'EOF'
Roster Attr01_java_propagate_bool_direct {
    propagate.bAllPublicMethod = true;
}
EOF
run_roster_case "attr01_java_propagate_bool_direct" "java" "Attr01_java_propagate_bool_direct_0" "direct-assign-should-fail" "propagate boolean toggle should stay block-only unlike general.*" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr02_java_propagate_bool_block_false" "Attr02_java_propagate_bool_block_false_0.ros" <<'EOF'
Roster Attr02_java_propagate_bool_block_false {
    propagate.bAllPublicMethod += {
        value = false;
    };
}
EOF
run_roster_case "attr02_java_propagate_bool_block_false" "java" "Attr02_java_propagate_bool_block_false_0" "block-false-should-pass" "propagate boolean toggle accepts false, not only true" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr03_java_sink_bool_direct" "Attr03_java_sink_bool_direct_0.ros" <<'EOF'
Roster Attr03_java_sink_bool_direct {
    sink.bUseSinkFilter = true;
}
EOF
run_roster_case "attr03_java_sink_bool_direct" "java" "Attr03_java_sink_bool_direct_0" "direct-assign-should-fail" "sink boolean toggle should also be block-only" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr04_java_sink_bool_block_false" "Attr04_java_sink_bool_block_false_0.ros" <<'EOF'
Roster Attr04_java_sink_bool_block_false {
    sink.bUseSinkFilter += {
        value = false;
    };
}
EOF
run_roster_case "attr04_java_sink_bool_block_false" "java" "Attr04_java_sink_bool_block_false_0" "block-false-should-pass" "sink boolean toggle accepts false even though production uses true" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr05_java_sink_method_arg_flag_param" "Attr05_java_sink_method_arg_flag_param_0.ros" <<'EOF'
Roster Attr05_java_sink_method_arg_flag_param {
    sink.methodArg += {
        precise = true;
        value = "java.sql.PreparedStatement.executeQuery";
        param = "[{'position':0,'tainted':true,'type':'String'}]";
        flag = "sdk sink";
    };
}
EOF
run_roster_case "attr05_java_sink_method_arg_flag_param" "java" "Attr05_java_sink_method_arg_flag_param_0" "should-pass" "sink.methodArg supports param plus flag together as seen in SQLi roster patterns" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr06_java_sink_method_arg_exclude_tag" "Attr06_java_sink_method_arg_exclude_tag_0.ros" <<'EOF'
Roster Attr06_java_sink_method_arg_exclude_tag {
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
        param = "[{'position':0,'tainted':true}]";
        excludeTag = "SkipRuntimeExec";
    };
}
EOF
run_roster_case "attr06_java_sink_method_arg_exclude_tag" "java" "Attr06_java_sink_method_arg_exclude_tag_0" "infer-from-other-block-fields" "test whether excludeTag generalizes to sink.methodArg even without production sample" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr07_java_sink_method_object_param" "Attr07_java_sink_method_object_param_0.ros" <<'EOF'
Roster Attr07_java_sink_method_object_param {
    sink.methodObject += {
        precise = true;
        value = "java.io.ObjectInputStream.readObject";
        param = "[{'position':0,'tainted':true}]";
    };
}
EOF
run_roster_case "attr07_java_sink_method_object_param" "java" "Attr07_java_sink_method_object_param_0" "param-should-stay-methodArg-only" "test whether param leaks from sink.methodArg to sink.methodObject" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr08_java_sink_alloc_arg_param" "Attr08_java_sink_alloc_arg_param_0.ros" <<'EOF'
Roster Attr08_java_sink_alloc_arg_param {
    sink.allocArg += {
        precise = true;
        value = "java.net.URL";
        param = "[{'position':0,'tainted':true}]";
    };
}
EOF
run_roster_case "attr08_java_sink_alloc_arg_param" "java" "Attr08_java_sink_alloc_arg_param_0" "param-should-stay-methodArg-only" "test whether param leaks from sink.methodArg to sink.allocArg" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr09_java_propagate_custom_accurate" "Attr09_java_propagate_custom_accurate_0.ros" <<'EOF'
Roster Attr09_java_propagate_custom_accurate {
    propagate.customMethodPropagate += {
        precise = true;
        value = "java.lang.String.join";
        from = "1";
        to = "return";
        accurate = true;
    };
}
EOF
run_roster_case "attr09_java_propagate_custom_accurate" "java" "Attr09_java_propagate_custom_accurate_0" "should-pass" "customMethodPropagate accepts precise/from/to/accurate together" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr10_java_propagate_object_to_return_accurate" "Attr10_java_propagate_object_to_return_accurate_0.ros" <<'EOF'
Roster Attr10_java_propagate_object_to_return_accurate {
    propagate.methodObjectToReturn += {
        value = "append";
        accurate = true;
    };
}
EOF
run_roster_case "attr10_java_propagate_object_to_return_accurate" "java" "Attr10_java_propagate_object_to_return_accurate_0" "accurate-should-stay-customMethodPropagate-only" "test whether accurate leaks to fixed-direction propagate fields" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr11_java_sink_method_object_flag" "Attr11_java_sink_method_object_flag_0.ros" <<'EOF'
Roster Attr11_java_sink_method_object_flag {
    sink.methodObject += {
        precise = true;
        value = "java.io.ObjectInputStream.readObject";
        flag = "object sink";
    };
}
EOF
run_roster_case "attr11_java_sink_method_object_flag" "java" "Attr11_java_sink_method_object_flag_0" "flag-may-be-field-specific" "test whether sink.methodArg style flag generalizes to sink.methodObject" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr12_java_source_method_return_flag" "Attr12_java_source_method_return_flag_0.ros" <<'EOF'
Roster Attr12_java_source_method_return_flag {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
        flag = "not generic";
    };
}
EOF
run_roster_case "attr12_java_source_method_return_flag" "java" "Attr12_java_source_method_return_flag_0" "flag-may-be-field-specific" "test whether source.mvcMapping style flag generalizes to source.methodReturn" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr13_js_sink_method_arg_flag" "Attr13_js_sink_method_arg_flag_0.ros" <<'EOF'
Roster Attr13_js_sink_method_arg_flag {
    sink.methodArg += {
        pattern += "/\\beval\\b/";
        flag = "sdk sink";
    };
}
EOF
run_roster_case "attr13_js_sink_method_arg_flag" "javascript" "Attr13_js_sink_method_arg_flag_0" "java-flag-may-not-carry-to-js" "test whether Java sink flag attribute migrates to JS sink.methodArg" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr14_js_source_method_return_exclude_tag" "Attr14_js_source_method_return_exclude_tag_0.ros" <<'EOF'
Roster Attr14_js_source_method_return_exclude_tag {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
        excludeTag = "FrontendExcludeMe";
    };
}
EOF
run_roster_case "attr14_js_source_method_return_exclude_tag" "javascript" "Attr14_js_source_method_return_exclude_tag_0" "java-excludeTag-may-not-carry-to-js" "test whether Java block excludeTag attribute migrates to JS source.methodReturn" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr15_js_sink_method_arg_param" "Attr15_js_sink_method_arg_param_0.ros" <<'EOF'
Roster Attr15_js_sink_method_arg_param {
    sink.methodArg += {
        pattern += "/\\beval\\b/";
        param = "[{'position':0,'tainted':true}]";
    };
}
EOF
run_roster_case "attr15_js_sink_method_arg_param" "javascript" "Attr15_js_sink_method_arg_param_0" "java-param-should-not-carry-to-js" "test whether Java param JSON migrates to JS sink.methodArg" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr16_java_sanitizer_method_return_flag" "Attr16_java_sanitizer_method_return_flag_0.ros" <<'EOF'
Roster Attr16_java_sanitizer_method_return_flag {
    sanitizer.methodReturn += {
        precise = true;
        value = "org.springframework.web.util.HtmlUtils.htmlEscape";
        flag = "sanitizer flag";
    };
}
EOF
run_roster_case "attr16_java_sanitizer_method_return_flag" "java" "Attr16_java_sanitizer_method_return_flag_0" "flag-may-be-broad-java-block-attribute" "test whether flag generalizes to sanitizer.methodReturn" >> "$SUMMARY_FILE"

write_roster "$LAB_DIR/attr17_java_propagate_method_object_to_return_flag" "Attr17_java_propagate_method_object_to_return_flag_0.ros" <<'EOF'
Roster Attr17_java_propagate_method_object_to_return_flag {
    propagate.methodObjectToReturn += {
        value = "append|concat";
        flag = "propagate flag";
    };
}
EOF
run_roster_case "attr17_java_propagate_method_object_to_return_flag" "java" "Attr17_java_propagate_method_object_to_return_flag_0" "flag-may-be-broad-java-block-attribute" "test whether flag generalizes to propagate.methodObjectToReturn" >> "$SUMMARY_FILE"

echo "Wrote results to $SUMMARY_FILE"