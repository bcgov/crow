# Inspection Prompt: Idempotency, Replay and Dual Writes

Use for payment/webhook handlers, queue consumers, retries, one-time tokens, and any code
that writes to a database and also calls or notifies something else.

## 1. Map deliveries and effects
- For each handler: can the same logical request arrive twice? (Client retry, double
  click, webhook redelivery, at-least-once queue, load balancer retry on timeout.)
- List every effect it causes: rows written, money moved, emails sent, events published,
  external APIs called. Note which are inside the DB transaction and which are not.

## 2. Checklist
- [ ] **Idempotency key**: present, derived from the caller's intent (not generated per
      attempt), stored under a unique constraint **in the same transaction** as the effect?
- [ ] **Check-then-insert on the key** (`if not exists(key): process()`) is itself a race;
      the unique constraint must be what decides.
- [ ] **Webhooks**: signature verified over the raw body; timestamp tolerance enforced;
      event id deduplicated; handler tolerates events out of order.
- [ ] **One-time tokens** consumed with a conditional update and row-count check.
- [ ] **Dual writes**: DB commit then publish/call (or the reverse) with no outbox or
      reconciliation? What state does a crash between the two leave?
- [ ] **Retries of non-idempotent calls**: HTTP client or job framework auto-retries a
      `POST` to a payment provider without an idempotency key?

## 3. Discriminating tests

```python
def test_duplicate_webhook_applies_once(client, signed_event):
    for _ in range(3):
        assert client.post("/webhooks/payments", **signed_event).status_code in (200, 204)
    assert Payment.objects.filter(provider_event_id=signed_event.id).count() == 1
    assert ledger_balance(signed_event.account) == signed_event.amount


def test_coupon_redeemed_once_under_concurrency(coupon, users):
    results = run_concurrently(*[lambda u=u: redeem(coupon.code, u) for u in users])
    assert sum(r.ok for r in results) == coupon.max_uses
```
