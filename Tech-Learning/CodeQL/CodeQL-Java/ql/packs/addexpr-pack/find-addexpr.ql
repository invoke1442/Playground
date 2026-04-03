/**
 * @name Extract all AddExpr
 * @description Retrieves all Java AddExpr nodes ("+") in the analyzed code.
 * @kind problem
 * @id java-learning/extract-all-addexpr
 * @tags analysis
 * @problem.severity warning
 * @precision medium
 */

import java

from ExprStmt exprstmt
select exprstmt, "Found ExprStmt: " + exprstmt.toString()
