#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
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
const networkTimeoutMs = 10000;

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
    if (["confirm", "force", "no-raven"].includes(key)) {
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
    shell: false,
    timeout: options.timeout
  });
  if (result.error?.code === "ETIMEDOUT") {
    fail(`${command} timed out after ${options.timeout}ms.`);
  }
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

function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

function isRavenState(value) {
  return value === null ||
    (isRecord(value) &&
      typeof value.ref === "string" &&
      /^[0-9a-f]{40}$/.test(value.revision || "") &&
      isRecord(value.freshnessTrack) &&
      ["branch", "pinned"].includes(value.freshnessTrack.type) &&
      typeof value.freshnessTrack.value === "string" &&
      typeof value.runtimePath === "string");
}

function isCodebaseState(value) {
  return isRecord(value) &&
    /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value.version || "") &&
    typeof value.installPath === "string" &&
    /^sha512-[A-Za-z0-9+/=]+$/.test(value.integrity || "") &&
    /^[0-9a-f]{64}$/.test(value.entrypointSha256 || "");
}

function isServerCatalogSnapshot(value) {
  if (!isRecord(value) ||
      value.schemaVersion !== 1 ||
      !/^[0-9a-f]{64}$/.test(value.sha256 || "") ||
      !Array.isArray(value.servers)) {
    return false;
  }
  const { sha256, ...snapshot } = value;
  return sha256 === createHash("sha256")
    .update(JSON.stringify(snapshot))
    .digest("hex");
}

function isManagedFragment(value, selectedServers) {
  const isCommand = (entry) => isRecord(entry) &&
    typeof entry.command === "string" &&
    entry.command.length > 0 &&
    Array.isArray(entry.args) &&
    entry.args.every((argument) => typeof argument === "string");
  if (!isRecord(value?.mcpServers) ||
      !isCommand(value.mcpServers["codebase-memory-mcp"])) {
    return false;
  }
  return selectedServers.every((id) => isCommand(value.mcpServers[id]));
}

function isStateSnapshot(value) {
  if (!isRecord(value) ||
      !isRavenState(value.raven) ||
      !isCodebaseState(value.codebaseMemory) ||
      !Array.isArray(value.selectedServers) ||
      !value.selectedServers.every((id) => /^[a-z][a-z0-9-]+$/.test(id)) ||
      new Set(value.selectedServers).size !== value.selectedServers.length ||
      !((value.selectedServers.length === 0 && value.raven === null) ||
        (value.selectedServers.length > 0 && value.raven !== null)) ||
      !isServerCatalogSnapshot(value.serverCatalog) ||
      !isManagedFragment(value.managedFragment, value.selectedServers)) {
    return false;
  }
  return JSON.stringify(value.serverCatalog.servers.map((server) => server.id)) ===
    JSON.stringify(value.selectedServers);
}

function readState(target) {
  const state = readJson(target.state, "Crow Raven setup state");
  if (state.schemaVersion !== 1 ||
      !["pinned-source", "codebase-memory-only"].includes(state.delivery) ||
      !isStateSnapshot(state) ||
      ((state.raven === null) !== (state.delivery === "codebase-memory-only")) ||
      !isTimestamp(state.configuredAt) ||
      !isTimestamp(state.lastCheckedAt) ||
      (state.previous !== null && !isStateSnapshot(state.previous))) {
    fail("Crow Raven setup state is malformed or has an unsupported schema.");
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
  if (args["no-raven"]) {
    if (args.servers) fail("--no-raven cannot be combined with --servers.");
    return [];
  }
  const requested = String(args.servers || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  if (requested.length === 0) {
    fail("Choose Raven servers with --servers <id,...> or explicitly select --no-raven.");
  }
  if (new Set(requested).size !== requested.length) fail("--servers contains duplicate IDs.");
  const known = new Map(serverCatalog.servers.map((server) => [server.id, server]));
  const unknown = requested.filter((id) => !known.has(id));
  if (unknown.length > 0) fail(`Unknown Raven server IDs: ${unknown.join(", ")}.`);
  return requested.map((id) => known.get(id));
}

function assertPrerequisites({ requiresGit = true } = {}) {
  const [major, minor] = process.versions.node.split(".").map(Number);
  const supported = (major === 22 && minor >= 12) || major === 24 || major >= 26;
  if (!supported) {
    fail(`Raven requires Node.js 22.12.x, 24.x, or 26+; found ${process.versions.node}.`);
  }
  if (npmCli && !existsSync(npmCli)) fail(`npm CLI was not found beside Node.js: ${npmCli}`);
  if (requiresGit) run("git", ["--version"], { capture: true });
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
      shell: false,
      timeout: networkTimeoutMs
    });
    if (output.error?.code === "ETIMEDOUT") {
      fail(`Raven ref lookup timed out after ${networkTimeoutMs}ms.`);
    }
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

function createFragment(runtimePath, servers, codebaseInstallPath) {
  const codebaseEntrypoint = join(
    codebaseInstallPath,
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
      !["pinned-source", "codebase-memory-only"].includes(plan.delivery) ||
      !Array.isArray(plan.selectedServers) ||
      !isServerCatalogSnapshot(plan.serverCatalog) ||
      !isRecord(plan.codebaseMemory) ||
      typeof plan.codebaseMemory.installPath !== "string" ||
      JSON.stringify(plan.serverCatalog.servers) !==
        JSON.stringify(plan.selectedServers) ||
      (plan.selectedServers.length === 0
        ? plan.raven !== null || plan.delivery !== "codebase-memory-only"
        : !isRecord(plan.raven) ||
          !/^[0-9a-f]{40}$/.test(plan.raven.revision || "") ||
          plan.delivery !== "pinned-source")) {
    fail(`Setup plan is malformed: ${planPath}`);
  }
  validateExactVersion(plan.codebaseMemory?.version);
  const target = paths({ "state-dir": plan.stateDir });
  const generationPattern = /^[0-9a-f-]{36}$/;
  const codebaseName = basename(plan.codebaseMemory.installPath);
  const codebasePrefix = `${plan.codebaseMemory.version}-`;
  if (resolve(dirname(plan.codebaseMemory.installPath)) !== resolve(target.codebaseMemory) ||
      !codebaseName.startsWith(codebasePrefix) ||
      !generationPattern.test(codebaseName.slice(codebasePrefix.length))) {
    fail(`Setup plan contains an invalid managed codebase-memory-mcp path: ${planPath}`);
  }
  if (plan.raven) {
    const runtimeName = basename(plan.raven.runtimePath);
    const runtimePrefix = `${plan.raven.revision}-`;
    if (resolve(dirname(plan.raven.runtimePath)) !== resolve(target.versions) ||
        !runtimeName.startsWith(runtimePrefix) ||
        !generationPattern.test(runtimeName.slice(runtimePrefix.length))) {
      fail(`Setup plan contains an invalid managed Raven runtime path: ${planPath}`);
    }
  }
  const createdAt = Date.parse(plan.createdAt || "");
  const age = Date.now() - createdAt;
  if (!Number.isFinite(createdAt) || age < 0 || age > planLifetimeMs) {
    fail("Setup plan timestamp is invalid or outside the 24-hour confirmation window; generate and review a new plan.");
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

function stageCodebaseMemory(installPath, version) {
  const stagingPath = `${installPath}.staging-${process.pid}`;
  if (existsSync(stagingPath)) rmSync(stagingPath, { recursive: true, force: true });
  mkdirSync(dirname(installPath), { recursive: true });
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
  return { stagingPath, ...validateCodebaseInstall(stagingPath, version) };
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
  plan (--servers <id,...> | --no-raven) [--raven-ref main|vX.Y.Z|sha]
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
  const serverCatalog = catalog();
  const servers = selectedServers(args, serverCatalog);
  const includesRaven = servers.length > 0;
  if (!includesRaven && args["raven-ref"]) {
    fail("--raven-ref cannot be combined with --no-raven.");
  }
  assertPrerequisites({ requiresGit: includesRaven });
  const ravenRef = includesRaven ? args["raven-ref"] || "main" : null;
  const revision = includesRaven ? resolveRavenRevision(ravenRef) : null;
  const codebaseVersion = args["codebase-memory-version"] || await latestCodebaseVersion();
  validateExactVersion(codebaseVersion);
  const target = paths(args);
  const priorState = existsSync(target.state) ? readState(target) : null;
  const generationId = randomUUID();
  const runtimePath = includesRaven
    ? join(target.versions, `${revision}-${generationId}`)
    : null;
  const codebaseInstallPath = join(
    target.codebaseMemory,
    `${codebaseVersion}-${generationId}`
  );
  const npmCi = npmInvocation(["ci"]);
  const npmBuild = npmInvocation(["run", "build"]);
  const npmInstallCodebase = npmInvocation([
    "install", "--prefix", `${codebaseInstallPath}.staging-<pid>`,
    "--save-exact", "--omit=dev", "--no-audit", "--no-fund",
    `codebase-memory-mcp@${codebaseVersion}`
  ]);
  const plan = {
    schemaVersion: 1,
    action: "setup",
    createdAt: new Date().toISOString(),
    delivery: includesRaven ? "pinned-source" : "codebase-memory-only",
    assurance: includesRaven ? "transitional-source-build" : "registry-package",
    stateDir: target.stateDir,
    raven: includesRaven ? {
      source: ravenUrl,
      ref: ravenRef,
      revision,
      freshnessTrack: ravenRef === "main"
        ? { type: "branch", value: "main" }
        : { type: "pinned", value: ravenRef },
      runtimePath
    } : null,
    codebaseMemory: {
      source: npmRegistryUrl,
      version: codebaseVersion,
      installPath: codebaseInstallPath
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
      ...(includesRaven ? [
        "clone and build the immutable Raven revision in a new staging directory",
        "publish the Raven runtime only after all startup checks pass"
      ] : []),
      "install the exact codebase-memory-mcp package in an isolated user-local directory",
      "startup-smoke-test codebase-memory-mcp and every selected Raven server",
      "replace only Crow's state.json and mcp-fragment.json after verification"
    ],
    commands: [
      ...(includesRaven ? [
        { command: "git", args: ["clone", "--no-checkout", "--filter=blob:none", ravenUrl, `${runtimePath}.staging-<pid>`] },
        { command: "git", args: ["checkout", "--detach", revision], cwd: `${runtimePath}.staging-<pid>` },
        { ...npmCi, cwd: `${runtimePath}.staging-<pid>` },
        { ...npmBuild, cwd: `${runtimePath}.staging-<pid>` }
      ] : []),
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
  const planPath = resolve(args.plan);
  const plan = readJson(planPath, "Crow Raven setup plan");
  validatePlan(plan, planPath);
  assertPrerequisites({ requiresGit: plan.raven !== null });
  if (planDigest(plan) !== args["plan-sha256"].toLowerCase()) {
    fail("Setup plan content changed after review; generate and review a new plan.");
  }
  const target = paths({ "state-dir": plan.stateDir });
  if (resolve(target.plan) !== planPath) {
    fail(`Plan must be the managed pending plan at ${target.plan}.`);
  }
  const serverCatalog = catalog();
  const servers = selectedServers(
    plan.selectedServers.length > 0
      ? { servers: plan.selectedServers.map((server) => server.id).join(",") }
      : { "no-raven": true },
    serverCatalog
  );
  for (const server of servers) {
    const planned = plan.selectedServers.find((candidate) => candidate.id === server.id);
    if (JSON.stringify(planned) !== JSON.stringify(server)) {
      fail(`Planned metadata for '${server.id}' differs from Crow's reviewed catalog.`);
    }
  }
  const codebaseVersion = plan.codebaseMemory.version;
  const priorState = existsSync(target.state) ? readState(target) : null;
  const protectedRuntimePaths = [
    priorState?.raven?.runtimePath,
    priorState?.previous?.raven?.runtimePath
  ].filter(Boolean);
  const protectedCodebasePaths = [
    priorState?.codebaseMemory?.installPath,
    priorState?.previous?.codebaseMemory?.installPath
  ].filter(Boolean);
  if ((plan.raven?.runtimePath &&
       protectedRuntimePaths.includes(plan.raven.runtimePath)) ||
      protectedCodebasePaths.includes(plan.codebaseMemory.installPath)) {
    fail("This setup plan is already active or retained as a rollback target.");
  }

  const runtimePath = plan.raven?.runtimePath || null;
  const runtimeStagingPath = runtimePath ? `${runtimePath}.staging-${process.pid}` : null;
  const codebaseInstallPath = plan.codebaseMemory.installPath;
  if (runtimePath && existsSync(runtimePath)) {
    rmSync(runtimePath, { recursive: true, force: true });
  }
  if (runtimeStagingPath && existsSync(runtimeStagingPath)) {
    rmSync(runtimeStagingPath, { recursive: true, force: true });
  }
  if (existsSync(codebaseInstallPath)) {
    rmSync(codebaseInstallPath, { recursive: true, force: true });
  }

  if (runtimeStagingPath) {
    mkdirSync(target.versions, { recursive: true });
    run("git", ["clone", "--no-checkout", "--filter=blob:none", ravenUrl, runtimeStagingPath]);
    run("git", ["checkout", "--detach", plan.raven.revision], { cwd: runtimeStagingPath });
    runNpm(["ci"], { cwd: runtimeStagingPath });
    runNpm(["run", "build"], { cwd: runtimeStagingPath });
    const actualRevision = run(
      "git",
      ["rev-parse", "HEAD"],
      { cwd: runtimeStagingPath, capture: true }
    ).toLowerCase();
    if (actualRevision !== plan.raven.revision) {
      fail(`Raven checkout resolved to ${actualRevision}, expected ${plan.raven.revision}.`);
    }
    validateUpstreamConfig(runtimeStagingPath, servers);
  }

  const codebaseInstall = stageCodebaseMemory(codebaseInstallPath, codebaseVersion);
  const stagingFragment = createFragment(
    runtimeStagingPath,
    servers,
    codebaseInstall.stagingPath
  );
  try {
    await verifyFragment(stagingFragment, runtimeStagingPath, servers);
  } catch (error) {
    fail(error.message);
  }

  renameSync(codebaseInstall.stagingPath, codebaseInstallPath);
  if (runtimeStagingPath) renameSync(runtimeStagingPath, runtimePath);
  const fragment = createFragment(runtimePath, servers, codebaseInstallPath);
  const now = new Date().toISOString();
  const state = {
    schemaVersion: 1,
    delivery: plan.delivery,
    raven: plan.raven ? {
      ref: plan.raven.ref,
      revision: plan.raven.revision,
      freshnessTrack: plan.raven.freshnessTrack,
      runtimePath
    } : null,
    codebaseMemory: {
      version: codebaseVersion,
      installPath: codebaseInstallPath,
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
  if (!Number.isFinite(lastChecked) || age < 0) {
    fail("Crow Raven setup state has an invalid future lastCheckedAt timestamp.");
  }
  if (!args.force && Number.isFinite(lastChecked) && age < 24 * 60 * 60 * 1000) {
    console.log(JSON.stringify({ checked: false, reason: "fresh", lastCheckedAt: state.lastCheckedAt }, null, 2));
    return;
  }
  assertPrerequisites({ requiresGit: state.raven !== null });
  const freshnessTrack = state.raven?.freshnessTrack || null;
  const latestRevision = freshnessTrack?.type === "branch"
    ? resolveRavenRevision(freshnessTrack.value)
    : state.raven?.revision || null;
  const latestCodebase = await latestCodebaseVersion();
  state.lastCheckedAt = new Date().toISOString();
  writeJsonAtomic(target.state, state);
  const result = {
    checked: true,
    raven: state.raven ? {
      current: state.raven.revision,
      latest: latestRevision,
      track: freshnessTrack,
      updateAvailable: state.raven.revision !== latestRevision,
      note: freshnessTrack.type === "pinned" ? "Pinned refs have no automatic Raven update track." : null
    } : null,
    codebaseMemory: { current: state.codebaseMemory.version, latest: latestCodebase, updateAvailable: state.codebaseMemory.version !== latestCodebase }
  };
  console.log(JSON.stringify(result, null, 2));
  if (result.raven?.updateAvailable || result.codebaseMemory.updateAvailable) process.exitCode = 10;
}

async function rollbackCommand(args) {
  if (!args.confirm) fail("Rollback requires --confirm after the user reviews the target.");
  const target = paths(args);
  if (!existsSync(target.state)) fail("Crow Raven setup is not configured.");
  const state = readState(target);
  if (!state.previous) {
    fail("No retained previous setup is available.");
  }
  if (state.previous.raven?.runtimePath &&
      !existsSync(state.previous.raven.runtimePath)) {
    fail("The retained previous Raven runtime is unavailable.");
  }
  if (!existsSync(state.previous.codebaseMemory.installPath)) {
    fail("The retained previous codebase-memory-mcp installation is unavailable.");
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
    await verifyFragment(fragment, state.previous.raven?.runtimePath, servers);
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
