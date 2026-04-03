#!/bin/bash
# w-series experiments: Java source sub-fields + Roster import mechanism
set -euo pipefail

VERIFY_SH="/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="/tmp/w-results"
mkdir -p "$RESULTS_DIR"

run_roster() {
    local name="$1" rosfile="$2" roscontent="$3"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters"
    echo "$roscontent" > "$D/rosters/${rosfile}"
    bash "$VERIFY_SH" roster java "$rosfile" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(python3 -c "import sys,json;d=json.load(open('$RESULTS_DIR/${name}.json'));print(d.get('data',{}).get('output','')[:400])" 2>&1)
    echo "[$name] $out"
}

run_rule() {
    local name="$1" ruleid="$2" rulcontent="$3" rosfile="$4" roscontent="$5" relcontent="$6"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters" "$D/relation"
    echo "$rulcontent" > "$D/${ruleid}.rul"
    if [[ -n "$rosfile" ]]; then
        echo "$roscontent" > "$D/rosters/${rosfile}"
    fi
    if [[ -n "$relcontent" ]]; then
        echo "$relcontent" > "$D/relation/config_roster_relation.json"
    fi
    bash "$VERIFY_SH" rule java "$ruleid" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(python3 -c "import sys,json;d=json.load(open('$RESULTS_DIR/${name}.json'));print(d.get('data',{}).get('output','')[:400])" 2>&1)
    echo "[$name] $out"
}

echo "====== Part 1: Java source sub-fields ======"
echo ""

# --- source.param_annotation ---
echo "--- source.param_annotation ---"
run_roster w01 "Java_w01_0.ros" 'Roster Java_w01 {
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
}'

run_roster w02 "Java_w02_0.ros" 'Roster Java_w02 {
    source.param_annotation += "org.springframework.web.bind.annotation.RequestParam";
}'

# --- source.method_annotation ---
echo ""
echo "--- source.method_annotation ---"
run_roster w03 "Java_w03_0.ros" 'Roster Java_w03 {
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
}'

run_roster w04 "Java_w04_0.ros" 'Roster Java_w04 {
    source.method_annotation += "org.springframework.web.bind.annotation.GetMapping";
}'

# --- source.method_param ---
echo ""
echo "--- source.method_param ---"
run_roster w05 "Java_w05_0.ros" 'Roster Java_w05 {
    source.method_param = "com.example.Controller.handleRequest[0]";
}'

run_roster w06 "Java_w06_0.ros" 'Roster Java_w06 {
    source.method_param += "com.example.Controller.handleRequest[0]";
}'

# w07: method_param with xpath and tag (PDF syntax)
run_roster w07 "Java_w07_0.ros" 'Roster Java_w07 {
    source.method_param += {
        xpath = "//MethodDeclaration[@MethodName=\"handleRequest\"]/FormalParameters/FormalParameter[0]";
        tag = "userInput";
    };
}'

# --- source.expression ---
echo ""
echo "--- source.expression ---"
run_roster w08 "Java_w08_0.ros" 'Roster Java_w08 {
    source.expression = "com.example.Config.getProperty";
}'

run_roster w09 "Java_w09_0.ros" 'Roster Java_w09 {
    source.expression += "com.example.Config.getProperty";
}'

run_roster w10 "Java_w10_0.ros" 'Roster Java_w10 {
    source.expression += {
        precise = true;
        value = "com.example.Config.getProperty";
    };
}'

# --- source sub-fields in Rule (not Roster) ---
echo ""
echo "--- source sub-fields in Rule ---"
run_rule w11 "90001" 'Rule ParamAnnRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

run_rule w12 "90002" 'Rule MethodAnnRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

run_rule w13 "90003" 'Rule ExprRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.expression = "com.example.Config.getProperty";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

run_rule w14 "90004" 'Rule MethodParamRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.method_param = "com.example.Controller.handleRequest[0]";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

echo ""
echo "====== Part 2: Roster import mechanism ======"
echo ""

# w15: import roster with declaration name (import as FIRST before type)
run_rule w15 "90010" 'Rule ImportDeclName extends AbstractTaintRule {
    import roster Java_w15;
    type = "Test";
    subType = "TestRule";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "Java_w15_0.ros" 'Roster Java_w15 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
}' ""

# w16: same but WITH relation config too
run_rule w16 "90011" 'Rule ImportWithRelation extends AbstractTaintRule {
    import roster Java_w16;
    type = "Test";
    subType = "TestRule";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "Java_w16_0.ros" 'Roster Java_w16 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
}' '{"90011": ["Java_w16_0"]}'

# w17: import with filename (including _0)
run_rule w17 "90012" 'Rule ImportFileName extends AbstractTaintRule {
    import roster Java_w17_0;
    type = "Test";
    subType = "TestRule";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "Java_w17_0.ros" 'Roster Java_w17 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
}' '{"90012": ["Java_w17_0"]}'

# w18: Relation-only linking: Rule has ONLY type+subType, Roster has source+sink
# Does Roster source/sink auto-apply?
run_rule w18 "90013" 'Rule EmptyRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w18_0.ros" 'Roster Java_w18 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90013": ["Java_w18_0"]}'

# w19: Relation uses declaration name (no _0) — does it work?
run_rule w19 "90014" 'Rule RelDeclName extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w19_0.ros" 'Roster Java_w19 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90014": ["Java_w19"]}'

# w20: Relation uses declaration name with _0 suffix matching filename
run_rule w20 "90015" 'Rule RelFileName extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w20_0.ros" 'Roster Java_w20 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90015": ["Java_w20_0"]}'

# w21: Rule with source inline + Roster with additional source via relation
# Test if both Rule's inline and Roster's source co-exist
run_rule w21 "90016" 'Rule InlineAndRoster extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += { precise = true; value = "com.example.InlineSource.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "Java_w21_0.ros" 'Roster Java_w21 {
    source.methodReturn += { precise = true; value = "com.example.RosterSource.get"; };
}' '{"90016": ["Java_w21_0"]}'

echo ""
echo "====== All experiments done ======"
