// Semgrep generic engine tests using '//' comments

// ruleid: plsql-auth-function-when-others-allow
FUNCTION chk_user_access(p_user_id IN NUMBER, p_doc_id IN NUMBER) RETURN BOOLEAN IS
  v_role VARCHAR2(50);
BEGIN
  SELECT role INTO v_role FROM doc_perms WHERE user_id = p_user_id AND doc_id = p_doc_id;
  RETURN v_role = 'ADMIN';
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Error reading perms: ' || SQLERRM);
    RETURN TRUE;
END;
/

// ruleid: plsql-auth-function-when-others-allow
FUNCTION user_has_security_clearance(p_user VARCHAR2) RETURN VARCHAR2 IS
  v_ok VARCHAR2(1);
BEGIN
  SELECT granted INTO v_ok FROM sec_matrix WHERE username = p_user;
  RETURN v_ok;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    v_ok := 'Y';
    RETURN v_ok;
END;
/

// ok: plsql-auth-function-when-others-allow
FUNCTION chk_user_access_safe(p_user_id IN NUMBER, p_doc_id IN NUMBER) RETURN BOOLEAN IS
  v_role VARCHAR2(50);
BEGIN
  SELECT role INTO v_role FROM doc_perms WHERE user_id = p_user_id AND doc_id = p_doc_id;
  RETURN v_role = 'ADMIN';
EXCEPTION
  WHEN OTHERS THEN
    RETURN FALSE;
END;
/

// ruleid: plsql-vpd-policy-empty-predicate
FUNCTION vpd_tenant_policy(p_schema VARCHAR2, p_tab VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  RETURN 'tenant_id = SYS_CONTEXT(''app_ctx'', ''tenant_id'')';
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END;
/

// ruleid: plsql-vpd-policy-empty-predicate
FUNCTION vpd_org_security(p_schema IN VARCHAR2, p_object IN VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  IF SYS_CONTEXT('USERENV', 'CLIENT_INFO') IS NULL THEN
    RETURN '';
  END IF;
  RETURN 'org_id = SYS_CONTEXT(''USERENV'', ''CLIENT_INFO'')';
END;
/

// ruleid: plsql-vpd-policy-empty-predicate
FUNCTION vpd_local_context(p_schema IN VARCHAR2, p_object IN VARCHAR2) RETURN VARCHAR2 IS
  v_org_id VARCHAR2(50);
BEGIN
  v_org_id := SYS_CONTEXT('APP_SESSION_CTX', 'ORGANIZATION_ID');
  IF v_org_id IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN 'organization_id = ''' || v_org_id || '''';
END;
/

// ruleid: plsql-vpd-policy-empty-predicate
FUNCTION vpd_unconditional(p_schema VARCHAR2, p_object VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  RETURN NULL;
END;
/

// ok: plsql-vpd-policy-empty-predicate
FUNCTION vpd_tenant_policy_safe(p_schema VARCHAR2, p_tab VARCHAR2) RETURN VARCHAR2 IS
BEGIN
  RETURN 'tenant_id = SYS_CONTEXT(''app_ctx'', ''tenant_id'')';
EXCEPTION
  WHEN OTHERS THEN
    RETURN '1=0';
END;
/

// ok: plsql-vpd-policy-empty-predicate
FUNCTION get_customer_name(p_cust_id NUMBER) RETURN VARCHAR2 IS
  v_name VARCHAR2(100);
BEGIN
  SELECT name INTO v_name FROM customers WHERE id = p_cust_id;
  RETURN v_name;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    RETURN NULL;
END;
/

// ruleid: plsql-null-expands-scope-filter
SELECT * FROM permits WHERE (:p_tenant_id IS NULL OR tenant_id = :p_tenant_id);

// ruleid: plsql-null-expands-scope-filter
SELECT * FROM permits WHERE (p_org IS NULL OR org_id = p_org);

// ruleid: plsql-null-expands-scope-filter
SELECT * FROM permits t WHERE (:CTRL.ORG_ID IS NULL OR t.org_id = :CTRL.ORG_ID);

// ruleid: plsql-null-expands-scope-filter
SELECT * FROM permits t WHERE t.org_id = NVL(:CTRL.ORG_ID, t.org_id);

// ruleid: plsql-null-expands-scope-filter
SELECT * FROM permits t WHERE t.org_id = DECODE(:p_org, NULL, t.org_id, :p_org);

// ok: plsql-null-expands-scope-filter
SELECT * FROM permits WHERE tenant_id = :p_tenant_id;

// ok: plsql-null-expands-scope-filter
SELECT * FROM permits WHERE (:p_tenant_id IS NULL OR status = 'ACTIVE');
