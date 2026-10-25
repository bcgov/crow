"""Check that the SARIF oracle rejects silent misses and extra findings."""

from copy import deepcopy
import unittest

from test_codeql import check_results


class SarifOracleTests(unittest.TestCase):
    """Exercise successful, incomplete, and failed analyzer reports."""

    def setUp(self):
        self.expected = {"rule_id": "test/rule", "file": "app/views.py", "lines": [6]}
        self.report = {"runs": [{
            "invocations": [{"executionSuccessful": True}],
            "results": [{
                "ruleId": "test/rule",
                "locations": [{"physicalLocation": {
                    "artifactLocation": {"uri": "app/views.py"},
                    "region": {"startLine": 6},
                }}],
            }],
        }]}

    def test_exact_results_pass(self):
        check_results(self.report, self.expected)

    def test_missing_finding_fails(self):
        self.report["runs"][0]["results"] = []
        with self.assertRaises(ValueError):
            check_results(self.report, self.expected)

    def test_extra_finding_fails(self):
        extra = deepcopy(self.report["runs"][0]["results"][0])
        extra["locations"][0]["physicalLocation"]["region"]["startLine"] = 26
        self.report["runs"][0]["results"].append(extra)
        with self.assertRaises(ValueError):
            check_results(self.report, self.expected)

    def test_failed_analysis_fails(self):
        self.report["runs"][0]["invocations"][0]["executionSuccessful"] = False
        with self.assertRaises(ValueError):
            check_results(self.report, self.expected)

    def test_empty_report_fails(self):
        with self.assertRaises(ValueError):
            check_results({"runs": []}, self.expected)


if __name__ == "__main__":
    unittest.main()
