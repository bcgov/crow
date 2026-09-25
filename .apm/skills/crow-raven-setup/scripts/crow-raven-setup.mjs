#!/usr/bin/env node

import { spawn, spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import {
  cpSync,
  createReadStream,
  createWriteStream,
  existsSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  readlinkSync,
  renameSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { fileURLToPath, pathToFileURL } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = resolve(scriptDir, "..");
const catalogPath = join(skillDir, "resources", "raven-servers.json");
const ravenRepository = "bcgov/raven";
const ravenRepositoryUrl = `https://github.com/${ravenRepository}`;
const ravenUrl = `${ravenRepositoryUrl}.git`;
const ravenApi = `https://api.github.com/repos/${ravenRepository}`;
const ravenRawUrl = `https://raw.githubusercontent.com/${ravenRepository}`;
const npmRegistryUrl = "https://registry.npmjs.org/codebase-memory-mcp/latest";
const defaultStateDir = join(homedir(), ".crow", "raven-setup");
const npmCli = process.platform === "win32"
  ? join(dirname(process.execPath), "node_modules", "npm", "bin", "npm-cli.js")
  : null;
const planLifetimeMs = 24 * 60 * 60 * 1000;
const startupGraceMs = 5000;
const startupStopMs = 2000;
const networkTimeoutMs = 10000;
const codebaseWindowsCandidateTimeoutMs = 120000;
const ravenPlatform = `${process.platform}-${process.arch}`;

function fail(message, code = 1) {
  console.error(`ERROR: ${message}`);
  process.exit(code);
}

function parseArgs(values) {
  const parsed = { _: [] };
  let pendingKey = null;
  for (const value of values) {
    if (pendingKey) {
      parsed[pendingKey] = value;
      pendingKey = null;
      continue;
    }
    if (!value.startsWith("--")) {
      parsed._.push(value);
      continue;
    }
    const key = value.slice(2);
    if (["confirm", "force", "no-raven"].includes(key)) {
      parsed[key] = true;
      continue;
    }
    pendingKey = key;
  }
  if (pendingKey) fail(`Missing value for --${pendingKey}.`);
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

function runApm(args) {
  const command = process.platform === "win32" ? "apm.exe" : "apm";
  const result = spawnSync(command, args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    shell: false,
    timeout: networkTimeoutMs,
    windowsHide: true
  });
  return {
    status: result.status,
    stdout: result.stdout?.trim() || "",
    stderr: result.stderr?.trim() || "",
    error: result.error || null
  };
}

function parseCrowOutdatedOutput(output) {
  const normalized = output.replace(/\u001b\[[0-9;]*m/g, "");
  const line = normalized
    .split(/\r?\n/)
    .find((candidate) => /\bbcgov\/crow\b/i.test(candidate));
  const status = line?.match(/\b(up-to-date|outdated|unknown)\b/i)?.[1]?.toLowerCase() || null;
  return {
    reported: Boolean(line),
    status,
    updateAvailable: status === "outdated"
  };
}

function checkCrowApmUpdate(runCommand = runApm) {
  const metadata = runCommand(["view", "bcgov/crow", "--global"]);
  const metadataOutput = `${metadata.stdout}\n${metadata.stderr}`.trim();
  if (metadata.error?.code === "ENOENT") {
    return {
      checked: false,
      configured: false,
      updateAvailable: null,
      reason: "apm-not-installed"
    };
  }
  if (metadata.error) {
    return {
      checked: false,
      configured: true,
      updateAvailable: null,
      error: `Could not run APM package lookup: ${metadata.error.message}`
    };
  }
  if (metadata.status !== 0) {
    if (/Package .* not found in apm_modules\//i.test(metadataOutput)) {
      return {
        checked: false,
        configured: false,
        updateAvailable: null,
        reason: "crow-not-installed-with-apm"
      };
    }
    return {
      checked: false,
      configured: true,
      updateAvailable: null,
      error: `APM package lookup failed with exit code ${metadata.status}.`
    };
  }

  const current = metadata.stdout.match(/\bVersion:\s+([^\s]+)/i)?.[1] || null;
  const outdated = runCommand(["outdated", "--global"]);
  const outdatedOutput = `${outdated.stdout}\n${outdated.stderr}`.trim();
  if (outdated.error) {
    return {
      checked: false,
      configured: true,
      current,
      updateAvailable: null,
      error: `Could not check APM package freshness: ${outdated.error.message}`
    };
  }
  if (outdated.status !== 0) {
    return {
      checked: false,
      configured: true,
      current,
      updateAvailable: null,
      error: `APM package freshness check failed with exit code ${outdated.status}.`
    };
  }

  const parsed = parseCrowOutdatedOutput(outdatedOutput);
  if (parsed.status === "unknown") {
    return {
      checked: false,
      configured: true,
      current,
      updateAvailable: null,
      error: "APM could not resolve the current Crow package version."
    };
  }
  return {
    checked: true,
    configured: true,
    current,
    updateAvailable: parsed.updateAvailable,
    source: "apm outdated --global"
  };
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

function writeJsonAtomic(path, value, options = {}) {
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
    if (options.throwOnError) {
      throw new Error(`Could not replace ${path}: ${error.message}`);
    }
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
      typeof value.runtimePath === "string" &&
      /^[0-9a-f]{64}$/.test(value.runtimeTreeSha256 || "") &&
      (
        (value.delivery === "pinned-source" &&
          typeof value.ref === "string" &&
          /^[0-9a-f]{40}$/.test(value.revision || "") &&
          isRecord(value.freshnessTrack) &&
          ["branch", "pinned"].includes(value.freshnessTrack.type) &&
          typeof value.freshnessTrack.value === "string") ||
        (value.delivery === "bundled-release" &&
          /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value.suiteVersion || "") &&
          value.platform === ravenPlatform &&
          /^[0-9a-f]{40}$/.test(value.sourceCommit || "") &&
          /^[0-9a-f]{64}$/.test(value.archiveSha256 || "") &&
          typeof value.releaseTag === "string")
      ));
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
  const expectedKeys = ["codebase-memory-mcp", ...selectedServers]
    .sort((left, right) => left.localeCompare(right));
  const actualKeys = Object.keys(value.mcpServers)
    .sort((left, right) => left.localeCompare(right));
  return JSON.stringify(actualKeys) === JSON.stringify(expectedKeys) &&
    selectedServers.every((id) => isCommand(value.mcpServers[id]));
}

function isStateSnapshot(value) {
  if (!isRecord(value) ||
      !["bundled-release", "pinned-source", "codebase-memory-only"].includes(value.delivery) ||
      !isRavenState(value.raven) ||
      !isCodebaseState(value.codebaseMemory) ||
      !Array.isArray(value.selectedServers) ||
      !value.selectedServers.every((id) => /^[a-z][a-z0-9-]+$/.test(id)) ||
      new Set(value.selectedServers).size !== value.selectedServers.length ||
      !((value.selectedServers.length === 0 && value.raven === null) ||
        (value.selectedServers.length > 0 && value.raven !== null)) ||
      (value.raven === null
        ? value.delivery !== "codebase-memory-only"
        : value.raven.delivery !== value.delivery) ||
      !isServerCatalogSnapshot(value.serverCatalog) ||
      !isManagedFragment(value.managedFragment, value.selectedServers)) {
    return false;
  }
  return JSON.stringify(value.serverCatalog.servers.map((server) => server.id)) ===
    JSON.stringify(value.selectedServers);
}

function readState(target) {
  const state = readJson(target.state, "Crow Raven setup state");
  const snapshots = [state, state.previous].filter(Boolean);
  if (state.schemaVersion !== 1 ||
      !["bundled-release", "pinned-source", "codebase-memory-only"].includes(state.delivery) ||
      !isStateSnapshot(state) ||
      ((state.raven === null) !== (state.delivery === "codebase-memory-only")) ||
      !isTimestamp(state.configuredAt) ||
      !isTimestamp(state.lastCheckedAt) ||
      (state.previous !== null && !isStateSnapshot(state.previous))) {
    fail("Crow Raven setup state is malformed or has an unsupported schema.");
  }
  for (const snapshot of snapshots) {
    const codebaseName = basename(snapshot.codebaseMemory.installPath);
    const codebasePrefix = `${snapshot.codebaseMemory.version}-`;
    const runtimePathIsManaged = !snapshot.raven ||
      resolve(dirname(snapshot.raven.runtimePath)) === resolve(target.versions);
    const expectedFragment = createFragment(
      snapshot.raven?.runtimePath || null,
      snapshot.serverCatalog.servers,
      snapshot.codebaseMemory.installPath,
      snapshot.delivery,
      false
    );
    if (resolve(dirname(snapshot.codebaseMemory.installPath)) !== resolve(target.codebaseMemory) ||
        !codebaseName.startsWith(codebasePrefix) ||
        !runtimePathIsManaged ||
        JSON.stringify(snapshot.managedFragment) !== JSON.stringify(expectedFragment)) {
      fail("Crow Raven setup state contains unmanaged paths or fragment commands.");
    }
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
    promotion: join(stateDir, "pending-promotion.json"),
    versions: join(stateDir, "versions"),
    codebaseMemory: join(stateDir, "codebase-memory")
  };
}

function reconcilePromotion(target) {
  if (!existsSync(target.promotion)) return;
  const promotion = readJson(target.promotion, "Crow Raven promotion journal");
  const validPair = (stagingPath, finalPath, parent) => {
    if (typeof stagingPath !== "string" || typeof finalPath !== "string") return false;
    const resolvedFinal = resolve(finalPath);
    const stagingPrefix = `${resolvedFinal}.staging-`;
    const resolvedStaging = resolve(stagingPath);
    return resolve(dirname(finalPath)) === resolve(parent) &&
      resolvedStaging.startsWith(stagingPrefix) &&
      /^\d+$/.test(resolvedStaging.slice(stagingPrefix.length));
  };
  const ravenPromotionIsValid = promotion.raven === null ||
    (isRecord(promotion.raven) &&
      validPair(promotion.raven.stagingPath, promotion.raven.runtimePath, target.versions));
  let expectedTemporaryPaths = [];
  if (promotion.raven && ravenPromotionIsValid) {
    const stagingPrefix = `${resolve(promotion.raven.runtimePath)}.staging-`;
    const processId = resolve(promotion.raven.stagingPath).slice(stagingPrefix.length);
    expectedTemporaryPaths = [
      `${promotion.raven.runtimePath}.extract-${processId}`,
      `${promotion.raven.runtimePath}.download-${processId}.tar.gz`
    ];
  }
  if (promotion.schemaVersion !== 1 ||
      !isRecord(promotion.codebaseMemory) ||
      !validPair(
        promotion.codebaseMemory.stagingPath,
        promotion.codebaseMemory.installPath,
        target.codebaseMemory
      ) ||
      !ravenPromotionIsValid ||
      !Array.isArray(promotion.temporaryPaths) ||
      JSON.stringify(promotion.temporaryPaths) !== JSON.stringify(expectedTemporaryPaths)) {
    fail("Crow Raven promotion journal is malformed or contains unmanaged paths.");
  }
  const state = existsSync(target.state)
    ? readJson(target.state, "Crow Raven setup state during promotion recovery")
    : null;
  const promotionIsActive =
    state?.codebaseMemory?.installPath === promotion.codebaseMemory.installPath &&
    state?.raven?.runtimePath === promotion.raven?.runtimePath;
  const cleanup = promotionIsActive
    ? [
        promotion.codebaseMemory.stagingPath,
        promotion.raven?.stagingPath,
        ...promotion.temporaryPaths
      ]
    : [
        promotion.codebaseMemory.stagingPath,
        promotion.codebaseMemory.installPath,
        promotion.raven?.stagingPath,
        promotion.raven?.runtimePath,
        ...promotion.temporaryPaths
      ];
  for (const path of cleanup.filter(Boolean)) {
    if (existsSync(path)) rmSync(path, { recursive: true, force: true });
  }
  rmSync(target.promotion, { force: true });
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

function assertPrerequisites({
  requiresGit = false,
  requiresReleaseTools = false,
  requiresSourceNode = false
} = {}) {
  const [major, minor] = process.versions.node.split(".").map(Number);
  if (major < 18) {
    fail(`codebase-memory-mcp requires Node.js 18 or later; found ${process.versions.node}.`);
  }
  const sourceSupported = (major === 22 && minor >= 12) || major === 24 || major >= 26;
  if (requiresSourceNode && !sourceSupported) {
    fail(`Raven requires Node.js 22.12.x, 24.x, or 26+; found ${process.versions.node}.`);
  }
  if (npmCli && !existsSync(npmCli)) fail(`npm CLI was not found beside Node.js: ${npmCli}`);
  if (requiresGit) run("git", ["--version"], { capture: true });
  if (requiresReleaseTools) {
    run("gh", ["--version"], { capture: true });
    run("tar", ["--version"], { capture: true });
  }
  runNpm(["--version"], { capture: true });
}

function resolveRavenRevision(ref) {
  if (/^[0-9a-f]{40}$/i.test(ref)) return ref.toLowerCase();
  const candidates = ref === "main"
    ? [`refs/heads/${ref}`]
    : [`refs/tags/${ref}^{}`, `refs/tags/${ref}`];
  for (const candidate of candidates) {
    const output = run(
      "git",
      ["ls-remote", ravenUrl, candidate],
      { capture: true, timeout: networkTimeoutMs }
    );
    const revision = output.split(/\s+/)[0];
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

async function fetchJson(url, label) {
  let response;
  try {
    response = await fetch(url, {
      headers: { "User-Agent": "bcgov-crow-raven-setup" },
      signal: AbortSignal.timeout(networkTimeoutMs)
    });
  } catch (error) {
    fail(`Could not query ${label}: ${error.message}`);
  }
  if (!response.ok) fail(`${label} returned HTTP ${response.status}.`);
  const bytes = Buffer.from(await response.arrayBuffer());
  try {
    return { bytes, value: JSON.parse(bytes.toString("utf8")) };
  } catch (error) {
    fail(`${label} returned invalid JSON: ${error.message}`);
  }
}

function validateReleaseManifest(manifest, version, platform) {
  const bundleName = `raven-${version}-${platform}`;
  if (manifest.schemaVersion !== 1 ||
      manifest.suiteVersion !== version ||
      manifest.sourceRepository !== ravenRepositoryUrl ||
      !/^[0-9a-f]{40}$/.test(manifest.sourceCommit || "") ||
      manifest.platform !== platform ||
      manifest.protocolCompatibility !== "MCP over stdio" ||
      manifest.archive !== `${bundleName}.tar.gz` ||
      !/^[0-9a-f]{64}$/.test(manifest.archiveSha256 || "") ||
      manifest.catalog !== "server-catalog.json" ||
      !/^[0-9a-f]{64}$/.test(manifest.catalogSha256 || "") ||
      manifest.smokeTests?.status !== "passed" ||
      !Number.isInteger(manifest.smokeTests?.startedServerCount) ||
      manifest.smokeTests.startedServerCount < 1) {
    fail(`Raven ${version} returned an unsupported ${platform} release manifest.`);
  }
}

function validateReleaseCatalog(releaseCatalog, manifest) {
  if (releaseCatalog.schemaVersion !== 1 ||
      releaseCatalog.suiteVersion !== manifest.suiteVersion ||
      releaseCatalog.nodeVersion !== manifest.nodeVersion ||
      releaseCatalog.protocolCompatibility !== manifest.protocolCompatibility ||
      !releaseCatalog.supportedPlatforms?.includes(manifest.platform) ||
      !Array.isArray(releaseCatalog.servers) ||
      releaseCatalog.servers.length !== manifest.smokeTests.startedServerCount) {
    fail(`Raven ${manifest.suiteVersion} returned an unsupported server catalog.`);
  }
}

async function resolveRavenRelease(version) {
  if (!["darwin-x64", "linux-x64", "win32-x64"].includes(ravenPlatform)) {
    fail(`Raven bundled releases do not support '${ravenPlatform}'. Use --delivery source.`);
  }
  const releaseUrl = version
    ? `${ravenApi}/releases/tags/v${version}`
    : `${ravenApi}/releases/latest`;
  const { value: release } = await fetchJson(releaseUrl, "Raven release metadata");
  if (release.draft || release.prerelease || !/^v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(release.tag_name || "")) {
    fail("Raven release metadata does not identify a stable published SemVer release.");
  }
  const suiteVersion = release.tag_name.slice(1);
  if (version && suiteVersion !== version) {
    fail(`Raven release resolved to ${suiteVersion}, expected ${version}.`);
  }
  const bundleName = `raven-${suiteVersion}-${ravenPlatform}`;
  const asset = (name) => release.assets?.find((candidate) => candidate.name === name);
  const manifestAsset = asset(`${bundleName}.manifest.json`);
  const archiveAsset = asset(`${bundleName}.tar.gz`);
  if (!manifestAsset?.browser_download_url || !archiveAsset?.browser_download_url) {
    fail(`Raven ${suiteVersion} does not publish the required ${ravenPlatform} assets.`);
  }
  const { value: manifest } = await fetchJson(
    manifestAsset.browser_download_url,
    "Raven release manifest"
  );
  validateReleaseManifest(manifest, suiteVersion, ravenPlatform);
  if (archiveAsset.digest &&
      archiveAsset.digest !== `sha256:${manifest.archiveSha256}`) {
    fail("Raven release archive digest differs from the signed release manifest.");
  }
  const catalogUrl =
    `${ravenRawUrl}/${release.tag_name}/release/server-catalog.json`;
  const { bytes: catalogBytes, value: releaseCatalog } = await fetchJson(
    catalogUrl,
    "Raven release catalog"
  );
  if (createHash("sha256").update(catalogBytes).digest("hex") !== manifest.catalogSha256) {
    fail("Raven release catalog digest differs from the release manifest.");
  }
  validateReleaseCatalog(releaseCatalog, manifest);
  return {
    delivery: "bundled-release",
    suiteVersion,
    releaseTag: release.tag_name,
    platform: ravenPlatform,
    sourceCommit: manifest.sourceCommit,
    archive: manifest.archive,
    archiveSha256: manifest.archiveSha256,
    archiveUrl: archiveAsset.browser_download_url,
    catalogSha256: manifest.catalogSha256,
    provenanceVerification: manifest.provenanceVerification,
    runtimeNodeVersion: manifest.nodeVersion,
    releasedCatalog: releaseCatalog
  };
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

function createFragment(
  runtimePath,
  servers,
  codebaseInstallPath,
  ravenDelivery,
  validatePaths = true
) {
  const codebaseEntrypoint = join(
    codebaseInstallPath,
    "node_modules",
    "codebase-memory-mcp",
    "bin.js"
  );
  if (validatePaths && !existsSync(codebaseEntrypoint)) {
    fail(`codebase-memory-mcp entrypoint is missing: ${codebaseEntrypoint}`);
  }
  const mcpServers = {
    "codebase-memory-mcp": {
      command: process.execPath,
      args: [codebaseEntrypoint]
    }
  };
  for (const server of servers) {
    if (ravenDelivery === "bundled-release") {
      const launcher = join(
        runtimePath,
        "bin",
        process.platform === "win32" ? `${server.launcher}.cmd` : server.launcher
      );
      if (validatePaths && !existsSync(launcher)) fail(`Raven launcher is missing: ${launcher}`);
      mcpServers[server.id] = { command: launcher, args: [] };
    } else {
      const entrypoint = join(runtimePath, ...server.entrypoint.split("/"));
      if (validatePaths && !existsSync(entrypoint)) fail(`Built entrypoint is missing: ${entrypoint}`);
      mcpServers[server.id] = { command: process.execPath, args: [entrypoint] };
    }
  }
  return { mcpServers };
}

function startupInvocation(command, args) {
  if (process.platform !== "win32" || !command.toLowerCase().endsWith(".cmd")) {
    return { command, args };
  }
  if (args.length > 0) {
    fail("Windows Raven launchers do not accept Crow-managed command arguments.");
  }
  const commandProcessor = process.env.ComSpec;
  if (!commandProcessor) fail("ComSpec is required to verify Windows Raven launchers.");
  return {
    command: commandProcessor,
    args: ["/d", "/s", "/c", "call", command]
  };
}

function isValidRavenPlan(plan) {
  if (plan.selectedServers.length === 0) {
    return plan.raven === null && plan.delivery === "codebase-memory-only";
  }
  if (!isRecord(plan.raven) || plan.raven.delivery !== plan.delivery) return false;
  if (plan.delivery === "pinned-source") {
    return /^[0-9a-f]{40}$/.test(plan.raven.revision || "");
  }
  if (plan.delivery !== "bundled-release") return false;
  return /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(plan.raven.suiteVersion || "") &&
    plan.raven.releaseTag === `v${plan.raven.suiteVersion}` &&
    plan.raven.platform === ravenPlatform &&
    /^[0-9a-f]{40}$/.test(plan.raven.sourceCommit || "") &&
    plan.raven.archive ===
      `raven-${plan.raven.suiteVersion}-${plan.raven.platform}.tar.gz` &&
    plan.raven.archiveUrl ===
      `${ravenRepositoryUrl}/releases/download/${plan.raven.releaseTag}/${plan.raven.archive}` &&
    /^[0-9a-f]{64}$/.test(plan.raven.archiveSha256 || "") &&
    /^[0-9a-f]{64}$/.test(plan.raven.catalogSha256 || "");
}

function validatePlan(plan, planPath) {
  if (plan.schemaVersion !== 1 ||
      plan.action !== "setup" ||
      !["bundled-release", "pinned-source", "codebase-memory-only"].includes(plan.delivery) ||
      !Array.isArray(plan.selectedServers) ||
      !isServerCatalogSnapshot(plan.serverCatalog) ||
      !isRecord(plan.codebaseMemory) ||
      typeof plan.codebaseMemory.installPath !== "string" ||
      JSON.stringify(plan.serverCatalog.servers) !==
        JSON.stringify(plan.selectedServers) ||
      !isValidRavenPlan(plan)) {
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
    const runtimePrefix = plan.delivery === "bundled-release"
      ? `${plan.raven.suiteVersion}-${plan.raven.platform}-`
      : `${plan.raven.revision}-`;
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

function codebaseInstallArgs(stagingPath, version) {
  return [
    "install",
    "--prefix", stagingPath,
    "--save-exact",
    "--omit=dev",
    "--no-audit",
    "--no-fund",
    ...(process.platform === "win32" ? ["--ignore-scripts"] : []),
    `codebase-memory-mcp@${version}`
  ];
}

function runCodebaseWindowsInstaller(stagingPath) {
  const packagePath = join(stagingPath, "node_modules", "codebase-memory-mcp");
  const installerPath = join(packagePath, "install.js");
  const original = readFileSync(installerPath, "utf8");
  const timeoutDeclaration = "const CANDIDATE_TIMEOUT_MS = 15_000;";
  if (!original.includes(timeoutDeclaration)) {
    fail("codebase-memory-mcp Windows installer has an unsupported candidate-timeout contract.");
  }
  const adjusted = original.replace(
    timeoutDeclaration,
    `const CANDIDATE_TIMEOUT_MS = ${codebaseWindowsCandidateTimeoutMs};`
  );
  writeFileSync(installerPath, adjusted, "utf8");
  const result = spawnSync(process.execPath, [installerPath], {
    cwd: packagePath,
    encoding: "utf8",
    stdio: "inherit",
    shell: false,
    timeout: 10 * 60 * 1000,
    windowsHide: true
  });
  writeFileSync(installerPath, original, "utf8");
  if (result.error?.code === "ETIMEDOUT") {
    fail("codebase-memory-mcp Windows installer exceeded the 10-minute setup timeout.");
  }
  if (result.error) fail(`Could not run codebase-memory-mcp installer: ${result.error.message}`);
  if (result.status !== 0) {
    fail(`codebase-memory-mcp installer exited with code ${result.status}.`);
  }
}

function stageCodebaseMemory(installPath, version) {
  const stagingPath = `${installPath}.staging-${process.pid}`;
  if (existsSync(stagingPath)) rmSync(stagingPath, { recursive: true, force: true });
  mkdirSync(dirname(installPath), { recursive: true });
  mkdirSync(stagingPath);
  runNpm(codebaseInstallArgs(stagingPath, version));
  if (process.platform === "win32") runCodebaseWindowsInstaller(stagingPath);
  return { stagingPath, ...validateCodebaseInstall(stagingPath, version) };
}

async function downloadFile(url, path, label) {
  let response;
  try {
    response = await fetch(url, {
      headers: { "User-Agent": "bcgov-crow-raven-setup" },
      redirect: "follow",
      signal: AbortSignal.timeout(5 * 60 * 1000)
    });
  } catch (error) {
    fail(`Could not download ${label}: ${error.message}`);
  }
  if (!response.ok || !response.body) {
    fail(`${label} download returned HTTP ${response.status}.`);
  }
  await pipeline(Readable.fromWeb(response.body), createWriteStream(path, { mode: 0o600 }));
}

async function sha256File(path) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}

async function sha256Tree(root, excludeGit = false) {
  const hash = createHash("sha256");
  const visit = async (directory, relativeDirectory = "") => {
    const entries = readdirSync(directory, { withFileTypes: true })
      .sort((left, right) => left.name.localeCompare(right.name));
    for (const entry of entries) {
      const relativePath = relativeDirectory
        ? `${relativeDirectory}/${entry.name}`
        : entry.name;
      if (excludeGit && (relativePath === ".git" || relativePath.startsWith(".git/"))) {
        continue;
      }
      const path = join(directory, entry.name);
      const metadata = lstatSync(path);
      if (metadata.isSymbolicLink()) {
        hash.update(`L\0${relativePath}\0${readlinkSync(path)}\0`);
      } else if (metadata.isDirectory()) {
        hash.update(`D\0${relativePath}\0`);
        await visit(path, relativePath);
      } else if (metadata.isFile()) {
        hash.update(`F\0${relativePath}\0${metadata.mode & 0o777}\0${metadata.size}\0`);
        for await (const chunk of createReadStream(path)) hash.update(chunk);
        hash.update("\0");
      } else {
        fail(`Raven runtime contains unsupported filesystem entry '${relativePath}'.`);
      }
    }
  };
  await visit(root);
  return hash.digest("hex");
}

function releasedServers(selected, releasedCatalog) {
  const released = new Map(releasedCatalog.servers.map((server) => [server.id, server]));
  return selected.map((server) => {
    const contract = released.get(server.id);
    if (!contract ||
        contract.entrypoint !== server.entrypoint ||
        contract.packageVersion !== server.packageVersion ||
        contract.access !== server.access ||
        typeof contract.package !== "string" ||
        !/^raven-[a-z0-9-]+$/.test(contract.launcher || "")) {
      fail(`Raven release contract for '${server.id}' differs from Crow's reviewed catalog.`);
    }
    return { ...server, package: contract.package, launcher: contract.launcher };
  });
}

async function stageRavenBundle(raven) {
  const stagingRoot = `${raven.runtimePath}.staging-${process.pid}`;
  const extractionRoot = `${raven.runtimePath}.extract-${process.pid}`;
  const archivePath = `${raven.runtimePath}.download-${process.pid}.tar.gz`;
  for (const path of [stagingRoot, extractionRoot, archivePath]) {
    if (existsSync(path)) rmSync(path, { recursive: true, force: true });
  }
  mkdirSync(dirname(raven.runtimePath), { recursive: true });
  await downloadFile(raven.archiveUrl, archivePath, `Raven ${raven.suiteVersion} archive`);
  if (await sha256File(archivePath) !== raven.archiveSha256) {
    rmSync(archivePath, { force: true });
    fail("Downloaded Raven archive digest differs from the reviewed manifest.");
  }
  run("gh", ["attestation", "verify", archivePath, "--repo", ravenRepository], {
    capture: true,
    timeout: 2 * 60 * 1000
  });
  mkdirSync(extractionRoot);
  run("tar", ["-xzf", archivePath, "-C", extractionRoot], {
    capture: true,
    timeout: 2 * 60 * 1000
  });
  rmSync(archivePath, { force: true });
  const extracted = join(
    extractionRoot,
    `raven-${raven.suiteVersion}-${raven.platform}`
  );
  if (!existsSync(extracted)) {
    rmSync(extractionRoot, { recursive: true, force: true });
    fail("Raven archive does not contain its canonical bundle directory.");
  }
  try {
    renameSync(extracted, stagingRoot);
  } catch (error) {
    if (process.platform !== "win32" || error.code !== "EPERM") throw error;
    cpSync(extracted, stagingRoot, {
      recursive: true,
      errorOnExist: true,
      force: false,
      verbatimSymlinks: true
    });
    rmSync(extracted, { recursive: true, force: true });
  }
  rmSync(extractionRoot, { recursive: true, force: true });
  const metadata = readJson(join(stagingRoot, "bundle-metadata.json"), "Raven bundle metadata");
  const embeddedCatalogPath = join(stagingRoot, "server-catalog.json");
  if (metadata.schemaVersion !== 1 ||
      metadata.suiteVersion !== raven.suiteVersion ||
      metadata.sourceCommit !== raven.sourceCommit ||
      metadata.platform !== raven.platform ||
      metadata.smokeTests?.status !== "passed" ||
      await sha256File(embeddedCatalogPath) !== raven.catalogSha256) {
    rmSync(stagingRoot, { recursive: true, force: true });
    fail("Extracted Raven bundle metadata differs from the reviewed release.");
  }
  return stagingRoot;
}

function terminateProcessTree(child, force = false) {
  if (process.platform === "win32") {
    if (!Number.isInteger(child.pid)) return "child process ID is unavailable";
    const windowsRoot = process.env.SystemRoot || process.env.windir;
    if (!windowsRoot) return "the Windows system root is unavailable";
    const taskkill = join(windowsRoot, "System32", "taskkill.exe");
    const result = spawnSync(
      taskkill,
      ["/PID", String(child.pid), "/T", "/F"],
      { encoding: "utf8", stdio: "pipe", shell: false }
    );
    if (result.status === 0) return null;
    return (result.stderr || result.stdout || `taskkill exited with ${result.status}`).trim();
  }
  const signal = force ? "SIGKILL" : "SIGTERM";
  if (child.kill(signal)) return null;
  return "the process did not accept the termination signal";
}

async function verifyStartup(name, command, args, cwd) {
  const invocation = startupInvocation(command, args);
  await new Promise((resolvePromise, rejectPromise) => {
    const child = spawn(invocation.command, invocation.args, {
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
      const stopError = terminateProcessTree(child);
      if (stopError) {
        rejectPromise(new Error(`${name} process tree could not be stopped: ${stopError}`));
        return;
      }
      expectedStop = true;
      forceStopTimer = setTimeout(() => {
        const forceStopError = terminateProcessTree(child, true);
        child.stdin.destroy();
        child.stdout.destroy();
        child.stderr.destroy();
        child.unref();
        const detail = forceStopError ? ` ${forceStopError}` : "";
        rejectPromise(new Error(
          `${name} did not stop within ${startupStopMs}ms; process ID ${child.pid}.${detail}`
        ));
      }, startupStopMs);
    }, startupGraceMs);
  });
}

async function validateInstalledSnapshot(snapshot) {
  const codebase = validateCodebaseInstall(
    snapshot.codebaseMemory.installPath,
    snapshot.codebaseMemory.version
  );
  if (codebase.integrity !== snapshot.codebaseMemory.integrity ||
      codebase.entrypointSha256 !== snapshot.codebaseMemory.entrypointSha256) {
    fail("Installed codebase-memory-mcp integrity differs from Crow's recorded state.");
  }
  const servers = snapshot.serverCatalog.servers;
  if (snapshot.raven) {
    const runtimeTreeSha256 = await sha256Tree(
      snapshot.raven.runtimePath,
      snapshot.raven.delivery === "pinned-source"
    );
    if (runtimeTreeSha256 !== snapshot.raven.runtimeTreeSha256) {
      fail("Installed Raven runtime files differ from Crow's recorded verified tree.");
    }
  }
  if (snapshot.raven?.delivery === "bundled-release") {
    const metadata = readJson(
      join(snapshot.raven.runtimePath, "bundle-metadata.json"),
      "Installed Raven bundle metadata"
    );
    if (metadata.schemaVersion !== 1 ||
        metadata.suiteVersion !== snapshot.raven.suiteVersion ||
        metadata.sourceCommit !== snapshot.raven.sourceCommit ||
        metadata.platform !== snapshot.raven.platform ||
        metadata.smokeTests?.status !== "passed" ||
        await sha256File(join(snapshot.raven.runtimePath, "server-catalog.json")) !==
          snapshot.raven.catalogSha256) {
      fail("Installed Raven bundle integrity differs from Crow's recorded state.");
    }
  } else if (snapshot.raven) {
    const revision = run(
      "git",
      ["rev-parse", "HEAD"],
      { cwd: snapshot.raven.runtimePath, capture: true }
    ).toLowerCase();
    if (revision !== snapshot.raven.revision) {
      fail("Installed Raven source revision differs from Crow's recorded state.");
    }
    validateUpstreamConfig(snapshot.raven.runtimePath, servers);
  }
  const fragment = createFragment(
    snapshot.raven?.runtimePath || null,
    servers,
    snapshot.codebaseMemory.installPath,
    snapshot.delivery
  );
  if (JSON.stringify(fragment) !== JSON.stringify(snapshot.managedFragment)) {
    fail("Crow's managed fragment differs from its recorded installed paths.");
  }
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
  plan (--servers <id,...> | --no-raven)
       [--delivery release|source] [--raven-version X.Y.Z]
       [--raven-ref main|vX.Y.Z|sha]
       [--codebase-memory-version X.Y.Z] [--state-dir <path>]
  setup --plan <path> --plan-sha256 <digest> --confirm
  check [--state-dir <path>] [--force]
  rollback [--state-dir <path>] --confirm

Plan resolves every mutable version and writes a reviewable pending-plan.json.
Raven uses verified bundled releases by default. Source builds require the
explicit --delivery source fallback. Setup does not merge client configuration
or collect credentials.`);
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
  reconcilePromotion(target);
  if (!existsSync(target.state)) {
    console.log(JSON.stringify({ configured: false, stateDir: target.stateDir }, null, 2));
    return;
  }
  const state = readState(target);
  console.log(JSON.stringify({ configured: true, ...state, stateDir: target.stateDir }, null, 2));
}

function planAssurance(raven) {
  if (!raven) return "registry-package";
  return raven.delivery === "bundled-release"
    ? "publisher-attestation-required-at-setup"
    : "transitional-source-build";
}

function ravenPlanEffects(raven) {
  if (!raven) return [];
  if (raven.delivery === "bundled-release") {
    return [
      "download the platform-specific Raven release archive",
      "verify its SHA-256 digest and GitHub build attestation before extraction",
      "validate embedded release metadata and the server catalog"
    ];
  }
  return [
    "clone and build the immutable Raven revision in a new staging directory",
    "publish the Raven runtime only after all startup checks pass"
  ];
}

function ravenPlanCommands(raven, npmCi, npmBuild) {
  if (!raven) return [];
  if (raven.delivery === "bundled-release") {
    return [
      { command: "download", args: [raven.archiveUrl, raven.archive] },
      { command: "sha256", args: [raven.archiveSha256] },
      { command: "gh", args: ["attestation", "verify", raven.archive, "--repo", ravenRepository] },
      { command: "tar", args: ["-xzf", raven.archive] }
    ];
  }
  const stagingPath = `${raven.runtimePath}.staging-<pid>`;
  return [
    { command: "git", args: ["clone", "--no-checkout", "--filter=blob:none", ravenUrl, stagingPath] },
    { command: "git", args: ["checkout", "--detach", raven.revision], cwd: stagingPath },
    { ...npmCi, cwd: stagingPath },
    { ...npmBuild, cwd: stagingPath }
  ];
}

async function planCommand(args) {
  const serverCatalog = catalog();
  let servers = selectedServers(args, serverCatalog);
  const includesRaven = servers.length > 0;
  const requestedDelivery = args.delivery || "release";
  if (!["release", "source"].includes(requestedDelivery)) {
    fail("--delivery must be 'release' or 'source'.");
  }
  if (!includesRaven && (args["raven-ref"] || args["raven-version"] || args.delivery)) {
    fail("Raven delivery, ref, and version options cannot be combined with --no-raven.");
  }
  if (includesRaven && requestedDelivery === "release" && args["raven-ref"]) {
    fail("--raven-ref requires --delivery source.");
  }
  if (includesRaven && requestedDelivery === "source" && args["raven-version"]) {
    fail("--raven-version cannot be combined with --delivery source.");
  }
  assertPrerequisites({
    requiresGit: includesRaven && requestedDelivery === "source",
    requiresSourceNode: includesRaven && requestedDelivery === "source"
  });
  let raven = null;
  if (includesRaven && requestedDelivery === "release") {
    const release = await resolveRavenRelease(args["raven-version"]);
    servers = releasedServers(servers, release.releasedCatalog);
    const generationId = randomUUID();
    raven = {
      ...release,
      runtimePath: join(
        paths(args).versions,
        `${release.suiteVersion}-${release.platform}-${generationId}`
      )
    };
    delete raven.releasedCatalog;
  } else if (includesRaven) {
    const ref = args["raven-ref"] || "main";
    const revision = resolveRavenRevision(ref);
    raven = {
      delivery: "pinned-source",
      source: ravenUrl,
      ref,
      revision,
      freshnessTrack: ref === "main"
        ? { type: "branch", value: "main" }
        : { type: "pinned", value: ref },
      runtimePath: join(paths(args).versions, `${revision}-${randomUUID()}`)
    };
  }
  const codebaseVersion = args["codebase-memory-version"] || await latestCodebaseVersion();
  validateExactVersion(codebaseVersion);
  const target = paths(args);
  reconcilePromotion(target);
  const priorState = existsSync(target.state) ? readState(target) : null;
  const generationId = randomUUID();
  const codebaseInstallPath = join(
    target.codebaseMemory,
    `${codebaseVersion}-${generationId}`
  );
  const npmCi = npmInvocation(["ci"]);
  const npmBuild = npmInvocation(["run", "build"]);
  const plannedCodebaseStagingPath = `${codebaseInstallPath}.staging-<pid>`;
  const npmInstallCodebase = npmInvocation(
    codebaseInstallArgs(plannedCodebaseStagingPath, codebaseVersion)
  );
  const codebaseCommands = [{ ...npmInstallCodebase }];
  if (process.platform === "win32") {
    codebaseCommands.push({
      command: process.execPath,
      args: [
        join(
          plannedCodebaseStagingPath,
          "node_modules",
          "codebase-memory-mcp",
          "install.js"
        )
      ],
      note: `Run the integrity-verified upstream installer with a ${codebaseWindowsCandidateTimeoutMs}ms candidate timeout.`
    });
  }
  const plan = {
    schemaVersion: 1,
    action: "setup",
    createdAt: new Date().toISOString(),
    delivery: raven?.delivery || "codebase-memory-only",
    assurance: planAssurance(raven),
    stateDir: target.stateDir,
    raven,
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
      ...ravenPlanEffects(raven),
      "install the exact codebase-memory-mcp package in an isolated user-local directory",
      "startup-smoke-test codebase-memory-mcp and every selected Raven server",
      "replace only Crow's state.json and mcp-fragment.json after verification"
    ],
    commands: [
      ...ravenPlanCommands(raven, npmCi, npmBuild),
      ...codebaseCommands
    ]
  };
  writeJsonAtomic(target.plan, plan);
  console.log(JSON.stringify({ planPath: target.plan, planSha256: planDigest(plan), ...plan }, null, 2));
}

function validatePlannedServers(plan) {
  const serverCatalog = catalog();
  const servers = selectedServers(
    plan.selectedServers.length > 0
      ? { servers: plan.selectedServers.map((server) => server.id).join(",") }
      : { "no-raven": true },
    serverCatalog
  );
  for (const server of servers) {
    const planned = plan.selectedServers.find((candidate) => candidate.id === server.id);
    const reviewedFields = Object.fromEntries(
      Object.entries(planned || {}).filter(([key]) => !["package", "launcher"].includes(key))
    );
    if (JSON.stringify(reviewedFields) !== JSON.stringify(server)) {
      fail(`Planned metadata for '${server.id}' differs from Crow's reviewed catalog.`);
    }
    if (plan.delivery === "bundled-release" &&
        (typeof planned.package !== "string" || typeof planned.launcher !== "string")) {
      fail(`Released metadata for '${server.id}' is incomplete.`);
    }
  }
  return plan.selectedServers;
}

function ensureGenerationAvailable(plan, priorState) {
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
}

async function stageRavenRuntime(plan, target, servers, runtimeStagingPath) {
  if (!runtimeStagingPath) return;
  mkdirSync(target.versions, { recursive: true });
  if (plan.delivery === "bundled-release") {
    await stageRavenBundle(plan.raven);
    return;
  }
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

async function setupCommand(args) {
  if (!args.confirm) fail("Setup requires --confirm after the user reviews the resolved plan.");
  if (!args.plan) fail("Setup requires --plan <path> from the plan command.");
  if (!/^[0-9a-f]{64}$/i.test(args["plan-sha256"] || "")) {
    fail("Setup requires --plan-sha256 <digest> from the reviewed plan output.");
  }
  const planPath = resolve(args.plan);
  const plan = readJson(planPath, "Crow Raven setup plan");
  validatePlan(plan, planPath);
  assertPrerequisites({
    requiresGit: plan.delivery === "pinned-source",
    requiresReleaseTools: plan.delivery === "bundled-release",
    requiresSourceNode: plan.delivery === "pinned-source"
  });
  if (planDigest(plan) !== args["plan-sha256"].toLowerCase()) {
    fail("Setup plan content changed after review; generate and review a new plan.");
  }
  const target = paths({ "state-dir": plan.stateDir });
  if (resolve(target.plan) !== planPath) {
    fail(`Plan must be the managed pending plan at ${target.plan}.`);
  }
  reconcilePromotion(target);
  const servers = validatePlannedServers(plan);
  const codebaseVersion = plan.codebaseMemory.version;
  const priorState = existsSync(target.state) ? readState(target) : null;
  ensureGenerationAvailable(plan, priorState);

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

  const codebaseStagingPath = `${codebaseInstallPath}.staging-${process.pid}`;
  const temporaryPaths = runtimePath ? [
    `${runtimePath}.extract-${process.pid}`,
    `${runtimePath}.download-${process.pid}.tar.gz`
  ] : [];
  writeJsonAtomic(target.promotion, {
    schemaVersion: 1,
    codebaseMemory: {
      stagingPath: codebaseStagingPath,
      installPath: codebaseInstallPath
    },
    raven: runtimePath ? {
      stagingPath: runtimeStagingPath,
      runtimePath
    } : null,
    temporaryPaths
  });
  let cleanupArmed = true;
  const cleanupUnpromotedGeneration = () => {
    if (cleanupArmed && existsSync(target.promotion)) reconcilePromotion(target);
  };
  process.once("exit", cleanupUnpromotedGeneration);

  await stageRavenRuntime(plan, target, servers, runtimeStagingPath);

  const codebaseInstall = stageCodebaseMemory(codebaseInstallPath, codebaseVersion);
  if (codebaseInstall.stagingPath !== codebaseStagingPath) {
    fail("codebase-memory-mcp staging path differs from the promotion journal.");
  }
  const stagingFragment = createFragment(
    runtimeStagingPath,
    servers,
    codebaseInstall.stagingPath,
    plan.delivery
  );
  try {
    await verifyFragment(stagingFragment, runtimeStagingPath, servers);
  } catch (error) {
    fail(error.message);
  }
  const runtimeTreeSha256 = runtimeStagingPath
    ? await sha256Tree(runtimeStagingPath, plan.delivery === "pinned-source")
    : null;

  const fragment = createFragment(
    runtimePath,
    servers,
    codebaseInstallPath,
    plan.delivery,
    false
  );
  const now = new Date().toISOString();
  const state = {
    schemaVersion: 1,
    delivery: plan.delivery,
    raven: plan.raven ? { ...plan.raven, runtimePath, runtimeTreeSha256 } : null,
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
      delivery: priorState.delivery,
      raven: priorState.raven,
      codebaseMemory: priorState.codebaseMemory,
      selectedServers: priorState.selectedServers,
      serverCatalog: priorState.serverCatalog,
      managedFragment: priorState.managedFragment
    } : null
  };
  try {
    renameSync(codebaseInstall.stagingPath, codebaseInstallPath);
    if (runtimeStagingPath) renameSync(runtimeStagingPath, runtimePath);
    writeJsonAtomic(target.state, state, { throwOnError: true });
    writeJsonAtomic(target.fragment, fragment, { throwOnError: true });
    rmSync(target.promotion, { force: true });
    cleanupArmed = false;
    process.removeListener("exit", cleanupUnpromotedGeneration);
  } catch (error) {
    reconcilePromotion(target);
    fail(`Could not promote the verified setup: ${error.message}`);
  }
  console.log(JSON.stringify({ statePath: target.state, fragmentPath: target.fragment, ...state }, null, 2));
}

async function checkCommand(args) {
  const target = paths(args);
  reconcilePromotion(target);
  if (!existsSync(target.state)) fail("Crow Raven setup is not configured.");
  const state = readState(target);
  await validateInstalledSnapshot(state);
  const lastChecked = Date.parse(state.lastCheckedAt || "");
  const age = Date.now() - lastChecked;
  if (!Number.isFinite(lastChecked) || age < 0) {
    fail("Crow Raven setup state has an invalid future lastCheckedAt timestamp.");
  }
  if (!args.force && Number.isFinite(lastChecked) && age < 24 * 60 * 60 * 1000) {
    console.log(JSON.stringify({ checked: false, reason: "fresh", lastCheckedAt: state.lastCheckedAt }, null, 2));
    return;
  }
  assertPrerequisites({
    requiresGit: state.delivery === "pinned-source",
    requiresSourceNode: state.delivery === "pinned-source"
  });
  const freshnessTrack = state.raven?.freshnessTrack || null;
  const latestRelease = state.delivery === "bundled-release"
    ? await resolveRavenRelease()
    : null;
  const latestRevision = freshnessTrack?.type === "branch"
    ? resolveRavenRevision(freshnessTrack.value)
    : state.raven?.revision || null;
  const latestCodebase = await latestCodebaseVersion();
  state.lastCheckedAt = new Date().toISOString();
  writeJsonAtomic(target.state, state);
  let ravenResult = null;
  if (state.raven && state.delivery === "bundled-release") {
    ravenResult = {
      current: state.raven.suiteVersion,
      latest: latestRelease.suiteVersion,
      track: { type: "release", value: "latest" },
      updateAvailable: state.raven.suiteVersion !== latestRelease.suiteVersion,
      note: null
    };
  } else if (state.raven) {
    ravenResult = {
      current: state.raven.revision,
      latest: latestRevision,
      track: freshnessTrack,
      updateAvailable: state.raven.revision !== latestRevision,
      note: freshnessTrack.type === "pinned"
        ? "Pinned refs have no automatic Raven update track."
        : null
    };
  }
  const result = {
    checked: true,
    raven: ravenResult,
    codebaseMemory: { current: state.codebaseMemory.version, latest: latestCodebase, updateAvailable: state.codebaseMemory.version !== latestCodebase },
    crowPackage: checkCrowApmUpdate()
  };
  console.log(JSON.stringify(result, null, 2));
  if (result.crowPackage.error) process.exitCode = 1;
  if (result.raven?.updateAvailable || result.codebaseMemory.updateAvailable) process.exitCode = 10;
  if (result.crowPackage.updateAvailable) process.exitCode = 10;
}

async function rollbackCommand(args) {
  if (!args.confirm) fail("Rollback requires --confirm after the user reviews the target.");
  const target = paths(args);
  reconcilePromotion(target);
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
  await validateInstalledSnapshot(state.previous);
  try {
    await verifyFragment(fragment, state.previous.raven?.runtimePath, servers);
  } catch (error) {
    fail(error.message);
  }
  const current = {
    delivery: state.delivery,
    raven: state.raven,
    codebaseMemory: state.codebaseMemory,
    selectedServers: state.selectedServers,
    serverCatalog: state.serverCatalog,
    managedFragment: state.managedFragment
  };
  state.delivery = state.previous.delivery;
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

export {
  checkCrowApmUpdate,
  createFragment,
  parseCrowOutdatedOutput,
  ravenRepositoryUrl,
  releasedServers,
  sha256Tree,
  startupInvocation,
  validateReleaseCatalog,
  validateReleaseManifest,
  verifyStartup
};

if (import.meta.url === pathToFileURL(resolve(process.argv[1] || "")).href) {
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
}
