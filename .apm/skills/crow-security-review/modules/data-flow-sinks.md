# Module: Cross-File Data Flow — Entry Points to Dangerous Sinks

**Purpose:** Use codebase-memory-mcp `trace_path` to verify whether untrusted input actually reaches dangerous sinks across multiple files. This is what SonarQube's single-file analysis cannot do effectively.

## Strategy

1. **Enumerate entry points** via `search_graph` — controllers, message handlers, CLI parsers, webhook receivers, scheduled jobs with external input
2. **Enumerate dangerous sinks** via `search_graph`:
   - SQL execution (raw queries, string interpolation in query builders)
   - OS command execution
   - File path construction from input
   - HTTP client URL construction (SSRF)
   - Template rendering with user-controlled template names
   - Redirect URL construction
   - Deserialization of external data
   - LDAP/XPath query construction
   - LLM prompt/message construction, retrieval context, and memory ingestion
   - Model-output-driven tools, commands, URLs, SQL, file writes, or unsafe HTML/Markdown rendering
3. **For each sink**, run `trace_path direction="inbound"` to find which entry points reach it
4. **For reachable paths**, read intermediate code at each hop to check for sanitization/validation
5. **Classify** as Confirmed (no sanitization found), Probable (sanitization may exist but couldn't fully verify), or safe (sanitization verified)

## Sink Patterns by Language

### SQL Execution Sinks

| Language | Dangerous Sink | Safe Alternative (NOT a finding) |
|----------|---------------|----------------------------------|
| Java | `Statement.execute*` with string concat | `PreparedStatement` with `?` params |
| Java | `EntityManager.createNativeQuery(str)` with concat | `createQuery` with named params |
| Java | `JdbcTemplate.query(sql)` where sql includes `+` | `JdbcTemplate.query(sql, args)` |
| C# | `FromSqlRaw(interpolated)` | `FromSqlInterpolated()` or parameterized |
| C# | `ExecuteSqlRaw` without parameters | `ExecuteSqlInterpolated` |
| C# | `new SqlCommand(concat)` | `SqlCommand` with `SqlParameter` |
| Python | `cursor.execute(f"..." )` / `.format()` | `cursor.execute("...%s", (param,))` |
| Python | `django.db.connection.cursor()` with concat | ORM queries or parameterized raw |
| Node.js | `connection.query(concat)` | `connection.query(sql, [params])` |
| Go | `db.Query(fmt.Sprintf(...))` | `db.Query(sql, args...)` |
| PHP | `$pdo->query($concat)` | `$pdo->prepare($sql)->execute($params)` |
| Ruby | `ActiveRecord::Base.connection.execute(interpolated)` | `where` with hash conditions |

### Command Execution Sinks

| Language | Dangerous Sink | Safe Alternative |
|----------|---------------|-----------------|
| Java | `Runtime.exec(userInput)` | Allowlisted commands, no user-controlled args |
| Java | `ProcessBuilder` with user-controlled args | Strict input validation + allowlist |
| Python | `os.system(input)`, `subprocess(..., shell=True)` | `subprocess.run([cmd, arg], shell=False)` |
| Node.js | `child_process.exec(input)` | `child_process.execFile(cmd, [args])` |
| C# | `Process.Start(input)` | Hardcoded executable + validated args |
| PHP | `exec($input)`, `system()`, `passthru()` | Escaped + allowlisted commands |
| Go | `exec.Command(userInput)` | Hardcoded command + validated args |
| Ruby | `` `#{input}` ``, `system(input)` | `Open3.capture3(cmd, arg)` |

### SSRF Sinks

| Language | Dangerous Pattern |
|----------|------------------|
| Java | `new URL(request.getParameter("url")).openConnection()` |
| Java | `RestTemplate.getForObject(userUrl, ...)` |
| C# | `HttpClient.GetAsync(userUrl)` |
| Python | `requests.get(user_url)` |
| Node.js | `axios.get(req.body.url)` / `fetch(userInput)` |
| Go | `http.Get(userURL)` |

**Mitigation check:** Look for URL validation, allowlist filtering, or SSRF protection middleware before the HTTP call.

### File Path Sinks

| Language | Dangerous Pattern |
|----------|------------------|
| Java | `new File(basePath + userInput)` without canonicalization |
| C# | `Path.Combine(base, userInput)` without `GetFullPath` + prefix check |
| Python | `open(os.path.join(base, user_input))` without normalization |
| Node.js | `fs.readFile(path.join(dir, req.params.file))` without validation |
| Go | `os.Open(filepath.Join(base, userInput))` without `filepath.Clean` + prefix |

**Mitigation check:** Canonicalization (`Path.GetFullPath`, `realpath`, `filepath.Clean`) followed by prefix validation.

## Multi-Hop Tracing Protocol

When `trace_path` reveals a path from entry point to sink:

1. Read the entry point code — how is user input extracted?
2. Read each intermediate service/method — is input transformed, validated, or sanitized?
3. Read the sink code — does it use the input directly or through a safe API?
4. Document the full trace in the finding: `Controller → Service → Repository → SQL`

**Example finding format:**
```
Entry: UserController.updateProfile(request) [src/controllers/UserController.java:45]
  → ProfileService.update(dto) [src/services/ProfileService.java:78]
    → UserRepository.updateByQuery(name) [src/repositories/UserRepository.java:23]
      → SINK: Statement.executeQuery("SELECT ... WHERE name='" + name + "'")
Sanitization found: NONE
Classification: Confirmed
```

## What This Catches That SonarQube Doesn't

- Multi-hop injection (input enters in Controller A, passed through Service B, reaches SQL in Repository C)
- SSRF through indirect URL construction (config + user input combined across files)
- Command injection through argument arrays built across multiple methods
- Path traversal where the path is constructed in a utility method separate from the file access
- Template injection where template name comes from a database lookup driven by user input
- Direct or stored/second-order prompt injection where untrusted content reaches an LLM context and influences a privileged sink
- Insecure model-output handling where model text reaches executable or active-content sinks without independent validation/encoding

For LLM, agent, RAG, or Markdown paths, load `llm-prompt-and-markdown-security.md` and trace across storage/retrieval boundaries; a database or vector store is an intermediate hop, not the end of the flow.
