function checkUserAccess(req, resourceId) {
  try {
    return queryDatabaseAcl(req.user, resourceId);
    // ruleid: fail-open-authorization-handler
  } catch (err) {
    return true;
  }
}

const isAllowedArrow = (user, op) => {
  try {
    return evaluatePolicy(user, op);
    // ruleid: fail-open-authorization-handler
  } catch (e) {
    return { allowed: true };
  }
};

class AccessController {
  hasPrivilege(user, role) {
    try {
      return lookupLdap(user, role);
      // ruleid: fail-open-authorization-handler
    } catch (err) {
      return "ALLOW";
    }
  }

  isAuthorized(user, perm) {
    try {
      return verifyPerm(user, perm);
      // ruleid: fail-open-authorization-handler
    } catch (err) {
      return "authorized";
    }
  }
}

function authMiddlewareGuard(req, res, next) {
  try {
    verifySessionToken(req);
    next();
    // ruleid: fail-open-authorization-handler
  } catch (err) {
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
