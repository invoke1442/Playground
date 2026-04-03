#!/bin/bash
# x-series: Systematic exploration of Java sink, Java sanitizer, JS sink sub-fields + expression semantics
set -euo pipefail

VERIFY_SH="/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="/tmp/x-results"
mkdir -p "$RESULTS_DIR"

run_roster() {
    local name="$1" lang="$2" roster_name="$3" rosfilename="$4" roscontent="$5"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters"
    echo "$roscontent" > "$D/rosters/${rosfilename}"
    bash "$VERIFY_SH" roster "$lang" "$roster_name" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:400] if o else 'PASS')" 2>&1)
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
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:400] if o else 'PASS')" 2>&1)
    echo "[$name] $out"
}

echo "========================================"
echo "Part 1: Java SINK sub-fields (Roster)"
echo "========================================"

# Known: sink.methodArg ✅ (block syntax), sink.methodReturn ❌, sink.functionArg ❌
# Test new: sink.expression, sink.param_annotation, sink.method_annotation, sink.method_param
# Also try: sink with string syntax like source sub-fields

echo "--- sink.expression (string) ---"
run_roster x01 java "Java_x01_0" "Java_x01_0.ros" 'Roster Java_x01 {
    sink.expression = "com.example.Sink.dangerous";
}'

echo "--- sink.expression (+= string) ---"
run_roster x02 java "Java_x02_0" "Java_x02_0.ros" 'Roster Java_x02 {
    sink.expression += "com.example.Sink.dangerous";
}'

echo "--- sink.expression (+= block) ---"
run_roster x03 java "Java_x03_0" "Java_x03_0.ros" 'Roster Java_x03 {
    sink.expression += {
        precise = true;
        value = "com.example.Sink.dangerous";
    };
}'

echo "--- sink.param_annotation (string) ---"
run_roster x04 java "Java_x04_0" "Java_x04_0.ros" 'Roster Java_x04 {
    sink.param_annotation = "com.example.SinkAnnotation";
}'

echo "--- sink.method_annotation (string) ---"
run_roster x05 java "Java_x05_0" "Java_x05_0.ros" 'Roster Java_x05 {
    sink.method_annotation = "com.example.DangerousMethod";
}'

echo "--- sink.method_param (string) ---"
run_roster x06 java "Java_x06_0" "Java_x06_0.ros" 'Roster Java_x06 {
    sink.method_param = "com.example.Sink.exec[0]";
}'

echo "--- sink.methodReturn (block) [re-verify known ❌] ---"
run_roster x07 java "Java_x07_0" "Java_x07_0.ros" 'Roster Java_x07 {
    sink.methodReturn += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}'

echo "--- sink.methodReturn (string) ---"
run_roster x08 java "Java_x08_0" "Java_x08_0.ros" 'Roster Java_x08 {
    sink.methodReturn = "com.example.Sink.exec";
}'

echo "--- sink.customSinkFunc = string (no loadclass) ---"
run_roster x09 java "Java_x09_0" "Java_x09_0.ros" 'Roster Java_x09 {
    sink.customSinkFunc = "com.example.CustomSink";
}'

echo "--- sink.customSanitizerFunc (wrong name test) ---"
run_roster x10 java "Java_x10_0" "Java_x10_0.ros" 'Roster Java_x10 {
    sink.customSinkFunc = loadclass("CustomChecker.sinkCheck_0");
}'

echo ""
echo "========================================"
echo "Part 2: Java SANITIZER sub-fields (Roster)"
echo "========================================"

# Known: sanitizer.methodReturn ✅, sanitizer.methodArg ✅, sanitizer.functionArg ❌, sanitizer.functionReturn ❌
# Test new: sanitizer.expression, sanitizer.param_annotation, sanitizer.method_annotation, sanitizer.method_param
# Also: sanitizer.customSanitizerFunc, sanitizer with string syntax

echo "--- sanitizer.expression (string) ---"
run_roster x11 java "Java_x11_0" "Java_x11_0.ros" 'Roster Java_x11 {
    sanitizer.expression = "com.example.Sanitizer.clean";
}'

echo "--- sanitizer.expression (+= string) ---"
run_roster x12 java "Java_x12_0" "Java_x12_0.ros" 'Roster Java_x12 {
    sanitizer.expression += "com.example.Sanitizer.clean";
}'

echo "--- sanitizer.param_annotation (string) ---"
run_roster x13 java "Java_x13_0" "Java_x13_0.ros" 'Roster Java_x13 {
    sanitizer.param_annotation = "com.example.SafeAnnotation";
}'

echo "--- sanitizer.method_annotation (string) ---"
run_roster x14 java "Java_x14_0" "Java_x14_0.ros" 'Roster Java_x14 {
    sanitizer.method_annotation = "com.example.Sanitized";
}'

echo "--- sanitizer.method_param (string) ---"
run_roster x15 java "Java_x15_0" "Java_x15_0.ros" 'Roster Java_x15 {
    sanitizer.method_param = "com.example.Sanitizer.clean[0]";
}'

echo "--- sanitizer.customSanitizerFunc (loadclass) ---"
run_roster x16 java "Java_x16_0" "Java_x16_0.ros" 'Roster Java_x16 {
    sanitizer.customSanitizerFunc = loadclass("CustomChecker.sanitizerCheck_0");
}'

echo "--- sanitizer.customSanitizerFunc (string) ---"
run_roster x17 java "Java_x17_0" "Java_x17_0.ros" 'Roster Java_x17 {
    sanitizer.customSanitizerFunc = "com.example.CustomSanitizer";
}'

echo "--- sanitizer.methodArg (block) [re-verify ✅] ---"
run_roster x18 java "Java_x18_0" "Java_x18_0.ros" 'Roster Java_x18 {
    sanitizer.methodArg += {
        precise = true;
        value = "com.example.Sanitizer.sanitizeParam";
    };
}'

echo "--- sanitizer.methodArg (string) ---"
run_roster x19 java "Java_x19_0" "Java_x19_0.ros" 'Roster Java_x19 {
    sanitizer.methodArg = "com.example.Sanitizer.sanitizeParam";
}'

echo ""
echo "========================================"
echo "Part 3: JS SINK sub-fields (Roster)"
echo "========================================"

echo "--- JS sink.expression (pattern block) ---"
run_roster x20 javascript "NodeJS_x20_0" "NodeJS_x20_0.ros" 'Roster NodeJS_x20 {
    sink.expression += {
        pattern += "/\\bdocument\\.write\\b/";
    };
}'

echo "--- JS sink.expression (value block) ---"
run_roster x21 javascript "NodeJS_x21_0" "NodeJS_x21_0.ros" 'Roster NodeJS_x21 {
    sink.expression += {
        value += "/\\bdocument\\.write\\b/";
    };
}'

echo "--- JS sink.methodReturn (pattern block) ---"
run_roster x22 javascript "NodeJS_x22_0" "NodeJS_x22_0.ros" 'Roster NodeJS_x22 {
    sink.methodReturn += {
        pattern += "/\\beval\\b/";
    };
}'

echo "--- JS sink.paramDecorator (pattern block) ---"
run_roster x23 javascript "NodeJS_x23_0" "NodeJS_x23_0.ros" 'Roster NodeJS_x23 {
    sink.paramDecorator += {
        pattern += "/\\b@Inject\\b/";
    };
}'

echo "--- JS sink.customSinkFunc = loadclass ---"
run_roster x24 javascript "NodeJS_x24_0" "NodeJS_x24_0.ros" 'Roster NodeJS_x24 {
    sink.customSinkFunc = loadclass("NodeJS_x24.customSink_0");
}'

echo "--- JS sink.functionArg (pattern block) ---"
run_roster x25 javascript "NodeJS_x25_0" "NodeJS_x25_0.ros" 'Roster NodeJS_x25 {
    sink.functionArg += {
        pattern += "/\\bexec\\b/";
    };
}'

echo "--- JS sanitizer.expression (pattern block) ---"
run_roster x26 javascript "NodeJS_x26_0" "NodeJS_x26_0.ros" 'Roster NodeJS_x26 {
    sanitizer.expression += {
        pattern += "/\\bescapeHtml\\b/";
    };
}'

echo "--- JS sanitizer.methodArg (pattern block) ---"
run_roster x27 javascript "NodeJS_x27_0" "NodeJS_x27_0.ros" 'Roster NodeJS_x27 {
    sanitizer.methodArg += {
        pattern += "/\\bsanitizeInput\\b/";
    };
}'

echo "--- JS sanitizer.paramDecorator (pattern) ---"
run_roster x28 javascript "NodeJS_x28_0" "NodeJS_x28_0.ros" 'Roster NodeJS_x28 {
    sanitizer.paramDecorator += {
        pattern += "/@Sanitized\\b/";
    };
}'

echo "--- JS sanitizer.customSanitizerFunc = loadclass ---"
run_roster x29 javascript "NodeJS_x29_0" "NodeJS_x29_0.ros" 'Roster NodeJS_x29 {
    sanitizer.customSanitizerFunc = loadclass("NodeJS_x29.customSanitizer_0");
}'

echo ""
echo "========================================"
echo "Part 4: Expression semantics tests"
echo "========================================"

# Test: source.expression in Java (Roster) with several patterns to understand matching
echo "--- Java source.expression = FQN method (Roster) ---"
run_roster x30 java "Java_x30_0" "Java_x30_0.ros" 'Roster Java_x30 {
    source.expression = "com.example.Config.getProperty";
}'

echo "--- Java source.expression = FQN class (no method) ---"
run_roster x31 java "Java_x31_0" "Java_x31_0.ros" 'Roster Java_x31 {
    source.expression = "com.example.Config";
}'

echo "--- Java source.expression = simple name ---"
run_roster x32 java "Java_x32_0" "Java_x32_0.ros" 'Roster Java_x32 {
    source.expression = "getProperty";
}'

echo "--- Java source.expression = wildcard ---"
run_roster x33 java "Java_x33_0" "Java_x33_0.ros" 'Roster Java_x33 {
    source.expression = "com.example.*";
}'

echo "--- Java sink.expression = FQN method ---"
echo "(already x01)"

echo "--- Java sanitizer.expression = FQN method ---"
echo "(already x11)"

# Test expression in JS more deeply
echo "--- JS source.expression with regex (already known ✅) ---"
echo "--- JS sink.expression (already x20/x21) ---"

echo "--- JS source.expression with value = plain string (no regex slashes) ---"
run_roster x34 javascript "NodeJS_x34_0" "NodeJS_x34_0.ros" 'Roster NodeJS_x34 {
    source.expression += {
        value = "ctx.request.body";
    };
}'

echo "--- JS source.expression with value += regex ---"
run_roster x35 javascript "NodeJS_x35_0" "NodeJS_x35_0.ros" 'Roster NodeJS_x35 {
    source.expression += {
        value += "/ctx\\.request\\.(body|query)$/";
    };
}'

echo "--- Java source.expression in full rule context via relation ---"
run_rule x36 java "95001" 'Rule ExprTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_x36_0.ros" 'Roster Java_x36 {
    source.expression = "com.example.Config.getProperty";
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"95001": ["Java_x36_0"]}'

echo "--- Java sink.expression in full rule context via relation ---"
run_rule x37 java "95002" 'Rule SinkExprTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_x37_0.ros" 'Roster Java_x37 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.expression = "com.example.Sink.dangerous";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"95002": ["Java_x37_0"]}'

echo ""
echo "========================================"
echo "Part 5: Additional Java sink/sanitizer tries"
echo "========================================"

echo "--- Java sink.methodArg (string, not block) ---"
run_roster x38 java "Java_x38_0" "Java_x38_0.ros" 'Roster Java_x38 {
    sink.methodArg = "com.example.Sink.exec";
}'

echo "--- Java sink.methodArg += string ---"
run_roster x39 java "Java_x39_0" "Java_x39_0.ros" 'Roster Java_x39 {
    sink.methodArg += "com.example.Sink.exec";
}'

echo "--- Java sanitizer.methodReturn (string, not block) ---"
run_roster x40 java "Java_x40_0" "Java_x40_0.ros" 'Roster Java_x40 {
    sanitizer.methodReturn = "com.example.Sanitizer.clean";
}'

echo ""
echo "====== All x-series experiments done ======"
