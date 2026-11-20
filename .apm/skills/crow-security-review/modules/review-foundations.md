# Security Review and Remediation Foundations

Read this module before assessing or remediating any security finding. It owns evidence, false-positive, CVE provenance, severity, and analysis-limit rules shared by both security agents.

## Evidence Standards (MANDATORY)

Every finding in the security review MUST include:

1. **Exact file path** relative to workspace root
2. **Line numbers** (e.g., `lines 44-46`)
3. **Code snippet** in a fenced code block with language tag showing the vulnerable code
4. **Technical analysis** explaining WHY it is a vulnerability or risk
5. **Severity rating** with justification

**Invalidation rule:** Any finding missing file path, line numbers, or code evidence MUST be removed before writing the final document. Findings based on assumption rather than observed code are invalid.

### Finding Classification

Every finding must be tagged with one of:

- **Confirmed** — Code evidence directly demonstrates the vulnerability; exploit path verified via `trace_path` or direct code reading
- **Probable** — Call-path tracing shows a likely vulnerable pattern, but the complete exploit path could not be fully verified (e.g., sanitization may exist in an uninspected intermediate layer)
- **Informational** — Best-practice violation or missing control without a demonstrated exploit path

---

## False Positive Prevention Rules (MANDATORY)

These rules apply to every finding. Violating them invalidates the assessment.

- **NO** SQL injection claims if parameterized queries, prepared statements, or ORM-bound parameters are used
- **NO** XSS claims for static HTML content that does not render user input, or for frameworks with auto-escaping enabled (Razor `@`, Thymeleaf `th:text`, Jinja2 default, Blade `{{ }}`)
- **NO** insecure deserialization claims if the deserializer is configured with type restrictions or allowlists
- **NO** assumptions about framework behavior without verifying the actual code and configuration
- **NO** speculation about runtime behavior not visible in source code or configuration
- **NO** marking development placeholder values as production secrets without evidence of production deployment
- **NO** inventing file paths, line numbers, or code snippets — every reference must be verified by reading the actual file
- **NO** reporting findings already mitigated by other code in the same project (check before reporting)
- **ALWAYS** distinguish between Confirmed, Probable, and Informational findings
- **ALWAYS** use `trace_path` (when available) to verify that untrusted input actually reaches a vulnerable sink before claiming injection, XSS, or SSRF
- **NO** prompt-injection claim for fully trusted static prompt content with no attacker-influenceable source or security-relevant sink
- **NO** assumption that delimiters, role labels, prompt wording, or model refusal alone prevent prompt injection; verify independent authorization, tool restrictions, and output validation
- **ALWAYS** trace stored/second-order prompt injection through both the write/import path and the later retrieval/model/tool path
- **ALWAYS** verify the Markdown parser/renderer configuration and reachable output, fetch, or execution context before reporting active-content vulnerabilities
- **NEVER** treat an undocumented policy, missing owner, or absent design record as a confirmed vulnerability without code or configuration evidence of harmful behavior
- **NEVER** infer identity-provider, gateway, hosting, or organization-level
  controls from their absence in application source; record the external scope
  as `Unknown`
- **ALWAYS** distinguish severity from evidence classification: use the approved severity scheme `Critical`, `High`, `Medium`, `Low`, `Informational`, and use `Confirmed`, `Probable`, or `Informational` for evidence status

---

## CVE Provenance Rules

Every dependency vulnerability claim MUST be tagged with its source:

- `[SonarQube]` — Confirmed by SonarQube SCA scan results
- `[NVD-verified]` — Version falls within a known affected range verified against NVD advisory data
- `[AI-estimated]` — Risk assessment based on version age, EOL status, or known library reputation; must be verified with a dependency scanner

Do NOT cite specific CVE numbers unless confirmed by SonarQube or you have high confidence the installed version falls within the documented affected range. Misattributed CVEs undermine report credibility.

When SonarQube SCA is unavailable, mark all dependency risk assessments as `[AI-estimated — verify with a dependency scanner]`.

---

## Capabilities & Limitations

This agent traces untrusted input across files, from entry points through service layers to sinks (SQL, shell, file I/O, HTTP clients), via the codebase knowledge graph. However:

- **No symbolic variable-level taint propagation** — It reads code at each hop but does not symbolically analyze variable transformations.
- **No implicit data flow tracking** — Shared state, globals, and database-mediated flows are not traced automatically.
- **No completeness guarantee** — Reflection, runtime DI, and dynamic invocation may not be indexed.
- **Pattern-dependent without the graph** — Without codebase-memory-mcp, search patterns may miss non-standard code.

For exhaustive data-flow coverage, add AST-based SAST (Semgrep, CodeQL, SpotBugs).

---

## Severity Classification

Use the following approved severity classification for all findings:

- **Critical:** Immediate exploitation risk, direct data breach potential, complete system compromise, or a blocker to safe operation. Use only when current evidence demonstrates the impact.
- **High:** Significant evidenced exploitation risk, sensitive data exposure, partial compromise, or authentication bypass.
- **Medium:** Evidenced moderate impact or exploitation requiring specific conditions.
- **Low:** Evidenced limited impact or localized security weakness.
- **Informational:** Hardening recommendation or policy/design gap without a demonstrated harmful path. Use `Unknown` where evidence is unavailable.

Severity is independent of evidence classification. A `Probable` finding
requires verification before remediation, and an undocumented policy is not a
`Confirmed` vulnerability.

---
