import bandit
from bandit.core import issue
from bandit.core import test_properties as test


@test.checks("Assert")
@test.test_id("B950")
def canonical_assert_rule(context):
    return bandit.Issue(
        severity=bandit.HIGH,
        confidence=bandit.HIGH,
        cwe=issue.Cwe.IMPROPER_CHECK_OF_EXCEPT_COND,
        text="Canonical validation rule: assert must not be used.",
    )
