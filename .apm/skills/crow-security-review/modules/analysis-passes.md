# Security Analysis Passes

Load for a full security review after repository/service scope and attack-surface coverage are established. Apply Passes A-F and H to the service under review, marking inapplicable domains with evidence. Apply Pass G only to the LLM, agent, and Markdown surfaces described below. Select detection modules through the skill router; do not read every technology module.

## Pass A: OWASP Top 10 (2025) Analysis
Systematically evaluate each OWASP Top 10 category against the codebase:
- **A01 — Broken Access Control:** Missing/bypassable authorization, IDOR, path traversal, CORS misconfigurations, privilege escalation, SSRF, DNS rebinding, webhook exposure.
- **A02 — Security Misconfiguration:** Default credentials, verbose errors, unnecessary features, missing security headers, open cloud storage, debug modes in production.
- **A03 — Software Supply Chain Failures:** Vulnerable dependencies, outdated frameworks, EOL components, missing lockfiles, dependency confusion, typosquatting, unsigned build tools, missing SBOM.
- **A04 — Cryptographic Failures:** Weak algorithms (MD5, SHA1, DES, RC4), hardcoded keys, insufficient key lengths, insecure RNG, missing TLS enforcement, plaintext transmission.
- **A05 — Injection:** SQL, NoSQL, command, LDAP, XPath, template, expression language, and ORM injection vectors.
- **LLM-specific risks:** Direct and indirect prompt injection, stored/second-order injection, sensitive information disclosure, improper model-output handling, excessive agency, vector/embedding weaknesses, and unbounded consumption.
- **A06 — Insecure Design:** Missing security design patterns, lack of threat modeling, insecure business logic, missing rate limiting.
- **A07 — Authentication Failures:** Weak password policies, missing MFA, session fixation, credential stuffing, account enumeration, JWT flaws.
- **A08 — Software or Data Integrity Failures:** Insecure deserialization, missing code signing, CI/CD pipeline injection, TOFU issues.
- **A09 — Security Logging & Alerting Failures:** Missing security event logging, insufficient forensic detail, sensitive data in logs, no log integrity protection, logging without alerting.
- **A10 — Mishandling of Exceptional Conditions:** Exception handlers exposing stack traces, failing open on errors, DoS through unhandled exceptions, swallowed exceptions masking security failures.

## Pass B: Secure Coding Practices
- **Input Validation & Output Encoding:** Validate all inputs at trust boundaries, allowlists over denylists, type/length/format/range validation, context-aware output encoding (HTML, JS, URL, SQL parameterization).
- **Cryptography Implementation:** Industry-standard algorithms (AES-256, RSA-2048+, ECDSA), secure key storage (HSM/KMS/vault), correct IV/nonce usage, authenticated encryption (GCM, Poly1305).
- **Secrets Management:** No hardcoded secrets in source, environment variable or vault usage, rotation mechanisms, secret detection in logs.
- **Session Handling:** Secure session ID generation, timeouts, invalidation on logout, session fixation prevention, secure cookie attributes (HttpOnly, Secure, SameSite).
- **API Security:** Authentication on all endpoints, rate limiting, input validation on API parameters, proper HTTP method usage.

## Pass C: Architecture Security Assessment
- **Trust Boundary Analysis:** Identify all trust boundaries, map data flows across boundaries, validate cross-boundary data, document trust assumptions and implicit trust relationships.
- **Attack Surface Assessment:** Enumerate public endpoints, exposed services/ports, authentication requirements, data exposure points, third-party integrations.
- **Privilege Escalation Analysis:** Identify privilege boundaries, map role/permission structures, check for elevation paths, assess admin functionality exposure, review service account permissions.
- **Data Flow Security:** Map sensitive data flows, identify encryption points, assess data retention, review data minimization and sanitization.
- **Platform data and proofs (when applicable):** Verify over-fetching, purpose/subject/audience scope, pairwise correlation risk, proof audience/expiry/revocation/replay resistance/minimal disclosure, assurance levels and safe downgrade/fallback, and audit context where observable. Record missing policy as `Unknown` or `Informational` unless harmful behavior is evidenced.

## Pass D: Supply Chain Security
- **Dependency Analysis:** Scan for known vulnerabilities, check for outdated packages, verify dependency integrity, assess maintainer trustworthiness, review dependency trees for anomalies.
- **Lockfile Security:** Verify lockfile presence and integrity, assess lockfile update practices, review dependency resolution.
- **Dependency Confusion:** Check for private package namespacing, assess public package conflicts, review internal registry configuration.
- **Third-Party Component Risks:** Assess component provenance, review update practices, check for abandoned dependencies, evaluate security track records.

## Pass E: DevSecOps Configuration Review
- **Security Headers:** Content-Security-Policy, X-Content-Type-Options, X-Frame-Options, Strict-Transport-Security, Referrer-Policy, Permissions-Policy.
- **CORS Configuration:** Origin allowlist, credential handling, preflight caching, method restrictions.
- **Rate Limiting:** Per-endpoint, per-user, and global limits; burst handling; rate limit headers.
- **Logging Configuration:** Security event coverage, log retention, aggregation, alert configuration, log access controls.
- **Docker / Container Security:** Base image selection, multi-stage builds, non-root user execution, secret handling in builds, image scanning, minimal attack surface.
- **CI/CD Pipeline Security:** Pipeline authentication, secret injection security, build environment isolation, artifact signing, deployment approval workflows, pipeline injection prevention.

## Pass F: Advanced Security Frameworks
- **OWASP ASVS & CWE Top 25:** Map findings to specific ASVS v4.0.3 requirements (e.g., V2.1.1) and CWE/SANS Top 25 entries.
- **Language-Specific & Ecosystem Rules:** Apply ecosystem-specific secure coding standards (e.g., CERT C/C++, Rust safe abstractions, Node.js prototype pollution checks).
- **MITRE ATT&CK / D3FEND:** Map identified vulnerabilities to attacker tactics and techniques (e.g., T1190 — Exploit Public-Facing Application).
- **STRIDE Threat Model:** Use the required, evidence-backed six-category matrix in [stride-threat-model.md](stride-threat-model.md).

## Pass G: LLM, Agent, and Markdown Security
- Load [llm-prompt-and-markdown-security.md](llm-prompt-and-markdown-security.md) whenever the repository contains LLM/agent SDKs, prompt templates, RAG/embedding/vector storage, tool/function/MCP calling, model-output rendering, Markdown/MDX rendering, documentation generation, or automation that consumes Markdown.
- Trace direct and stored/second-order prompt injection from every untrusted source through storage/retrieval into the model and onward to privileged tools or active output sinks.
- Review every tracked Markdown family file (`.md`, `.mdx`, `.markdown`) that can be rendered, published, ingested by a model, or consumed by automation. Inspect renderer/parser configuration rather than treating documentation as inert by default.

## Pass H: Control Assurance, Validation, and Synthesis
- Load [security-logging-and-audit.md](security-logging-and-audit.md) for authentication, authorization,
  credential, token, privileged, or sensitive-state lifecycles.
- Load [security-control-assurance.md](security-control-assurance.md); map each material security control to
  unit, integration, negative-case, and CI evidence; verify tests invoke
  production controls. Run and verify the CI gate candidate script.
- Independently adjudicate every Critical/High finding and every proposed chain
  source. Resolve changed severity, scope, preconditions, or causal language.
- When two or more findings share an evidenced control, workflow, resource, or
  attacker path, load [finding-synthesis-and-validation.md](finding-synthesis-and-validation.md). Record
  cross-domain themes, eligible attack paths, and component priority without
  changing source finding severity.
