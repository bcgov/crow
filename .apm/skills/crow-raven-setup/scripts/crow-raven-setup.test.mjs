import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  createFragment,
  parseCrowOutdatedOutput,
  ravenRepositoryUrl,
  releasedServers,
  sha256Tree,
  startupInvocation,
  validateReleaseCatalog,
  validateReleaseManifest,
  verifyStartup
} from "./crow-raven-setup.mjs";

const script = fileURLToPath(new URL("./crow-raven-setup.mjs", import.meta.url));

function run(args) {
  return spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    windowsHide: true
  });
}

function codebaseOnlyState(stateDir) {
  const serverCatalog = {
    schemaVersion: 1,
    protocolCompatibility: "MCP over stdio",
    dependencySemantics: "none",
    servers: []
  };
  const installPath = join(
    stateDir,
    "codebase-memory",
    "0.11.0-00000000-0000-0000-0000-000000000000"
  );
  return {
    schemaVersion: 1,
    delivery: "codebase-memory-only",
    raven: null,
    codebaseMemory: {
      version: "0.11.0",
      installPath,
      integrity: `sha512-${Buffer.from("integrity").toString("base64")}`,
      entrypointSha256: "a".repeat(64)
    },
    selectedServers: [],
    serverCatalog: {
      sha256: createHash("sha256").update(JSON.stringify(serverCatalog)).digest("hex"),
      ...serverCatalog
    },
    managedFragment: createFragment(
      null,
      [],
      installPath,
      "codebase-memory-only",
      false
    ),
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

test("parses an outstanding Crow APM update without treating current output as stale", () => {
  assert.deepEqual(
    parseCrowOutdatedOutput("bcgov/crow  v0.9.1  -  v0.9.2  outdated  git tags"),
    { reported: true, status: "outdated", updateAvailable: true }
  );
  assert.deepEqual(
    parseCrowOutdatedOutput("[+] All dependencies are up-to-date."),
    { reported: false, status: null, updateAvailable: false }
  );
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
  const state = codebaseOnlyState(stateDir);
  writeFileSync(
    join(stateDir, "state.json"),
    JSON.stringify(state)
  );
  writeFileSync(join(stateDir, "mcp-fragment.json"), JSON.stringify({ mcpServers: {} }));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(
    JSON.parse(readFileSync(join(stateDir, "mcp-fragment.json"), "utf8")),
    state.managedFragment
  );
});

test("status rejects injected managed fragment commands", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  const state = codebaseOnlyState(stateDir);
  state.managedFragment.mcpServers.injected = {
    command: process.execPath,
    args: ["malicious.js"]
  };
  writeFileSync(join(stateDir, "state.json"), JSON.stringify(state));
  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /state is malformed|unmanaged paths or fragment commands/);
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

test("status recovers an interrupted uncommitted promotion", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-test-"));
  writeFileSync(
    join(stateDir, "state.json"),
    JSON.stringify(codebaseOnlyState(stateDir))
  );
  const installPath = join(stateDir, "codebase-memory", "0.11.0-new-generation");
  const stagingPath = `${installPath}.staging-1234`;
  const runtimePath = join(stateDir, "versions", "0.1.0-win32-x64-new-generation");
  const runtimeStagingPath = `${runtimePath}.staging-1234`;
  const extractionPath = `${runtimePath}.extract-1234`;
  const archivePath = `${runtimePath}.download-1234.tar.gz`;
  mkdirSync(installPath, { recursive: true });
  mkdirSync(stagingPath);
  mkdirSync(runtimePath, { recursive: true });
  mkdirSync(runtimeStagingPath);
  mkdirSync(extractionPath);
  writeFileSync(archivePath, "partial archive");
  writeFileSync(join(stateDir, "pending-promotion.json"), JSON.stringify({
    schemaVersion: 1,
    codebaseMemory: { stagingPath, installPath },
    raven: { stagingPath: runtimeStagingPath, runtimePath },
    temporaryPaths: [extractionPath, archivePath]
  }));

  const result = run(["status", "--state-dir", stateDir]);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(installPath), false);
  assert.equal(existsSync(stagingPath), false);
  assert.equal(existsSync(runtimePath), false);
  assert.equal(existsSync(runtimeStagingPath), false);
  assert.equal(existsSync(extractionPath), false);
  assert.equal(existsSync(archivePath), false);
  assert.equal(existsSync(join(stateDir, "pending-promotion.json")), false);
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
  assert.equal(plan.commands.length, process.platform === "win32" ? 2 : 1);
  if (process.platform === "win32") {
    assert.ok(plan.commands[0].args.includes("--ignore-scripts"));
    assert.match(plan.commands[1].note, /120000ms candidate timeout/);
  }
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
    "--delivery", "source",
    "--raven-ref", revision,
    "--codebase-memory-version", "0.11.0",
    "--state-dir", stateDir
  ]);
  assert.equal(result.status, 0, result.stderr);
  const plan = JSON.parse(result.stdout);
  assert.match(plan.raven.runtimePath, new RegExp(`${revision}-[0-9a-f-]{36}$`));
  assert.equal(plan.commands.length, process.platform === "win32" ? 6 : 5);
  assert.equal(plan.commands[0].args.at(-1), `${plan.raven.runtimePath}.staging-<pid>`);
  assert.equal(plan.commands[2].cwd, `${plan.raven.runtimePath}.staging-<pid>`);
});

test("Raven release metadata reconciles reviewed servers and native launchers", () => {
  const version = "0.1.0";
  const platform = `${process.platform}-${process.arch}`;
  const manifest = {
    schemaVersion: 1,
    suiteVersion: version,
    sourceRepository: ravenRepositoryUrl,
    sourceCommit: "a".repeat(40),
    platform,
    nodeVersion: "24.21.0",
    protocolCompatibility: "MCP over stdio",
    archive: `raven-${version}-${platform}.tar.gz`,
    archiveSha256: "b".repeat(64),
    catalog: "server-catalog.json",
    catalogSha256: "c".repeat(64),
    smokeTests: { status: "passed", startedServerCount: 17 }
  };
  const releasedCatalog = {
    schemaVersion: 1,
    suiteVersion: version,
    nodeVersion: "24.21.0",
    protocolCompatibility: "MCP over stdio",
    supportedPlatforms: [platform],
    servers: Array.from({ length: 17 }, (_, index) => ({
      id: index === 0 ? "jira" : `server-${index}`,
      package: index === 0 ? "@bcgov/raven-jira" : `@bcgov/raven-server-${index}`,
      launcher: index === 0 ? "raven-jira" : `raven-server-${index}`,
      entrypoint: index === 0 ? "packages/jira/dist/index.js" : `packages/server-${index}/dist/index.js`,
      packageVersion: "0.1.0",
      access: "read-write"
    }))
  };
  validateReleaseManifest(manifest, version, platform);
  validateReleaseCatalog(releasedCatalog, manifest);
  const reviewed = [{
    id: "jira",
    group: "atlassian",
    description: "Jira",
    entrypoint: "packages/jira/dist/index.js",
    packageVersion: "0.1.0",
    access: "read-write"
  }];
  const selected = releasedServers(reviewed, releasedCatalog);
  assert.equal(selected[0].launcher, "raven-jira");

  const root = mkdtempSync(join(tmpdir(), "crow-raven-release-"));
  const codebase = join(root, "codebase");
  const runtime = join(root, "raven");
  const codebaseEntrypoint = join(codebase, "node_modules", "codebase-memory-mcp", "bin.js");
  const launcher = join(runtime, "bin", process.platform === "win32" ? "raven-jira.cmd" : "raven-jira");
  mkdirSync(join(codebase, "node_modules", "codebase-memory-mcp"), { recursive: true });
  mkdirSync(join(runtime, "bin"), { recursive: true });
  writeFileSync(codebaseEntrypoint, "");
  writeFileSync(launcher, "");
  const fragment = createFragment(runtime, selected, codebase, "bundled-release");
  assert.deepEqual(fragment.mcpServers.jira, { command: launcher, args: [] });
  const invocation = startupInvocation(launcher, []);
  if (process.platform === "win32") {
    assert.equal(invocation.command, process.env.ComSpec);
    assert.deepEqual(invocation.args, ["/d", "/s", "/c", "call", launcher]);
    const spacedDirectory = join(root, "path with spaces");
    const smokeLauncher = join(spacedDirectory, "raven-smoke.cmd");
    mkdirSync(spacedDirectory);
    writeFileSync(smokeLauncher, "@exit /b 0\r\n");
    const smokeInvocation = startupInvocation(smokeLauncher, []);
    const smoke = spawnSync(smokeInvocation.command, smokeInvocation.args);
    assert.equal(smoke.status, 0, smoke.error?.message);
  } else {
    assert.deepEqual(invocation, { command: launcher, args: [] });
  }
});

test("runtime tree digest detects generated and launcher changes", async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-raven-tree-"));
  mkdirSync(join(root, "bin"));
  writeFileSync(join(root, "bin", "raven-test"), "launcher");
  mkdirSync(join(root, "packages"));
  writeFileSync(join(root, "packages", "server.js"), "compiled");
  const original = await sha256Tree(root);
  writeFileSync(join(root, "packages", "server.js"), "modified");
  assert.notEqual(await sha256Tree(root), original);
});

test("Windows startup verification terminates the launcher process tree", {
  skip: process.platform !== "win32"
}, async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-raven-process-tree-"));
  const pidPath = join(root, "child.pid");
  const launcher = join(root, "raven-tree.cmd");
  writeFileSync(
    launcher,
    `@"${process.execPath}" -e "require('fs').writeFileSync(process.argv[1],String(process.pid));setInterval(()=>{},1000)" "${pidPath}"\r\n`
  );
  await verifyStartup("Windows process-tree fixture", launcher, [], root);
  const childPid = Number(readFileSync(pidPath, "utf8"));
  assert.throws(() => process.kill(childPid, 0));
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
