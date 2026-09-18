import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";

const script = fileURLToPath(new URL("./crow-raven-setup.mjs", import.meta.url));

function run(args) {
  return spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    windowsHide: true
  });
}

test("list emits reviewed Raven servers", () => {
  const result = run(["list", "--group", "atlassian"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /^jira\tatlassian\t/m);
  assert.doesNotMatch(result.stdout, /^sonar\t/m);
});

test("status reports an unconfigured custom state directory", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 0, result.stderr);
  const output = JSON.parse(result.stdout);
  assert.equal(output.configured, false);
  assert.equal(output.stateDir, stateDir);
});

test("setup requires explicit confirmation before prerequisite or network work", () => {
  const result = run(["setup", "--plan", "not-used.json"]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /requires --confirm/);
});

test("status reconciles the generated fragment from authoritative state", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const managedFragment = {
    mcpServers: {
      "codebase-memory-mcp": { command: process.execPath, args: ["verified-bin.js"] }
    }
  };
  writeFileSync(join(stateDir, "state.json"), JSON.stringify({
    schemaVersion: 1,
    selectedServers: [],
    managedFragment
  }));
  writeFileSync(join(stateDir, "mcp-fragment.json"), JSON.stringify({ mcpServers: {} }));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(
    JSON.parse(readFileSync(join(stateDir, "mcp-fragment.json"), "utf8")),
    managedFragment
  );
});

test("catalog has unique IDs, safe entrypoints, and selection metadata", () => {
  const catalog = JSON.parse(readFileSync(new URL("../resources/raven-servers.json", import.meta.url), "utf8"));
  const ids = catalog.servers.map((server) => server.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const server of catalog.servers) {
    assert.match(server.id, /^[a-z][a-z0-9-]+$/);
    assert.match(server.entrypoint, /^packages\/[a-z0-9-]+\/dist\/index\.js$/);
    assert.equal(server.entrypoint.includes(".."), false);
    assert.match(server.packageVersion, /^\d+\.\d+\.\d+$/);
    assert.ok(["read-only", "read-write", "mixed"].includes(server.access));
    assert.equal(typeof server.authentication, "string");
    assert.equal(typeof server.securityStatus, "string");
  }
});
