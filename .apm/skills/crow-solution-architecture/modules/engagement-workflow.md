# Evidence-first architecture engagement

## Step 1: Homework

Before asking questions:

1. Identify the business capability, users, existing systems, delivery stage,
   repository shape, runtime manifests, deployment definitions, current
   architecture records, business criticality, required uptime, RTO, RPO, data
   classification, and data retention and destruction requirements.
2. Read `crow.config` when present. Treat its public references as discovery
   hints, not proof.
3. Use codebase intelligence when available and disclose coverage gaps. Read
   source directly where coverage is partial.
4. Search the relevant available requirements and documentation sources,
   including repository documents, `crow.config` references, Jira, Confluence,
   GitHub, SharePoint, ADO, asset catalogues, and authoritative web guidance.
   No provider has priority by default. Rank evidence by authority, directness,
   freshness, scope, and corroboration.
5. Review relevant current public B.C. guidance and common-component
   information. Use private sources only as read-only evidence and never copy
   their identifiers or source content into reusable Crow assets.
6. When comparing technology preferences, review a bounded sample from any
   relevant available repository or application-inventory providers. Record
   the date, selection criteria, aggregate technologies observed, and
   limitations. Do not copy private identifiers or source content into public
   Crow assets or generated public documents. If representative evidence is
   unavailable, mark it `Unknown` rather than presenting a preference as an
   organizational standard.
7. Separate facts, constraints, assumptions, preferences, and decisions.

## Step 2: Open the interview

Present a short evidence summary and a numbered list of provisional
assumptions. Ask one focused question at a time. Prefer choices with a
recommended option and explain what changes between choices.

Ask only questions whose answers are not discoverable and materially affect
the solution. Cover these decision areas, skipping those already resolved:

1. business outcome, service boundary, success measure, and accountable owner;
2. user populations, delegated or organizational access, and identity
   assurance;
3. information classification, residency, retention, destruction, records, and
   privacy;
4. business criticality, volume, latency, uptime, RTO, RPO, seasonality, and
   growth;
5. integrations, system-of-record responsibilities, and common components;
6. delivery date, funding, team skills, operational ownership, and support
   hours;
7. hosting, network, licensing, procurement, and migration constraints;
8. which decision maker can accept trade-offs and remaining risk.

For each answer, update the decision status:

- `Confirmed`: accepted by an accountable stakeholder or authoritative source;
- `Provisional`: safe working assumption with an owner and review date;
- `Rejected`: considered but not selected, with rationale;
- `Blocked`: unresolved and architecture-significant.

Do not ask the user to repeat repository facts. If answers conflict, state the
conflict and ask which source governs.

## Step 3: Shape the solution

1. Rank quality attributes and identify the few that drive architecture.
2. Define the system boundary, external actors, protected resources, data
   responsibility, and deployment units.
3. Apply the preferred defaults, then test them against constraints.
4. Record each fallback as `trigger -> alternative -> consequence -> revisit`.
5. Prefer reversible decisions and explicit contracts. Identify decisions that
   require an approval outside this engagement.
6. Produce one recommended design. Keep alternatives only when a pending
   decision genuinely prevents convergence.

## Step 4: Review and write

Before writing, recap the recommendation and material deviations for user
confirmation. Then populate the canonical Markdown without deleting unresolved
risks or unknowns. Create the HTML review from that Markdown and preserve the
same decision IDs, statuses, values, and source dates.

The document is a decision baseline, not proof of implementation or approval.
Date all external evidence and make time-sensitive recommendations easy to
revisit.

## Presentation contract

- Keep all authoritative statements, decisions, and implementation guidance in
  the Markdown so implementation agents can work without parsing presentation
  markup.
- Use HTML to improve review, not to introduce new decisions. Present the
  executive summary as status cards; use semantic tables for comparisons;
  use `<details>` for supporting rationale; and use accessible inline SVG or
  equivalent semantic HTML for context, workflow, and data-flow views.
- Include textual alternatives for every visual flow. Do not encode meaning by
  colour alone.
- Keep the HTML self-contained and printable. JavaScript is optional and must
  only enhance presentation; the full content must remain available without it.
- Use optional JSON only for structured presentation or hand-off needs. It is
  derived from Markdown and must not become a second authority.
