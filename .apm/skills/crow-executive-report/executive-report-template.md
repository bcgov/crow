# Executive Summary Template

*Global template for generating executive summary reports from architecture and security review data.*

---

# Executive Summary Report

**Application:** {{APPLICATION_NAME}} ({{APPLICATION_ACRONYM}})  
**Report Date:** {{REPORT_DATE}}  
**Source Documents:** 
- Architecture Document: `{{ARCHITECTURE_DOC_PATH}}` (Last Updated: {{ARCHITECTURE_DATE}})
- Security Review Document: `{{SECURITY_DOC_PATH}}` (Last Updated: {{SECURITY_DATE}})
**Overall Security Risk:** {{OVERALL_RISK}}  
**Quality Gate:** {{QUALITY_GATE_STATUS}}

---

## 1. Executive Brief

*Provide a 2-3 paragraph plain-language overview of the application's overall technical health, security posture, and key risk areas suitable for C-level executives and non-technical stakeholders.*

---

## 2. Key Metrics Dashboard

| Metric Category | Current Status | Details / Highlights |
| :--- | :--- | :--- |
| **Overall Security Risk** | `[CRITICAL / HIGH / MODERATE / LOW / SECURE]` | |
| **Quality Gate Status** | `[PASSED / FAILED / NOT RUN]` | |
| **Runtime & Framework Currency** | `[Up to Date / EOL Risk / Outdated]` | |
| **Third-Party Dependency Health** | `[Healthy / Vulnerabilities Found]` | |
| **Confirmed Findings** | `[Count]` | Fully verified with code evidence |
| **Probable Findings** | `[Count]` | Likely vulnerabilities pending full verification |
| **Critical Findings** | `[Count]` | |
| **High Findings** | `[Count]` | |
| **Coverage Baseline Gaps** | `[Count]` | Entry points not fully assessed |

---

## 3. High-Risk Security Issues (Plain Language)

*Translate critical and high-severity security findings into plain business language explaining the risk, potential business impact, and required remediation. Prioritize Confirmed findings over Probable findings.*

| Issue / Finding | Severity | Classification | Business Risk & Impact (Plain Language) | Recommended Action |
| :--- | :--- | :--- | :--- | :--- |
| | `CRITICAL / HIGH` | `Confirmed / Probable` | | |

---

## 4. Technical Debt & Platform Currency Assessment

*Summarize technical debt, unsupported or End-of-Life (EOL) technologies, outdated dependencies, and architectural risks in plain language.*

| Component / Technology | Category | Technical Debt Risk | Impact on Stability & Security | Action Required |
| :--- | :--- | :--- | :--- | :--- |
| | `EOL Runtime / Outdated Dep / Arch Risk` | | | |

---

## 5. Architectural High-Level Overview

*Brief summary of the system architecture, primary technology stack, key integration boundaries, and resilience capability.*

* **Primary Tech Stack:** {{TECH_STACK_SUMMARY}}
* **Architecture Pattern:** {{ARCH_PATTERN}}
* **Deployment Model:** {{DEPLOYMENT_MODEL}}
* **Resilience & Disaster Recovery:** {{RESILIENCE_SUMMARY}}

### Optional platform alignment

Include this subsection only when the source architecture document contains
evidence. Report the conditional role, one-to-many consumer impact, reuse
decision, data custodian and `Open / Shared / Closed` spectrum, contract owner,
and degradation behavior. Optional measured counts may include known consumers,
shared dependencies, contracts with owners, and tested fallback scenarios.
Leave unsupported values null or state `Unknown`; do not invent a platform
catalogue or a maturity score.

---

## 6. Strategic Recommendations & Action Plan

*Prioritized recommendations for leadership and engineering teams.*

| Priority | Focus Area | Recommended Action | Target Timeline |
| :--- | :--- | :--- | :--- |
| **P1 - Immediate** | Security & Critical Debt | | Current Sprint |
| **P2 - Short Term** | High Risk & Upgrade | | 1-2 Sprints |
| **P3 - Strategic** | Architecture Hardening | | Next Quarter |
