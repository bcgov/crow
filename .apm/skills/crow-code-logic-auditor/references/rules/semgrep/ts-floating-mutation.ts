async function handler(req) {
  // ruleid: ts-floating-mutation-promise
  orderService.save(req.body);
  // ok: ts-floating-mutation-promise
  await orderService.update(req.body);
  // ok: ts-floating-mutation-promise
  logger.info("x");
  // ok: ts-floating-mutation-promise
  void audit.publishEvent(req.body);
  // ok: ts-floating-mutation-promise
  billing.charge(1).catch(report);
  // ok: ts-floating-mutation-promise
  return repo.delete(1);
}

class S {
  async h() {
    // ruleid: ts-floating-mutation-promise
    this.repo.delete(1);
  }
}

const f = async () => {
  // ruleid: ts-floating-mutation-promise
  billing.charge(1);
};

function syncOnly() {
  // ok: ts-floating-mutation-promise
  cache.update(1);
}
