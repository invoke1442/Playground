#!/bin/bash
# Matching capability experiments — what literals can Ali DSL match?
set -uo pipefail

VERIFY="../../../alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="results"
mkdir -p "$RESULTS_DIR"

run_rule() {
    local id="$1" lang="$2" desc="$3"
    echo "=== $id: $desc ==="
    local resp
    resp=$(bash "$VERIFY" rule "$lang" "$id" "config-$id" 2>&1)
    echo "$resp" > "$RESULTS_DIR/$id.txt"
    if echo "$resp" | grep -q "✅"; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL"
        echo "$resp" | tail -3
    fi
    echo ""
}

run_roster() {
    local name="$1" lang="$2" desc="$3"
    echo "=== $name: $desc ==="
    local resp
    resp=$(bash "$VERIFY" roster "$lang" "$name" "config-$name" 2>&1)
    echo "$resp" > "$RESULTS_DIR/$name.txt"
    if echo "$resp" | grep -q "✅"; then
        echo "  ✅ PASS"
    else
        echo "  ❌ FAIL"
        echo "$resp" | tail -3
    fi
    echo ""
}

echo "=========================================="
echo "Matching Capability Experiments"
echo "=========================================="
echo ""

# --- m01: sanitizer.safeVarNames (match variable/parameter names) ---
run_roster "m01_safeVarNames_0" java "sanitizer.safeVarNames — 匹配变量名"

# --- m02: sanitizer.safeTypes (match type names) ---
run_roster "m02_safeTypes_0" java "sanitizer.safeTypes — 匹配类型名"

# --- m03: propagate.methodObjectToReturn (real propagate field) ---
run_roster "m03_propagate_0" java "propagate.methodObjectToReturn — 真实propagate字段"

# --- m04: propagate.customMethodPropagate with from/to ---
run_roster "m04_customPropagate_0" java "propagate.customMethodPropagate — from/to传播"

# --- m05: source.paramAnnotation (camelCase, block syntax) ---
run_roster "m05_paramAnnotation_0" java "source.paramAnnotation(camelCase) — block语法"

# --- m06: general.userDefinePatternClass with loadclass ---
run_rule "40006" java "general.userDefinePatternClass + loadclass"

# --- m07: sink.methodArg with param JSON field ---
run_roster "m07_sinkParam_0" java "sink.methodArg + param JSON — 参数位置匹配"

# --- m08: propagate.vmContext ---
run_roster "m08_vmContext_0" java "propagate.vmContext — 模板上下文传播"

# --- m09: propagate.noTaintNoSourceFile (regex matching file/method patterns) ---
run_roster "m09_noTaint_0" java "propagate.noTaintNoSourceFile — 方法名正则过滤"

# --- m10: sanitizer.methodObject (method receiver matching) ---
run_roster "m10_methodObject_0" java "sanitizer.methodObject — 方法接收者匹配"

# --- m11: multiple propagate boolean fields ---
run_roster "m11_propagateBool_0" java "propagate boolean fields — 布尔控制字段"

# --- m12: general.entranceFileXpath (xpath matching) ---
run_roster "m12_xpath_0" java "general.entranceFileXpath — XPath匹配"

# --- m13: sink.allocArg (constructor argument matching) ---
run_roster "m13_allocArg_0" java "sink.allocArg — 构造器参数匹配"

# --- m14: propagate.xxeType + xxeMethod ---
run_roster "m14_xxePropagate_0" java "propagate.xxeType + xxeMethod"

# --- m15: source.methodParam with xpath (camelCase) ---
run_roster "m15_methodParam_0" java "source.methodParam(camelCase) — xpath匹配"

echo "=========================================="
echo "Done! Results in $RESULTS_DIR/"
echo "=========================================="
