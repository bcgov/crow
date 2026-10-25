function checkUserAccess(req, resourceId) {
  try {
    return queryDatabaseAcl(req.user, resourceId);
  } catch (err) {
    // ruleid: fail-open-authorization-handler
    return true;
  }
}

const isAllowedArrow = (user, op) => {
  try {
    return evaluatePolicy(user, op);
  } catch (e) {
    // ruleid: fail-open-authorization-handler
    return { allowed: true };
  }
};

class AccessController {
  hasPrivilege(user, role) {
    try {
      return lookupLdap(user, role);
    } catch (err) {
      // ruleid: fail-open-authorization-handler
      return "ALLOW";
    }
  }

  isAuthorized(user, perm) {
    try {
      return verifyPerm(user, perm);
    } catch (err) {
      // ruleid: fail-open-authorization-handler
      return "authorized";
    }
  }
}

function authMiddlewareGuard(req, res, next) {
  try {
    verifySessionToken(req);
    next();
  } catch (err) {
    // ruleid: fail-open-authorization-handler
    next();
  }
}

function checkUserAccessSafe(req, resourceId) {
  try {
    return queryDatabaseAcl(req.user, resourceId);
  } catch (err) {
    // ok: fail-open-authorization-handler
    return false;
  }
}

function authMiddlewareGuardSafe(req, res, next) {
  try {
    verifySessionToken(req);
    next();
  } catch (err) {
    // ok: fail-open-authorization-handler
    next(new Error("Unauthorized"));
  }
}
