"""Run query regressions against fixture databases and compare SARIF sink locations.

Requires CodeQL CLI and access to its query-pack registry (or cached packs).
Databases, copied packs, lockfiles, and reports stay in a temporary directory.
"""

import argparse
from collections import Counter
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import unquote, urlparse


SKILL_ROOT = Path(__file__).resolve().parent.parent


def check_results(report, expected):
    """Reject missing findings, extra findings, and analyzer errors."""
    runs = report.get("runs", [])
    if not runs:
        raise ValueError("SARIF contains no analysis runs")
    actual = Counter()
    for run in runs:
        for invocation in run.get("invocations", []):
            if invocation.get("executionSuccessful") is False:
                raise ValueError("CodeQL analysis did not complete successfully")
            for notification in invocation.get("toolExecutionNotifications", []):
                if notification.get("level") == "error":
                    raise ValueError("CodeQL reported an analysis error")
        for result in run.get("results", []):
            for location in result["locations"]:
                physical = location["physicalLocation"]
                uri = physical["artifactLocation"]["uri"]
                path = unquote(urlparse(uri).path).replace("\\", "/")
                actual[(result["ruleId"], path, physical["region"]["startLine"])] += 1
    wanted = Counter((expected["rule_id"], expected["file"], line)
                     for line in expected["lines"])
    if actual != wanted:
        raise ValueError(f"Unexpected sink locations: expected {wanted}, got {actual}")


def run_case(codeql, case, work):
    """Extract a fixture, analyze its query, and assert the complete result set."""
    language = case["language"]
    pack = work / language / "pack"
    shutil.copytree(SKILL_ROOT / "references/rules/codeql" / language, pack)
    database = work / language / "db"
    report = work / language / "results.sarif"
    commands = [
        [codeql, "pack", "install", str(pack)],
        [codeql, "database", "create", str(database), f"--language={language}",
         f"--source-root={SKILL_ROOT / case['fixture']}"],
        [codeql, "database", "analyze", str(database), str(pack / case["query"]),
         "--format=sarif-latest", f"--output={report}"],
    ]
    for command in commands:
        subprocess.run(command, check=True)
    check_results(json.loads(report.read_text(encoding="utf-8")), case)
    print(f"Passed: {case['query']}")


def main():
    """Run all cases; a missing CLI or any failed case exits unsuccessfully."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codeql", default="codeql", help="CodeQL executable")
    args = parser.parse_args()
    codeql = shutil.which(args.codeql)
    if codeql is None:
        parser.error(f"CodeQL executable not found: {args.codeql}")
    cases = json.loads((SKILL_ROOT / "evals/codeql-cases.json").read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="crow-codeql-") as directory:
        for case in cases:
            run_case(codeql, case, Path(directory))


if __name__ == "__main__":
    main()
