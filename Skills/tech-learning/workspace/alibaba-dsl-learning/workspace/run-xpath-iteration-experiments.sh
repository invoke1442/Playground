#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_DIR="$ROOT_DIR/xpath-iteration-lab"
RESULTS_DIR="$LAB_DIR/results"
VERIFY_SCRIPT="${VERIFY_SCRIPT:-/home/nyn/Desktop/Projects/SAST/oh-my-rule/packages/skills/alibaba-dsl/scripts/verify.sh}"

mkdir -p "$LAB_DIR" "$RESULTS_DIR"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "verify.sh not found or not executable: $VERIFY_SCRIPT" >&2
  exit 1
fi

create_roster_config() {
  local dir="$1"
  local roster_file="$2"
  local roster_body="$3"
  rm -rf "$dir"
  mkdir -p "$dir/rosters"
  printf '%s\n' "$roster_body" > "$dir/rosters/$roster_file"
}

run_roster_case() {
  local case_id="$1"
  local lang="$2"
  local roster_name="$3"
  local expected="$4"
  local note="$5"
  local dir="$LAB_DIR/$case_id"
  local out_json="$RESULTS_DIR/$case_id.json"

  bash "$VERIFY_SCRIPT" roster "$lang" "$roster_name" "$dir" 2>/dev/null | sed -n '1p' > "$out_json"

  python3 - "$case_id" "$lang" "$expected" "$note" "$out_json" <<'PY'
import json, sys
case_id, lang, expected, note, path = sys.argv[1:]
data = json.load(open(path))
output = data.get("data", {}).get("output", "")
status = "PASS" if output == "[]" else "FAIL"
print("\t".join([case_id, lang, expected, status, note, output.replace("\n", " ")[:220]]))
PY
}

SUMMARY_FILE="$RESULTS_DIR/summary.tsv"
printf 'case\tlanguage\texpected\tactual\tnote\toutput\n' > "$SUMMARY_FILE"

# xp01: production style entranceFileXpath with += string in Java
create_roster_config "$LAB_DIR/xp01_java_general_entrance_plus" "XP01_java_general_entrance_plus_0.ros" 'Roster XP01_java_general_entrance_plus {
    general.entranceFileXpath += "./self::CompilationUnit/ImportDeclaration/Name[matches(@Image,\"java.util.List|java.util.Map\")]";
}'
run_roster_case "xp01_java_general_entrance_plus" "java" "XP01_java_general_entrance_plus_0" "pass" "general.entranceFileXpath supports production-style += string" >> "$SUMMARY_FILE"

# xp02: production style methodRedirect with xpath block in Java
create_roster_config "$LAB_DIR/xp02_java_general_method_redirect" "XP02_java_general_method_redirect_0.ros" 'Roster XP02_java_general_method_redirect {
    general.methodRedirect += {
        precise = true;
        value = "com.example.Redirected";
        xpath = "./self::Annotation/NormalAnnotation/MemberValuePairs/MemberValuePair[@Image=\"to\"]/MemberValue/PrimaryExpression/PrimaryPrefix/ResultType";
    };
}'
run_roster_case "xp02_java_general_method_redirect" "java" "XP02_java_general_method_redirect_0" "pass" "general.methodRedirect accepts xpath as a subfield" >> "$SUMMARY_FILE"

# xp03: source.methodParam with complex xpath
create_roster_config "$LAB_DIR/xp03_java_source_method_param_xpath" "XP03_java_source_method_param_xpath_0.ros" 'Roster XP03_java_source_method_param_xpath {
    source.methodParam += {
        xpath = "./self::FormalParameter[../../..[@Public=\"true\" and @Static=\"false\" and @MethodName=\"handle\"] and ancestor::ClassOrInterfaceDeclaration[isExtends(@ClassName,\"java.lang.Object\")] and not(ancestor::ClassOrInterfaceBodyDeclaration//Annotation/MarkerAnnotation/Name[@Image=\"Skip\"])]";
        tag = "methodParamXPath";
    };
}'
run_roster_case "xp03_java_source_method_param_xpath" "java" "XP03_java_source_method_param_xpath_0" "pass" "source.methodParam accepts complex xpath predicates" >> "$SUMMARY_FILE"

# xp04: hypothesis - source.methodReturn does not accept xpath subfield
create_roster_config "$LAB_DIR/xp04_java_source_method_return_xpath" "XP04_java_source_method_return_xpath_0.ros" 'Roster XP04_java_source_method_return_xpath {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp04_java_source_method_return_xpath" "java" "XP04_java_source_method_return_xpath_0" "fail" "test whether source.methodReturn also accepts xpath" >> "$SUMMARY_FILE"

# xp05: hypothesis - source.methodArg does not accept xpath subfield
create_roster_config "$LAB_DIR/xp05_java_source_method_arg_xpath" "XP05_java_source_method_arg_xpath_0.ros" 'Roster XP05_java_source_method_arg_xpath {
    source.methodArg += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getInputStream";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp05_java_source_method_arg_xpath" "java" "XP05_java_source_method_arg_xpath_0" "fail" "test whether source.methodArg also accepts xpath" >> "$SUMMARY_FILE"

# xp06: hypothesis - sink.methodArg does not accept xpath subfield
create_roster_config "$LAB_DIR/xp06_java_sink_method_arg_xpath" "XP06_java_sink_method_arg_xpath_0.ros" 'Roster XP06_java_sink_method_arg_xpath {
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp06_java_sink_method_arg_xpath" "java" "XP06_java_sink_method_arg_xpath_0" "fail" "test whether sink.methodArg accepts xpath subfield" >> "$SUMMARY_FILE"

# xp07: hypothesis - sanitizer.methodReturn does not accept xpath subfield
create_roster_config "$LAB_DIR/xp07_java_sanitizer_method_return_xpath" "XP07_java_sanitizer_method_return_xpath_0.ros" 'Roster XP07_java_sanitizer_method_return_xpath {
    sanitizer.methodReturn += {
        value = "org.springframework.web.util.HtmlUtils.htmlEscape";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp07_java_sanitizer_method_return_xpath" "java" "XP07_java_sanitizer_method_return_xpath_0" "fail" "test whether sanitizer.methodReturn accepts xpath subfield" >> "$SUMMARY_FILE"

# xp08: hypothesis - JS has no general.entranceFileXpath support
create_roster_config "$LAB_DIR/xp08_js_general_entrance_xpath" "XP08_js_general_entrance_xpath_0.ros" 'Roster XP08_js_general_entrance_xpath {
    general.entranceFileXpath += "//Program";
}'
run_roster_case "xp08_js_general_entrance_xpath" "javascript" "XP08_js_general_entrance_xpath_0" "fail" "test Java general.entranceFileXpath analogue in JS" >> "$SUMMARY_FILE"

# xp09: hypothesis - JS source.methodReturn block rejects xpath
create_roster_config "$LAB_DIR/xp09_js_source_method_return_xpath" "XP09_js_source_method_return_xpath_0.ros" 'Roster XP09_js_source_method_return_xpath {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
        xpath = "//CallExpression";
    };
}'
run_roster_case "xp09_js_source_method_return_xpath" "javascript" "XP09_js_source_method_return_xpath_0" "fail" "test xpath subfield on JS source.methodReturn" >> "$SUMMARY_FILE"

# xp10: hypothesis - JS paramDecorator remains regex/value based, not xpath based
create_roster_config "$LAB_DIR/xp10_js_source_param_decorator_xpath" "XP10_js_source_param_decorator_xpath_0.ros" 'Roster XP10_js_source_param_decorator_xpath {
    source.paramDecorator += {
        value += "/@Query\\b/";
        xpath = "//Decorator";
    };
}'
run_roster_case "xp10_js_source_param_decorator_xpath" "javascript" "XP10_js_source_param_decorator_xpath_0" "fail" "test xpath subfield on JS source.paramDecorator" >> "$SUMMARY_FILE"

# xp11: control - sink.methodArg should reject arbitrary unknown subfield if xpath is genuinely special
create_roster_config "$LAB_DIR/xp11_java_sink_method_arg_bogus" "XP11_java_sink_method_arg_bogus_0.ros" 'Roster XP11_java_sink_method_arg_bogus {
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
        bogus = "x";
    };
}'
run_roster_case "xp11_java_sink_method_arg_bogus" "java" "XP11_java_sink_method_arg_bogus_0" "fail" "control case: sink.methodArg with bogus subfield" >> "$SUMMARY_FILE"

# xp12: hypothesis - sanitizer.methodArg shares methodArg-like xpath capability with sink.methodArg
create_roster_config "$LAB_DIR/xp12_java_sanitizer_method_arg_xpath" "XP12_java_sanitizer_method_arg_xpath_0.ros" 'Roster XP12_java_sanitizer_method_arg_xpath {
    sanitizer.methodArg += {
        precise = true;
        value = "java.net.URL.<init>";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp12_java_sanitizer_method_arg_xpath" "java" "XP12_java_sanitizer_method_arg_xpath_0" "pass" "test whether sanitizer.methodArg also accepts xpath" >> "$SUMMARY_FILE"

# xp13: hypothesis - sink.methodObject may share sink.methodArg xpath capability
create_roster_config "$LAB_DIR/xp13_java_sink_method_object_xpath" "XP13_java_sink_method_object_xpath_0.ros" 'Roster XP13_java_sink_method_object_xpath {
    sink.methodObject += {
        precise = true;
        value = "java.io.ObjectInputStream.readObject";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp13_java_sink_method_object_xpath" "java" "XP13_java_sink_method_object_xpath_0" "pass" "test whether sink.methodObject accepts xpath" >> "$SUMMARY_FILE"

# xp14: hypothesis - source.paramAnnotation does not accept xpath even though it is a block source field
create_roster_config "$LAB_DIR/xp14_java_source_param_annotation_xpath" "XP14_java_source_param_annotation_xpath_0.ros" 'Roster XP14_java_source_param_annotation_xpath {
    source.paramAnnotation += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestParam";
        xpath = "./self::FormalParameter[@ChildIndex=0]";
    };
}'
run_roster_case "xp14_java_source_param_annotation_xpath" "java" "XP14_java_source_param_annotation_xpath_0" "fail" "test whether source.paramAnnotation accepts xpath" >> "$SUMMARY_FILE"

# xp15: hypothesis - source.mvcMapping does not accept xpath
create_roster_config "$LAB_DIR/xp15_java_source_mvc_mapping_xpath" "XP15_java_source_mvc_mapping_xpath_0.ros" 'Roster XP15_java_source_mvc_mapping_xpath {
    source.mvcMapping += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestMapping";
        flag = "m";
        xpath = "./self::Annotation";
    };
}'
run_roster_case "xp15_java_source_mvc_mapping_xpath" "java" "XP15_java_source_mvc_mapping_xpath_0" "fail" "test whether source.mvcMapping accepts xpath" >> "$SUMMARY_FILE"

# xp16: hypothesis - JS sink.methodArg accepts xpath like Java sink.methodArg
create_roster_config "$LAB_DIR/xp16_js_sink_method_arg_xpath" "XP16_js_sink_method_arg_xpath_0.ros" 'Roster XP16_js_sink_method_arg_xpath {
    sink.methodArg += {
        pattern += "/\\beval\\b/";
        xpath = "//CallExpression";
    };
}'
run_roster_case "xp16_js_sink_method_arg_xpath" "javascript" "XP16_js_sink_method_arg_xpath_0" "pass" "test xpath subfield on JS sink.methodArg" >> "$SUMMARY_FILE"

# xp17: control - JS sink.methodArg with bogus subfield
create_roster_config "$LAB_DIR/xp17_js_sink_method_arg_bogus" "XP17_js_sink_method_arg_bogus_0.ros" 'Roster XP17_js_sink_method_arg_bogus {
    sink.methodArg += {
        pattern += "/\\beval\\b/";
        bogus = "x";
    };
}'
run_roster_case "xp17_js_sink_method_arg_bogus" "javascript" "XP17_js_sink_method_arg_bogus_0" "fail" "control case: JS sink.methodArg with bogus subfield" >> "$SUMMARY_FILE"

# xp18: hypothesis - JS does not expose general.methodRedirect even if it exposes entranceFileXpath
create_roster_config "$LAB_DIR/xp18_js_general_method_redirect" "XP18_js_general_method_redirect_0.ros" 'Roster XP18_js_general_method_redirect {
    general.methodRedirect += {
        value = "my.decorator";
        xpath = "//Decorator";
    };
}'
run_roster_case "xp18_js_general_method_redirect" "javascript" "XP18_js_general_method_redirect_0" "fail" "test general.methodRedirect analogue in JS" >> "$SUMMARY_FILE"

# xp19: control - JS general non-existent field should fail, proving general.entranceFileXpath is a recognized field
create_roster_config "$LAB_DIR/xp19_js_general_nonexistent" "XP19_js_general_nonexistent_0.ros" 'Roster XP19_js_general_nonexistent {
    general.notARealField = true;
}'
run_roster_case "xp19_js_general_nonexistent" "javascript" "XP19_js_general_nonexistent_0" "fail" "control case: JS unknown general field" >> "$SUMMARY_FILE"

# xp20: does sink.methodArgJws inherit sink.methodArg's xpath capability?
create_roster_config "$LAB_DIR/xp20_java_sink_method_arg_jws_xpath" "XP20_java_sink_method_arg_jws_xpath_0.ros" 'Roster XP20_java_sink_method_arg_jws_xpath {
    sink.methodArgJws += {
        value = "jws.response.write";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp20_java_sink_method_arg_jws_xpath" "java" "XP20_java_sink_method_arg_jws_xpath_0" "fail" "test whether sink.methodArgJws accepts xpath" >> "$SUMMARY_FILE"

# xp21: does sink.methoArgUpcast inherit sink.methodArg's xpath capability?
create_roster_config "$LAB_DIR/xp21_java_sink_metho_arg_upcast_xpath" "XP21_java_sink_metho_arg_upcast_xpath_0.ros" 'Roster XP21_java_sink_metho_arg_upcast_xpath {
    sink.methoArgUpcast += {
        value = "java.lang.Object.toString";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp21_java_sink_metho_arg_upcast_xpath" "java" "XP21_java_sink_metho_arg_upcast_xpath_0" "fail" "test whether sink.methoArgUpcast accepts xpath" >> "$SUMMARY_FILE"

# xp22: does sink.responseBody accept xpath or is xpath limited to methodArg only?
create_roster_config "$LAB_DIR/xp22_java_sink_response_body_xpath" "XP22_java_sink_response_body_xpath_0.ros" 'Roster XP22_java_sink_response_body_xpath {
    sink.responseBody += {
        value = "javax.servlet.http.HttpServletResponse";
        xpath = "./self::MethodDeclaration[@MethodName=\"handle\"]";
    };
}'
run_roster_case "xp22_java_sink_response_body_xpath" "java" "XP22_java_sink_response_body_xpath_0" "fail" "test whether sink.responseBody accepts xpath" >> "$SUMMARY_FILE"

echo "Wrote results to $SUMMARY_FILE"
