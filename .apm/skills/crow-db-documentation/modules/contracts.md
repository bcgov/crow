# Handoffs and optional integration

Accept future handoff inputs from report-design work (signed-off
specification, decisions, glossary) and architecture review (objects failing
the Convention-versus-Surprise test). Return coverage, confirmed
documentation, findings, skipped/deferred objects, and session decisions.

`crow-business-rules` may provide optional, user-supplied context or consume
confirmed outputs. It is not a dependency and must never be auto-run. Keep
business-rule evidence separate from database documentation findings.

Raven is a deferred live-provider boundary. Phase 1 defines no tool names,
authentication, query protocol, or API shape.
