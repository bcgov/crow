import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  unlinkSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { applyClientConfig, previewClientConfig } from "./client-config.mjs";
import {
  checkCrowApmUpdate,
  checkCrowUpdates,
  createFragment,
  createCrowUpdateHookConfig,
  handleUpdateHookEvent,
  fetchLatestCodebaseVersion,
  findExecutable,
  latestCrowVersion,
  latestRavenVersion,
  markCrowUpdateNotified,
  resolveInstalledCrowPackage,
  parseCrowOutdatedOutput,
  persistSuccessfulFreshnessCheck,
  ravenRepositoryUrl,
  releasedServers,
  sha256Tree,
  startupInvocation,
  taskkillTerminationError,
  validateReleaseCatalog,
  validateReleaseManifest,
  verifyStartup,
  verifyGitHubAuth
} from "./crow-raven-setup.mjs";

const script = fileURLToPath(new URL("./crow-raven-setup.mjs", import.meta.url));

const noManagedUpdateVersions = () => ({ raven: null, codebaseMemory: null });

function configFixture(client = "copilot") {
  const root = mkdtempSync(join(tmpdir(), "crow-config-fixture-"));
  const fragment = join(root, "mcp-fragment.json");
  const config = join(root, "mcp-config.json");
  writeFileSync(fragment, JSON.stringify({
    mcpServers: {
      sonar: { command: "node", args: [join(root, "sonar.js")] },
      "codebase-memory-mcp": { command: "node", args: [join(root, "memory.js")] }
    }
  }));
  return { root, config, args: { client, config, fragment } };
}

test("VS Code and Copilot merge into the global mcp-config.json and remain idempotent", () => {
  const fixture = configFixture();
  const unrelated = { mcpServers: { existing: { command: "tool", args: [] } }, inputs: [{ id: "keep" }] };
  writeFileSync(fixture.config, JSON.stringify(unrelated));
  const preview = previewClientConfig(fixture.args);
  assert.equal(preview.configPath, fixture.config);
  assert.deepEqual(preview.added, ["sonar", "codebase-memory-mcp"]);
  assert.deepEqual(preview.proposed.sonar, {
    command: "node", args: [join(fixture.root, "sonar.js")]
  });
  assert.throws(() => applyClientConfig(fixture.args), /requires --approval-sha256/);
  const applied = applyClientConfig({
    ...fixture.args, "approval-sha256": preview.approvalSha256, confirm: true
  });
  assert.equal(applied.applied, true);
  assert.deepEqual(JSON.parse(readFileSync(applied.backupPath, "utf8")), unrelated);
  const merged = JSON.parse(readFileSync(fixture.config, "utf8"));
  assert.deepEqual(merged.inputs, unrelated.inputs);
  assert.deepEqual(merged.mcpServers.existing, unrelated.mcpServers.existing);
  assert.deepEqual(Object.keys(merged.mcpServers), ["existing", "sonar", "codebase-memory-mcp"]);
  const repeat = previewClientConfig(fixture.args);
  assert.deepEqual(repeat.added, []);
  assert.equal(applyClientConfig({
    ...fixture.args, "approval-sha256": repeat.approvalSha256, confirm: true
  }).applied, false);
});

test("config merge rejects stale previews, collisions, malformed and wrong-schema files", () => {
  const fixture = configFixture();
  const preview = previewClientConfig(fixture.args);
  writeFileSync(fixture.config, JSON.stringify({ mcpServers: { other: { command: "other" } } }));
  assert.throws(() => applyClientConfig({
    ...fixture.args, "approval-sha256": preview.approvalSha256, confirm: true
  }), /changed since preview/);
  assert.equal(existsSync(`${fixture.config}.crow.lock`), false);
  writeFileSync(fixture.config, JSON.stringify({ mcpServers: { sonar: { command: "not-crow" } } }));
  assert.throws(() => previewClientConfig(fixture.args), /collision/);
  writeFileSync(fixture.config, "{");
  assert.throws(() => previewClientConfig(fixture.args), /malformed/);
  writeFileSync(fixture.config, JSON.stringify({ servers: {} }));
  assert.throws(() => previewClientConfig(fixture.args), /not the selected client's mcpServers format/);
  unlinkSync(fixture.config);
  assert.throws(() => previewClientConfig({ ...fixture.args, config: join(fixture.root, "settings.json") }), /unsupported configuration file/);
  assert.throws(() => previewClientConfig({ ...fixture.args, config: join(fixture.root, "mcp.json") }), /unsupported configuration file/);
  assert.throws(() => previewClientConfig({ ...fixture.args, client: "vscode" }), /Choose --client copilot/);
  assert.equal(existsSync(join(fixture.root, "mcp.json")), false);
});

test("already migrated VS Code entries with stdio type are verified, not duplicated", () => {
  const fixture = configFixture();
  const fragment = JSON.parse(readFileSync(fixture.args.fragment, "utf8"));
  writeFileSync(fixture.config, JSON.stringify({
    mcpServers: {
      sonar: { type: "stdio", ...fragment.mcpServers.sonar },
      "codebase-memory-mcp": fragment.mcpServers["codebase-memory-mcp"]
    }
  }));
  const preview = previewClientConfig(fixture.args);
  assert.deepEqual(preview.added, []);
  assert.deepEqual(preview.unchanged, ["sonar", "codebase-memory-mcp"]);
  const applied = applyClientConfig({
    ...fixture.args, "approval-sha256": preview.approvalSha256, confirm: true
  });
  assert.equal(applied.applied, false);
  assert.equal(applied.backupPath, null);
});

test("approved upgrades replace only previous Crow-managed entries and preserve unrelated config", () => {
  const fixture = configFixture();
  const previousEntries = JSON.parse(readFileSync(fixture.args.fragment, "utf8")).mcpServers;
  const managedEntries = {
    sonar: { command: "node", args: [join(fixture.root, "new-sonar.js")] },
    "codebase-memory-mcp": { command: "node", args: [join(fixture.root, "new-memory.js")] },
    jira: { command: "node", args: [join(fixture.root, "jira.js")] }
  };
  const args = { ...fixture.args, managedEntries, previousEntries };
  const before = {
    mcpServers: {
      sonar: { type: "stdio", ...previousEntries.sonar },
      "codebase-memory-mcp": previousEntries["codebase-memory-mcp"],
      other: { command: "other", args: [] }
    },
    inputs: [{ id: "keep" }]
  };
  writeFileSync(fixture.config, JSON.stringify(before));
  const preview = previewClientConfig(args);
  assert.deepEqual(preview.added, ["jira"]);
  assert.deepEqual(preview.replaced, ["sonar", "codebase-memory-mcp"]);
  assert.deepEqual(preview.proposed, managedEntries);
  assert.equal(preview.backupRequired, true);
  const applied = applyClientConfig({
    ...args, "approval-sha256": preview.approvalSha256, confirm: true
  });
  assert.equal(applied.applied, true);
  assert.deepEqual(JSON.parse(readFileSync(applied.backupPath, "utf8")), before);
  const after = JSON.parse(readFileSync(fixture.config, "utf8"));
  assert.deepEqual(after.inputs, before.inputs);
  assert.deepEqual(after.mcpServers.other, before.mcpServers.other);
  assert.deepEqual(after.mcpServers.sonar, managedEntries.sonar);
  assert.deepEqual(after.mcpServers["codebase-memory-mcp"], managedEntries["codebase-memory-mcp"]);
  assert.deepEqual(after.mcpServers.jira, managedEntries.jira);
  assert.deepEqual(previewClientConfig(args).replaced, []);
  writeFileSync(fixture.config, JSON.stringify({
    ...before,
    mcpServers: { ...before.mcpServers, sonar: { command: "user-custom", args: [] } }
  }));
  assert.throws(() => previewClientConfig(args), /collision.*sonar/);
  writeFileSync(fixture.config, JSON.stringify(before));
  const stale = previewClientConfig(args);
  writeFileSync(fixture.config, JSON.stringify({
    ...before,
    mcpServers: { ...before.mcpServers, other: { command: "changed", args: [] } }
  }));
  assert.throws(() => applyClientConfig({
    ...args, "approval-sha256": stale.approvalSha256, confirm: true
  }), /changed since preview/);
});

test("another editor's verified portable mcp.json preserves unrelated settings", () => {
  const fixture = configFixture("portable");
  fixture.config = join(fixture.root, "mcp.json");
  fixture.args.config = fixture.config;
  writeFileSync(fixture.config, JSON.stringify({ mcpServers: { keep: { command: "keep" } }, other: true }));
  const preview = previewClientConfig(fixture.args);
  const applied = applyClientConfig({
    ...fixture.args, "approval-sha256": preview.approvalSha256, confirm: true
  });
  assert.equal(applied.applied, true);
  const merged = JSON.parse(readFileSync(fixture.config, "utf8"));
  assert.equal(merged.other, true);
  assert.equal(merged.mcpServers.keep.command, "keep");
  assert.equal(merged.mcpServers.sonar.command, "node");
});

test("findExecutable distinguishes a PATH entry from a standard Windows location", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-prerequisite-"));
  const nodeDir = join(root, "nodejs");
  mkdirSync(nodeDir);
  writeFileSync(join(nodeDir, "node.exe"), "");
  const env = { PATH: "", ProgramFiles: root, LOCALAPPDATA: root, USERPROFILE: root };
  assert.deepEqual(findExecutable("node", env, "win32", join(root, "unknown.exe")), {
    path: join(nodeDir, "node.exe"), source: "standard-location"
  });
  assert.deepEqual(findExecutable("node", { ...env, PATH: nodeDir }, "win32", join(root, "unknown.exe")), {
    path: join(nodeDir, "node.exe"), source: "PATH"
  });
});

test("GitHub authentication must succeed before Raven release planning", () => {
  assert.throws(
    () => verifyGitHubAuth((command, args) => {
      assert.equal(command, "gh");
      assert.deepEqual(args, ["auth", "status"]);
      throw new Error("GitHub CLI is not authenticated");
    }),
    /not authenticated/
  );
});

test("CLI dry-run plans and merges only a temporary client configuration", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-config-cli-"));
  const stateDir = join(root, "state");
  mkdirSync(stateDir);
  const plan = run([
    "plan", "--no-raven", "--state-dir", stateDir,
    "--codebase-memory-version", "0.11.0"
  ]);
  assert.equal(plan.status, 0, plan.stderr);
  assert.match(JSON.parse(plan.stdout).planSha256, /^[a-f0-9]{64}$/);
  const state = codebaseOnlyState(stateDir);
  writeFileSync(join(stateDir, "state.json"), JSON.stringify(state));
  writeFileSync(join(stateDir, "mcp-fragment.json"), JSON.stringify(state.managedFragment));
  const config = join(root, "mcp-config.json");
  const options = ["--state-dir", stateDir, "--client", "copilot"];
  const env = { COPILOT_HOME: root };
  const preview = run(["config", "preview", ...options], undefined, env);
  assert.equal(preview.status, 0, preview.stderr);
  const reviewed = JSON.parse(preview.stdout);
  assert.equal(reviewed.configPath, config);
  assert.deepEqual(reviewed.added, ["codebase-memory-mcp"]);
  assert.equal(Object.hasOwn(reviewed, "content"), false);
  assert.equal(existsSync(config), false);
  const apply = run(["config", "apply", ...options, "--approval-sha256", reviewed.approvalSha256, "--confirm"], undefined, env);
  assert.equal(apply.status, 0, apply.stderr);
  assert.equal(JSON.parse(apply.stdout).applied, true);
  assert.deepEqual(
    Object.keys(JSON.parse(readFileSync(config, "utf8")).mcpServers),
    ["codebase-memory-mcp"]
  );
  const retry = run(["config", "preview", ...options], undefined, env);
  assert.equal(retry.status, 0, retry.stderr);
  assert.deepEqual(JSON.parse(retry.stdout).unchanged, ["codebase-memory-mcp"]);
});

test("CLI upgrade and rollback use only verified previous Crow fragments for replacements", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-config-upgrade-"));
  const stateDir = join(root, "state");
  mkdirSync(stateDir);
  const state = codebaseOnlyState(stateDir);
  const oldSnapshot = {
    delivery: state.delivery,
    raven: state.raven,
    codebaseMemory: state.codebaseMemory,
    selectedServers: state.selectedServers,
    serverCatalog: state.serverCatalog,
    managedFragment: state.managedFragment
  };
  const oldDefinition = state.managedFragment.mcpServers["codebase-memory-mcp"];
  state.previous = oldSnapshot;
  state.codebaseMemory = {
    ...state.codebaseMemory,
    installPath: join(stateDir, "codebase-memory", "0.11.0-11111111-1111-1111-1111-111111111111")
  };
  state.managedFragment = createFragment(
    null, [], state.codebaseMemory.installPath, "codebase-memory-only", false
  );
  writeFileSync(join(stateDir, "state.json"), JSON.stringify(state));
  const config = join(root, "mcp-config.json");
  writeFileSync(config, JSON.stringify({ mcpServers: { "codebase-memory-mcp": oldDefinition } }));
  const options = ["--state-dir", stateDir, "--client", "copilot"];
  const env = { COPILOT_HOME: root };
  const upgrade = run(["config", "preview", ...options], undefined, env);
  assert.equal(upgrade.status, 0, upgrade.stderr);
  const upgradePreview = JSON.parse(upgrade.stdout);
  assert.deepEqual(upgradePreview.replaced, ["codebase-memory-mcp"]);
  const upgraded = run([
    "config", "apply", ...options,
    "--approval-sha256", upgradePreview.approvalSha256, "--confirm"
  ], undefined, env);
  assert.equal(upgraded.status, 0, upgraded.stderr);
  assert.equal(JSON.parse(upgraded.stdout).applied, true);
  assert.deepEqual(
    JSON.parse(readFileSync(config, "utf8")).mcpServers["codebase-memory-mcp"],
    state.managedFragment.mcpServers["codebase-memory-mcp"]
  );

  const newSnapshot = {
    delivery: state.delivery,
    raven: state.raven,
    codebaseMemory: state.codebaseMemory,
    selectedServers: state.selectedServers,
    serverCatalog: state.serverCatalog,
    managedFragment: state.managedFragment
  };
  writeFileSync(join(stateDir, "state.json"), JSON.stringify({
    ...state, ...oldSnapshot, previous: newSnapshot
  }));
  const rollback = run(["config", "preview", ...options], undefined, env);
  assert.equal(rollback.status, 0, rollback.stderr);
  const rollbackPreview = JSON.parse(rollback.stdout);
  assert.deepEqual(rollbackPreview.replaced, ["codebase-memory-mcp"]);
  const restored = run([
    "config", "apply", ...options,
    "--approval-sha256", rollbackPreview.approvalSha256, "--confirm"
  ], undefined, env);
  assert.equal(restored.status, 0, restored.stderr);
  assert.deepEqual(
    JSON.parse(readFileSync(config, "utf8")).mcpServers["codebase-memory-mcp"],
    oldDefinition
  );
});

function run(args, input, env) {
  return spawnSync(process.execPath, [script, ...args], {
    encoding: "utf8",
    input,
    env: env ? { ...process.env, ...env } : process.env,
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

function bundledRavenState(stateDir) {
  const state = codebaseOnlyState(stateDir);
  const servers = [{ id: "jira", launcher: "jira" }];
  const serverCatalog = {
    schemaVersion: 1,
    protocolCompatibility: "MCP over stdio",
    dependencySemantics: "none",
    servers
  };
  const runtimePath = join(stateDir, "versions", "0.1.0");
  state.delivery = "bundled-release";
  state.raven = {
    delivery: "bundled-release",
    suiteVersion: "0.1.0",
    platform: `${process.platform}-${process.arch}`,
    runtimePath,
    runtimeTreeSha256: "b".repeat(64),
    sourceCommit: "c".repeat(40),
    archiveSha256: "d".repeat(64),
    releaseTag: "v0.1.0"
  };
  state.selectedServers = ["jira"];
  state.serverCatalog = {
    sha256: createHash("sha256").update(JSON.stringify(serverCatalog)).digest("hex"),
    ...serverCatalog
  };
  state.managedFragment = createFragment(
    runtimePath,
    servers,
    state.codebaseMemory.installPath,
    "bundled-release",
    false
  );
  return state;
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
  const ansiEscape = String.fromCodePoint(27);
  assert.equal(
    parseCrowOutdatedOutput(
      `${ansiEscape}[32mbcgov/crow  v0.9.1  -  v0.9.2  outdated  git tags${ansiEscape}[0m`
    ).updateAvailable,
    true
  );
});

test("checks the globally installed Crow package through APM", () => {
  const calls = [];
  const result = checkCrowApmUpdate((args) => {
    calls.push(args);
    if (args[0] === "view") {
      return {
        status: 0,
        stdout: "Version: 0.9.1",
        stderr: "",
        error: null
      };
    }
    return {
      status: 0,
      stdout: "bcgov/crow  v0.9.1  -  v0.9.2  outdated  git tags",
      stderr: "",
      error: null
    };
  });
  assert.deepEqual(calls, [
    ["view", "bcgov/crow", "--global"],
    ["outdated", "--global"]
  ]);
  assert.deepEqual(result, {
    checked: true,
    configured: true,
    current: "0.9.1",
    updateAvailable: true,
    source: "apm outdated --global"
  });
});

test("reports an up-to-date globally installed Crow package", () => {
  const result = checkCrowApmUpdate((args) => {
    if (args[0] === "view") {
      return { status: 0, stdout: "Version: 0.9.2", stderr: "", error: null };
    }
    return {
      status: 0,
      stdout: "bcgov/crow  v0.9.2  -  v0.9.2  up-to-date  git tags",
      stderr: "",
      error: null
    };
  });
  assert.equal(result.checked, true);
  assert.equal(result.updateAvailable, false);
});

test("reports an unavailable APM installation as an unknown Crow update state", () => {
  const result = checkCrowApmUpdate(() => ({
    status: null,
    stdout: "",
    stderr: "",
    error: { code: "ENOENT", message: "apm was not found" }
  }));
  assert.equal(result.checked, false);
  assert.equal(result.updateAvailable, null);
  assert.equal(result.reason, "apm-not-installed");
});

test("reports an APM freshness failure as an unknown Crow update state", () => {
  let callCount = 0;
  const result = checkCrowApmUpdate((args) => {
    callCount++;
    if (args[0] === "view") {
      return { status: 0, stdout: "Version: 0.9.2", stderr: "", error: null };
    }
    return {
      status: 1,
      stdout: "",
      stderr: "network unavailable",
      error: null
    };
  });
  assert.equal(callCount, 2);
  assert.equal(result.checked, false);
  assert.equal(result.updateAvailable, null);
  assert.match(result.error, /failed with exit code 1/);
});

test("advances Raven freshness timestamps only after APM checks succeed", () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-raven-freshness-"));
  const statePath = join(stateDir, "state.json");
  const state = codebaseOnlyState(stateDir);
  writeFileSync(statePath, JSON.stringify(state));
  const previousTimestamp = state.lastCheckedAt;
  const checkedAt = new Date(Date.now() + 60_000);

  assert.equal(
    persistSuccessfulFreshnessCheck(
      { state: statePath },
      state,
      { crowPackage: { error: "APM unavailable" } },
      checkedAt
    ),
    false
  );
  assert.equal(JSON.parse(readFileSync(statePath, "utf8")).lastCheckedAt, previousTimestamp);

  assert.equal(
    persistSuccessfulFreshnessCheck(
      { state: statePath },
      state,
      { crowPackage: { checked: true } },
      checkedAt
    ),
    true
  );
  assert.equal(JSON.parse(readFileSync(statePath, "utf8")).lastCheckedAt, checkedAt.toISOString());
});

test("checks Crow updates once per day and notifies again on the next daily check", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-update-cadence-"));
  const now = Date.now() + 60_000;
  let versionLookups = 0;
  const check = (at) => checkCrowUpdates({
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: at,
    getCurrentVersion: () => {
      versionLookups++;
      return "0.10.2";
    },
    getLatestVersion: () => {
      versionLookups++;
      return "0.11.0";
    }
  });

  const first = await check(now);
  assert.equal(first.checked, true);
  assert.equal(first.updateAvailable, true);
  assert.equal(first.notify, true);
  assert.deepEqual(first.updates.map((update) => update.component), ["crow"]);
  assert.equal(first.versions.raven.current, null);
  assert.equal(first.versions.codebaseMemory.current, null);
  assert.equal(markCrowUpdateNotified(stateDir, first, now), true);

  const early = await check(now + 24 * 60 * 60 * 1000 - 1);
  assert.deepEqual(early, { checked: false, reason: "fresh" });
  assert.equal(versionLookups, 2);

  const nextDay = await check(now + 24 * 60 * 60 * 1000);
  assert.equal(nextDay.checked, true);
  assert.equal(nextDay.notify, true);
  assert.equal(markCrowUpdateNotified(stateDir, nextDay, now + 24 * 60 * 60 * 1000), true);
  assert.equal(versionLookups, 4);
});

test("checks configured Raven and codebase-memory releases with Crow once per day", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-managed-release-state-"));
  const updateStateDir = mkdtempSync(join(tmpdir(), "crow-managed-release-check-"));
  const setupStatePath = join(setupStateDir, "state.json");
  const setupState = bundledRavenState(setupStateDir);
  writeFileSync(setupStatePath, JSON.stringify(setupState));
  const originalSetupState = readFileSync(setupStatePath, "utf8");
  const now = Date.now() + 60_000;

  const result = await checkCrowUpdates({
    stateDir: updateStateDir,
    setupStateDir,
    now,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0",
    getLatestRavenVersion: () => "0.2.0",
    getLatestCodebaseVersion: () => "0.12.0"
  });

  assert.equal(result.checked, true);
  assert.equal(result.updateAvailable, true);
  assert.equal(result.notify, true);
  assert.deepEqual(result.updates, [
    { component: "raven", name: "Raven", current: "0.1.0", latest: "0.2.0" },
    {
      component: "codebaseMemory",
      name: "codebase-memory-mcp",
      current: "0.11.0",
      latest: "0.12.0"
    }
  ]);
  assert.equal(readFileSync(setupStatePath, "utf8"), originalSetupState);
  assert.equal(existsSync(join(setupStateDir, "mcp-fragment.json")), false);
  assert.equal(markCrowUpdateNotified(updateStateDir, result, now), true);
  const updateState = JSON.parse(readFileSync(join(updateStateDir, "state.json"), "utf8"));
  assert.equal(updateState.lastNotifiedVersions.raven, "0.2.0");
  assert.equal(updateState.lastNotifiedVersions.codebaseMemory, "0.12.0");
});

test("checks codebase-memory when configured without Raven", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-codebase-only-state-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-codebase-only-check-"));
  writeFileSync(
    join(setupStateDir, "state.json"),
    JSON.stringify(codebaseOnlyState(setupStateDir))
  );
  const result = await checkCrowUpdates({
    stateDir,
    setupStateDir,
    now: Date.now() + 60_000,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => "0.12.0"
  });
  assert.deepEqual(result.updates.map((update) => update.component), ["codebaseMemory"]);
  assert.equal(result.versions.raven.current, null);
});

test("compares managed package versions using semantic ordering", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-semver-state-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-semver-check-"));
  const setupState = codebaseOnlyState(setupStateDir);
  setupState.codebaseMemory.version = "1.9.0";
  setupState.codebaseMemory.installPath = join(
    setupStateDir,
    "codebase-memory",
    "1.9.0-00000000-0000-0000-0000-000000000000"
  );
  setupState.managedFragment = createFragment(
    null,
    [],
    setupState.codebaseMemory.installPath,
    "codebase-memory-only",
    false
  );
  writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(setupState));
  const result = await checkCrowUpdates({
    stateDir,
    setupStateDir,
    now: Date.now() + 60_000,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => "1.10.0"
  });
  assert.deepEqual(result.updates.map((update) => update.current), ["1.9.0"]);
});

test("orders managed prerelease identifiers using semantic precedence", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-prerelease-state-"));
  const cases = [
    ["1.0.0-alpha.9", "1.0.0-alpha.10", true],
    ["1.0.0-alpha.10", "1.0.0-alpha.9", false],
    ["1.0.0-rc.1", "1.0.0", true],
    ["1.0.0-alpha.1", "1.0.0-alpha.beta", true],
    ["1.0.0-alpha.beta", "1.0.0-alpha.beta.1", true]
  ];

  for (const [current, latest, updateExpected] of cases) {
    const stateDir = mkdtempSync(join(tmpdir(), "crow-prerelease-check-"));
    const setupState = codebaseOnlyState(setupStateDir);
    setupState.codebaseMemory.version = current;
    setupState.codebaseMemory.installPath = join(
      setupStateDir,
      "codebase-memory",
      `${current}-00000000-0000-0000-0000-000000000000`
    );
    setupState.managedFragment = createFragment(
      null,
      [],
      setupState.codebaseMemory.installPath,
      "codebase-memory-only",
      false
    );
    writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(setupState));

    const result = await checkCrowUpdates({
      stateDir,
      setupStateDir,
      now: Date.now() + 60_000,
      getCurrentVersion: () => "0.11.0",
      getLatestVersion: () => "0.11.0",
      getLatestCodebaseVersion: () => latest
    });
    assert.equal(result.checked, true);
    assert.equal(
      result.updates.some((update) => update.component === "codebaseMemory"),
      updateExpected,
      `${current} -> ${latest}`
    );
  }
});

test("a malformed setup state does not suppress Crow update detection", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-malformed-setup-state-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-malformed-setup-check-"));
  writeFileSync(join(setupStateDir, "state.json"), "{invalid json");
  const result = await checkCrowUpdates({
    stateDir,
    setupStateDir,
    now: Date.now() + 60_000,
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0"
  });
  assert.equal(result.checked, true);
  assert.equal(result.updateAvailable, true);
  assert.match(result.error, /Crow Raven setup state/);
  assert.deepEqual(result.updates.map((update) => update.component), ["crow"]);
});

test("retries a failed managed-component release check after one hour", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-codebase-retry-state-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-codebase-retry-check-"));
  writeFileSync(
    join(setupStateDir, "state.json"),
    JSON.stringify(codebaseOnlyState(setupStateDir))
  );
  const now = Date.now() + 60_000;
  const failed = await checkCrowUpdates({
    stateDir,
    setupStateDir,
    now,
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => {
      throw new Error("registry unavailable");
    }
  });
  assert.equal(failed.checked, true);
  assert.equal(failed.updateAvailable, true);
  assert.equal(failed.notify, true);
  assert.deepEqual(failed.updates.map((update) => update.component), ["crow"]);
  assert.match(failed.error, /codebase-memory-mcp: registry unavailable/);
  assert.equal(markCrowUpdateNotified(stateDir, failed, now), true);

  const retry = await checkCrowUpdates({
    stateDir,
    setupStateDir,
    now: now + 60 * 60 * 1000,
    getCurrentVersion: () => { throw new Error("Crow should not be rechecked on component retry"); },
    getLatestVersion: () => { throw new Error("Crow should not be rechecked on component retry"); },
    getLatestCodebaseVersion: () => "0.11.0"
  });
  assert.equal(retry.checked, true);
  assert.equal(retry.updateAvailable, true);
  assert.deepEqual(retry.updates.map((update) => update.component), ["crow"]);
  assert.equal(retry.notify, false);
});

test("hourly failures do not extend a successful component's daily cache lifetime", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-fixed-retry-deadline-"));
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-fixed-retry-setup-"));
  writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(codebaseOnlyState(setupStateDir)));
  const now = Date.now() + 60_000;
  let crowChecks = 0;
  const options = {
    stateDir,
    setupStateDir,
    getCurrentVersion: () => { crowChecks++; return "0.10.2"; },
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => { throw new Error("registry unavailable"); }
  };
  for (let hour = 0; hour <= 24; hour++) {
    const result = await checkCrowUpdates({ ...options, now: now + hour * 60 * 60 * 1000 });
    assert.equal(result.checked, true);
    assert.match(result.error, /registry unavailable/);
  }
  assert.equal(crowChecks, 2);
  const state = JSON.parse(readFileSync(join(stateDir, "state.json"), "utf8"));
  assert.equal(state.lastCheckedByComponent.crow, new Date(now + 24 * 60 * 60 * 1000).toISOString());
  assert.equal(state.lastCheckedByComponent.codebaseMemory, null);
});

test("changed installed managed versions invalidate successful retry caches", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-changed-install-setup-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-changed-install-check-"));
  const setupState = codebaseOnlyState(setupStateDir);
  writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(setupState));
  const now = Date.now() + 60_000;
  let codebaseLookups = 0;
  const first = await checkCrowUpdates({
    stateDir, setupStateDir, now,
    getCurrentVersion: () => { throw new Error("Crow lookup unavailable"); },
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => { codebaseLookups++; return "0.12.1"; }
  });
  assert.equal(first.checked, true);
  assert.deepEqual(first.versions.codebaseMemory, { current: "0.11.0", latest: "0.12.1" });
  setupState.codebaseMemory = {
    ...setupState.codebaseMemory,
    version: "0.12.0",
    installPath: join(setupStateDir, "codebase-memory", "0.12.0-22222222-2222-2222-2222-222222222222")
  };
  setupState.managedFragment = createFragment(
    null, [], setupState.codebaseMemory.installPath, "codebase-memory-only", false
  );
  writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(setupState));
  const retry = await checkCrowUpdates({
    stateDir, setupStateDir, now: now + 60 * 60 * 1000,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => { codebaseLookups++; return "0.12.1"; }
  });
  assert.equal(retry.checked, true);
  assert.equal(retry.error, undefined);
  assert.equal(codebaseLookups, 2);
  assert.deepEqual(retry.versions.codebaseMemory, { current: "0.12.0", latest: "0.12.1" });
});

test("older v2 retry state without per-component times rechecks successful components", async () => {
  const setupStateDir = mkdtempSync(join(tmpdir(), "crow-old-retry-setup-"));
  const stateDir = mkdtempSync(join(tmpdir(), "crow-old-retry-check-"));
  writeFileSync(join(setupStateDir, "state.json"), JSON.stringify(codebaseOnlyState(setupStateDir)));
  const now = Date.now() + 60_000;
  await checkCrowUpdates({
    stateDir, setupStateDir, now,
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => { throw new Error("registry unavailable"); }
  });
  const path = join(stateDir, "state.json");
  const legacyState = JSON.parse(readFileSync(path, "utf8"));
  delete legacyState.lastCheckedByComponent;
  writeFileSync(path, JSON.stringify(legacyState));
  let crowLookups = 0;
  const retry = await checkCrowUpdates({
    stateDir, setupStateDir, now: now + 60 * 60 * 1000,
    getCurrentVersion: () => { crowLookups++; return "0.10.2"; },
    getLatestVersion: () => "0.11.0",
    getLatestCodebaseVersion: () => "0.11.0"
  });
  assert.equal(retry.checked, true);
  assert.equal(crowLookups, 1);
  assert.deepEqual(retry.updates.map((update) => update.component), ["crow"]);
});

test("migrates Crow-only update state without resetting its daily notice", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-update-state-migration-"));
  const now = Date.now() + 60_000;
  const previousCheck = new Date(now - 25 * 60 * 60 * 1000).toISOString();
  const previousNotice = new Date(now - 60 * 60 * 1000).toISOString();
  writeFileSync(join(stateDir, "state.json"), JSON.stringify({
    schemaVersion: 1,
    hookDecision: "enabled",
    hookDecisionAt: previousCheck,
    lastAttemptAt: previousCheck,
    lastAttemptStatus: "success",
    lastSuccessfulCheckAt: previousCheck,
    currentVersion: "0.10.2",
    latestVersion: "0.11.0",
    lastNotifiedAt: previousNotice,
    lastNotifiedVersion: "0.11.0"
  }));

  const result = await checkCrowUpdates({
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now,
    force: true,
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0"
  });
  assert.equal(result.checked, true);
  assert.equal(result.notify, false);
  const migratedState = JSON.parse(readFileSync(join(stateDir, "state.json"), "utf8"));
  assert.equal(migratedState.schemaVersion, 2);
  assert.deepEqual(migratedState.versions.crow, { current: "0.10.2", latest: "0.11.0" });
  assert.equal(migratedState.lastNotifiedVersions.crow, "0.11.0");
  assert.equal(migratedState.lastNotifiedVersions.raven, null);
});

test("retries a failed Crow update check after a short backoff", async () => {
  const stateDir = mkdtempSync(join(tmpdir(), "crow-update-retry-"));
  const now = Date.now() + 60_000;
  let currentVersionLookups = 0;

  const failed = await checkCrowUpdates({
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now,
    getCurrentVersion: () => {
      currentVersionLookups++;
      throw new Error("network unavailable");
    },
    getLatestVersion: () => "0.11.0"
  });
  assert.match(failed.error, /network unavailable/);

  const backedOff = await checkCrowUpdates({
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: now + 60 * 60 * 1000 - 1,
    getCurrentVersion: () => {
      currentVersionLookups++;
      return "0.11.0";
    }
  });
  assert.deepEqual(backedOff, { checked: false, reason: "retry-backoff" });
  assert.equal(currentVersionLookups, 1);

  const retry = await checkCrowUpdates({
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: now + 60 * 60 * 1000,
    getCurrentVersion: () => {
      currentVersionLookups++;
      return "0.11.0";
    },
    getLatestVersion: () => "0.11.0"
  });
  assert.equal(retry.checked, true);
  assert.equal(retry.updateAvailable, false);
  assert.equal(currentVersionLookups, 2);
});

test("installs the optional hook once and preserves the user's Copilot hook files", () => {
  const root = mkdtempSync(join(tmpdir(), "crow update hook-"));
  const stateDir = join(root, "state");
  const copilotHome = join(root, "copilot home");
  const hookPath = join(copilotHome, "hooks", "crow-update-notification.json");
  const env = { COPILOT_HOME: copilotHome };

  const initialStatus = run(["update-hook", "status", "--state-dir", stateDir], undefined, env);
  assert.equal(initialStatus.status, 0, initialStatus.stderr);
  assert.equal(JSON.parse(initialStatus.stdout).decision, "pending");

  const unconfirmed = run(["update-hook", "install", "--state-dir", stateDir], undefined, env);
  assert.equal(unconfirmed.status, 1);
  assert.equal(existsSync(hookPath), false);

  const installed = run([
    "update-hook", "install", "--state-dir", stateDir, "--confirm"
  ], undefined, env);
  assert.equal(installed.status, 0, installed.stderr);
  const config = JSON.parse(readFileSync(hookPath, "utf8"));
  assert.deepEqual(config, createCrowUpdateHookConfig(script, stateDir));
  assert.deepEqual(Object.keys(config.hooks), ["userPromptSubmitted", "userPromptTransformed"]);
  assert.match(config.hooks.userPromptSubmitted[0].bash, /"[^"]*crow-raven-setup\.mjs"/);
  assert.match(config.hooks.userPromptSubmitted[0].powershell, /'[^']*crow-raven-setup\.mjs'/);
  assert.match(config.hooks.userPromptSubmitted[0].powershell, /^& '/);
  assert.deepEqual(config.hooks.userPromptSubmitted[0], config.hooks.userPromptTransformed[0]);

  const repeatedInstall = run([
    "update-hook", "install", "--state-dir", stateDir, "--confirm"
  ], undefined, env);
  assert.equal(repeatedInstall.status, 0, repeatedInstall.stderr);
  assert.equal(JSON.parse(repeatedInstall.stdout).alreadyInstalled, true);

  const unconfirmedRemoval = run([
    "update-hook", "remove", "--state-dir", stateDir
  ], undefined, env);
  assert.equal(unconfirmedRemoval.status, 1);
  assert.equal(existsSync(hookPath), true);

  const removed = run([
    "update-hook", "remove", "--state-dir", stateDir, "--confirm"
  ], undefined, env);
  assert.equal(removed.status, 0, removed.stderr);
  assert.equal(existsSync(hookPath), false);
  const finalStatus = run(["update-hook", "status", "--state-dir", stateDir], undefined, env);
  assert.equal(JSON.parse(finalStatus.stdout).decision, "declined");
});

test("reports an installed hook with missing opt-in state as recoverable", async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-hook-state-recovery-"));
  const stateDir = join(root, "state");
  const hookDir = join(root, "hooks");
  const installArgs = [
    "update-hook", "install",
    "--state-dir", stateDir,
    "--hook-dir", hookDir,
    "--confirm"
  ];
  const installed = run(installArgs);
  assert.equal(installed.status, 0, installed.stderr);
  const hookPath = join(hookDir, "crow-update-notification.json");
  const expectedHook = readFileSync(hookPath, "utf8");
  const statePath = join(stateDir, "state.json");
  const pendingState = JSON.parse(readFileSync(statePath, "utf8"));
  pendingState.hookDecision = "pending";
  pendingState.hookDecisionAt = null;
  writeFileSync(statePath, JSON.stringify(pendingState));

  const pending = run([
    "update-hook", "status", "--state-dir", stateDir, "--hook-dir", hookDir
  ]);
  assert.equal(pending.status, 0, pending.stderr);
  assert.equal(JSON.parse(pending.stdout).decision, "recoverable");

  unlinkSync(statePath);

  const recoverable = run([
    "update-hook", "status", "--state-dir", stateDir, "--hook-dir", hookDir
  ]);
  assert.equal(recoverable.status, 0, recoverable.stderr);
  assert.deepEqual(JSON.parse(recoverable.stdout), {
    decision: "recoverable",
    hookInstalled: true,
    persistedDecision: "pending",
    lastSuccessfulCheckAt: null
  });
  assert.equal(existsSync(statePath), false);

  const restored = run(installArgs);
  assert.equal(restored.status, 0, restored.stderr);
  assert.equal(JSON.parse(restored.stdout).alreadyInstalled, true);
  assert.equal(readFileSync(hookPath, "utf8"), expectedHook);
  const restoredStatus = run([
    "update-hook", "status", "--state-dir", stateDir, "--hook-dir", hookDir
  ]);
  assert.equal(JSON.parse(restoredStatus.stdout).decision, "enabled");

  const eventResult = await handleUpdateHookEvent({
    hook_event_name: "UserPromptSubmit",
    session_id: "recovered-hook-session",
    prompt: "Check for updates."
  }, {
    stateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: Date.now() + 60_000,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0"
  });
  assert.equal(eventResult.checkResult.checked, true);
});

test("refuses to overwrite a conflicting Copilot hook file", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-update-hook-conflict-"));
  const stateDir = join(root, "state");
  const hookDir = join(root, "hooks");
  const hookPath = join(hookDir, "crow-update-notification.json");
  const original = JSON.stringify({ hooks: { userPromptSubmitted: [] } });
  mkdirSync(hookDir, { recursive: true });
  writeFileSync(hookPath, original);

  const status = run(["update-hook", "status", "--state-dir", stateDir, "--hook-dir", hookDir]);
  assert.equal(status.status, 0, status.stderr);
  const conflict = JSON.parse(status.stdout);
  assert.equal(conflict.decision, "conflicting");
  assert.equal(conflict.hookInstalled, false);
  const unapproved = run([
    "update-hook", "replace", "--state-dir", stateDir, "--hook-dir", hookDir,
    "--hook-sha256", conflict.hookSha256
  ]);
  assert.notEqual(unapproved.status, 0);
  assert.equal(readFileSync(hookPath, "utf8"), original);
  const stale = run([
    "update-hook", "replace", "--state-dir", stateDir, "--hook-dir", hookDir,
    "--hook-sha256", "a".repeat(64), "--confirm"
  ]);
  assert.notEqual(stale.status, 0);
  assert.equal(readFileSync(hookPath, "utf8"), original);

  const result = run([
    "update-hook", "install",
    "--state-dir", stateDir,
    "--hook-dir", hookDir,
    "--confirm"
  ]);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /different content and was left unchanged/);
  assert.equal(readFileSync(hookPath, "utf8"), original);

  const replaced = run([
    "update-hook", "replace", "--state-dir", stateDir, "--hook-dir", hookDir,
    "--hook-sha256", conflict.hookSha256, "--confirm"
  ]);
  assert.equal(replaced.status, 0, replaced.stderr);
  assert.equal(readFileSync(JSON.parse(replaced.stdout).backupPath, "utf8"), original);
  assert.equal(JSON.parse(run([
    "update-hook", "status", "--state-dir", stateDir, "--hook-dir", hookDir
  ]).stdout).decision, "enabled");
});

test("hook status surfaces read errors rather than reporting a conflict", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-unreadable-hook-"));
  const hookDir = join(root, "hooks");
  mkdirSync(join(hookDir, "crow-update-notification.json"), { recursive: true });
  const result = run(["update-hook", "status", "--state-dir", join(root, "state"), "--hook-dir", hookDir]);
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /EISDIR|illegal operation on a directory|permission denied/i);
  assert.doesNotMatch(result.stdout, /"decision": "conflicting"/);
});

test("delivers update reminders using Local and Copilot CLI hook output formats", async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-update-hook-output-"));
  const localStateDir = join(root, "local-state");
  const cliStateDir = join(root, "cli-state");
  for (const [stateDir, hookDir] of [
    [localStateDir, join(root, "local-hooks")],
    [cliStateDir, join(root, "cli-hooks")]
  ]) {
    const installed = run([
      "update-hook", "install",
      "--state-dir", stateDir,
      "--hook-dir", hookDir,
      "--confirm"
    ]);
    assert.equal(installed.status, 0, installed.stderr);
  }

  const localNow = Date.now() + 60_000;
  const local = await handleUpdateHookEvent({
    hook_event_name: "UserPromptSubmit",
    session_id: "local-session",
    prompt: "What changed?"
  }, {
    stateDir: localStateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: localNow,
    getCrowInstallSelector: () => "bcgov/crow",
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0"
  });
  assert.match(local.output.systemMessage, /Crow update available/);
  assert.match(local.output.systemMessage, /apm install 'bcgov\/crow#stable'/);
  assert.match(local.output.systemMessage, /apm update --global --target copilot/);
  assert.match(local.output.hookSpecificOutput.additionalContext, /Tell the user/);
  assert.equal(markCrowUpdateNotified(localStateDir, local.checkResult, localNow), true);

  let submittedLookups = 0;
  const submitted = await handleUpdateHookEvent({
    sessionId: "cli-session",
    prompt: "What changed?"
  }, {
    stateDir: cliStateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: localNow,
    getCurrentVersion: () => {
      submittedLookups++;
      return "0.10.2";
    }
  });
  assert.deepEqual(submitted.output, {});
  assert.equal(submitted.checkResult, null);
  assert.equal(submittedLookups, 0);

  const transformed = await handleUpdateHookEvent({
    sessionId: "cli-session",
    prompt: "What changed?",
    transformedPrompt: "What changed?"
  }, {
    stateDir: cliStateDir,
    getConfiguredUpdateVersions: noManagedUpdateVersions,
    now: localNow,
    getCrowInstallSelector: () => "bcgov/crow",
    getCurrentVersion: () => "0.10.2",
    getLatestVersion: () => "0.11.0"
  });
  assert.match(transformed.output.modifiedTransformedPrompt, /Crow update available/);
  assert.match(transformed.progress.message, /Crow update available: installed v0\.10\.2; latest v0\.11\.0/);
  assert.match(transformed.progress.message, /apm install 'bcgov\/crow#stable'/);
  assert.equal(markCrowUpdateNotified(cliStateDir, transformed.checkResult, localNow), true);
});

test("uses the detected selector when recommending Crow collection updates", async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-collection-update-reminder-"));
  for (const selector of [
    "bcgov/crow/collections/starter-package",
    "bcgov/crow/collections/security-remediation"
  ]) {
    const selectorName = selector.split("/").at(-1);
    const stateDir = join(root, selectorName, "state");
    const hookDir = join(root, selectorName, "hooks");
    const installed = run([
      "update-hook", "install",
      "--state-dir", stateDir,
      "--hook-dir", hookDir,
      "--confirm"
    ]);
    assert.equal(installed.status, 0, installed.stderr);

    const now = Date.now() + 60_000;
    const result = await handleUpdateHookEvent({
      hook_event_name: "UserPromptSubmit",
      session_id: `${selectorName}-session`,
      prompt: "What updates are available?"
    }, {
      stateDir,
      getConfiguredUpdateVersions: noManagedUpdateVersions,
      now,
      getCrowInstallSelector: () => selector,
      getCurrentVersion: () => "0.10.2",
      getLatestVersion: () => "0.11.0"
    });
    assert.ok(
      result.output.systemMessage.includes(
        `apm install '${selector}#stable' --global --target copilot`
      )
    );
    assert.doesNotMatch(result.output.systemMessage, /bcgov\/crow#stable/);
    assert.equal(markCrowUpdateNotified(stateDir, result.checkResult, now), true);
  }
});

test("notifies about configured Raven and codebase-memory updates during agent use", async () => {
  const root = mkdtempSync(join(tmpdir(), "crow-managed-update-hook-"));
  const setupStateDir = join(root, "custom Raven state");
  const updateStateDir = join(root, "update state");
  const hookDir = join(root, "hooks");
  mkdirSync(setupStateDir, { recursive: true });
  writeFileSync(
    join(setupStateDir, "state.json"),
    JSON.stringify(bundledRavenState(setupStateDir))
  );
  const installed = run([
    "update-hook", "install",
    "--state-dir", updateStateDir,
    "--setup-state-dir", setupStateDir,
    "--hook-dir", hookDir,
    "--confirm"
  ]);
  assert.equal(installed.status, 0, installed.stderr);
  const hookConfig = JSON.parse(readFileSync(join(hookDir, "crow-update-notification.json"), "utf8"));
  assert.match(hookConfig.hooks.userPromptSubmitted[0].bash, /--setup-state-dir ".*custom Raven state"/);
  assert.match(
    hookConfig.hooks.userPromptSubmitted[0].powershell,
    /--setup-state-dir '.*custom Raven state'/
  );

  const now = Date.now() + 60_000;
  const result = await handleUpdateHookEvent({
    hook_event_name: "UserPromptSubmit",
    session_id: "managed-release-session",
    prompt: "What updates are available?"
  }, {
    stateDir: updateStateDir,
    setupStateDir,
    now,
    getCurrentVersion: () => "0.11.0",
    getLatestVersion: () => "0.11.0",
    getLatestRavenVersion: () => "0.2.0",
    getLatestCodebaseVersion: () => "0.12.0"
  });
  assert.match(result.output.systemMessage, /Raven v0\.1\.0 -> v0\.2\.0/);
  assert.match(result.output.systemMessage, /codebase-memory-mcp v0\.11\.0 -> v0\.12\.0/);
  assert.match(result.output.systemMessage, /Crow Raven Setup Agent/);
  assert.doesNotMatch(result.output.systemMessage, /apm install/);
  assert.equal(markCrowUpdateNotified(updateStateDir, result.checkResult, now), true);
});

test("validates GitHub's latest Crow release before accepting its version", async () => {
  let requestedUrl;
  const version = await latestCrowVersion(async (url, options) => {
    requestedUrl = url;
    assert.equal(options.headers["User-Agent"], "bcgov-crow-update-check");
    return {
      ok: true,
      status: 200,
      json: async () => ({ tag_name: "v0.12.3", draft: false, prerelease: false })
    };
  });
  assert.equal(requestedUrl, "https://api.github.com/repos/bcgov/crow/releases/latest");
  assert.equal(version, "0.12.3");
  await assert.rejects(
    latestCrowVersion(async () => ({
      ok: true,
      status: 200,
      json: async () => ({ tag_name: "v0.12.3-rc.1", draft: false, prerelease: true })
    })),
    /stable Crow release/
  );
});

test("resolves the installed APM selector and version for the full package and collections", () => {
  for (const selector of [
    "bcgov/crow",
    "bcgov/crow/collections/starter-package",
    "bcgov/crow/collections/security-remediation"
  ]) {
    const root = mkdtempSync(join(tmpdir(), "crow-apm-selector-"));
    const manifestPath = join(root, "apm.yml");
    const scriptPath = selector === "bcgov/crow"
      ? script
      : join(root, "installed", "scripts", "crow-raven-setup.mjs");
    writeFileSync(manifestPath, [
      "name: test-global",
      "dependencies:",
      "  apm:",
      `    - ${selector}#v0.10.2`,
      "  mcp: []"
    ].join("\n"));
    let apmCalls = 0;
    const installed = resolveInstalledCrowPackage({
      manifestPath,
      scriptPath,
      runApm: (args) => {
        apmCalls++;
        assert.deepEqual(args, ["view", selector, "--global"]);
        return {
          status: 0,
          stdout: "Name: installed-crow-package\nVersion: 0.10.2",
          stderr: "",
          error: null
        };
      }
    });
    assert.equal(installed.selector, selector);
    if (selector === "bcgov/crow") {
      const plugin = JSON.parse(readFileSync(
        new URL("../../../../.github/plugin/plugin.json", import.meta.url),
        "utf8"
      ));
      assert.equal(installed.version, plugin.version);
      assert.equal(apmCalls, 0);
    } else {
      assert.equal(installed.version, "0.10.2");
      assert.equal(apmCalls, 1);
    }
  }
});

test("resolves a Crow collection from its APM repository path", () => {
  const root = mkdtempSync(join(tmpdir(), "crow-apm-collection-path-"));
  const manifestPath = join(root, "apm.yml");
  const selector = "bcgov/crow/collections/starter-package";
  writeFileSync(manifestPath, [
    "name: test-global",
    "dependencies:",
    "  apm:",
    "    - git: https://github.com/bcgov/crow.git",
    "      path: collections/starter-package",
    "      ref: v0.10.2",
    "  mcp: []"
  ].join("\n"));

  const installed = resolveInstalledCrowPackage({
    manifestPath,
    scriptPath: join(root, "installed", "scripts", "crow-raven-setup.mjs"),
    runApm: (args) => {
      assert.deepEqual(args, ["view", selector, "--global"]);
      return {
        status: 0,
        stdout: "Name: installed-crow-collection\nVersion: 0.10.2",
        stderr: "",
        error: null
      };
    }
  });
  assert.deepEqual(installed, { version: "0.10.2", selector });
});

test("validates the latest Raven release and codebase-memory registry version", async () => {
  let ravenUrl;
  const ravenVersion = await latestRavenVersion(async (url, options) => {
    ravenUrl = url;
    assert.equal(options.headers["User-Agent"], "bcgov-crow-update-check");
    return {
      ok: true,
      status: 200,
      json: async () => ({ tag_name: "v0.2.0", draft: false, prerelease: false })
    };
  });
  assert.equal(ravenUrl, "https://api.github.com/repos/bcgov/raven/releases/latest");
  assert.equal(ravenVersion, "0.2.0");
  await assert.rejects(
    latestRavenVersion(async () => ({
      ok: true,
      status: 200,
      json: async () => ({ tag_name: "v0.2.0-rc.1", draft: false, prerelease: true })
    })),
    /stable Raven release/
  );

  let registryUrl;
  const codebaseVersion = await fetchLatestCodebaseVersion(async (url, options) => {
    registryUrl = url;
    assert.ok(options.signal);
    return {
      ok: true,
      status: 200,
      json: async () => ({ version: "1.2.3" })
    };
  }, 5000);
  assert.equal(registryUrl, "https://registry.npmjs.org/codebase-memory-mcp/latest");
  assert.equal(codebaseVersion, "1.2.3");
  await assert.rejects(
    fetchLatestCodebaseVersion(async () => ({
      ok: true,
      status: 200,
      json: async () => ({ version: "not-semver" })
    }), 5000),
    /invalid codebase-memory-mcp version/
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

test("Crow's reviewed catalog matches Raven v0.2.0 contracts", () => {
  const catalog = JSON.parse(readFileSync(new URL("../resources/raven-servers.json", import.meta.url), "utf8"));
  for (const server of catalog.servers) {
    assert.equal(server.packageVersion, "0.2.0", server.id);
  }

  const ado = catalog.servers.find((server) => server.id === "ado");
  assert.ok(ado);
  const releasedCatalog = {
    servers: [{
      id: "ado",
      package: "@nrs/ado-mcp",
      launcher: "raven-ado",
      entrypoint: "packages/ado-mcp/dist/index.js",
      packageVersion: "0.2.0",
      access: "read-write"
    }]
  };
  assert.equal(releasedServers([ado], releasedCatalog)[0].launcher, "raven-ado");
});

test("Windows taskkill errors are ignored only when reported processes have exited", () => {
  const result = {
    status: 1,
    stderr: "ERROR: The process with PID 26724 (child process of PID 26648) could not be terminated.\n" +
      "Reason: There is no running instance of the task."
  };
  const checkedPids = [];
  assert.equal(
    taskkillTerminationError(result, 26648, (pid) => {
      checkedPids.push(pid);
      return false;
    }),
    null
  );
  assert.deepEqual(checkedPids, [26648, 26724]);
  assert.match(
    taskkillTerminationError(result, 26648, (pid) => pid === 26724),
    /There is no running instance of the task/
  );
});

test("Windows taskkill root-not-found errors are ignored only when the root has exited", () => {
  const result = {
    status: 1,
    stderr: 'ERROR: The process "26648" not found.'
  };
  const checkedPids = [];
  assert.equal(
    taskkillTerminationError(result, 26648, (pid) => {
      checkedPids.push(pid);
      return false;
    }),
    null
  );
  assert.deepEqual(checkedPids, [26648]);
  assert.match(
    taskkillTerminationError(result, 26648, (pid) => pid === 26648),
    /The process "26648" not found/
  );
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
