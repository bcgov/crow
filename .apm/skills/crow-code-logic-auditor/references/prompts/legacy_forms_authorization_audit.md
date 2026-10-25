# Inspection Prompt: Oracle Forms & Legacy PL/SQL Authorization Audit

> [!IMPORTANT]
> **Governing Doctrine**: All inspections are governed by `instructions.md` (First-Principles Epistemology, Invariant Sourcing, and Four Evidence Levels). Reject appeals to tradition ("this Form has run safely in production for 15 years"). Verify whether authorization invariants reside strictly in client UI triggers or are enforced at the database storage engine.

Execute this inspection when auditing enterprise legacy Oracle Forms (FMB/XML), Oracle Reports, PL/SQL package libraries (PLL/PLD), and database triggers undergoing modern API exposure, re-platforming, microservice extraction, or invariant auditing.

## 1. Oracle Forms & PL/SQL Library Source Extraction
Binary `.fmb`, `.mmb`, and `.pll` files cannot be inspected directly by static analysis. Convert them to inspectable plain text:

```bash
# Set FORMS_PATH so attached libraries and referenced object groups resolve
export FORMS_PATH="/path/to/forms/libs:/path/to/forms/templates:$FORMS_PATH"

# Convert binary Form (.fmb) to XML for static AST/XPath inspection (frmf2xml.bat on Windows)
frmf2xml.sh OVERWRITE=YES <form_name>.fmb
# Result: <form_name>_fmb.xml

# Convert binary PL/SQL shared library (.pll) to text (.pld) (frmcmp.bat on Windows)
frmcmp.sh userid=username/password@db module=<lib_name>.pll module_type=LIBRARY script=YES
# Result: <lib_name>.pld
```

## 2. Invariant Checklist: Client-Enforced vs Storage-Enforced Rules

### A. Client UI Validation Monopoly vs API Bypass
- [ ] **UI Item Disabling as Authorization**: Does the application rely on `SET_ITEM_PROPERTY('<item>', ENABLED, PROPERTY_FALSE)` or `SET_ITEM_PROPERTY('<item>', UPDATE_ALLOWED, PROPERTY_FALSE)` to prevent unauthorized updates, while the underlying table or procedure allows updates directly?
- [ ] **Client Validation Monopoly**: Do business and authorization invariants live solely inside Form client triggers (`WHEN-VALIDATE-ITEM`, `WHEN-VALIDATE-RECORD`, `PRE-INSERT`, `PRE-UPDATE`)?
  - *Vulnerability*: Any modern REST API wrapper, batch script, microservice, or direct SQL*Net caller bypasses client triggers completely, writing invalid state directly to tables.
- [ ] **Ambient `:GLOBAL.*` Trust**: Are security attributes (e.g. `:GLOBAL.USER_ROLE`, `:GLOBAL.IS_ADMIN`) initialized once at login and trusted across foreign form invocations (`CALL_FORM`, `OPEN_FORM`) without server-side signature or re-querying database privileges?
- [ ] **Menu Security (`USE_SECURITY`)**: Does menu security rely on Oracle Forms menu role properties (`USE_SECURITY = YES`) without backend row-level or package-level validation?

### B. Exception Swallows & Permissive Defaults
- [ ] **Error Suppression via `:SYSTEM.MESSAGE_LEVEL`**: Does code set `:SYSTEM.MESSAGE_LEVEL := '25'` or higher without immediately restoring it, silently discarding fatal database trigger and constraint errors?
- [ ] **Fail-Open `ON-ERROR` and `ON-MESSAGE` Triggers**: Does an `ON-ERROR` trigger catch database errors without executing `RAISE FORM_TRIGGER_FAILURE;`?
  - *Vulnerability*: Swallowing the error allows the form to advance to navigation or commit stages with invalid or partially committed records.
- [ ] **Fail-Open Function Exceptions**: In security checks (`can_access`, `chk_auth`, `is_authorized`), does `EXCEPTION WHEN OTHERS` or `WHEN NO_DATA_FOUND` return `TRUE`, `'Y'`, or set an allow variable?
- [ ] **VPD / Row-Level Security Predicate Disablement**: Do Virtual Private Database policy functions return `NULL` or empty strings upon `NO_DATA_FOUND` or normal paths, causing Oracle to omit the security WHERE clause and expose all rows?
- [ ] **Autonomous Transaction Mutating Table Workarounds**: Does a database trigger declare `PRAGMA AUTONOMOUS_TRANSACTION` to avoid `ORA-04091` (mutating table error)?

### C. Direct Database Privilege & Grants Inventory
- [ ] **Connection Account Privilege Escalation**: What direct operations can the Forms runtime database connection perform without the Forms client? Run:
```sql
-- Inventory direct table and procedure privileges for the runtime account
SELECT table_name, privilege FROM user_tab_privs;
SELECT role FROM user_role_privs;

-- CRITICAL: Check whether the connection holds EXEMPT ACCESS POLICY
SELECT * FROM session_privs WHERE privilege = 'EXEMPT ACCESS POLICY';
```
*(If `EXEMPT ACCESS POLICY` is granted, Oracle VPD / FGAC policies are completely bypassed for all connections made by that user.)*

## 3. Discriminating Test Vector (Safe Execution & Rollback)

> [!CAUTION]
> **Reproducer Safety Rule**: Never run reproducers against shared or production databases. Execute exclusively against an isolated local development container or transactionally roll back after assertion.

```sql
-- Connect as the least-privileged Forms runtime user (e.g., APP_USER)
-- Sourced Invariant: Lifecycle status cannot jump to 'APPROVED' without authorized role
SET SERVEROUTPUT ON;

DECLARE
  v_permit_id NUMBER := 999999;
  v_status_after VARCHAR2(50);
BEGIN
  SAVEPOINT test_start;

  -- Attempt direct database mutation bypassing Forms client validation triggers:
  UPDATE permits
  SET status = 'APPROVED'
  WHERE permit_id = v_permit_id;

  SELECT status INTO v_status_after FROM permits WHERE permit_id = v_permit_id;

  -- If the update succeeds, the invariant is enforced ONLY in Forms UI, breaching storage integrity:
  IF v_status_after = 'APPROVED' THEN
    DBMS_OUTPUT.PUT_LINE('FAILURE: Direct API/SQL caller bypassed Forms UI authorization guard!');
  END IF;

  -- Mandatory: Always rollback test mutations
  ROLLBACK TO test_start;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('SUCCESS: Database storage engine enforced invariant: ' || SQLERRM);
    ROLLBACK TO test_start;
END;
/
```
