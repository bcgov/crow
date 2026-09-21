import assert from "node:assert/strict";
import { createHash } from "node:crypto";
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

function codebaseOnlyState(managedFragment) {
  const serverCatalog = {
    schemaVersion: 1,
    protocolCompatibility: "MCP over stdio",
    dependencySemantics: "none",
    servers: []
  };
  return {
    schemaVersion: 1,
    delivery: "codebase-memory-only",
    raven: null,
    codebaseMemory: {
      version: "0.11.0",
      installPath: join(tmpdir(), "codebase-memory-mcp"),
      integrity: `sha512-${Buffer.from("integrity").toString("base64")}`,
      entrypointSha256: "a".repeat(64)
    },
    selectedServers: [],
    serverCatalog: {
      sha256: createHash("sha256").update(JSON.stringify(serverCatalog)).digest("hex"),
      ...serverCatalog
    },
    managedFragment,
    configuredAt: "2026-09-21T12:00:00.000Z",
    lastCheckedAt: new Date().toISOString(),
    previous: null
  };
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
  writeFileSync(
    join(stateDir, "state.json"),
    JSON.stringify(codebaseOnlyState(managedFragment))
  );
  writeFileSync(join(stateDir, "mcp-fragment.json"), JSON.stringify({ mcpServers: {} }));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(
    JSON.parse(readFileSync(join(stateDir, "mcp-fragment.json"), "utf8")),
    managedFragment
  );
});

test("status rejects partial state with a documented schema error", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  writeFileSync(join(stateDir, "state.json"), JSON.stringify({
    schemaVersion: 1,
    selectedServers: [],
    managedFragment: { mcpServers: {} }
  }));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /state is malformed or has an unsupported schema/);
  assert.doesNotMatch(result.stderr, /TypeError/);
});

test("plan supports an explicit codebase-memory-only selection", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const result = run([
    "plan",
    "--no-raven",
    "--codebase-memory-version", "0.11.0",
    "--state-dir", stateDir
  ]);
  assert.equal(result.status, 0, result.stderr);
  const plan = JSON.parse(result.stdout);
  assert.equal(plan.delivery, "codebase-memory-only");
  assert.equal(plan.raven, null);
  assert.deepEqual(plan.selectedServers, []);
  assert.equal(plan.commands.length, 1);
  assert.match(plan.codebaseMemory.installPath, /0\.11\.0-[0-9a-f-]{36}$/);
});

test("plan requires an explicit Raven or no-Raven choice", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const result = run([
    "plan",
    "--codebase-memory-version", "0.11.0",
    "--state-dir", stateDir
  ]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /explicitly select --no-raven/);
});

test("plan stages Raven builds in a generation-specific directory", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const revision = "a".repeat(40);
  const result = run([
    "plan",
    "--servers", "jira",
    "--raven-ref", revision,
    "--codebase-memory-version", "0.11.0",
    "--state-dir", stateDir
  ]);
  assert.equal(result.status, 0, result.stderr);
  const plan = JSON.parse(result.stdout);
  assert.match(plan.raven.runtimePath, new RegExp(`${revision}-[0-9a-f-]{36}$`));
  assert.equal(plan.commands.length, 5);
  assert.equal(plan.commands[0].args.at(-1), `${plan.raven.runtimePath}.staging-<pid>`);
  assert.equal(plan.commands[2].cwd, `${plan.raven.runtimePath}.staging-<pid>`);
});

test("setup rejects a future-dated plan", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const planPath = join(stateDir, "pending-plan.json");
  const serverCatalog = {
    schemaVersion: 1,
    protocolCompatibility: "MCP over stdio",
    dependencySemantics: "none",
    servers: []
  };
  writeFileSync(planPath, JSON.stringify({
    schemaVersion: 1,
    action: "setup",
    createdAt: new Date(Date.now() + 60_000).toISOString(),
    delivery: "codebase-memory-only",
    stateDir,
    raven: null,
    codebaseMemory: {
      version: "0.11.0",
      installPath: join(
        stateDir,
        "codebase-memory",
        "0.11.0-00000000-0000-0000-0000-000000000000"
      )
    },
    selectedServers: [],
    serverCatalog: {
      sha256: createHash("sha256").update(JSON.stringify(serverCatalog)).digest("hex"),
      ...serverCatalog
    }
  }));
  const result = run([
    "setup",
    "--plan", planPath,
    "--plan-sha256", "0".repeat(64),
    "--confirm"
  ]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /timestamp is invalid or outside the 24-hour confirmation window/);
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
