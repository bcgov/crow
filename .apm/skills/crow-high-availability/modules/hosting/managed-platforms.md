# Managed platforms and vendor controls

Identify product, tier, region, deployed runtime/version, instance/concurrency
limits, actual release controls and owning team. No provider name implies a
supported slot swap, revision routing, or maintenance guarantee.

Establish:

- Instance/revision isolation, spare capacity, warm-up/readiness behavior,
  scale-to-zero/cold starts and traffic-switch propagation.
- Settings, secrets, identity, network/storage bindings and background jobs
  affected by promotion or swapping. Avoid duplicate side effects during warm-up.
- Existing connections, session state, asynchronous work and the old/new
  application/data compatibility interval.
- Abort/reversal mechanics and their limits after new writes or external
  effects; retained revisions do not establish reversible data.
- Provider-controlled maintenance, evidence access and contractual limitations.
  Record these dependencies without claiming host/OS or engine patch coverage.

For example, consult [App Service staging slots](https://learn.microsoft.com/en-us/azure/app-service/deploy-staging-slots)
only when that product and tier apply. Use the actual provider/version's
official sources for others, recording `last_confirmed` and `review_after`.
If controls or representative evidence are unavailable, mark the conclusion
Unknown/cannot-establish rather than treating a vendor claim as an application
test. No live provider access, resource changes or swaps are authorized.
