#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = resolve(scriptDir, "..");
const catalogPath = join(skillDir, "resources", "raven-servers.json");
const ravenUrl = "https://github.com/bcgov/raven.git";
const npmRegistryUrl = "https://registry.npmjs.org/codebase-memory-mcp/latest";
const defaultStateDir = join(homedir(), ".crow", "raven-setup");
const npmCli = process.platform === "win32"
  ? join(dirname(process.execPath), "node_modules", "npm", "bin", "npm-cli.js")
  : null;
const planLifetimeMs = 24 * 60 * 60 * 1000;
const startupGraceMs = 5000;
const startupStopMs = 2000;

function fail(message, code = 1) {
  console.error(`ERROR: ${message}`);
  process.exit(code);
}

function parseArgs(values) {
  const parsed = { _: [] };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    if (!value.startsWith("--")) {
      parsed._.push(value);
      continue;
    }
    const key = value.slice(2);
    if (["confirm", "force"].includes(key)) {
      parsed[key] = true;
      continue;
    }
    if (index + 1 >= values.length) fail(`Missing value for --${key}.`);
    parsed[key] = values[index + 1];
    index += 1;
  }
  return parsed;
}

function run(command, args, options = {}) {
  const result = spawnSync(command, args, {
    cwd: options.cwd,
    encoding: "utf8",
    stdio: options.capture ? "pipe" : "inherit",
    shell: false
  });
  if (result.error) fail(`Could not run ${command}: ${result.error.message}`);
  if (result.status !== 0) {
    const detail = options.capture ? ` ${result.stderr.trim()}` : "";
    fail(`${command} exited with code ${result.status}.${detail}`);
  }
  return options.capture ? result.stdout.trim() : "";
}

function npmInvocation(args) {
  return npmCli
    ? { command: process.execPath, args: [npmCli, ...args] }
    : { command: "npm", args };
}

function runNpm(args, options = {}) {
  const invocation = npmInvocation(args);
  return run(invocation.command, invocation.args, options);
}

function writeJsonAtomic(path, value) {
  mkdirSync(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  const backup = `${path}.${process.pid}.bak`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { encoding: "utf8", mode: 0o600 });
  try {
    if (existsSync(path)) renameSync(path, backup);
    renameSync(temporary, path);
    if (existsSync(backup)) rmSync(backup);
  } catch (error) {
    if (!existsSync(path) && existsSync(backup)) renameSync(backup, path);
    if (existsSync(temporary)) rmSync(temporary);
    fail(`Could not replace ${path}: ${error.message}`);
  }
}

function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(`${label} is malformed: ${error.message}`);
  }
}

function readState(target) {
  const state = readJson(target.state, "Crow Raven setup state");
  if (state.schemaVersion !== 1 ||
      !state.managedFragment?.mcpServers ||
      !Array.isArray(state.selectedServers)) {
    fail("Crow Raven setup state has an unsupported shape.");
  }
  let fragmentMatches = false;
  if (existsSync(target.fragment)) {
    try {
      fragmentMatches = JSON.stringify(JSON.parse(readFileSync(target.fragment, "utf8"))) ===
        JSON.stringify(state.managedFragment);
    } catch {
      fragmentMatches = false;
    }
  }
  if (!fragmentMatches) writeJsonAtomic(target.fragment, state.managedFragment);
  return state;
}

function paths(args) {
  const stateDir = resolve(args["state-dir"] || defaultStateDir);
  return {
    stateDir,
    state: join(stateDir, "state.json"),
    fragment: join(stateDir, "mcp-fragment.json"),
    plan: join(stateDir, "pending-plan.json"),
    versions: join(stateDir, "versions"),
    codebaseMemory: join(stateDir, "codebase-memory")
  };
}

function catalog() {
  const value = readJson(catalogPath, "Bundled Raven server catalog");
  if (value.schemaVersion !== 1 || !Array.isArray(value.servers)) {
    fail("Bundled Raven server catalog has an unsupported shape.");
  }
  return value;
}

function selectedServers(args, serverCatalog) {
  const requested = String(args.servers || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (requested.length === 0) fail("--servers must contain at least one Raven server ID.");
  if (new Set(requested).size !== requested.length) fail("--servers contains duplicate IDs.");
  const known = new Map(serverCatalog.servers.map((server) => [server.id, server]));
  const unknown = requested.filter((id) => !known.has(id));
  if (unknown.length > 0) fail(`Unknown Raven server IDs: ${unknown.join(", ")}.`);
  return requested.map((id) => known.get(id));
}

function assertPrerequisites() {
  const [major, minor] = process.versions.node.split(".").map(Number);
  const supported = (major === 22 && minor >= 12) || major === 24 || major >= 26;
  if (!supported) {
    fail(`Raven requires Node.js 22.12.x, 24.x, or 26+; found ${process.versions.node}.`);
  }
  if (npmCli && !existsSync(npmCli)) fail(`npm CLI was not found beside Node.js: ${npmCli}`);
  run("git", ["--version"], { capture: true });
  runNpm(["--version"], { capture: true });
}

function resolveRavenRevision(ref) {
  if (/^[0-9a-f]{40}$/i.test(ref)) return ref.toLowerCase();
  const candidates = ref === "main"
    ? [`refs/heads/${ref}`]
    : [`refs/tags/${ref}^{}`, `refs/tags/${ref}`];
  for (const candidate of candidates) {
    const output = spawnSync("git", ["ls-remote", ravenUrl, candidate], {
      encoding: "utf8",
      stdio: "pipe",
      shell: false
    });
    if (output.error) fail(`Could not query Raven: ${output.error.message}`);
    if (output.status !== 0) fail(`Could not query Raven ref ${ref}: ${output.stderr.trim()}`);
    const revision = output.stdout.trim().split(/\s+/)[0];
    if (/^[0-9a-f]{40}$/i.test(revision)) return revision.toLowerCase();
  }
  fail(`Raven ref '${ref}' was not found.`);
}

async function latestCodebaseVersion() {
  let response;
  try {
    response = await fetch(npmRegistryUrl, { signal: AbortSignal.timeout(10000) });
  } catch (error) {
    fail(`Could not query codebase-memory-mcp: ${error.message}`);
  }
  if (!response.ok) fail(`npm registry returned HTTP ${response.status}.`);
  const metadata = await response.json();
  if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(metadata.version || "")) {
    fail("npm registry returned an invalid codebase-memory-mcp version.");
  }
  return metadata.version;
}

function validateExactVersion(version) {
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version || "")) {
    fail("--codebase-memory-version must be an exact semantic version.");
  }
}

function validateUpstreamConfig(runtimePath, servers) {
  const upstream = readJson(join(runtimePath, ".mcp.json"), "Raven .mcp.json");
  for (const server of servers) {
    const entry = upstream.mcpServers?.[server.id];
    if (entry?.command !== "node" ||
        !Array.isArray(entry.args) ||
        entry.args.length !== 1 ||
        entry.args[0].replaceAll("\\", "/").replace(/^\.\//, "") !== server.entrypoint) {
      fail(`Raven command for '${server.id}' differs from Crow's reviewed catalog.`);
    }
  }
}

function createFragment(runtimePath, servers, codebaseVersion) {
  const codebaseEntrypoint = join(
    dirname(runtimePath),
    "..",
    "codebase-memory",
    codebaseVersion,
    "node_modules",
    "codebase-memory-mcp",
    "bin.js"
  );
  if (!existsSync(codebaseEntrypoint)) {
    fail(`codebase-memory-mcp entrypoint is missing: ${codebaseEntrypoint}`);
  }
  const mcpServers = {
    "codebase-memory-mcp": {
      command: process.execPath,
      args: [codebaseEntrypoint]
    }
  };
  for (const server of servers) {
    const entrypoint = join(runtimePath, ...server.entrypoint.split("/"));
    if (!existsSync(entrypoint)) fail(`Built entrypoint is missing: ${entrypoint}`);
    mcpServers[server.id] = { command: process.execPath, args: [entrypoint] };
  }
  return { mcpServers };
}

function validatePlan(plan, planPath) {
  if (plan.schemaVersion !== 1 ||
      plan.action !== "setup" ||
      plan.delivery !== "pinned-source" ||
      !Array.isArray(plan.selectedServers) ||
      !/^[0-9a-f]{40}$/.test(plan.raven?.revision || "")) {
    fail(`Setup plan is malformed: ${planPath}`);
  }
  validateExactVersion(plan.codebaseMemory?.version);
  const createdAt = Date.parse(plan.createdAt || "");
  if (!Number.isFinite(createdAt) || Date.now() - createdAt > planLifetimeMs) {
    fail("Setup plan is older than 24 hours; generate and review a new plan.");
  }
}

function planDigest(plan) {
  return createHash("sha256").update(JSON.stringify(plan)).digest("hex");
}

function catalogSnapshot(serverCatalog, servers) {
  const snapshot = {
    schemaVersion: serverCatalog.schemaVersion,
    protocolCompatibility: serverCatalog.protocolCompatibility,
    dependencySemantics: serverCatalog.dependencySemantics,
    servers
  };
  return {
    sha256: createHash("sha256").update(JSON.stringify(snapshot)).digest("hex"),
    ...snapshot
  };
}

function validateCodebaseInstall(installPath, version) {
  const packagePath = join(installPath, "node_modules", "codebase-memory-mcp", "package.json");
  const lockPath = join(installPath, "package-lock.json");
  const entrypoint = join(installPath, "node_modules", "codebase-memory-mcp", "bin.js");
  if (!existsSync(packagePath) || !existsSync(lockPath) || !existsSync(entrypoint)) {
    fail(`codebase-memory-mcp ${version} installation is incomplete at ${installPath}.`);
  }
  const packageMetadata = readJson(packagePath, "Installed codebase-memory-mcp package");
  const lock = readJson(lockPath, "codebase-memory-mcp package lock");
  const locked = lock.packages?.["node_modules/codebase-memory-mcp"];
  if (packageMetadata.name !== "codebase-memory-mcp" ||
      packageMetadata.version !== version ||
      locked?.version !== version ||
      !/^sha512-[A-Za-z0-9+/=]+$/.test(locked.integrity || "")) {
    fail(`codebase-memory-mcp ${version} installation failed package and integrity validation.`);
  }
  return {
    entrypoint,
    integrity: locked.integrity,
    entrypointSha256: createHash("sha256").update(readFileSync(entrypoint)).digest("hex")
  };
}

function installCodebaseMemory(target, version, trustedInstalls) {
  const installPath = join(target.codebaseMemory, version);
  const existed = existsSync(installPath);
  if (!existed) {
    mkdirSync(target.codebaseMemory, { recursive: true });
    const stagingPath = `${installPath}.staging-${process.pid}`;
    if (existsSync(stagingPath)) rmSync(stagingPath, { recursive: true, force: true });
    mkdirSync(stagingPath);
    runNpm([
      "install",
      "--prefix", stagingPath,
      "--save-exact",
      "--omit=dev",
      "--no-audit",
      "--no-fund",
      `codebase-memory-mcp@${version}`
    ]);
    validateCodebaseInstall(stagingPath, version);
    renameSync(stagingPath, installPath);
  }
  const installed = validateCodebaseInstall(installPath, version);
  const trusted = trustedInstalls.find((candidate) => candidate?.version === version);
  if (existed && !trusted) {
    fail(`Existing codebase-memory-mcp ${version} has no verified Crow state; use a clean version directory.`);
  }
  if (trusted &&
      (trusted.integrity !== installed.integrity ||
       trusted.entrypointSha256 !== installed.entrypointSha256)) {
    fail(`Existing codebase-memory-mcp ${version} differs from its recorded verified installation.`);
  }
  return installed;
}

async function verifyStartup(name, command, args, cwd) {
  await new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(command, args, {
      cwd,
      env: process.env,
      shell: false,
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true
    });
    let output = "";
    let expectedStop = false;
    let startupTimer;
    let forceStopTimer;
    const capture = (chunk) => {
      if (output.length < 4000) output += chunk.toString();
    };
    child.stdout.on("data", capture);
    child.stderr.on("data", capture);
    child.once("error", (error) => {
      if (startupTimer) clearTimeout(startupTimer);
      if (forceStopTimer) clearTimeout(forceStopTimer);
      rejectPromise(new Error(`${name} could not start: ${error.message}`));
    });
    child.once("exit", (code, signal) => {
      if (startupTimer) clearTimeout(startupTimer);
      if (forceStopTimer) clearTimeout(forceStopTimer);
      if (expectedStop) {
        resolvePromise();
      } else {
        rejectPromise(new Error(
          `${name} exited during startup with code ${code ?? "none"} and signal ${signal ?? "none"}: ${output.trim()}`
        ));
      }
    });
    startupTimer = setTimeout(() => {
      expectedStop = true;
      child.kill();
      forceStopTimer = setTimeout(() => {
        child.kill("SIGKILL");
        child.stdin.destroy();
        child.stdout.destroy();
        child.stderr.destroy();
        child.unref();
        rejectPromise(new Error(`${name} did not stop within ${startupStopMs}ms; process ID ${child.pid}.`));
      }, startupStopMs);
    }, startupGraceMs);
  });
}

async function verifyFragment(fragment, runtimePath, servers) {
  const codebase = fragment.mcpServers["codebase-memory-mcp"];
  await verifyStartup("codebase-memory-mcp", codebase.command, codebase.args);
  for (const server of servers) {
    const entry = fragment.mcpServers[server.id];
    await verifyStartup(`Raven server '${server.id}'`, entry.command, entry.args, runtimePath);
  }
}

function printHelp() {
  console.log(`Crow Raven setup

Commands:
  list [--group <id>]
  status [--state-dir <path>]
  plan --servers <id,...> [--raven-ref main|vX.Y.Z|sha]
       [--codebase-memory-version X.Y.Z] [--state-dir <path>]
  setup --plan <path> --plan-sha256 <digest> --confirm
  check [--state-dir <path>] [--force]
  rollback [--state-dir <path>] --confirm

Plan resolves every mutable version and writes a reviewable pending-plan.json.
Setup uses only that plan and Raven's transitional pinned-source delivery. It
does not merge client configuration or collect credentials.`);
}

function listCommand(args) {
  const serverCatalog = catalog();
  const servers = args.group
    ? serverCatalog.servers.filter((server) => server.group === args.group)
    : serverCatalog.servers;
  if (servers.length === 0) fail(`No Raven servers found for group '${args.group}'.`);
  for (const server of servers) {
    console.log(`${server.id}\t${server.group}\t${server.description}`);
  }
}

function statusCommand(args) {
  const target = paths(args);
  if (!existsSync(target.state)) {
    console.log(JSON.stringify({ configured: false, stateDir: target.stateDir }, null, 2));
    return;
  }
  const state = readState(target);
  console.log(JSON.stringify({ configured: true, ...state, stateDir: target.stateDir }, null, 2));
}

async function planCommand(args) {
  assertPrerequisites();
  const serverCatalog = catalog();
  const servers = selectedServers(args, serverCatalog);
  const ravenRef = args["raven-ref"] || "main";
  const revision = resolveRavenRevision(ravenRef);
  const codebaseVersion = args["codebase-memory-version"] || await latestCodebaseVersion();
  validateExactVersion(codebaseVersion);
  const target = paths(args);
  const priorState = existsSync(target.state) ? readState(target) : null;
  const npmCi = npmInvocation(["ci"]);
  const npmBuild = npmInvocation(["run", "build"]);
  const npmInstallCodebase = npmInvocation([
    "install", "--prefix", join(target.codebaseMemory, codebaseVersion),
    "--save-exact", "--omit=dev", "--no-audit", "--no-fund",
    `codebase-memory-mcp@${codebaseVersion}`
  ]);
  const plan = {
    schemaVersion: 1,
    action: "setup",
    createdAt: new Date().toISOString(),
    delivery: "pinned-source",
    assurance: "transitional-source-build",
    stateDir: target.stateDir,
    raven: {
      source: ravenUrl,
      ref: ravenRef,
      revision,
      freshnessTrack: ravenRef === "main"
        ? { type: "branch", value: "main" }
        : { type: "pinned", value: ravenRef },
      runtimePath: join(target.versions, revision)
    },
    codebaseMemory: {
      source: npmRegistryUrl,
      version: codebaseVersion,
      installPath: join(target.codebaseMemory, codebaseVersion)
    },
    selectedServers: servers,
    serverCatalog: catalogSnapshot(serverCatalog, servers),
    rollbackTarget: priorState ? {
      raven: priorState.raven,
      codebaseMemory: priorState.codebaseMemory,
      selectedServers: priorState.selectedServers,
      serverCatalog: priorState.serverCatalog
    } : null,
    effects: [
      "clone the immutable Raven revision into a new user-local directory if absent",
      "run npm ci and Raven's build scripts if the revision is not already built",
      "install the exact codebase-memory-mcp package in an isolated user-local directory",
      "startup-smoke-test codebase-memory-mcp and every selected Raven server",
      "replace only Crow's state.json and mcp-fragment.json after verification"
    ],
    commands: [
      { command: "git", args: ["clone", "--no-checkout", "--filter=blob:none", ravenUrl, join(target.versions, revision)] },
      { command: "git", args: ["checkout", "--detach", revision], cwd: join(target.versions, revision) },
      { ...npmCi, cwd: join(target.versions, revision) },
      { ...npmBuild, cwd: join(target.versions, revision) },
      {
        ...npmInstallCodebase
      }
    ]
  };
  writeJsonAtomic(target.plan, plan);
  console.log(JSON.stringify({ planPath: target.plan, planSha256: planDigest(plan), ...plan }, null, 2));
}

async function setupCommand(args) {
  if (!args.confirm) fail("Setup requires --confirm after the user reviews the resolved plan.");
  if (!args.plan) fail("Setup requires --plan <path> from the plan command.");
  if (!/^[0-9a-f]{64}$/i.test(args["plan-sha256"] || "")) {
    fail("Setup requires --plan-sha256 <digest> from the reviewed plan output.");
  }
  assertPrerequisites();
  const planPath = resolve(args.plan);
  const plan = readJson(planPath, "Crow Raven setup plan");
  validatePlan(plan, planPath);
  if (planDigest(plan) !== args["plan-sha256"].toLowerCase()) {
    fail("Setup plan content changed after review; generate and review a new plan.");
  }
  const target = paths({ "state-dir": plan.stateDir });
  if (resolve(target.plan) !== planPath) {
    fail(`Plan must be the managed pending plan at ${target.plan}.`);
  }
  const serverCatalog = catalog();
  const servers = selectedServers(
    { servers: plan.selectedServers.map((server) => server.id).join(",") },
    serverCatalog
  );
  for (const server of servers) {
    const planned = plan.selectedServers.find((candidate) => candidate.id === server.id);
    if (JSON.stringify(planned) !== JSON.stringify(server)) {
      fail(`Planned metadata for '${server.id}' differs from Crow's reviewed catalog.`);
    }
  }
  const { revision } = plan.raven;
  const codebaseVersion = plan.codebaseMemory.version;

  const runtimePath = join(target.versions, revision);
  const priorState = existsSync(target.state) ? readState(target) : null;
  if (!existsSync(runtimePath)) {
    mkdirSync(target.versions, { recursive: true });
    run("git", ["clone", "--no-checkout", "--filter=blob:none", ravenUrl, runtimePath]);
    run("git", ["checkout", "--detach", revision], { cwd: runtimePath });
    runNpm(["ci"], { cwd: runtimePath });
    runNpm(["run", "build"], { cwd: runtimePath });
  }

  const actualRevision = run("git", ["rev-parse", "HEAD"], { cwd: runtimePath, capture: true }).toLowerCase();
  if (actualRevision !== revision) fail(`Raven checkout resolved to ${actualRevision}, expected ${revision}.`);
  validateUpstreamConfig(runtimePath, servers);
  const trustedCodebaseInstalls = [
    priorState?.codebaseMemory,
    priorState?.previous?.codebaseMemory
  ].filter(Boolean);
  const codebaseInstall = installCodebaseMemory(
    target,
    codebaseVersion,
    trustedCodebaseInstalls
  );
  const fragment = createFragment(runtimePath, servers, codebaseVersion);
  try {
    await verifyFragment(fragment, runtimePath, servers);
  } catch (error) {
    fail(error.message);
  }

  const now = new Date().toISOString();
  const state = {
    schemaVersion: 1,
    delivery: "pinned-source",
    raven: {
      ref: plan.raven.ref,
      revision,
      freshnessTrack: plan.raven.freshnessTrack,
      runtimePath
    },
    codebaseMemory: {
      version: codebaseVersion,
      integrity: codebaseInstall.integrity,
      entrypointSha256: codebaseInstall.entrypointSha256
    },
    selectedServers: servers.map((server) => server.id),
    serverCatalog: plan.serverCatalog,
    managedFragment: fragment,
    configuredAt: now,
    lastCheckedAt: now,
    previous: priorState ? {
      raven: priorState.raven,
      codebaseMemory: priorState.codebaseMemory,
      selectedServers: priorState.selectedServers,
      serverCatalog: priorState.serverCatalog,
      managedFragment: priorState.managedFragment
    } : null
  };
  writeJsonAtomic(target.state, state);
  writeJsonAtomic(target.fragment, fragment);
  console.log(JSON.stringify({ statePath: target.state, fragmentPath: target.fragment, ...state }, null, 2));
}

async function checkCommand(args) {
  const target = paths(args);
  if (!existsSync(target.state)) fail("Crow Raven setup is not configured.");
  const state = readState(target);
  const lastChecked = Date.parse(state.lastCheckedAt || "");
  const age = Date.now() - lastChecked;
  if (!args.force && Number.isFinite(lastChecked) && age < 24 * 60 * 60 * 1000) {
    console.log(JSON.stringify({ checked: false, reason: "fresh", lastCheckedAt: state.lastCheckedAt }, null, 2));
    return;
  }
  assertPrerequisites();
  const freshnessTrack = state.raven.freshnessTrack || { type: "pinned", value: state.raven.ref };
  const latestRevision = freshnessTrack.type === "branch"
    ? resolveRavenRevision(freshnessTrack.value)
    : state.raven.revision;
  const latestCodebase = await latestCodebaseVersion();
  state.lastCheckedAt = new Date().toISOString();
  writeJsonAtomic(target.state, state);
  const result = {
    checked: true,
    raven: {
      current: state.raven.revision,
      latest: latestRevision,
      track: freshnessTrack,
      updateAvailable: state.raven.revision !== latestRevision,
      note: freshnessTrack.type === "pinned" ? "Pinned refs have no automatic Raven update track." : null
    },
    codebaseMemory: { current: state.codebaseMemory.version, latest: latestCodebase, updateAvailable: state.codebaseMemory.version !== latestCodebase }
  };
  console.log(JSON.stringify(result, null, 2));
  if (result.raven.updateAvailable || result.codebaseMemory.updateAvailable) process.exitCode = 10;
}

async function rollbackCommand(args) {
  if (!args.confirm) fail("Rollback requires --confirm after the user reviews the target.");
  const target = paths(args);
  if (!existsSync(target.state)) fail("Crow Raven setup is not configured.");
  const state = readState(target);
  if (!state.previous?.raven?.runtimePath || !existsSync(state.previous.raven.runtimePath)) {
    fail("No retained previous Raven runtime is available.");
  }
  if (!Array.isArray(state.previous.selectedServers) ||
      state.previous.selectedServers.some((id) => !/^[a-z][a-z0-9-]+$/.test(id))) {
    fail("Previous state contains invalid selected server IDs.");
  }
  const servers = state.previous.selectedServers.map((id) => ({ id }));
  const fragment = state.previous.managedFragment;
  if (!fragment?.mcpServers) fail("Previous state does not contain its verified managed fragment.");
  for (const server of servers) {
    if (!fragment.mcpServers[server.id]) fail(`Previous fragment is missing '${server.id}'.`);
  }
  try {
    await verifyFragment(fragment, state.previous.raven.runtimePath, servers);
  } catch (error) {
    fail(error.message);
  }
  const current = {
    raven: state.raven,
    codebaseMemory: state.codebaseMemory,
    selectedServers: state.selectedServers,
    serverCatalog: state.serverCatalog,
    managedFragment: state.managedFragment
  };
  state.raven = state.previous.raven;
  state.codebaseMemory = state.previous.codebaseMemory;
  state.selectedServers = state.previous.selectedServers;
  state.serverCatalog = state.previous.serverCatalog;
  state.managedFragment = state.previous.managedFragment;
  state.previous = current;
  state.configuredAt = new Date().toISOString();
  writeJsonAtomic(target.state, state);
  writeJsonAtomic(target.fragment, fragment);
  console.log(JSON.stringify({ rolledBack: true, fragmentPath: target.fragment, ...state }, null, 2));
}

const args = parseArgs(process.argv.slice(2));
const command = args._[0] || "help";
switch (command) {
  case "help": printHelp(); break;
  case "list": listCommand(args); break;
  case "status": statusCommand(args); break;
  case "plan": await planCommand(args); break;
  case "setup": await setupCommand(args); break;
  case "check": await checkCommand(args); break;
  case "rollback": await rollbackCommand(args); break;
  default: fail(`Unknown command '${command}'. Run 'help' for usage.`);
}
