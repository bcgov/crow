# Verify and Troubleshoot

Load after config is applied and credentials are entered, or when a user
reports an authentication or connection failure.

## Verify in three levels

1. **Installed:** `node scripts/crow-raven-setup.mjs check`.
2. **Configured:** `config preview` shows no pending change; the client has
   been fully restarted.
3. **Authenticated:** after restart, make one read-only call per selected
   server, for example Confluence `list_spaces` or Jira `search_issues` with
   a small limit. Report pass or fail per server. Never use a write tool to
   test.

A server that starts but fails level 3 is **not verified**. Do not report
setup complete; authentication failures remain failures.

## Error classification

| Symptom | Likely cause | Next step |
|---|---|---|
| 404 on Confluence or Jira | Wrong base URL or missing path (Cloud Confluence needs `/wiki`) | Recheck the site type and URL in `credentials.md` |
| 401 | Wrong credential type or value (password versus API token) | Re-run the credential tool; do not retry in a loop |
| 403 | Account lacks access, or a different site or gateway than the credential was issued for | Confirm the site with the user; check access outside Raven |
| 410 on a search call | Endpoint removed on that Atlassian Cloud version | Report to the Raven maintainers; do not work around it silently |
| "No valid SMSESSION" | SMSESSION fallback expired or Playwright Chromium missing | `npx playwright install chromium`, then retry |
| Tools absent in client | Client not restarted, or config written to a different file | Restart; confirm the config path for the chosen client |

Raven's credential scripts may reject or lose input when a value is invalid;
if the user must retype everything, say that it is a known rough edge and
suggest editing only the failing value.

## Stop conditions

After two failed attempts on the same server, stop, summarise what was tried,
and let the user decide: skip that server, escalate to the Raven maintainers,
or continue later. Setup state keeps the other servers' results.
