# CodeQL 指令清单（HelloWorld）

- `codeql database create`（创建数据库 `HelloWorld-db`）

```bash
codeql database create /home/nyn/Desktop/Projects/Java/Java-learning/ql/db/HelloWorld-db \
  --overwrite \
  --language=java \
  --source-root /home/nyn/Desktop/Projects/Java/Java-learning/src \
  --command "javac /home/nyn/Desktop/Projects/Java/Java-learning/src/HelloWorld.java"
```

```bash
codeql database create /home/nyn/Desktop/Projects/Java/Java-learning/ql/db/codeql-ast-demo-db \
  --overwrite \
  --language=java \
  --source-root /home/nyn/Desktop/Projects/Java/Java-learning/src/codeql-ast-demo \
  --command "mvn -q -DskipTests clean compile"
```

- `codeql database analyze`（用 `find-addexpr.ql` 分析并导出结果）

```bash
codeql database analyze /home/nyn/Desktop/Projects/Java/Java-learning/ql/db/HelloWorld-db \
  /home/nyn/Desktop/Projects/Java/Java-learning/ql/packs/addexpr-pack/find-addexpr.ql \
  --format=sarif-latest \
  --output /home/nyn/Desktop/Projects/Java/Java-learning/ql/result/helloworld.sarif
```
