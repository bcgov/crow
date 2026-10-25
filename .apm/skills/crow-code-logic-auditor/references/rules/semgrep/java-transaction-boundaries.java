import static javax.ejb.TransactionAttributeType.REQUIRES_NEW;

class Ledger {
  // ruleid: java-requires-new-partial-commit
  @TransactionAttribute(TransactionAttributeType.REQUIRES_NEW)
  public void a() { x(); }

  // ruleid: java-requires-new-partial-commit
  @TransactionAttribute(REQUIRES_NEW)
  public void b() { x(); }

  // ruleid: java-requires-new-partial-commit
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void c() { x(); }

  // ok: java-requires-new-partial-commit
  @Transactional
  public void d() { x(); }
}

class OrderService {
  @Transactional
  public void placeOrder(Order o) { repo.save(o); stock.decrement(o); }

  // ruleid: java-requires-new-partial-commit
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void auditRecord(Order o) { auditRepo.save(o); }

  public void checkout(Order o) {
    validate(o);
    // ruleid: java-transactional-self-invocation
    this.placeOrder(o);
  }

  public void checkoutBare(Order o) {
    // ruleid: java-transactional-self-invocation
    placeOrder(o);
  }

  public void logAuditDirect(Order o) {
    // ruleid: java-transactional-self-invocation
    this.auditRecord(o);
  }

  @Transactional
  public void batch(Order o) {
    // Callee uses Propagation.REQUIRED and caller has active @Transactional.
    // ok: java-transactional-self-invocation
    placeOrder(o);
  }

  public void viaProxy(Order o) {
    // ok: java-transactional-self-invocation
    otherBean.placeOrder(o);
  }
}
