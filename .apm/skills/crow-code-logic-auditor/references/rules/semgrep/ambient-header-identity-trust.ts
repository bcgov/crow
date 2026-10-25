function extractIdentityUnsafe(req) {
  // ruleid: ambient-header-identity-trust
  const user = req.headers['x-forwarded-user'];
  // ruleid: ambient-header-identity-trust
  const siteminder = req.headers['sm_user'];
  // ruleid: ambient-header-identity-trust
  const azureUser = req.headers['x-ms-client-principal'];
  return { user, siteminder, azureUser };
}

function extractIdentityMethods(req) {
  // ruleid: ambient-header-identity-trust
  const user = req.header('x-user-id');
  // ruleid: ambient-header-identity-trust
  const sm = req.get('sm_user');
  // ruleid: ambient-header-identity-trust
  const remote = req.get('remote_user');
  return { user, sm, remote };
}

function extractDestructuring(req) {
  // ruleid: ambient-header-identity-trust
  const { 'x-user-id': u } = req.headers;
  // ruleid: ambient-header-identity-trust
  const { 'x-auth-request-user': authU } = req.headers;
  return { u, authU };
}

function extractIgnoredResult(req) {
  // Ignored boolean result / no throw: should still be flagged
  verifySignature(req);
  // ruleid: ambient-header-identity-trust
  const user = req.headers['x-forwarded-user'];
  return user;
}

function extractWrongRequest(req, otherReq) {
  // Verifies otherReq, but extracts from req: should still be flagged
  assertValidGateway(otherReq);
  // ruleid: ambient-header-identity-trust
  const user = req.headers['x-forwarded-user'];
  return user;
}

function extractIdentitySafeGuard(req) {
  if (!verifySignature(req)) {
    throw new Error("Unauthorized gateway caller");
  }
  // ok: ambient-header-identity-trust
  const user = req.headers['x-forwarded-user'];
  return user;
}

function extractIdentitySafeIf(req) {
  if (verifySignature(req)) {
    // ok: ambient-header-identity-trust
    const user = req.headers.get('x-user-id');
    return user;
  }
  return null;
}
