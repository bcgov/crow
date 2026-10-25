import javax.servlet.http.HttpServletRequest;

class AuthFilter {
    public String extractUser(HttpServletRequest req) {
        // ruleid: java-ambient-header-identity-trust
        String user = req.getHeader("SM_USER");
        // ruleid: java-ambient-header-identity-trust
        String remote = req.getRemoteUser();
        // ruleid: java-ambient-header-identity-trust
        String msUser = req.getHeader("x-ms-client-principal");
        return user;
    }

    public String extractSafe(HttpServletRequest req) {
        if (!verifySignature(req)) {
            throw new SecurityException("Invalid gateway signature");
        }
        // ok: java-ambient-header-identity-trust
        return req.getHeader("SM_USER");
    }

    private boolean verifySignature(HttpServletRequest req) {
        return true;
    }
}
