# Application Security & Dependency Review: {{APPLICATION_ACRONYM}} - {{APPLICATION_NAME}}

This document provides a detailed security posture, framework version audit, dependency vulnerability review, and static analysis scan summary for **{{APPLICATION_NAME}} ({{APPLICATION_ACRONYM}})**.

---

## Revision History

| Version | Date | Author | Changes |
| :--- | :--- | :--- | :--- |
| `1.0` | `YYYY-MM-DD` | `Security Review Agent` | `Initial generation` |

---

## 1. Framework & Runtime Currency Audit

This section documents all core language runtimes, web/application frameworks, and major runtime dependencies along with their exact versions and support / End-of-Life (EOL) status (e.g., Java, .NET, PHP, Python, Node.js, Go, Spring, ASP.NET Core, Express, Laravel).

| Technology Category | Tech Stack Item | Version | Support / EOL Status |
| :--- | :--- | :--- | :--- |
| **Runtime Language** | | | |
| **Web/Application Framework** | | | |
| **Database Driver / ORM** | | | | |
| **Database Engine** | | | |
| **Web/App Server** | | | |
| **Identity Provider** | | | |
| **Message Broker** | | | |
| **Container Runtime** | | | |
| **Orchestration Platform** | | | |

---

## 2. Third-Party Dependency & License Inventory

This section captures third-party library dependencies parsed from lock files, including license compliance details.

| Dependency Name | Installed Version | Latest Version | License | Direct / Transitive | License Risk |
| :--- | :--- | :--- | :--- | :--- | :--- |
| | | | | | `Direct / Transitive` | `Compliant / Flagged / Unknown` |

*Source: Generated from lock files (`package-lock.json`, `packages.lock.json`, `go.sum`, `requirements.txt`, `pom.xml`, `build.gradle`, `libman.json`, `*.csproj`, etc.)*

---

## 3. Known CVE & Vulnerability Assessment

This section lists known vulnerabilities (CVEs) identified across direct and transitive dependencies or container base images.

| CVE ID | Affected Component | Vulnerable Version | Severity | Fixed Version | Remediation Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| | | | `CRITICAL / HIGH / MEDIUM / LOW` | | `Open / Patched / Mitigated / Ignored` |

---

## 4. SonarQube / SonarCloud Code Analysis & Quality Gate Summary

This section summarizes static application security testing (SAST) and code quality scan results retrieved via SonarQube / SonarCloud integration.

### 4.1 Quality Gate Status
* **Quality Gate Overall:** `[PASSED / FAILED / NOT RUN]`
* **Project Key / Branch:** `[projectKey] / [branch]`
* **Scan Date:** `YYYY-MM-DD`

### 4.2 Security & Quality Metrics

| Metric Category | Count / Rating | Key Findings Summary |
| :--- | :--- | :--- |
| **Security Vulnerabilities** | `[Count] (Rating: A-F)` | |
| **Security Hotspots** | `[To Review / Acknowledged]` | |
| **Code Smells** | `[Count]` | |
| **Bugs** | `[Count]` | |
| **Code Coverage** | `[%]` | |
| **Duplicated Lines** | `[%]` | |

### 4.3 High Priority Security Issues / Hotspots

| Issue / Hotspot Key | Type | Severity | File Location | Status / Rule |
| :--- | :--- | :--- | :--- | :--- |
| | `VULNERABILITY / HOTSPOT / BUG` | `BLOCKER / CRITICAL / MAJOR` | | |

---

## 5. Security Posture & Safeguards

This section evaluates key security controls, hardcoded secret checks, and cryptographic implementations across the repository.

| Security Domain | Findings / Controls | Compliance Rating |
| :--- | :--- | :--- |
| **Hardcoded Secrets Scan** | *Search for credentials, private keys, tokens in code* | `Pass / Flagged` |
| **Authentication & Token Handling** | *Token generation RNG, secret transience, timing defenses* | `Pass / Needs Review` |
| **Input Validation & Sanitization** | *SQL injection, XSS, SSRF protection patterns* | `Pass / Needs Review` |
| **Cryptography & Hashing** | *Algorithms used (SHA-256, bcrypt, AES-GCM, etc.)* | `Pass / Needs Review` |
| **Audit & Logging Hygiene** | *Structured [AUDIT] events, PII redaction* | `Pass / Needs Review` |

---

## 6. OWASP Top 10 (2025) Analysis

Analyze each OWASP Top 10 category against the codebase and record findings.

### A01:2025 — Broken Access Control
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Missing or bypassable authorization checks | `Pass / Flagged / N/A` | |
| Insecure direct object references (IDOR) | `Pass / Flagged / N/A` | |
| Path traversal vulnerabilities | `Pass / Flagged / N/A` | |
| Missing function-level access control | `Pass / Flagged / N/A` | |
| CORS misconfigurations | `Pass / Flagged / N/A` | |
| Privilege escalation vectors (horizontal/vertical) | `Pass / Flagged / N/A` | |
| Server-Side Request Forgery (SSRF) | `Pass / Flagged / N/A` | |
| DNS rebinding / webhook exposure | `Pass / Flagged / N/A` | |

### A02:2025 — Security Misconfiguration
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Default credentials or configurations | `Pass / Flagged / N/A` | |
| Verbose error messages exposing internals | `Pass / Flagged / N/A` | |
| Unnecessary features enabled | `Pass / Flagged / N/A` | |
| Missing security headers | `Pass / Flagged / N/A` | |
| Open cloud storage buckets | `Pass / Flagged / N/A` | |
| Debug modes in production | `Pass / Flagged / N/A` | |

### A03:2025 — Software Supply Chain Failures
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Known vulnerable dependencies | `Pass / Flagged / N/A` | |
| Outdated frameworks and libraries | `Pass / Flagged / N/A` | |
| Unsupported / end-of-life components | `Pass / Flagged / N/A` | |
| Missing dependency lockfiles | `Pass / Flagged / N/A` | |
| Dependency confusion risks | `Pass / Flagged / N/A` | |
| Typosquatting indicators in package names | `Pass / Flagged / N/A` | |
| Compromised or unsigned build tools / CI/CD components | `Pass / Flagged / N/A` | |
| Absence of SBOM | `Pass / Flagged / N/A` | |

### A04:2025 — Cryptographic Failures
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Weak algorithms (MD5, SHA1, DES, RC4) | `Pass / Flagged / N/A` | |
| Hardcoded cryptographic keys | `Pass / Flagged / N/A` | |
| Insufficient key lengths | `Pass / Flagged / N/A` | |
| Insecure random number generation | `Pass / Flagged / N/A` | |
| Missing TLS/SSL enforcement | `Pass / Flagged / N/A` | |
| Plaintext transmission of sensitive data | `Pass / Flagged / N/A` | |

### A05:2025 — Injection
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| SQL injection | `Pass / Flagged / N/A` | |
| NoSQL injection | `Pass / Flagged / N/A` | |
| Command injection | `Pass / Flagged / N/A` | |
| LDAP / XPath / Template injection | `Pass / Flagged / N/A` | |
| Expression language / ORM injection | `Pass / Flagged / N/A` | |

### A06:2025 — Insecure Design
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Missing security design patterns | `Pass / Flagged / N/A` | |
| Lack of threat modeling evidence | `Pass / Flagged / N/A` | |
| Insecure business logic flows | `Pass / Flagged / N/A` | |
| Missing rate limiting or throttling | `Pass / Flagged / N/A` | |

### A07:2025 — Authentication Failures
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Weak password policies | `Pass / Flagged / N/A` | |
| Missing multi-factor authentication | `Pass / Flagged / N/A` | |
| Session fixation / insecure session management | `Pass / Flagged / N/A` | |
| Credential stuffing / account enumeration | `Pass / Flagged / N/A` | |
| JWT implementation flaws | `Pass / Flagged / N/A` | |

### A08:2025 — Software or Data Integrity Failures
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Insecure deserialization | `Pass / Flagged / N/A` | |
| Missing code signing verification | `Pass / Flagged / N/A` | |
| CI/CD pipeline injection risks | `Pass / Flagged / N/A` | |
| Trust on first use (TOFU) issues | `Pass / Flagged / N/A` | |

### A09:2025 — Security Logging & Alerting Failures
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Missing security event logging | `Pass / Flagged / N/A` | |
| Insufficient log detail for forensics | `Pass / Flagged / N/A` | |
| Logs containing sensitive data | `Pass / Flagged / N/A` | |
| No log integrity protection | `Pass / Flagged / N/A` | |
| Logging with no corresponding alerting | `Pass / Flagged / N/A` | |

### A10:2025 — Mishandling of Exceptional Conditions
| Check Item | Status | Details / Evidence |
| :--- | :--- | :--- |
| Exception handlers exposing stack traces | `Pass / Flagged / N/A` | |
| Failing open on errors (granting access on exception) | `Pass / Flagged / N/A` | |
| DoS through unhandled exceptions in critical paths | `Pass / Flagged / N/A` | |
| Swallowed exceptions masking security-relevant failures | `Pass / Flagged / N/A` | |

---

## 7. Secure Coding Practices Review

### Input Validation & Output Encoding
| Practice | Status | Details / Evidence |
| :--- | :--- | :--- |
| All inputs validated at trust boundaries | `Pass / Flagged / N/A` | |
| Allowlists preferred over denylists | `Pass / Flagged / N/A` | |
| Type, length, format, and range validation | `Pass / Flagged / N/A` | |
| Context-aware output encoding (HTML, JS, URL, SQL) | `Pass / Flagged / N/A` | |

### Cryptography Implementation
| Practice | Status | Details / Evidence |
| :--- | :--- | :--- |
| Industry-standard algorithms (AES-256, RSA-2048+, ECDSA) | `Pass / Flagged / N/A` | |
| Secure key storage (HSM, KMS, vault) | `Pass / Flagged / N/A` | |
| Correct IV/nonce usage | `Pass / Flagged / N/A` | |
| Authenticated encryption (GCM, Poly1305) | `Pass / Flagged / N/A` | |

### Secrets Management
| Practice | Status | Details / Evidence |
| :--- | :--- | :--- |
| No hardcoded secrets in source code | `Pass / Flagged / N/A` | |
| Environment variable or vault usage for secrets | `Pass / Flagged / N/A` | |
| Secrets rotation mechanisms | `Pass / Flagged / N/A` | |
| Secret detection in logs | `Pass / Flagged / N/A` | |

### Session Handling & API Security
| Practice | Status | Details / Evidence |
| :--- | :--- | :--- |
| Secure session ID generation & timeout | `Pass / Flagged / N/A` | |
| Session invalidation on logout | `Pass / Flagged / N/A` | |
| Secure cookie attributes (HttpOnly, Secure, SameSite) | `Pass / Flagged / N/A` | |
| Authentication on all API endpoints | `Pass / Flagged / N/A` | |
| Rate limiting on API endpoints | `Pass / Flagged / N/A` | |

---

## 8. Architecture Security Assessment

### Trust Boundary Analysis
*Identify all trust boundaries, map data flows across boundaries, and document trust assumptions.*

| Trust Boundary | Data Flow | Validation | Risk Level |
| :--- | :--- | :--- | :--- |
| | | `Validated / Missing / Partial` | `High / Medium / Low` |

### Attack Surface Assessment
| Surface | Exposed | Auth Required | Risk Level |
| :--- | :--- | :--- | :--- |
| *Public endpoints* | | `Yes / No / Partial` | |
| *Exposed services/ports* | | | |
| *Third-party integrations* | | | |

### Privilege Escalation Analysis
| Boundary / Role | Elevation Path | Risk | Mitigation |
| :--- | :--- | :--- | :--- |
| | | `High / Medium / Low` | |

### Data Flow Security
| Data Category | Encryption in Transit | Encryption at Rest | Retention | Sanitization |
| :--- | :--- | :--- | :--- | :--- |
| | `Yes / No` | `Yes / No` | | `Yes / No` |

---

## 9. Supply Chain Security

### Dependency Analysis & Lockfile Security
| Check | Status | Details |
| :--- | :--- | :--- |
| Lockfile present and up-to-date | `Pass / Flagged / N/A` | |
| Lockfile integrity verified | `Pass / Flagged / N/A` | |
| Dependency tree reviewed for anomalies | `Pass / Flagged / N/A` | |
| No dependency confusion risks | `Pass / Flagged / N/A` | |
| Private package namespacing correct | `Pass / Flagged / N/A` | |

### Third-Party Component Risks
| Component | Provenance | Maintained | Security Track Record | Risk |
| :--- | :--- | :--- | :--- | :--- |
| | `Verified / Unknown` | `Active / Abandoned` | `Good / Mixed / Poor` | |

---

## 10. DevSecOps Configuration Review

### Security Headers
| Header | Status | Details |
| :--- | :--- | :--- |
| Content-Security-Policy | `Present / Missing / Partial` | |
| X-Content-Type-Options | `Present / Missing` | |
| X-Frame-Options | `Present / Missing` | |
| Strict-Transport-Security | `Present / Missing` | |
| Referrer-Policy | `Present / Missing` | |
| Permissions-Policy | `Present / Missing` | |

### CORS & Rate Limiting
| Control | Status | Details |
| :--- | :--- | :--- |
| CORS origin allowlist | `Configured / Missing / Permissive` | |
| Rate limiting (per-endpoint) | `Configured / Missing / Partial` | |
| Rate limiting (per-user / global) | `Configured / Missing / Partial` | |

### Docker / Container Security
| Check | Status | Details |
| :--- | :--- | :--- |
| Minimal base image | `Pass / Flagged / N/A` | |
| Multi-stage build | `Pass / Flagged / N/A` | |
| Non-root user execution | `Pass / Flagged / N/A` | |
| No secrets in build layers | `Pass / Flagged / N/A` | |
| Image scanning enabled | `Pass / Flagged / N/A` | |

### CI/CD Pipeline Security
| Check | Status | Details |
| :--- | :--- | :--- |
| Pipeline authentication | `Pass / Flagged / N/A` | |
| Secret injection security | `Pass / Flagged / N/A` | |
| Build environment isolation | `Pass / Flagged / N/A` | |
| Artifact signing | `Pass / Flagged / N/A` | |
| Deployment approval workflows | `Pass / Flagged / N/A` | |

---

## 11. Advanced Security Frameworks

### OWASP ASVS & CWE Top 25 Mapping
*Map findings to specific ASVS v4.0.3 requirements and CWE/SANS Top 25 entries.*

| Finding ID | ASVS Requirement | CWE ID | MITRE ATT&CK Technique | Status |
| :--- | :--- | :--- | :--- | :--- |
| | e.g. `V2.1.1` | e.g. `CWE-89` | e.g. `T1190` | `Open / Mitigated` |

### STRIDE Threat Model Summary
| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elevation of Privilege |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| | | | | | | |

*Legend:* 🔴 High Risk | 🟡 Medium Risk | 🟢 Low Risk

---

## 12. Vulnerability Findings Detail

*For each finding, document using the structure below. Repeat for each finding.*

### [SEVERITY] Finding Title
- **Finding ID:** `SEC-NNN`
- **Location:** `path/to/file.ext:line_number`
- **OWASP Category:** `AXX:2025 — Category Name`
- **CWE:** `CWE-XXX`
- **CVSS Score:** `X.X`

#### Description
*Clear description of the vulnerability.*

#### Affected Code
```
[code snippet showing the vulnerability]
```

#### Exploit Scenario
*Step-by-step scenario showing how an attacker could exploit this.*

#### Remediation
*Specific steps to fix the vulnerability.*

#### Fixed Code Example
```
[code snippet showing the secure implementation]
```

---

## 13. Action Items & Security Remediation Roadmap

Prioritized list of security actions required to improve the posture of the application.

| Priority | Issue / Finding | Recommended Action | Target Date | Owner |
| :--- | :--- | :--- | :--- | :--- |
| `P1 - Critical` | | | | |
| `P2 - High` | | | | |
| `P3 - Medium` | | | | |
