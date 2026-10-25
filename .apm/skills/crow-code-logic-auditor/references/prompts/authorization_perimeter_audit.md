# Inspection Prompt: Perimeter Inversion, Ambient Trust & Data-Driven Authorization Audit

Execute this inspection when auditing authentication handoffs, microservice boundaries, legacy wrapper layers, database-driven RBAC/ABAC models, and multi-interface access vectors (e.g., API vs. MCP tools vs. batch queues).

---

## 1. Perimeter Assumption Deconstruction
- **Identify Ingress Topologies**:
  - List all entry points (HTTP controllers, MCP tool definitions, GraphQL resolvers, messaging queues, PL/SQL package procedures).
  - Determine whether authentication occurs in-frame (cryptographic validation) or out-of-frame (upstream reverse proxy, SiteMinder SSO, API gateway, corporate VPN).
- **Inspect Ambient Identity Extraction**:
  - Find all call sites reading raw HTTP headers (`SM_USER`, `X-Forwarded-User`, `X-User-Id`, `REMOTE_USER`).
  - Verify if each call site cryptographically validates origin (e.g., mTLS mutual auth, signed JWT HMAC/RSA with audience/expiry checks).
  - Flag any internal method or package procedure that lacks localized capability enforcement because it "assumes" upstream gatekeeping.

---

## 2. Data-Driven Authorization Verification (Database RBAC/ABAC)
- **Fail-Closed Inspection**:
  - Trace queries fetching user permissions from tables (e.g., `SELECT role FROM user_roles WHERE user_id = :uid`).
  - Check failure handling: If the query returns 0 rows, times out, throws `NO_DATA_FOUND`, or triggers an exception (`WHEN OTHERS`), does the code **fail closed (DENY)** or **fail open (ALLOW)**?
  - Verify that missing permissions or unauthenticated principals default to explicit, immediate rejection.
- **Wildcard & NULL Predicate Expansion**:
  - Inspect authorization queries using dynamic filtering:
    ```sql
    -- VULNERABLE: If :org_filter is NULL, matches all rows in multi-tenant table
    SELECT * FROM records WHERE (:org_filter IS NULL OR org_id = :org_filter)
    ```
  - Flag any pattern where an unsupplied or empty organizational context parameter silently expands authorization to all entities.

---

## 3. Surface Parity & Multi-Channel Ingress Audit
- **Entity Access Matrix**:
  - For each mutating business entity (e.g., `Permit`, `Claim`, `Transaction`), enumerate every code path capable of updating it:
    - Path A: Public / Standard REST API route.
    - Path B: Administrative / Batch route.
    - Path C: Async worker / Celery task / Event subscriber.
    - Path D: MCP tool handler (e.g. tools exposing VCS, issue tracker, or database mutations).
- **Check Ingress Parity**:
  - Assert that all paths enforce identical authorization checks, tenancy predicates, and business rule validations.
  - Flag any alternate path (e.g., an internal MCP tool or background task) that bypasses checks enforced on the primary API.

---

## 4. Discriminating Test Generation
Generate a concrete reproducer proving perimeter bypass or fail-open data authorization:

```python
def test_perimeter_bypass_direct_invocation():
    """
    Demonstrate that an internal service method or MCP tool allows unauthorized
    mutation when invoked directly without an upstream proxy session.
    """
    client = TestClient(app)
    
    # 1. Direct invocation bypassing upstream SSO proxy
    # Attacker crafts ambient header directly without valid cryptographic signature
    spoofed_headers = {"X-Forwarded-User": "admin@gov.bc.ca"}
    
    response = client.post("/internal/tools/execute-action", 
                           headers=spoofed_headers, 
                           json={"action": "MUTATE_RECORD", "id": 1001})
    
    # Invariant: Must return 401/403 Unauthorized unless authenticated via local cryptographic proof
    assert response.status_code in (401, 403), f"Bypassed perimeter authorization! Got {response.status_code}"
```
