#!/bin/bash
# w-series Part 2: Fix Roster verification (strip .ros) + modifiable tests
set -euo pipefail

VERIFY_SH="/home/nyn/Desktop/Projects/Agents/playground/Skills/tech-learning/workspace/alibaba-dsl-learning/alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="/tmp/w-results2"
mkdir -p "$RESULTS_DIR"

run_roster() {
    local name="$1" roster_name="$2" rosfilename="$3" roscontent="$4"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters"
    echo "$roscontent" > "$D/rosters/${rosfilename}"
    bash "$VERIFY_SH" roster java "$roster_name" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:400] if o else 'PASS')" 2>&1)
    echo "[$name] $out"
}

run_rule() {
    local name="$1" ruleid="$2" rulcontent="$3" rosfilename="$4" roscontent="$5" relcontent="$6"
    local D=$(mktemp -d)
    mkdir -p "$D/rosters" "$D/relation"
    echo "$rulcontent" > "$D/${ruleid}.rul"
    if [[ -n "$rosfilename" ]]; then
        echo "$roscontent" > "$D/rosters/${rosfilename}"
    fi
    if [[ -n "$relcontent" ]]; then
        echo "$relcontent" > "$D/relation/config_roster_relation.json"
    fi
    bash "$VERIFY_SH" rule java "$ruleid" "$D" > "$RESULTS_DIR/${name}.json" 2>&1 || true
    rm -rf "$D"
    local out=$(head -1 "$RESULTS_DIR/${name}.json" | python3 -c "import sys,json;d=json.load(sys.stdin);o=d.get('data',{}).get('output','');print(o[:400] if o else 'PASS')" 2>&1)
    echo "[$name] $out"
}

echo "====== Part 1: Roster sub-fields (fixed roster_name) ======"

# source.param_annotation
echo "--- source.param_annotation ---"
run_roster w01b "Java_w01_0" "Java_w01_0.ros" 'Roster Java_w01 {
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
}'
run_roster w02b "Java_w02_0" "Java_w02_0.ros" 'Roster Java_w02 {
    source.param_annotation += "org.springframework.web.bind.annotation.RequestParam";
}'

# source.method_annotation  
echo "--- source.method_annotation ---"
run_roster w03b "Java_w03_0" "Java_w03_0.ros" 'Roster Java_w03 {
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
}'
run_roster w04b "Java_w04_0" "Java_w04_0.ros" 'Roster Java_w04 {
    source.method_annotation += "org.springframework.web.bind.annotation.GetMapping";
}'

# source.method_param
echo "--- source.method_param ---"
run_roster w05b "Java_w05_0" "Java_w05_0.ros" 'Roster Java_w05 {
    source.method_param = "com.example.Controller.handleRequest[0]";
}'
run_roster w06b "Java_w06_0" "Java_w06_0.ros" 'Roster Java_w06 {
    source.method_param += "com.example.Controller.handleRequest[0]";
}'
run_roster w07b "Java_w07_0" "Java_w07_0.ros" 'Roster Java_w07 {
    source.method_param += {
        xpath = "//MethodDeclaration[@MethodName=\"handleRequest\"]/FormalParameters/FormalParameter[0]";
        tag = "userInput";
    };
}'

# source.expression
echo "--- source.expression ---"
run_roster w08b "Java_w08_0" "Java_w08_0.ros" 'Roster Java_w08 {
    source.expression = "com.example.Config.getProperty";
}'
run_roster w09b "Java_w09_0" "Java_w09_0.ros" 'Roster Java_w09 {
    source.expression += "com.example.Config.getProperty";
}'
run_roster w10b "Java_w10_0" "Java_w10_0.ros" 'Roster Java_w10 {
    source.expression += {
        precise = true;
        value = "com.example.Config.getProperty";
    };
}'

echo ""
echo "====== Part 2: Rule with modifiable + sub-fields ======"
echo "--- Rule with modifiable source.param_annotation ---"
run_rule w22 "90022" 'Rule ModParamAnn extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    modifiable source.param_annotation;
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

echo "--- Rule with modifiable source.method_annotation ---"
run_rule w23 "90023" 'Rule ModMethodAnn extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    modifiable source.method_annotation;
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

echo "--- Rule with modifiable source.expression ---"
run_rule w24 "90024" 'Rule ModExpr extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    modifiable source.expression;
    source.expression = "com.example.Config.getProperty";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

echo "--- Rule with modifiable source.method_param ---"
run_rule w25 "90025" 'Rule ModMethodParam extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    modifiable source.method_param;
    source.method_param = "com.example.Controller.handleRequest[0]";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' "" "" ""

echo ""
echo "====== Part 3: Roster sub-fields via relation (Rule verify) ======"
# Test if these sub-fields work when placed in Roster and linked via relation
echo "--- Roster with param_annotation via relation ---"
run_rule w26 "90026" 'Rule RosParamAnn extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w26_0.ros" 'Roster Java_w26 {
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90026": ["Java_w26_0"]}'

echo "--- Roster with method_annotation via relation ---"
run_rule w27 "90027" 'Rule RosMethodAnn extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w27_0.ros" 'Roster Java_w27 {
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90027": ["Java_w27_0"]}'

echo "--- Roster with expression via relation ---"
run_rule w28 "90028" 'Rule RosExpr extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w28_0.ros" 'Roster Java_w28 {
    source.expression = "com.example.Config.getProperty";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90028": ["Java_w28_0"]}'

echo "--- Roster with method_param via relation ---"
run_rule w29 "90029" 'Rule RosMethodParam extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w29_0.ros" 'Roster Java_w29 {
    source.method_param = "com.example.Controller.handleRequest[0]";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90029": ["Java_w29_0"]}'

echo ""
echo "====== Part 4: Clarify relation naming ======"
# w30: relation references declaration name (no _0), file is Name_0.ros  
echo "--- w30: relation=[\"Java_w30\"] file=Java_w30_0.ros ---"
run_rule w30 "90030" 'Rule RelNaming extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w30_0.ros" 'Roster Java_w30 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90030": ["Java_w30"]}'

# w31: relation references [Name_0] file=Name_0.ros
echo "--- w31: relation=[\"Java_w31_0\"] file=Java_w31_0.ros ---"
run_rule w31 "90031" 'Rule RelNaming2 extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w31_0.ros" 'Roster Java_w31 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90031": ["Java_w31_0"]}'

# w32: relation references [bogus_name] — should fail
echo "--- w32: relation=[\"Bogus_name\"] file=Java_w32_0.ros ---"
run_rule w32 "90032" 'Rule RelBogus extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w32_0.ros" 'Roster Java_w32 {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90032": ["Bogus_name"]}'

# w33: Roster file=Name_0.ros but declaration=Roster Something_Different
echo "--- w33: relation=[\"Java_w33_0\"] file=Java_w33_0.ros decl=SomethingElse ---"
run_rule w33 "90033" 'Rule DeclMismatch extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}' "Java_w33_0.ros" 'Roster SomethingElse {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}' '{"90033": ["Java_w33_0"]}'

echo ""
echo "====== All done ======"
