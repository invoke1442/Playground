#!/bin/bash
# Match capability experiments: what literal types can Ali DSL match?
set -uo pipefail
VERIFY="../alibaba-dsl-skill/alibaba-dsl-skill/scripts/verify.sh"
RESULTS_DIR="experiments/results"
mkdir -p "$RESULTS_DIR"

run_rule() {
  local id="$1" name="$2" dir="$3"
  echo "=== $name (rule $id) ==="
  RESP=$(bash "$VERIFY" rule java "$id" "$dir" 2>/dev/null)
  echo "$RESP" > "$RESULTS_DIR/${name}.json"
  # Check pass/fail
  CODE=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code','?'))" 2>/dev/null || echo "?")
  if [[ "$CODE" == "0" ]]; then
    OUTPUT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('output',''))" 2>/dev/null || echo "")
    if [[ "$OUTPUT" == "[]" || "$OUTPUT" == "" ]]; then
      echo "  ✅ PASS"
    else
      echo "  ❌ FAIL: $OUTPUT"
    fi
  else
    echo "  ❌ API ERROR (code=$CODE): $RESP"
  fi
  echo ""
}

run_roster() {
  local name="$1" rname="$2" dir="$3"
  echo "=== $name (roster $rname) ==="
  RESP=$(bash "$VERIFY" roster java "$rname" "$dir" 2>/dev/null)
  echo "$RESP" > "$RESULTS_DIR/${name}.json"
  CODE=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('code','?'))" 2>/dev/null || echo "?")
  if [[ "$CODE" == "0" ]]; then
    OUTPUT=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('output',''))" 2>/dev/null || echo "")
    if [[ "$OUTPUT" == "[]" || "$OUTPUT" == "" ]]; then
      echo "  ✅ PASS"
    else
      echo "  ❌ FAIL: $OUTPUT"
    fi
  else
    echo "  ❌ API ERROR (code=$CODE): $RESP"
  fi
  echo ""
}

# ========================================================
# EXPERIMENT SERIES: match01-match20
# Goal: verify what literal types each field can match
# ========================================================

# --- match01: source.methodReturn matches FQN ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters"
cat > "$DIR/40001.rul" << 'EOF'
Rule MatchTest01 extends AbstractTaintRule {
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
run_rule 40001 match01_source_methodReturn_FQN "$DIR"
rm -rf "$DIR"

# --- match02: source.methodReturn matches regex pattern ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters"
cat > "$DIR/40002.rul" << 'EOF'
Rule MatchTest02 extends AbstractTaintRule {
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = false; value = "getParameter|getHeader|getCookies"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
run_rule 40002 match02_source_methodReturn_regex "$DIR"
rm -rf "$DIR"

# --- match03: sink.methodArg with param JSON (matching parameter position) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match03_roster_0.ros" << 'EOF'
Roster Match03_roster {
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
        param = "[{'position':0,'tainted':true}]";
    };
}
EOF
cat > "$DIR/40003.rul" << 'EOF'
Rule MatchTest03 extends AbstractTaintRule {
    import roster Match03_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
}
EOF
echo '{"40003":["Match03_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40003 match03_sink_param_JSON "$DIR"
rm -rf "$DIR"

# --- match04: sanitizer.safeTypes (matching type/class name) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match04_roster_0.ros" << 'EOF'
Roster Match04_roster {
    sanitizer.safeTypes += {
        precise = true;
        value = "java.net.URL|java.io.File";
    };
}
EOF
cat > "$DIR/40004.rul" << 'EOF'
Rule MatchTest04 extends AbstractTaintRule {
    import roster Match04_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40004":["Match04_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40004 match04_sanitizer_safeTypes "$DIR"
rm -rf "$DIR"

# --- match05: sanitizer.safeVarNames (matching variable name pattern) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match05_roster_0.ros" << 'EOF'
Roster Match05_roster {
    sanitizer.safeVarNames += {
        value = "(?i)safe.*|clean.*|escaped.*";
    };
}
EOF
cat > "$DIR/40005.rul" << 'EOF'
Rule MatchTest05 extends AbstractTaintRule {
    import roster Match05_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40005":["Match05_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40005 match05_sanitizer_safeVarNames "$DIR"
rm -rf "$DIR"

# --- match06: source.param_annotation (matching annotation FQN) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match06_roster_0.ros" << 'EOF'
Roster Match06_roster {
    source.param_annotation = "org.springframework.web.bind.annotation.RequestParam";
}
EOF
cat > "$DIR/40006.rul" << 'EOF'
Rule MatchTest06 extends AbstractTaintRule {
    import roster Match06_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40006":["Match06_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40006 match06_source_param_annotation "$DIR"
rm -rf "$DIR"

# --- match07: source.method_annotation (matching method annotation FQN) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match07_roster_0.ros" << 'EOF'
Roster Match07_roster {
    source.method_annotation = "org.springframework.web.bind.annotation.GetMapping";
}
EOF
cat > "$DIR/40007.rul" << 'EOF'
Rule MatchTest07 extends AbstractTaintRule {
    import roster Match07_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40007":["Match07_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40007 match07_source_method_annotation "$DIR"
rm -rf "$DIR"

# --- match08: source.method_param (matching method+param index) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match08_roster_0.ros" << 'EOF'
Roster Match08_roster {
    source.method_param = "com.example.Controller.handleRequest[0]";
}
EOF
cat > "$DIR/40008.rul" << 'EOF'
Rule MatchTest08 extends AbstractTaintRule {
    import roster Match08_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40008":["Match08_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40008 match08_source_method_param "$DIR"
rm -rf "$DIR"

# --- match09: propagate.methodObjectToReturn (method name matching) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match09_roster_0.ros" << 'EOF'
Roster Match09_roster {
    propagate.methodObjectToReturn += {
        value = "append|concat|toString|replaceAll";
    };
}
EOF
cat > "$DIR/40009.rul" << 'EOF'
Rule MatchTest09 extends AbstractTaintRule {
    import roster Match09_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40009":["Match09_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40009 match09_propagate_methodObjectToReturn "$DIR"
rm -rf "$DIR"

# --- match10: propagate.customMethodPropagate with from/to ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match10_roster_0.ros" << 'EOF'
Roster Match10_roster {
    propagate.customMethodPropagate += {
        value = "java.lang.String.join";
        from = "1";
        to = "return";
    };
}
EOF
cat > "$DIR/40010.rul" << 'EOF'
Rule MatchTest10 extends AbstractTaintRule {
    import roster Match10_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40010":["Match10_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40010 match10_propagate_customMethodPropagate "$DIR"
rm -rf "$DIR"

# --- match11: propagate.vmContext (Velocity template context matching) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match11_roster_0.ros" << 'EOF'
Roster Match11_roster {
    propagate.vmContext += {
        precise = true;
        value = "com.alibaba.citrus.turbine.Context.put|javax.servlet.http.HttpServletRequest.setAttribute";
    };
}
EOF
cat > "$DIR/40011.rul" << 'EOF'
Rule MatchTest11 extends AbstractTaintRule {
    import roster Match11_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40011":["Match11_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40011 match11_propagate_vmContext "$DIR"
rm -rf "$DIR"

# --- match12: propagate boolean fields ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match12_roster_0.ros" << 'EOF'
Roster Match12_roster {
    propagate.bAllPublicMethod += { value = true; };
    propagate.bTaintedStart += { value = true; };
    propagate.bUnkownAsSafe += { value = false; };
}
EOF
cat > "$DIR/40012.rul" << 'EOF'
Rule MatchTest12 extends AbstractTaintRule {
    import roster Match12_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40012":["Match12_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40012 match12_propagate_booleans "$DIR"
rm -rf "$DIR"

# --- match13: general.entranceFileXpath (xpath matching) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match13_roster_0.ros" << 'EOF'
Roster Match13_roster {
    general.entranceFileXpath = "//CompilationUnit[.//MarkerAnnotation/Name[@Image='Controller']]";
}
EOF
cat > "$DIR/40013.rul" << 'EOF'
Rule MatchTest13 extends AbstractTaintRule {
    import roster Match13_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40013":["Match13_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40013 match13_general_entranceFileXpath "$DIR"
rm -rf "$DIR"

# --- match14: general.scanAllFiles + general.taintOnlyBySummary ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match14_roster_0.ros" << 'EOF'
Roster Match14_roster {
    general.scanAllFiles = true;
    general.taintOnlyBySummary = true;
    general.handlePolymorphism = true;
    general.polyHandleNum = 1;
}
EOF
cat > "$DIR/40014.rul" << 'EOF'
Rule MatchTest14 extends AbstractTaintRule {
    import roster Match14_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40014":["Match14_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40014 match14_general_booleans_int "$DIR"
rm -rf "$DIR"

# --- match15: propagate.noTaintNoSourceFile (regex matching file/method patterns) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match15_roster_0.ros" << 'EOF'
Roster Match15_roster {
    propagate.noTaintNoSourceFile += {
        value = "(?i)select|(?i)query|(?i)dao.*|\\binsert|\\bfind|\\bupdate";
    };
}
EOF
cat > "$DIR/40015.rul" << 'EOF'
Rule MatchTest15 extends AbstractTaintRule {
    import roster Match15_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40015":["Match15_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40015 match15_propagate_noTaintNoSourceFile "$DIR"
rm -rf "$DIR"

# --- match16: source.paramAnnotation (camelCase, block syntax) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match16_roster_0.ros" << 'EOF'
Roster Match16_roster {
    source.paramAnnotation += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestParam";
    };
}
EOF
cat > "$DIR/40016.rul" << 'EOF'
Rule MatchTest16 extends AbstractTaintRule {
    import roster Match16_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40016":["Match16_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40016 match16_source_paramAnnotation_camelCase "$DIR"
rm -rf "$DIR"

# --- match17: source.methodParam (camelCase with xpath - matching param by xpath) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match17_roster_0.ros" << 'EOF'
Roster Match17_roster {
    source.methodParam += {
        xpath = "//FormalParameter[.//Type/ReferenceType/ClassOrInterfaceType[@Image='String']]";
        tag = "stringParam";
    };
}
EOF
cat > "$DIR/40017.rul" << 'EOF'
Rule MatchTest17 extends AbstractTaintRule {
    import roster Match17_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40017":["Match17_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40017 match17_source_methodParam_xpath "$DIR"
rm -rf "$DIR"

# --- match18: source.mvcMapping (annotation-based source with flag) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match18_roster_0.ros" << 'EOF'
Roster Match18_roster {
    source.mvcMapping += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestMapping";
        flag = "webSource";
    };
}
EOF
cat > "$DIR/40018.rul" << 'EOF'
Rule MatchTest18 extends AbstractTaintRule {
    import roster Match18_roster;
    type = "Test"; subType = "MatchTest";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
EOF
echo '{"40018":["Match18_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40018 match18_source_mvcMapping "$DIR"
rm -rf "$DIR"

# --- match19: sink.allocArg (constructor argument matching) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match19_roster_0.ros" << 'EOF'
Roster Match19_roster {
    sink.allocArg += {
        precise = true;
        value = "java.io.FileOutputStream";
    };
}
EOF
cat > "$DIR/40019.rul" << 'EOF'
Rule MatchTest19 extends AbstractTaintRule {
    import roster Match19_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
}
EOF
echo '{"40019":["Match19_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40019 match19_sink_allocArg "$DIR"
rm -rf "$DIR"

# --- match20: sink.methodObject (method receiver object matching) ---
DIR=$(mktemp -d)
mkdir -p "$DIR/rosters" "$DIR/relation"
cat > "$DIR/rosters/Match20_roster_0.ros" << 'EOF'
Roster Match20_roster {
    sink.methodObject += {
        precise = true;
        value = "java.io.ObjectInputStream.readObject";
    };
}
EOF
cat > "$DIR/40020.rul" << 'EOF'
Rule MatchTest20 extends AbstractTaintRule {
    import roster Match20_roster;
    type = "Test"; subType = "MatchTest";
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
}
EOF
echo '{"40020":["Match20_roster_0"]}' > "$DIR/relation/config_roster_relation.json"
run_rule 40020 match20_sink_methodObject "$DIR"
rm -rf "$DIR"

echo "===== ALL EXPERIMENTS COMPLETE ====="
