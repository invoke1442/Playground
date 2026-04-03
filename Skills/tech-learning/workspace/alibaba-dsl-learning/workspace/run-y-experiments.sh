#!/bin/bash
# x-series follow-up: JS sink/sanitizer string syntax, Java expression comparison, methodReturn string vs block
set -euo pipefail

VERIFY_SH="/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="/tmp/x-results2"
mkdir -p "$RESULTS_DIR"

run_roster() {
    local name="$1" lang="$2" roster_name="$3" rosfilename="$4" roscontent="$5"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters"
    echo "$roscontent" > "$D/rosters/${rosfilename}"
    bash "$VERIFY_SH" roster "$lang" "$roster_name" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:300] if o else 'PASS')" 2>&1)
    echo "[$name] $out"
}

run_rule() {
    local name="$1" lang="$2" ruleid="$3" rulcontent="$4" rosfilename="$5" roscontent="$6" relcontent="$7"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters" "$D/relation"
    echo "$rulcontent" > "$D/${ruleid}.rul"
    if [[ -n "$rosfilename" ]]; then
        echo "$roscontent" > "$D/rosters/${rosfilename}"
    fi
    if [[ -n "$relcontent" ]]; then
        echo "$relcontent" > "$D/relation/config_roster_relation.json"
    fi
    bash "$VERIFY_SH" rule "$lang" "$ruleid" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:300] if o else 'PASS')" 2>&1)
    echo "[$name] $out"
}

echo "====== Part A: JS sink string syntax ======"
echo "--- JS sink.methodArg (string, not block) ---"
run_roster y01 javascript "NodeJS_y01_0" "NodeJS_y01_0.ros" 'Roster NodeJS_y01 {
    sink.methodArg = "/\\bres\\.send\\b/";
}'

echo "--- JS sink.expression = string ---"
run_roster y02 javascript "NodeJS_y02_0" "NodeJS_y02_0.ros" 'Roster NodeJS_y02 {
    sink.expression = "/\\bdocument\\.write\\b/";
}'

echo "--- JS sink.expression += string ---"
run_roster y03 javascript "NodeJS_y03_0" "NodeJS_y03_0.ros" 'Roster NodeJS_y03 {
    sink.expression += "/\\bdocument\\.write\\b/";
}'

echo "--- JS sink.methodReturn = string ---"
run_roster y04 javascript "NodeJS_y04_0" "NodeJS_y04_0.ros" 'Roster NodeJS_y04 {
    sink.methodReturn = "/\\beval\\b/";
}'

echo "--- JS sink.paramDecorator = string ---"
run_roster y05 javascript "NodeJS_y05_0" "NodeJS_y05_0.ros" 'Roster NodeJS_y05 {
    sink.paramDecorator = "/@Inject\\b/";
}'

echo "--- JS sink.param_annotation = string ---"
run_roster y06 javascript "NodeJS_y06_0" "NodeJS_y06_0.ros" 'Roster NodeJS_y06 {
    sink.param_annotation = "/\\bSinkAnnotation\\b/";
}'

echo "--- JS sink.method_annotation = string ---"
run_roster y07 javascript "NodeJS_y07_0" "NodeJS_y07_0.ros" 'Roster NodeJS_y07 {
    sink.method_annotation = "/\\bDangerous\\b/";
}'

echo "--- JS sink.method_param = string ---"
run_roster y08 javascript "NodeJS_y08_0" "NodeJS_y08_0.ros" 'Roster NodeJS_y08 {
    sink.method_param = "/\\bexec\\b/";
}'

echo ""
echo "====== Part B: JS sanitizer string syntax ======"
echo "--- JS sanitizer.methodReturn = string ---"
run_roster y09 javascript "NodeJS_y09_0" "NodeJS_y09_0.ros" 'Roster NodeJS_y09 {
    sanitizer.methodReturn = "/\\bescapeHtml\\b/";
}'

echo "--- JS sanitizer.expression = string ---"
run_roster y10 javascript "NodeJS_y10_0" "NodeJS_y10_0.ros" 'Roster NodeJS_y10 {
    sanitizer.expression = "/\\bsanitize\\b/";
}'

echo "--- JS sanitizer.methodArg = string ---"
run_roster y11 javascript "NodeJS_y11_0" "NodeJS_y11_0.ros" 'Roster NodeJS_y11 {
    sanitizer.methodArg = "/\\bsanitizeParam\\b/";
}'

echo "--- JS sanitizer.param_annotation = string ---"
run_roster y12 javascript "NodeJS_y12_0" "NodeJS_y12_0.ros" 'Roster NodeJS_y12 {
    sanitizer.param_annotation = "/\\bSafe\\b/";
}'

echo "--- JS sanitizer.method_annotation = string ---"
run_roster y13 javascript "NodeJS_y13_0" "NodeJS_y13_0.ros" 'Roster NodeJS_y13 {
    sanitizer.method_annotation = "/\\bSanitized\\b/";
}'

echo "--- JS sanitizer.method_param = string ---"
run_roster y14 javascript "NodeJS_y14_0" "NodeJS_y14_0.ros" 'Roster NodeJS_y14 {
    sanitizer.method_param = "/\\bclean\\b/";
}'

echo ""
echo "====== Part C: Java Two-syntax fields ======"
# Clarify which Java sink/sanitizer fields accept string vs block vs both

echo "--- Java sink.methodReturn += string ---"
run_roster y15 java "Java_y15_0" "Java_y15_0.ros" 'Roster Java_y15 {
    sink.methodReturn += "com.example.Sink.exec";
}'

echo "--- Java source.methodReturn = string ---"
run_roster y16 java "Java_y16_0" "Java_y16_0.ros" 'Roster Java_y16 {
    source.methodReturn = "com.example.Source.get";
}'

echo "--- Java source.methodReturn += string ---"
run_roster y17 java "Java_y17_0" "Java_y17_0.ros" 'Roster Java_y17 {
    source.methodReturn += "com.example.Source.get";
}'

echo "--- Java source.methodArg = string ---"
run_roster y18 java "Java_y18_0" "Java_y18_0.ros" 'Roster Java_y18 {
    source.methodArg = "com.example.Source.get";
}'

echo ""
echo "====== Part D: Expression vs methodReturn/methodArg comparison ======"
# What distinguishes expression from methodReturn/methodArg?
# Test: can expression and methodReturn co-exist? do they overlap?

echo "--- Java roster with both source.expression + source.methodReturn ---"
run_roster y19 java "Java_y19_0" "Java_y19_0.ros" 'Roster Java_y19 {
    source.expression = "com.example.Config.getProperty";
    source.methodReturn += { precise = true; value = "com.example.Source.getData"; };
}'

echo "--- Java roster with both sink.expression + sink.methodArg ---"
run_roster y20 java "Java_y20_0" "Java_y20_0.ros" 'Roster Java_y20 {
    sink.expression = "com.example.Sink.dangerous";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}'

echo "--- Java roster with all sink types ---"
run_roster y21 java "Java_y21_0" "Java_y21_0.ros" 'Roster Java_y21 {
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
    sink.expression = "com.example.Sink.dangerous";
    sink.methodReturn = "com.example.Sink.getResult";
    sink.param_annotation = "com.example.SinkParam";
    sink.method_annotation = "com.example.SinkMethod";
    sink.method_param = "com.example.Sink.run[0]";
    sink.customSinkFunc = "com.example.CustomSinkChecker";
}'

echo "--- Java roster with all sanitizer types ---"
run_roster y22 java "Java_y22_0" "Java_y22_0.ros" 'Roster Java_y22 {
    sanitizer.methodReturn += { value = "com.example.Sanitizer.clean"; };
    sanitizer.methodArg += { precise = true; value = "com.example.Sanitizer.filterParam"; };
    sanitizer.expression = "com.example.Sanitizer.escape";
    sanitizer.param_annotation = "com.example.Safe";
    sanitizer.method_annotation = "com.example.Sanitized";
    sanitizer.method_param = "com.example.Sanitizer.clean[0]";
    sanitizer.customSanitizerFunc = "com.example.CustomSanitizerChecker";
}'

echo "--- JS roster with all source types ---"
run_roster y23 javascript "NodeJS_y23_0" "NodeJS_y23_0.ros" 'Roster NodeJS_y23 {
    source.methodReturn += { value += "/\\breq\\.query\\b/"; };
    source.expression += { value += "/ctx\\.request\\.body$/"; };
    source.paramDecorator += { value = "/@Query\\b/"; };
}'

echo ""
echo "====== All y-series done ======"
