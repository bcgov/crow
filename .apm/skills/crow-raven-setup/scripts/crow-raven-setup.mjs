#!/usr/bin/env node

/**
 * Purpose:
 *   Plans, installs, verifies, updates and rolls back Crow's managed Raven
 *   MCP servers and codebase-memory-mcp, and runs the optional daily update
 *   check. Nothing is installed without a reviewed plan, its digest and
 *   --confirm. Credentials are never collected here.
 *
 * Layer: Skill script (crow-raven-setup), Node.js ESM, no third-party deps.
 *
 * Usage Examples:
 *   node crow-raven-setup.mjs list [--group <id>]
 *   node crow-raven-setup.mjs preflight [--delivery release|source|none]
 *   node crow-raven-setup.mjs plan --servers <id,...> | --no-raven
 *   node crow-raven-setup.mjs setup --plan <path> --plan-sha256 <digest> --confirm
 *   node crow-raven-setup.mjs config preview|apply --client copilot|portable
 *   node crow-raven-setup.mjs check [--force]
 *   node crow-raven-setup.mjs rollback --confirm
 *   node crow-raven-setup.mjs help   (full command reference)
 *
 * CLI Arguments:
 *   Commands: help, list, status, preflight, plan, setup, config, check,
 *   rollback, update-check, update-hook, update-hook-event.
 *   Common: --state-dir, --servers, --no-raven, --delivery, --raven-version,
 *   --raven-ref, --codebase-memory-version, --plan, --plan-sha256, --confirm,
 *   --force, --client, --config, --approval-sha256.
 *
 * Key Input Dependencies:
 *   - ../assets/raven-servers.json (reviewed server catalog)
 *   - ./client-config.mjs (client config preview and apply)
 *   - External tools: node, npm, git, gh (authenticated), tar, apm
 *   - Network: GitHub releases API, npm registry
 *   - State directory (default per user) holding state.json,
 *     mcp-fragment.json, pending-plan.json and versions/
 *
 * Key Functions:
 *   Core helpers: fail, parseArgs, run, findExecutable, npmInvocation, runNpm,
 *     writeJsonAtomic, readJson, paths, catalog, selectedServers
 *   Prerequisites: prerequisiteInvocation, inspectPrerequisite,
 *     preflightCommand, assertPrerequisites, verifyGitHubAuth
 *   State validation: isRecord, isTimestamp, isRavenState, isCodebaseState,
 *     isServerCatalogSnapshot, isManagedFragment, isStateSnapshot, readState,
 *     reconcilePromotion, readConfiguredUpdateVersions
 *   Release and version resolution: resolveRavenRevision, resolveRavenRelease,
 *     fetchLatestCodebaseVersion, latestCodebaseVersion, fetchJson,
 *     validateReleaseManifest, validateReleaseCatalog, releasedServers,
 *     validateExactVersion, validateUpstreamConfig
 *   Plan: planCommand, validatePlan, validatePlannedServers, planDigest,
 *     catalogSnapshot, planAssurance, ravenPlanEffects, ravenPlanCommands,
 *     isValidRavenPlan, ensureGenerationAvailable
 *   Install: setupCommand, stageRavenRuntime, stageRavenBundle,
 *     stageCodebaseMemory, codebaseInstallArgs, runCodebaseWindowsInstaller,
 *     validateCodebaseInstall, createFragment, downloadFile, sha256File,
 *     sha256Tree, credentialSetupResult
 *   Verify and process control: verifyStartup, verifyFragment, startupInvocation,
 *     validateInstalledSnapshot, isProcessRunning, taskkillTerminationError,
 *     terminateProcessTree
 *   Commands: printHelp, listCommand, statusCommand, configCommand,
 *     checkCommand, rollbackCommand
 *   Crow update check, APM: runApm, parseCrowOutdatedOutput, checkCrowApmUpdate,
 *     removeApmInlineComment, removeApmQuotes, normalizeCrowApmSelector,
 *     readCrowApmYamlValue, parseInlineCrowApmSelectors, parseCrowApmDependency,
 *     appendCrowApmDependency, parseGlobalApmCrowSelectors,
 *     readGlobalCrowApmSelectors, readApmInstalledPackageVersion,
 *     resolveInstalledCrowPackage, readCrowPackageVersion, crowUpdateInstallCommand
 *   Crow update check, versions: normalizeCrowVersion, compareCrowVersions,
 *     latestCrowVersion, latestRavenVersion, normalizeUpdateReleaseVersion,
 *     compareNumericPrereleaseIdentifiers, compareUpdatePrereleaseIdentifiers,
 *     compareUpdatePrereleaseVersions, compareUpdateReleaseVersions,
 *     isUpdateReleaseVersion, normalizeCrowVersionOrNull
 *   Crow update check, state and locking: defaultCrowUpdateState,
 *     hasExactObjectKeys, isCrowUpdateState, readCrowUpdateState,
 *     writeCrowUpdateState, getCrowUpdatePaths, validateCrowUpdateClock,
 *     crowUpdateSkipReason, crowUpdateCheckSkipReason, acquireCrowUpdateLock,
 *     releaseCrowUpdateLock, safeUpdateCheckError, shouldNotifyCrowUpdate,
 *     readCrowManagedUpdateVersions, createCrowUpdateChecks,
 *     checkCrowUpdateComponent, collectCrowUpdateFailures,
 *     mergeCrowUpdateVersions, findCrowUpdateCandidates, runCrowUpdateCheck,
 *     checkCrowUpdates, markCrowUpdateNotified, persistSuccessfulFreshnessCheck
 *   Update hook and notices: quoteBashArgument, quotePowerShellArgument,
 *     createCrowUpdateHookConfig, readExpectedCrowUpdateHook,
 *     statusCrowUpdateHook, replaceCrowUpdateHook, installCrowUpdateHook,
 *     declineCrowUpdateHook, removeCrowUpdateHook, crowUpdateHookCommand,
 *     updateReminder, handleUpdateHookEvent, updateCheckCommand,
 *     updateHookEventCommand
 *
 * Consumed by:
 *   SKILL.md and .apm/agents/crow-raven-setup.agent.md; tested by
 *   crow-raven-setup.test.mjs.
 */

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
  rmdirSync,
  statSync,
  unlinkSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { applyClientConfig, previewClientConfig } from "./client-config.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const skillDir = resolve(scriptDir, "..");
const catalogPath = join(skillDir, "assets", "raven-servers.json");
const ravenRepository = "bcgov/raven";
const ravenRepositoryUrl = `https://github.com/${ravenRepository}`;
const ravenUrl = `${ravenRepositoryUrl}.git`;
const ravenApi = `https://api.github.com/repos/${ravenRepository}`;
const ravenRawUrl = `https://raw.githubusercontent.com/${ravenRepository}`;
const crowApi = "https://api.github.com/repos/bcgov/crow";
const npmRegistryUrl = "https://registry.npmjs.org/codebase-memory-mcp/latest";
const defaultStateDir = join(homedir(), ".crow", "raven-setup");
const defaultCrowUpdateStateDir = join(homedir(), ".crow", "update-check");
const npmCli = process.platform === "win32"
  ? join(dirname(process.execPath), "node_modules", "npm", "bin", "npm-cli.js")
  : null;
const planLifetimeMs = 24 * 60 * 60 * 1000;
const crowUpdateCheckIntervalMs = 24 * 60 * 60 * 1000;
const crowUpdateRetryIntervalMs = 60 * 60 * 1000;
const crowUpdateLockStaleMs = 30 * 1000;
const crowUpdateCheckTimeoutMs = 5000;
const crowUpdateHookTimeoutSeconds = 20;
const crowUpdateHookFileName = "crow-update-notification.json";
const updateReleaseVersionPattern =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+([0-9A-Za-z.-]+))?$/;
const startupGraceMs = 5000;
const startupStopMs = 2000;
const networkTimeoutMs = 10000;
const codebaseWindowsCandidateTimeoutMs = 120000;
const ravenPlatform = `${process.platform}-${process.arch}`;

/** Prints an ERROR line to stderr and exits the process with the given code. */
function fail(message, code = 1) {
  console.error(`ERROR: ${message}`);
  process.exit(code);
}

/**
 * Parses command-line tokens into positional words (`_`) and `--key value`
 * options. The flags confirm, force, no-raven and sonar are booleans; any
 * other option consumes the next token, and a missing value is a hard error.
 *
 * @param {string[]} values - Raw argv tokens after the script name.
 * @returns {object} Parsed options with positional arguments in `_`.
 */
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
    if (["confirm", "force", "no-raven", "sonar"].includes(key)) {
      parsed[key] = true;
      continue;
    }
    pendingKey = key;
  }
  if (pendingKey) fail(`Missing value for --${pendingKey}.`);
  return parsed;
}

/**
 * Runs an external command synchronously without a shell and fails the whole
 * process on timeout, spawn error or non-zero exit. gh, tar, git and npm are
 * resolved through findExecutable so standard install locations are found.
 *
 * @param {string} command - Executable name.
 * @param {string[]} args - Arguments, passed without shell interpretation.
 * @param {{cwd?: string, capture?: boolean, timeout?: number}} options - Run options.
 * @returns {string} Trimmed stdout when capture is set, otherwise "".
 */
function run(command, args, options = {}) {
  const executable = ["gh", "tar", "git", "npm"].includes(command)
    ? findExecutable(command)?.path || command : command;
  const result = spawnSync(executable, args, {
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

/**
 * Finds an executable on PATH and in well-known per-platform install
 * directories, so tools installed outside the client's PATH are still located.
 *
 * @param {string} name - Executable name without extension.
 * @returns {{path: string, source: string}|null} Location and whether it came
 *   from PATH or a standard location, or null when not found.
 */
function findExecutable(name, env = process.env, platform = process.platform,
  currentExecutable = process.execPath) {
  const suffixes = platform === "win32" ? [".exe", ".cmd", ".bat", ""] : [""];
  const roots = (env.PATH || "").split(platform === "win32" ? ";" : ":").filter(Boolean);
  const standard = platform === "win32" ? [
    dirname(currentExecutable),
    join(env.SystemRoot || String.raw`C:\Windows`, "System32"),
    join(env.ProgramFiles || String.raw`C:\Program Files`, "nodejs"),
    join(env.ProgramFiles || String.raw`C:\Program Files`, "Git", "cmd"),
    join(env.ProgramFiles || String.raw`C:\Program Files`, "GitHub CLI"),
    join(env.ProgramFiles || String.raw`C:\Program Files`, "dotnet"),
    join(env["ProgramFiles(x86)"] || String.raw`C:\Program Files (x86)`, "dotnet"),
    join(env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "GitHub CLI"),
    join(env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "apm", "current"),
    join(env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "nodejs"),
    join(env.LOCALAPPDATA || join(homedir(), "AppData", "Local"), "Programs", "Git", "cmd"),
    join(env.USERPROFILE || homedir(), ".dotnet")
  ] : [
    dirname(currentExecutable), "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin",
    "/usr/local/share/dotnet", "/usr/share/dotnet", join(homedir(), ".local", "bin"),
    join(homedir(), ".dotnet")
  ];
  for (const directory of [...roots, ...standard]) {
    for (const suffix of suffixes) {
      const path = join(directory, `${name}${suffix}`);
      if (existsSync(path) && statSync(path).isFile()) {
        return { path, source: roots.includes(directory) ? "PATH" : "standard-location" };
      }
    }
  }
  return null;
}

/** Builds the command and arguments that print a prerequisite's version, handling npm's CLI script and Windows .cmd/.bat shims. */
function prerequisiteInvocation(name, path) {
  if (name === "npm" && npmCli) {
    return { command: process.execPath, args: [npmCli, "--version"] };
  }
  if (process.platform === "win32" && /\.(?:cmd|bat)$/i.test(path)) {
    return { command: process.env.ComSpec || "cmd.exe",
      args: ["/d", "/s", "/c", `"${path}" --version`] };
  }
  return { command: path, args: [name === "dotnet" ? "--list-sdks" : "--version"] };
}

/**
 * Inspects one prerequisite tool: locates it, runs its version command, and
 * reports status as available, outside-PATH, installed-but-unavailable or
 * not-installed-or-unlocated.
 *
 * @param {string} name - Tool name (node, npm, gh, tar, git, dotnet, sonar-scanner).
 * @param {boolean} required - Whether the chosen delivery mode requires it.
 * @returns {object} Inventory entry with path, version and any action text.
 */
function inspectPrerequisite(name, required) {
  const resolved = name === "node"
    ? { path: process.execPath, source: "current-process" }
    : findExecutable(name);
  if (!resolved) {
    return { name, required, status: "not-installed-or-unlocated", path: null, version: null };
  }
  const invocation = prerequisiteInvocation(name, resolved.path);
  const checked = spawnSync(invocation.command, invocation.args, {
    encoding: "utf8", shell: false, windowsHide: true, timeout: 5000
  });
  const success = checked.status === 0;
  const onPath = ["PATH", "current-process"].includes(resolved.source);
  let status = "installed-but-unavailable";
  if (success) status = onPath ? "available" : "outside-PATH";
  return {
    name, required, status, path: resolved.path,
    version: success ? checked.stdout.trim() : null,
    ...(success ? {} : { action: checked.error?.message || checked.stderr?.trim() || `exit ${checked.status}` })
  };
}

/**
 * The `preflight` command: prints a JSON inventory of prerequisites for the
 * chosen --delivery (release, source or none), GitHub CLI authentication for
 * release delivery, and the .NET SonarScanner global tool when --sonar is set.
 * Sets a failing exit code when a required tool or GitHub login is missing.
 */
function preflightCommand(args) {
  const delivery = args.delivery || "release";
  if (!["release", "source", "none"].includes(delivery)) {
    fail("--delivery must be release, source, or none.");
  }
  const required = new Set(["node", "npm"]);
  if (delivery === "release") { required.add("gh"); required.add("tar"); }
  if (delivery === "source") required.add("git");
  const inventory = ["node", "npm", "gh", "tar", "git", ...(args.sonar ? ["dotnet", "sonar-scanner"] : [])]
    .map((name) => inspectPrerequisite(name, required.has(name)));
  let githubAuth = null;
  const gh = inventory.find((item) => item.name === "gh");
  if (delivery === "release" && gh.path) {
    const result = spawnSync(gh.path, ["auth", "status"], {
      encoding: "utf8", stdio: "ignore", shell: false, windowsHide: true, timeout: 5000
    });
    githubAuth = result.status === 0 ? "authenticated" : "login-required";
  }
  let dotnetScanner = null;
  const dotnet = inventory.find((item) => item.name === "dotnet");
  if (args.sonar && dotnet?.path && ["available", "outside-PATH"].includes(dotnet.status)) {
    const tools = spawnSync(dotnet.path, ["tool", "list", "--global"], {
      encoding: "utf8", shell: false, windowsHide: true, timeout: 5000
    });
    if (tools.status === 0) {
      const match = tools.stdout.match(/^dotnet-sonarscanner\s+(\S+)/im);
      dotnetScanner = match ? { status: "installed", version: match[1] } :
        { status: "not-installed", version: null };
    } else {
      dotnetScanner = { status: "inventory-failed", action: tools.error?.message || tools.stderr?.trim() || `exit ${tools.status}` };
    }
  }
  console.log(JSON.stringify({ inventory, githubAuth, ...(args.sonar ? { dotnetScanner } : {}) }, null, 2));
  if (inventory.some((item) => item.required && !["available", "outside-PATH"].includes(item.status)) ||
      githubAuth === "login-required") process.exitCode = 1;
}

/** Runs the APM CLI with a network timeout and returns status, trimmed stdout/stderr and any spawn error instead of exiting. */
function runApm(args) {
  const command = findExecutable("apm")?.path || (process.platform === "win32" ? "apm.exe" : "apm");
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

/** Parses `apm outdated` output (ANSI codes stripped) for the bcgov/crow row and reports whether it is up-to-date, outdated or unknown. */
function parseCrowOutdatedOutput(output) {
  const ansiEscape = String.fromCodePoint(27);
  const normalized = output.replaceAll(
    new RegExp(String.raw`${ansiEscape}\[[0-9;]*m`, "g"),
    ""
  );
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

/**
 * Checks whether APM has a newer global Crow release. Looks the package up
 * with `apm view`, then `apm outdated --global`. Never applies an update, and
 * reports each failure mode (APM missing, Crow not APM-installed, command
 * error, unresolved version) as data instead of throwing.
 *
 * @param {Function} runCommand - Injectable APM runner, defaults to runApm.
 * @returns {object} checked, configured, current version and updateAvailable.
 */
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

/** Validates a stable x.y.z version (optional leading v) within the safe-integer range and returns it without the v; throws otherwise. */
function normalizeCrowVersion(value, label = "Crow version") {
  const match = typeof value === "string"
    ? /^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.exec(value)
    : null;
  if (!match) throw new Error(`${label} is not a stable semantic version.`);
  const parts = match.slice(1).map(Number);
  if (!parts.every(Number.isSafeInteger)) {
    throw new Error(`${label} exceeds the supported semantic-version range.`);
  }
  return parts.join(".");
}

/** Compares two stable Crow versions numerically; returns -1, 0 or 1. */
function compareCrowVersions(left, right) {
  const leftParts = normalizeCrowVersion(left).split(".").map(Number);
  const rightParts = normalizeCrowVersion(right).split(".").map(Number);
  for (let index = 0; index < leftParts.length; index++) {
    if (leftParts[index] !== rightParts[index]) {
      return leftParts[index] < rightParts[index] ? -1 : 1;
    }
  }
  return 0;
}

/** Walks up from this script (at most 8 levels) to the bcgov-crow plugin.json and returns its version, or null when not running inside Crow. */
function readCrowPackageVersion(scriptPath = fileURLToPath(import.meta.url)) {
  let directory = dirname(resolve(scriptPath));
  for (let depth = 0; depth < 8; depth++) {
    const manifestPath = join(directory, ".github", "plugin", "plugin.json");
    if (existsSync(manifestPath)) {
      let manifest;
      try {
        manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
      } catch (error) {
        throw new Error(`Crow plugin metadata is malformed: ${error.message}`);
      }
      if (manifest.name === "bcgov-crow") {
        return normalizeCrowVersion(manifest.version, "Crow plugin version");
      }
    }
    const parent = dirname(directory);
    if (parent === directory) break;
    directory = parent;
  }
  return null;
}

/** Strips a trailing YAML `# comment` (one preceded by whitespace) from an apm.yml value. */
function removeApmInlineComment(value) {
  for (let index = 1; index < value.length; index++) {
    if (value[index] === "#" && value[index - 1].trim() === "") {
      return value.slice(0, index).trimEnd();
    }
  }
  return value.trim();
}

/** Removes one matching pair of single or double quotes around a YAML scalar. */
function removeApmQuotes(value) {
  if (value.length >= 2 &&
      ((value[0] === "'" && value.at(-1) === "'") ||
       (value[0] === "\"" && value.at(-1) === "\""))) {
    return value.slice(1, -1);
  }
  return value;
}

/**
 * Normalizes an APM dependency string (comment, quotes, GitHub URL prefix,
 * `#ref` and `.git` removed) and returns it only when it is one of the three
 * Crow selectors: the full package or the starter-package or
 * security-remediation collection. Returns null for anything else.
 */
function normalizeCrowApmSelector(value) {
  if (typeof value !== "string") return null;
  const unquoted = removeApmQuotes(removeApmInlineComment(value.trim()));
  const packagePath = unquoted.split("#", 1)[0].trim();
  const githubPrefix = "https://github.com/";
  const repository = packagePath.toLowerCase().startsWith(githubPrefix)
    ? packagePath.slice(githubPrefix.length)
    : packagePath;
  const normalizedRepository = repository.toLowerCase();
  const selector = normalizedRepository.endsWith(".git")
    ? normalizedRepository.slice(0, -4)
    : normalizedRepository;
  if ([
    "bcgov/crow",
    "bcgov/crow/collections/starter-package",
    "bcgov/crow/collections/security-remediation"
  ].includes(selector)) {
    return selector;
  }
  return null;
}

/** Reads the value of `key: value` from one YAML line, or null when the line has a different key. */
function readCrowApmYamlValue(content, key) {
  const separator = content.indexOf(":");
  if (separator < 0 || content.slice(0, separator).trim() !== key) return null;
  return removeApmInlineComment(content.slice(separator + 1).trim());
}

/** Parses an inline apm list value (`[a, b]` or a single value) into the Crow selectors it contains. */
function parseInlineCrowApmSelectors(inlineValue) {
  if (!inlineValue || inlineValue === "[]") return [];
  const values = inlineValue.startsWith("[") && inlineValue.endsWith("]")
    ? inlineValue.slice(1, -1).split(",")
    : [inlineValue];
  const selectors = [];
  for (const value of values) {
    const selector = normalizeCrowApmSelector(value);
    if (selector) selectors.push(selector);
  }
  return selectors;
}

/**
 * Converts one multi-line apm dependency item into a Crow selector. Handles
 * the string form and the object form (git or repo_url plus an optional
 * `collections/...` path); returns null when it is not a Crow package.
 */
function parseCrowApmDependency(itemLines) {
  const firstLine = itemLines[0] || "";
  const separator = firstLine.indexOf(":");
  const firstKey = separator < 0 ? "" : firstLine.slice(0, separator).trim();
  if (firstLine && !["git", "repo_url", "path", "ref"].includes(firstKey)) {
    return normalizeCrowApmSelector(firstLine);
  }

  const fields = new Map();
  for (const line of itemLines) {
    const fieldSeparator = line.indexOf(":");
    if (fieldSeparator < 0) continue;
    const key = line.slice(0, fieldSeparator).trim();
    if (["git", "repo_url", "path"].includes(key)) {
      fields.set(key, removeApmInlineComment(line.slice(fieldSeparator + 1).trim()));
    }
  }

  const repository = normalizeCrowApmSelector(fields.get("git") || fields.get("repo_url"));
  if (!repository) return null;
  let dependencyPath = removeApmQuotes(fields.get("path") || "").trim();
  if (!dependencyPath || dependencyPath === ".") return repository;

  dependencyPath = dependencyPath.replaceAll("\\", "/");
  if (dependencyPath.startsWith("./")) dependencyPath = dependencyPath.slice(2);
  let pathEnd = dependencyPath.length;
  while (pathEnd > 0 && dependencyPath[pathEnd - 1] === "/") pathEnd--;
  const normalizedPath = dependencyPath.slice(0, pathEnd);
  if (normalizedPath.startsWith("collections/")) {
    return normalizeCrowApmSelector(`${repository}/${normalizedPath}`);
  }
  return null;
}

/** Parses a pending dependency item and, when it is a Crow package, pushes its selector onto the list. */
function appendCrowApmDependency(itemLines, selectors) {
  if (itemLines === null) return;
  const selector = parseCrowApmDependency(itemLines);
  if (selector) selectors.push(selector);
}

/**
 * Scans a global apm.yml line by line for Crow entries under
 * `dependencies: apm:`, supporting inline lists, string items and object items.
 *
 * @param {string} manifest - apm.yml text.
 * @returns {string[]} Unique Crow selectors found.
 */
function parseGlobalApmCrowSelectors(manifest) {
  const selectors = [];
  let inDependencies = false;
  let apmIndent = null;
  let currentItem = null;

  for (const line of manifest.split(/\r?\n/)) {
    const content = line.trim();
    if (!content || content.startsWith("#")) continue;
    const indentation = line.length - line.trimStart().length;
    if (indentation === 0) {
      appendCrowApmDependency(currentItem, selectors);
      currentItem = null;
      inDependencies = readCrowApmYamlValue(content, "dependencies") !== null;
      apmIndent = null;
      continue;
    }
    if (!inDependencies) continue;
    if (apmIndent === null) {
      const inlineValue = readCrowApmYamlValue(content, "apm");
      if (inlineValue === null) continue;
      apmIndent = indentation;
      selectors.push(...parseInlineCrowApmSelectors(inlineValue));
      continue;
    }
    if (indentation <= apmIndent) {
      appendCrowApmDependency(currentItem, selectors);
      currentItem = null;
      apmIndent = null;
      continue;
    }
    if (content.startsWith("-")) {
      appendCrowApmDependency(currentItem, selectors);
      currentItem = [content.slice(1).trim()];
    } else if (currentItem !== null) {
      currentItem.push(content);
    }
  }
  appendCrowApmDependency(currentItem, selectors);
  return [...new Set(selectors)];
}

/** Reads the global APM manifest ($APM_HOME or ~/.apm) and returns whether it exists plus the Crow selectors it lists. */
function readGlobalCrowApmSelectors(manifestPath = join(
  process.env.APM_HOME || join(homedir(), ".apm"),
  "apm.yml"
)) {
  if (!existsSync(manifestPath)) return { exists: false, selectors: [] };
  let manifest;
  try {
    manifest = readFileSync(manifestPath, "utf8");
  } catch (error) {
    throw new Error(`Could not read the APM global package manifest: ${error.message}`);
  }
  return { exists: true, selectors: parseGlobalApmCrowSelectors(manifest) };
}

/** Asks APM for the installed version of a Crow selector and returns it normalized; throws with a specific cause when APM is absent or the lookup fails. */
function readApmInstalledPackageVersion(selector, runCommand = runApm) {
  const metadata = runCommand(["view", selector, "--global"]);
  if (metadata.error) {
    if (metadata.error.code === "ENOENT") {
      throw new Error("APM is absent or unavailable on the hook PATH; restore APM or configure its executable path before checking Crow.");
    }
    throw new Error(`Could not read the installed Crow version from APM: ${metadata.error.message}`);
  }
  if (metadata.status !== 0) {
    throw new Error(
      `APM could not look up Crow package '${selector}' (exit code ${metadata.status}); check the installed selector and APM/network access.`
    );
  }
  const version = metadata.stdout.match(/\bVersion:\s+(v?\d+\.\d+\.\d+)\b/i)?.[1];
  return normalizeCrowVersion(version, `APM ${selector} package version`);
}

/**
 * Identifies the installed Crow package and its version. Uses the plugin
 * metadata for the full package, otherwise asks APM for the single installed
 * selector. Throws when several selectors are installed and none can be
 * chosen, or when no selector can be identified.
 *
 * @returns {{version: string, selector: string|null}} Installed version and selector.
 */
function resolveInstalledCrowPackage(options = {}) {
  const pluginVersion = readCrowPackageVersion(options.scriptPath);
  const apmManifest = readGlobalCrowApmSelectors(options.manifestPath);
  let selector = null;
  if (apmManifest.selectors.length === 1) {
    [selector] = apmManifest.selectors;
  } else if (apmManifest.selectors.length > 1) {
    if (pluginVersion && apmManifest.selectors.includes("bcgov/crow")) {
      selector = "bcgov/crow";
    } else {
      throw new Error(
        `Multiple Crow package selectors are installed globally: ${apmManifest.selectors.join(", ")}.`
      );
    }
  }

  if (selector === "bcgov/crow" && pluginVersion) {
    return { version: pluginVersion, selector };
  }
  if (selector) {
    return {
      version: readApmInstalledPackageVersion(selector, options.runApm || runApm),
      selector
    };
  }
  if (pluginVersion) return { version: pluginVersion, selector: null };
  if (!apmManifest.exists) {
    return {
      version: readApmInstalledPackageVersion("bcgov/crow", options.runApm || runApm),
      selector: "bcgov/crow"
    };
  }
  throw new Error(
    "Could not identify an installed Crow package selector from the APM global manifest."
  );
}

/** Fetches the latest stable (non-draft, non-prerelease) bcgov/crow release from GitHub and returns its normalized version; throws on network, HTTP or shape errors. */
async function latestCrowVersion(fetcher = fetch) {
  let response;
  try {
    response = await fetcher(`${crowApi}/releases/latest`, {
      headers: { "User-Agent": "bcgov-crow-update-check" },
      signal: AbortSignal.timeout(crowUpdateCheckTimeoutMs)
    });
  } catch (error) {
    throw new Error(`Could not query the latest Crow release: ${error.message}`);
  }
  if (!response.ok) {
    throw new Error(`GitHub returned HTTP ${response.status} while checking Crow releases.`);
  }
  let release;
  try {
    release = await response.json();
  } catch {
    throw new Error("GitHub returned invalid Crow release metadata.");
  }
  if (!isRecord(release) ||
      release.draft ||
      release.prerelease ||
      typeof release.tag_name !== "string" ||
      !/^v\d+\.\d+\.\d+$/.test(release.tag_name)) {
    throw new Error("GitHub did not return a stable Crow release.");
  }
  return normalizeCrowVersion(release.tag_name, "GitHub Crow release tag");
}

/** Fetches the latest stable bcgov/raven release from GitHub and returns its version without the v prefix; throws on network, HTTP or tag errors. */
async function latestRavenVersion(fetcher = fetch) {
  let response;
  try {
    response = await fetcher(`${ravenApi}/releases/latest`, {
      headers: { "User-Agent": "bcgov-crow-update-check" },
      signal: AbortSignal.timeout(crowUpdateCheckTimeoutMs)
    });
  } catch (error) {
    throw new Error(`Could not query the latest Raven release: ${error.message}`);
  }
  if (!response.ok) {
    throw new Error(`GitHub returned HTTP ${response.status} while checking Raven releases.`);
  }
  let release;
  try {
    release = await response.json();
  } catch {
    throw new Error("GitHub returned invalid Raven release metadata.");
  }
  if (!isRecord(release) ||
      release.draft ||
      release.prerelease ||
      typeof release.tag_name !== "string") {
    throw new Error("GitHub did not return a stable Raven release.");
  }
  const version = release.tag_name.replace(/^v/, "");
  if (!isUpdateReleaseVersion(version)) {
    throw new Error("GitHub returned an invalid Raven release tag.");
  }
  return version;
}

/** Strips a leading v and validates a release version, throwing an error naming `label` when it is invalid. */
function normalizeUpdateReleaseVersion(value, label) {
  const version = typeof value === "string" ? value.replace(/^v/, "") : "";
  if (!isUpdateReleaseVersion(version)) {
    throw new Error(`${label} is not a valid release version.`);
  }
  return version;
}

/** Compares two numeric semver prerelease identifiers by length then text, so large values need no integer parsing. */
function compareNumericPrereleaseIdentifiers(left, right) {
  if (left.length < right.length) return -1;
  if (left.length > right.length) return 1;
  if (left === right) return 0;
  return left < right ? -1 : 1;
}

/** Compares one prerelease identifier pair per semver: numeric sorts below alphanumeric, numerics numerically, others lexically. */
function compareUpdatePrereleaseIdentifiers(left, right) {
  const leftIsNumeric = /^\d+$/.test(left);
  const rightIsNumeric = /^\d+$/.test(right);
  if (leftIsNumeric) {
    return rightIsNumeric ? compareNumericPrereleaseIdentifiers(left, right) : -1;
  }
  if (rightIsNumeric) return 1;
  if (left === right) return 0;
  return left < right ? -1 : 1;
}

/** Compares dot-separated prerelease strings per semver: a release outranks any prerelease, and a shorter list sorts first when all shared identifiers match. */
function compareUpdatePrereleaseVersions(left, right) {
  const leftIdentifiers = left ? left.split(".") : [];
  const rightIdentifiers = right ? right.split(".") : [];
  if (leftIdentifiers.length === 0 && rightIdentifiers.length === 0) return 0;
  if (leftIdentifiers.length === 0) return 1;
  if (rightIdentifiers.length === 0) return -1;

  const commonLength = Math.min(leftIdentifiers.length, rightIdentifiers.length);
  for (let index = 0; index < commonLength; index++) {
    const comparison = compareUpdatePrereleaseIdentifiers(
      leftIdentifiers[index],
      rightIdentifiers[index]
    );
    if (comparison !== 0) return comparison;
  }
  if (leftIdentifiers.length === rightIdentifiers.length) return 0;
  return leftIdentifiers.length < rightIdentifiers.length ? -1 : 1;
}

/** Compares two valid release versions by major, minor, patch, then prerelease; returns -1, 0 or 1. Build metadata is ignored. */
function compareUpdateReleaseVersions(left, right) {
  const leftMatch = updateReleaseVersionPattern.exec(left);
  const rightMatch = updateReleaseVersionPattern.exec(right);
  for (let index = 1; index <= 3; index++) {
    const leftPart = Number(leftMatch[index]);
    const rightPart = Number(rightMatch[index]);
    if (leftPart < rightPart) return -1;
    if (leftPart > rightPart) return 1;
  }
  return compareUpdatePrereleaseVersions(leftMatch[4], rightMatch[4]);
}

/** Returns a fresh schema-2 update-check state: hook decision pending and no versions, attempts or notifications recorded. */
function defaultCrowUpdateState() {
  return {
    schemaVersion: 2,
    hookDecision: "pending",
    hookDecisionAt: null,
    lastAttemptAt: null,
    lastAttemptStatus: null,
    lastSuccessfulComponents: [],
    lastCheckedByComponent: { crow: null, raven: null, codebaseMemory: null },
    lastSuccessfulCheckAt: null,
    versions: {
      crow: { current: null, latest: null },
      raven: { current: null, latest: null },
      codebaseMemory: { current: null, latest: null }
    },
    lastNotifiedAt: null,
    lastNotifiedVersions: {
      crow: null,
      raven: null,
      codebaseMemory: null
    }
  };
}

/** True when the value is a valid semantic version: safe-integer parts, no leading-zero numeric prerelease identifiers, and no empty identifiers. */
function isUpdateReleaseVersion(value) {
  if (typeof value !== "string") return false;
  const match = updateReleaseVersionPattern.exec(value);
  if (!match?.slice(1, 4).every((part) => Number.isSafeInteger(Number(part)))) {
    return false;
  }
  const prereleaseIdentifiers = match[4]?.split(".") || [];
  const buildIdentifiers = match[5]?.split(".") || [];
  return prereleaseIdentifiers.every((identifier) =>
    identifier.length > 0 &&
    !(/^\d+$/.test(identifier) && identifier.length > 1 && identifier.startsWith("0"))
  ) && buildIdentifiers.every((identifier) => identifier.length > 0);
}

/** True when the value is a plain object whose own keys are exactly the expected set. */
function hasExactObjectKeys(record, expectedKeys) {
  if (!isRecord(record)) return false;
  const actualKeys = Object.keys(record);
  return actualKeys.length === expectedKeys.length &&
    expectedKeys.every((key) => Object.hasOwn(record, key));
}

/**
 * Strictly validates a schema-2 update-check state: hook decision, attempt
 * status, timestamps, per-component versions and notification records, and
 * the cross-field rules between them (for example current and latest are set
 * together). Returns false instead of throwing so callers choose the error.
 */
function isCrowUpdateState(value) {
  if (!isRecord(value) ||
      value.schemaVersion !== 2 ||
      !["pending", "enabled", "declined"].includes(value.hookDecision) ||
      ![null, "started", "failed", "success"].includes(value.lastAttemptStatus)) {
    return false;
  }
  const components = ["crow", "raven", "codebaseMemory"];
  if (value.lastSuccessfulComponents !== undefined &&
      (!Array.isArray(value.lastSuccessfulComponents) ||
       value.lastSuccessfulComponents.some((component) => !components.includes(component)) ||
       new Set(value.lastSuccessfulComponents).size !== value.lastSuccessfulComponents.length)) {
    return false;
  }
  if (value.lastCheckedByComponent !== undefined &&
      (!hasExactObjectKeys(value.lastCheckedByComponent, components) ||
       components.some((component) => {
         const timestamp = value.lastCheckedByComponent[component];
         return timestamp !== null && !isTimestamp(timestamp);
       }))) {
    return false;
  }
  if (!hasExactObjectKeys(value.versions, components) ||
      !hasExactObjectKeys(value.lastNotifiedVersions, components)) {
    return false;
  }
  const timestamps = [
    value.hookDecisionAt,
    value.lastAttemptAt,
    value.lastSuccessfulCheckAt,
    value.lastNotifiedAt
  ];
  if (!timestamps.every((timestamp) => timestamp === null || isTimestamp(timestamp)) ||
      (value.hookDecision === "pending"
        ? value.hookDecisionAt !== null
        : value.hookDecisionAt === null) ||
      (value.lastAttemptAt === null
        ? value.lastAttemptStatus !== null
        : value.lastAttemptStatus === null)) {
    return false;
  }
  for (const component of components) {
    const versions = value.versions[component];
    const lastNotifiedVersion = value.lastNotifiedVersions[component];
    if (!hasExactObjectKeys(versions, ["current", "latest"]) ||
        ((versions.current === null) !== (versions.latest === null))) {
      return false;
    }
    const isValidVersion = component === "crow"
      ? (version) => normalizeCrowVersionOrNull(version) !== null
      : isUpdateReleaseVersion;
    if ((versions.current !== null &&
        (!isValidVersion(versions.current) || !isValidVersion(versions.latest))) ||
        (lastNotifiedVersion !== null && !isValidVersion(lastNotifiedVersion))) {
      return false;
    }
  }
  if ((value.lastSuccessfulCheckAt !== null && value.versions.crow.current === null) ||
      (value.lastNotifiedAt === null
        ? components.some((component) => value.lastNotifiedVersions[component] !== null)
        : components.every((component) => value.lastNotifiedVersions[component] === null))) {
    return false;
  }
  return true;
}

/** Like normalizeCrowVersion but returns null for an invalid value instead of throwing. */
function normalizeCrowVersionOrNull(value) {
  try {
    return normalizeCrowVersion(value);
  } catch {
    return null;
  }
}

/** Reads the update-check state file, returning defaults when absent, upgrading a schema-1 file to schema 2, and throwing when it is malformed or invalid. */
function readCrowUpdateState(path) {
  if (!existsSync(path)) return defaultCrowUpdateState();
  let state;
  try {
    state = JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    throw new Error(`Crow update state is malformed: ${error.message}`);
  }
  if (isRecord(state) && state.schemaVersion === 1) {
    state = {
      schemaVersion: 2,
      hookDecision: state.hookDecision,
      hookDecisionAt: state.hookDecisionAt,
      lastAttemptAt: state.lastAttemptAt,
      lastAttemptStatus: state.lastAttemptStatus,
      lastSuccessfulComponents: [],
      lastCheckedByComponent: { crow: null, raven: null, codebaseMemory: null },
      lastSuccessfulCheckAt: state.lastSuccessfulCheckAt,
      versions: {
        crow: { current: state.currentVersion, latest: state.latestVersion },
        raven: { current: null, latest: null },
        codebaseMemory: { current: null, latest: null }
      },
      lastNotifiedAt: state.lastNotifiedAt,
      lastNotifiedVersions: {
        crow: state.lastNotifiedVersion,
        raven: null,
        codebaseMemory: null
      }
    };
  }
  if (!isCrowUpdateState(state)) {
    throw new Error("Crow update state has an unsupported or invalid schema.");
  }
  return state;
}

/** Validates then atomically writes the update-check state (private directory); refuses to write an invalid state. */
function writeCrowUpdateState(path, state) {
  if (!isCrowUpdateState(state)) {
    throw new Error("Refusing to write invalid Crow update state.");
  }
  mkdirSync(dirname(path), { recursive: true, mode: 0o700 });
  writeJsonAtomic(path, state, { throwOnError: true });
}

/** Resolves the update-check state file, lock file and Copilot hook file paths from --state-dir, --setup-state-dir, --hook-dir and COPILOT_HOME. */
function getCrowUpdatePaths(args = {}) {
  const stateDir = resolve(args["state-dir"] || defaultCrowUpdateStateDir);
  const setupStateDir = resolve(args["setup-state-dir"] || defaultStateDir);
  const copilotHome = args["hook-dir"]
    ? null
    : process.env.COPILOT_HOME;
  const hookDir = resolve(
    args["hook-dir"] ||
    (copilotHome
      ? join(copilotHome, "hooks")
      : join(homedir(), ".copilot", "hooks"))
  );
  return {
    stateDir,
    setupStateDir,
    state: join(stateDir, "state.json"),
    lock: join(stateDir, "check.lock"),
    hook: join(hookDir, crowUpdateHookFileName)
  };
}

/** Wraps a value in double quotes for bash, escaping backslash, double quote, dollar and backtick. */
function quoteBashArgument(value) {
  const backslash = String.fromCodePoint(92);
  const escapable = new Set([backslash, '"', "$", "`"]);
  return `"${Array.from(value, (character) =>
    escapable.has(character) ? backslash + character : character
  ).join("")}"`;
}

/** Wraps a value in single quotes for PowerShell, doubling embedded single quotes. */
function quotePowerShellArgument(value) {
  return `'${value.replaceAll("'", "''")}'`;
}

/** Builds the Copilot hook file content: bash and PowerShell commands that run `update-hook-event` on prompt submission, with quoted paths and an optional --setup-state-dir. */
function createCrowUpdateHookConfig(scriptPath, stateDir, setupStateDir = defaultStateDir) {
  const resolvedScript = resolve(scriptPath);
  const resolvedStateDir = resolve(stateDir);
  const resolvedSetupStateDir = resolve(setupStateDir);
  const hookArgs = ["update-hook-event", "--state-dir", resolvedStateDir];
  const setupStateArgument = resolvedSetupStateDir === resolve(defaultStateDir)
    ? ""
    : ` --setup-state-dir ${quoteBashArgument(resolvedSetupStateDir)}`;
  const powershellSetupStateArgument = resolvedSetupStateDir === resolve(defaultStateDir)
    ? ""
    : ` --setup-state-dir ${quotePowerShellArgument(resolvedSetupStateDir)}`;
  const hookCommand = {
    type: "command",
    bash: `${quoteBashArgument(process.execPath)} ${quoteBashArgument(resolvedScript)} ${hookArgs[0]} ${hookArgs[1]} ${quoteBashArgument(resolvedStateDir)}${setupStateArgument}`,
    powershell: `& ${quotePowerShellArgument(process.execPath)} ${quotePowerShellArgument(resolvedScript)} ${hookArgs[0]} ${hookArgs[1]} ${quotePowerShellArgument(resolvedStateDir)}${powershellSetupStateArgument}`,
    timeoutSec: crowUpdateHookTimeoutSeconds
  };
  return {
    version: 1,
    hooks: {
      userPromptSubmitted: [hookCommand],
      userPromptTransformed: [hookCommand]
    }
  };
}

/** Returns true when the hook file exists and equals the expected content, false when absent, and throws a CROW_HOOK_CONFLICT error when it is malformed or different. */
function readExpectedCrowUpdateHook(path, expected) {
  if (!existsSync(path)) return false;
  const content = readFileSync(path, "utf8");
  let current;
  try {
    current = JSON.parse(content);
  } catch (error) {
    throw Object.assign(
      new Error(`The Copilot hook file is malformed and was left unchanged: ${error.message}`),
      { code: "CROW_HOOK_CONFLICT" }
    );
  }
  if (!isDeepStrictEqual(current, expected)) {
    throw Object.assign(
      new Error("The Copilot hook file already exists with different content and was left unchanged."),
      { code: "CROW_HOOK_CONFLICT" }
    );
  }
  return true;
}

/** Prints the update-hook status as JSON: decision (pending, enabled, declined, missing, recoverable or conflicting), whether the hook file is installed, and the last check time. */
function statusCrowUpdateHook(target, state, expected) {
  let hookInstalled = false;
  let conflict = null;
  try {
    hookInstalled = readExpectedCrowUpdateHook(target.hook, expected);
  } catch (error) {
    if (error.code !== "CROW_HOOK_CONFLICT") throw error;
    conflict = error.message;
  }
  let decision = state.hookDecision;
  if (conflict) decision = "conflicting";
  else if (hookInstalled && decision !== "enabled") decision = "recoverable";
  else if (!hookInstalled && decision === "enabled") decision = "missing";
  console.log(JSON.stringify({
    decision,
    hookInstalled,
    persistedDecision: state.hookDecision,
    lastSuccessfulCheckAt: state.lastSuccessfulCheckAt,
    ...(conflict ? {
      conflict,
      hookFile: target.hook,
      hookSha256: createHash("sha256").update(readFileSync(target.hook)).digest("hex")
    } : {})
  }, null, 2));
}

/** Replaces a conflicting hook file after explicit approval: verifies the status digest, backs up the original, writes the expected hook and records the enabled decision, restoring the original if any step fails. */
function replaceCrowUpdateHook(args, target, state, expected) {
  if (!args.confirm || !/^[a-f0-9]{64}$/i.test(args["hook-sha256"] || "")) {
    fail("Replacing a conflicting hook requires --hook-sha256 <status digest> and --confirm after explicit approval.");
  }
  if (!existsSync(target.hook)) fail("The conflicting hook is missing; check status again.");
  const actual = createHash("sha256").update(readFileSync(target.hook)).digest("hex");
  if (actual !== args["hook-sha256"].toLowerCase()) {
    fail("The conflicting hook changed since status; review it again before replacement.");
  }
  const backup = `${target.hook}.${randomUUID()}.bak`;
  const replacement = `${JSON.stringify(expected, null, 2)}\n`;
  renameSync(target.hook, backup);
  let wrote = false;
  try {
    const moved = createHash("sha256").update(readFileSync(backup)).digest("hex");
    if (moved !== actual) throw new Error("The conflicting hook changed during replacement.");
    writeFileSync(target.hook, replacement, {
      encoding: "utf8", flag: "wx", mode: 0o600
    });
    wrote = true;
    state.hookDecision = "enabled";
    state.hookDecisionAt = new Date().toISOString();
    writeCrowUpdateState(target.state, state);
  } catch (error) {
    if (wrote && existsSync(target.hook) &&
        readFileSync(target.hook, "utf8") === replacement) {
      unlinkSync(target.hook);
    }
    if (!existsSync(target.hook)) renameSync(backup, target.hook);
    throw new Error(`Could not replace the hook: ${error.message}. Original backup: ${backup}`);
  }
  console.log(JSON.stringify({ decision: "enabled", hookInstalled: true,
    hookFile: target.hook, backupPath: backup }, null, 2));
}

/** Installs the user-level Copilot hook after the user opts in (--confirm) and records the enabled decision; removes a file it just created if the state write fails. */
function installCrowUpdateHook(args, target, state, expected) {
  if (!args.confirm) fail("Installing the user-level Copilot hook requires --confirm after the user opts in.");
  const alreadyInstalled = readExpectedCrowUpdateHook(target.hook, expected);
  let created = false;
  try {
    if (!alreadyInstalled) {
      mkdirSync(dirname(target.hook), { recursive: true });
      writeFileSync(target.hook, `${JSON.stringify(expected, null, 2)}\n`, {
        encoding: "utf8",
        flag: "wx",
        mode: 0o600
      });
      created = true;
    }
    state.hookDecision = "enabled";
    state.hookDecisionAt = new Date().toISOString();
    writeCrowUpdateState(target.state, state);
  } catch (error) {
    if (created && existsSync(target.hook)) unlinkSync(target.hook);
    throw error;
  }
  console.log(JSON.stringify({
    hookInstalled: true,
    alreadyInstalled,
    decision: "enabled",
    hookFile: target.hook
  }, null, 2));
}

/** Records that the user declined the update hook; fails if a hook file is installed, since removal must be explicit. */
function declineCrowUpdateHook(target, state, expected) {
  if (existsSync(target.hook)) {
    readExpectedCrowUpdateHook(target.hook, expected);
    fail("The Copilot hook is installed; remove it explicitly instead of recording a decline.");
  }
  if (state.hookDecision !== "declined") {
    state.hookDecision = "declined";
    state.hookDecisionAt = new Date().toISOString();
    writeCrowUpdateState(target.state, state);
  }
  console.log(JSON.stringify({ hookInstalled: false, decision: "declined" }, null, 2));
}

/** Removes the Crow-managed hook file (--confirm required) and records a decline; restores the file if the state write fails. */
function removeCrowUpdateHook(args, target, state, expected) {
  if (!args.confirm) fail("Removing the user-level Copilot hook requires --confirm.");
  const hookInstalled = readExpectedCrowUpdateHook(target.hook, expected);
  if (hookInstalled) unlinkSync(target.hook);
  state.hookDecision = "declined";
  state.hookDecisionAt = new Date().toISOString();
  try {
    writeCrowUpdateState(target.state, state);
  } catch (error) {
    if (hookInstalled) {
      writeFileSync(target.hook, `${JSON.stringify(expected, null, 2)}\n`, {
        encoding: "utf8",
        flag: "wx",
        mode: 0o600
      });
    }
    throw error;
  }
  console.log(JSON.stringify({ hookInstalled: false, decision: "declined" }, null, 2));
}

/** The `update-hook` command: dispatches status, install, replace, decline or remove against the expected hook content and persisted update state. */
function crowUpdateHookCommand(args) {
  const action = args._[1] || "status";
  const target = getCrowUpdatePaths(args);
  const expected = createCrowUpdateHookConfig(
    fileURLToPath(import.meta.url),
    target.stateDir,
    target.setupStateDir
  );
  const state = readCrowUpdateState(target.state);
  switch (action) {
    case "status":
      statusCrowUpdateHook(target, state, expected);
      break;
    case "install":
      installCrowUpdateHook(args, target, state, expected);
      break;
    case "replace":
      replaceCrowUpdateHook(args, target, state, expected);
      break;
    case "decline":
      declineCrowUpdateHook(target, state, expected);
      break;
    case "remove":
      removeCrowUpdateHook(args, target, state, expected);
      break;
    default:
      fail(`Unknown update-hook action '${action}'. Use status, install, replace, decline, or remove.`);
  }
}

/** Throws when any recorded timestamp in the update state is later than `now`, which signals clock tampering or a bad state file. */
function validateCrowUpdateClock(state, now) {
  for (const value of [
    state.hookDecisionAt,
    state.lastAttemptAt,
    state.lastSuccessfulCheckAt,
    state.lastNotifiedAt,
    ...Object.values(state.lastCheckedByComponent || {})
  ]) {
    if (value !== null && Date.parse(value) > now) {
      throw new Error("Crow update state contains a future timestamp.");
    }
  }
}

/** Decides whether the last attempt is recent enough to skip: "fresh" within 24 hours of a success, "retry-backoff" within an hour of a failure, otherwise null (run). --force never skips. */
function crowUpdateSkipReason(state, now, force) {
  if (force || state.lastAttemptAt === null) return null;
  const elapsed = now - Date.parse(state.lastAttemptAt);
  if (elapsed < 0) throw new Error("Crow update state contains a future attempt timestamp.");
  const interval = state.lastAttemptStatus === "success"
    ? crowUpdateCheckIntervalMs
    : crowUpdateRetryIntervalMs;
  if (elapsed >= interval) return null;
  return state.lastAttemptStatus === "success" ? "fresh" : "retry-backoff";
}

/** Returns why a check should be skipped ("hook-disabled", "fresh" or "retry-backoff") or null when it should run; validates the clock first. */
function crowUpdateCheckSkipReason(state, now, options) {
  validateCrowUpdateClock(state, now);
  if (options.requireEnabledHook && state.hookDecision !== "enabled") {
    return "hook-disabled";
  }
  return crowUpdateSkipReason(state, now, options.force === true);
}

/** Takes the update-check lock (a directory), reclaiming one older than 30 seconds; returns false when another live check holds it. */
function acquireCrowUpdateLock(path) {
  mkdirSync(dirname(path), { recursive: true });
  const createLock = () => {
    try {
      mkdirSync(path, { mode: 0o700 });
      return true;
    } catch (error) {
      if (error.code === "EEXIST") return false;
      throw error;
    }
  };
  if (createLock()) return true;

  let lockAge;
  try {
    lockAge = Date.now() - statSync(path).mtimeMs;
  } catch (error) {
    if (error.code === "ENOENT") return createLock();
    throw error;
  }
  if (lockAge < crowUpdateLockStaleMs) return false;
  try {
    rmdirSync(path);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
  return createLock();
}

/** Releases the update-check lock; a lock that is already gone is not an error. */
function releaseCrowUpdateLock(path) {
  try {
    rmdirSync(path);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
  }
}

/** Reduces an error to a single-line message of at most 240 characters so it is safe to store and print. */
function safeUpdateCheckError(error) {
  const message = error instanceof Error ? error.message : "Unknown update check failure.";
  return message.replaceAll(/[\r\n\t]+/g, " ").slice(0, 240);
}

/** True when an update exists and the last notice was more than 24 hours ago (or never), so reminders are rate limited. */
function shouldNotifyCrowUpdate(state, now, updateAvailable) {
  if (!updateAvailable) return false;
  const sinceLastNotice = state.lastNotifiedAt === null
    ? crowUpdateCheckIntervalMs
    : now - Date.parse(state.lastNotifiedAt);
  if (sinceLastNotice < 0) {
    throw new Error("Crow update state contains a future notification timestamp.");
  }
  return sinceLastNotice >= crowUpdateCheckIntervalMs;
}

/** Reads the Raven and codebase-memory-mcp versions recorded by Crow setup; on any failure returns null versions plus a safe failure message instead of throwing. */
function readCrowManagedUpdateVersions(options) {
  try {
    const configured = (options.getConfiguredUpdateVersions || readConfiguredUpdateVersions)(
      options.setupStateDir
    );
    if (!isRecord(configured) ||
        !Object.hasOwn(configured, "raven") ||
        !Object.hasOwn(configured, "codebaseMemory")) {
      throw new Error("Crow setup returned invalid managed-component versions.");
    }
    return { configured, failure: null };
  } catch (error) {
    return {
      configured: { raven: null, codebaseMemory: null },
      failure: safeUpdateCheckError(error)
    };
  }
}

/**
 * Builds the list of components to check: Crow always, plus Raven and
 * codebase-memory-mcp when setup state records them. Each entry has a current
 * and latest version provider and a version normalizer, and every provider can
 * be replaced through `options` for tests.
 *
 * @returns {{checks: object[], getSelector: Function}} Checks and a lazy Crow selector lookup.
 */
function createCrowUpdateChecks(options, configured) {
  const ravenCurrent = configured.raven === null
    ? null
    : normalizeUpdateReleaseVersion(configured.raven, "Installed Raven version");
  const codebaseMemoryCurrent = configured.codebaseMemory === null
    ? null
    : normalizeUpdateReleaseVersion(
      configured.codebaseMemory,
      "Installed codebase-memory-mcp version"
    );
  let installedCrowPackage = null;
  const currentCrowVersion = options.getCurrentVersion || (() => {
    installedCrowPackage = (options.resolveInstalledCrowPackage || resolveInstalledCrowPackage)();
    return installedCrowPackage.version;
  });
  const checks = [
    {
      component: "crow",
      name: "Crow",
      current: currentCrowVersion,
      latest: options.getLatestVersion || latestCrowVersion,
      normalize: (version, label) => normalizeCrowVersion(version, label)
    }
  ];
  if (ravenCurrent !== null) {
    checks.push({
      component: "raven",
      name: "Raven",
      current: () => ravenCurrent,
      latest: options.getLatestRavenVersion || latestRavenVersion,
      normalize: normalizeUpdateReleaseVersion
    });
  }
  if (codebaseMemoryCurrent !== null) {
    checks.push({
      component: "codebaseMemory",
      name: "codebase-memory-mcp",
      current: () => codebaseMemoryCurrent,
      latest: options.getLatestCodebaseVersion ||
        (() => fetchLatestCodebaseVersion(fetch, crowUpdateCheckTimeoutMs)),
      normalize: normalizeUpdateReleaseVersion
    });
  }
  return {
    checks,
    getSelector: () => options.getCrowInstallSelector
      ? options.getCrowInstallSelector()
      : installedCrowPackage?.selector || null
  };
}

/** Resolves one component's current and latest versions in parallel; throws a combined error if either fails, otherwise returns both normalized. */
async function checkCrowUpdateComponent(check) {
  const values = await Promise.allSettled([
    Promise.resolve().then(() => check.current()),
    Promise.resolve().then(() => check.latest())
  ]);
  const failures = values
    .filter((value) => value.status === "rejected")
    .map((value) => safeUpdateCheckError(value.reason));
  if (failures.length > 0) {
    throw new Error(`${check.name}: ${failures.join("; ")}`);
  }
  return {
    component: check.component,
    current: check.normalize(values[0].value, `Installed ${check.name} version`),
    latest: check.normalize(values[1].value, `Latest ${check.name} version`)
  };
}

/** Gathers safe error messages from a setup-state failure and any rejected component checks. */
function collectCrowUpdateFailures(setupStateFailure, checkedComponents) {
  const failures = [];
  if (setupStateFailure) failures.push(setupStateFailure);
  for (const value of checkedComponents) {
    if (value.status !== "rejected") continue;
    failures.push(safeUpdateCheckError(value.reason));
  }
  return failures;
}

/** Overlays fulfilled component checks onto the stored versions, clearing versions for components no longer managed; returns the merged versions and the set of components checked successfully. */
function mergeCrowUpdateVersions(state, checks, checkedComponents) {
  const versions = Object.fromEntries(
    ["crow", "raven", "codebaseMemory"].map((component) => [
      component,
      { ...state.versions[component] }
    ])
  );
  for (const component of ["raven", "codebaseMemory"]) {
    if (!checks.some((check) => check.component === component)) {
      versions[component] = { current: null, latest: null };
    }
  }
  const successfulComponents = new Set();
  for (const value of checkedComponents) {
    if (value.status !== "fulfilled") continue;
    const checked = value.value;
    successfulComponents.add(checked.component);
    versions[checked.component] = {
      current: checked.current,
      latest: checked.latest
    };
  }
  return { versions, successfulComponents };
}

/** Lists components whose current version is older than the latest, considering only components checked successfully. */
function findCrowUpdateCandidates(versions, successfulComponents) {
  const updates = [];
  const comparisons = {
    crow: compareCrowVersions,
    raven: compareUpdateReleaseVersions,
    codebaseMemory: compareUpdateReleaseVersions
  };
  for (const [component, name] of [
    ["crow", "Crow"],
    ["raven", "Raven"],
    ["codebaseMemory", "codebase-memory-mcp"]
  ]) {
    if (!successfulComponents.has(component)) continue;
    const version = versions[component];
    if (version.current === null) continue;
    if (comparisons[component](version.current, version.latest) < 0) {
      updates.push({
        component,
        name,
        current: version.current,
        latest: version.latest
      });
    }
  }
  return updates;
}

/**
 * Runs one update check and persists its outcome. Records the attempt first,
 * reuses recent successful component results after a partial failure, checks
 * the remaining components, then stores versions, status and notification
 * state. Failures are returned as data, never thrown.
 *
 * @returns {Promise<object>} checked flag, updates found, selector and error text.
 */
async function runCrowUpdateCheck(statePath, state, now, options) {
  const previousStatus = state.lastAttemptStatus;
  const attemptAt = new Date(now).toISOString();
  state.lastAttemptAt = attemptAt;
  state.lastAttemptStatus = "started";
  writeCrowUpdateState(statePath, state);

  let versions;
  let updates;
  let crowSelector = null;
  let failures = [];
  let successfulComponents = new Set();
  try {
    const { configured, failure: setupStateFailure } = readCrowManagedUpdateVersions(options);
    const updateChecks = createCrowUpdateChecks(options, configured);
    const checkTimes = {
      crow: null, raven: null, codebaseMemory: null,
      ...state.lastCheckedByComponent
    };
    const reuse = new Set();
    if (!options.force && previousStatus === "failed") {
      for (const check of updateChecks.checks) {
        const checkedAt = checkTimes[check.component];
        if (!state.lastSuccessfulComponents?.includes(check.component) || !checkedAt ||
            now - Date.parse(checkedAt) >= crowUpdateCheckIntervalMs) continue;
        if (check.component !== "crow" &&
            check.normalize(check.current(), `Installed ${check.name} version`) !==
              state.versions[check.component].current) continue;
        reuse.add(check.component);
      }
    }
    const pendingChecks = updateChecks.checks.filter((check) => !reuse.has(check.component));
    const checkedComponents = await Promise.allSettled(
      pendingChecks.map(checkCrowUpdateComponent)
    );
    for (const component of ["crow", "raven", "codebaseMemory"]) {
      if (!updateChecks.checks.some((check) => check.component === component)) {
        checkTimes[component] = null;
      }
    }
    pendingChecks.forEach((check, index) => {
      checkTimes[check.component] =
        checkedComponents[index].status === "fulfilled" ? attemptAt : null;
    });
    state.lastCheckedByComponent = checkTimes;
    failures = collectCrowUpdateFailures(setupStateFailure, checkedComponents);
    crowSelector = updateChecks.getSelector();
    const merged = mergeCrowUpdateVersions(state, updateChecks.checks, checkedComponents);
    versions = merged.versions;
    successfulComponents = new Set([
      ...merged.successfulComponents,
      ...updateChecks.checks.filter((check) =>
        reuse.has(check.component) && !pendingChecks.includes(check)
      ).map((check) => check.component)
    ]);
    updates = findCrowUpdateCandidates(versions, successfulComponents);
  } catch (error) {
    state.lastAttemptStatus = "failed";
    state.lastCheckedByComponent = { crow: null, raven: null, codebaseMemory: null };
    writeCrowUpdateState(statePath, state);
    return { checked: false, error: safeUpdateCheckError(error) };
  }

  if (successfulComponents.size === 0) {
    state.lastAttemptStatus = "failed";
    writeCrowUpdateState(statePath, state);
    return {
      checked: false,
      error: failures.length > 0
        ? failures.join("; ")
        : "No component versions could be checked."
    };
  }

  const updateAvailable = updates.length > 0;
  const notify = shouldNotifyCrowUpdate(state, now, updateAvailable);
  state.lastAttemptStatus = failures.length > 0 ? "failed" : "success";
  state.lastSuccessfulComponents = [...successfulComponents];
  if (failures.length === 0) state.lastSuccessfulCheckAt = attemptAt;
  state.versions = versions;
  if (!updateAvailable && failures.length === 0) {
    state.lastNotifiedAt = null;
    state.lastNotifiedVersions = {
      crow: null,
      raven: null,
      codebaseMemory: null
    };
  }
  writeCrowUpdateState(statePath, state);
  return {
    checked: true,
    current: versions.crow.current,
    latest: versions.crow.latest,
    crowSelector,
    versions,
    updates,
    updateAvailable,
    notify,
    checkedAt: attemptAt,
    ...(failures.length > 0 ? { error: failures.join("; ") } : {})
  };
}

/** Runs a Crow, Raven and codebase-memory-mcp update check under a lock, skipping when fresh, backing off after a failure, or when another check is running; returns the result object. */
async function checkCrowUpdates(options = {}) {
  const stateDir = resolve(options.stateDir || defaultCrowUpdateStateDir);
  const statePath = join(stateDir, "state.json");
  const lockPath = join(stateDir, "check.lock");
  const now = options.now ?? Date.now();
  if (!Number.isFinite(now)) throw new Error("Crow update check time is invalid.");

  let state = readCrowUpdateState(statePath);
  let reason = crowUpdateCheckSkipReason(state, now, options);
  if (reason) return { checked: false, reason };
  if (!acquireCrowUpdateLock(lockPath)) {
    return { checked: false, reason: "check-in-progress" };
  }

  try {
    state = readCrowUpdateState(statePath);
    reason = crowUpdateCheckSkipReason(state, now, options);
    if (reason) return { checked: false, reason };
    return await runCrowUpdateCheck(statePath, state, now, options);
  } finally {
    releaseCrowUpdateLock(lockPath);
  }
}

/** Records that a reminder was shown, but only if the state still matches the check result that produced it; returns whether anything was written. */
function markCrowUpdateNotified(stateDir, result, now = Date.now()) {
  if (!result.checked || !result.updateAvailable || !result.notify) return false;
  if (!Number.isFinite(now)) throw new Error("Crow update notification time is invalid.");
  const statePath = join(resolve(stateDir || defaultCrowUpdateStateDir), "state.json");
  const state = readCrowUpdateState(statePath);
  validateCrowUpdateClock(state, now);
  if (!["success", "failed"].includes(state.lastAttemptStatus) ||
      state.lastAttemptAt !== result.checkedAt ||
      !isDeepStrictEqual(state.versions, result.versions)) {
    throw new Error("Crow update state changed before the notification could be recorded.");
  }
  state.lastNotifiedAt = new Date(now).toISOString();
  state.lastNotifiedVersions = {
    crow: result.updates.find((update) => update.component === "crow")?.latest || null,
    raven: result.updates.find((update) => update.component === "raven")?.latest || null,
    codebaseMemory: result.updates
      .find((update) => update.component === "codebaseMemory")?.latest || null
  };
  writeCrowUpdateState(statePath, state);
  return true;
}

/** Builds the `apm install '<selector>#stable' --global --target copilot` command for a supported Crow selector; throws for any other selector. */
function crowUpdateInstallCommand(selector) {
  if (![
    "bcgov/crow",
    "bcgov/crow/collections/starter-package",
    "bcgov/crow/collections/security-remediation"
  ].includes(selector)) {
    throw new Error("The installed Crow package selector is unsupported.");
  }
  return `apm install '${selector}#stable' --global --target copilot`;
}

/** Builds the user-facing update notice (or failure notice) from a check result, with the right update instructions per component; returns null when there is nothing to say. Never installs anything. */
function updateReminder(result) {
  if (result.checked && result.updateAvailable && result.notify) {
    const updates = result.updates;
    const summary = updates.length === 1
      ? `${updates[0].name} update available: installed v${updates[0].current}; latest v${updates[0].latest}.`
      : `Updates available: ${updates.map((update) =>
        `${update.name} v${update.current} -> v${update.latest}`
      ).join("; ")}.`;
    const instructions = [];
    if (updates.some((update) => update.component === "crow")) {
      if (result.crowSelector) {
        instructions.push(
          `For an APM global Copilot install, migrate or update the detected \`${result.crowSelector}\` selector to its release-maintained stable branch with \`${crowUpdateInstallCommand(result.crowSelector)}\`; then \`apm update --global --target copilot\` follows published stable releases.`
        );
      } else {
        instructions.push(
          "Use the corresponding updater for the Crow installation that provided this agent; its APM package selector could not be determined."
        );
      }
    }
    if (updates.some((update) =>
      update.component === "raven" || update.component === "codebaseMemory"
    )) {
      instructions.push(
        "Ask the Crow Raven Setup Agent to review these component updates; it will request confirmation before applying them."
      );
    }
    const retry = result.error
      ? ` Some update checks failed: ${result.error}. Failed checks will retry in about one hour.`
      : "";
    return `${summary} ${instructions.join(" ")}${retry} No update was installed automatically.`;
  }
  if (result.error) {
    return `The daily Crow, Raven, and codebase-memory-mcp update check could not complete: ${result.error}. It will retry in about one hour; no update was installed.`;
  }
  return null;
}

/**
 * Handles a Copilot prompt hook event. Ignores prompt-only events, runs the
 * update check (hook must be enabled), and returns hook output carrying the
 * notice: system message and context for local VS Code, or a modified prompt
 * plus progress line for Copilot CLI.
 */
async function handleUpdateHookEvent(event, options = {}) {
  if (!isRecord(event)) throw new Error("Copilot sent an invalid Crow update-hook event.");
  if (typeof event.sessionId === "string" &&
      typeof event.prompt === "string" &&
      typeof event.transformedPrompt !== "string") {
    return { output: {}, checkResult: null };
  }
  const localPromptSubmit = event.hook_event_name === "UserPromptSubmit";
  const copilotPromptTransform = typeof event.transformedPrompt === "string";
  if (!localPromptSubmit && !copilotPromptTransform) {
    throw new Error("Copilot sent an unsupported Crow update-hook event.");
  }

  const result = await checkCrowUpdates({
    ...options,
    requireEnabledHook: true
  });
  const notice = updateReminder(result);
  if (!notice) return { output: {}, checkResult: result };
  if (localPromptSubmit) {
    return {
      output: {
        systemMessage: notice,
        hookSpecificOutput: {
          hookEventName: "UserPromptSubmit",
          additionalContext: `${notice} Tell the user about this update or check failure.`
        }
      },
      checkResult: result
    };
  }
  return {
    output: {
      modifiedTransformedPrompt: `${event.transformedPrompt}\n\n[${notice}]`
    },
    progress: {
      type: "progress",
      message: notice
    },
    checkResult: result
  };
}

/** The `update-check` command: prints the check result as JSON, records the notice, and exits 1 on error or 10 when an update is available. */
async function updateCheckCommand(args) {
  const result = await checkCrowUpdates({
    stateDir: args["state-dir"],
    setupStateDir: args["setup-state-dir"],
    force: args.force === true
  });
  console.log(JSON.stringify(result, null, 2));
  markCrowUpdateNotified(args["state-dir"], result);
  if (result.error) {
    process.exitCode = 1;
  } else if (result.updateAvailable) {
    process.exitCode = 10;
  }
}

/** The `update-hook-event` command: reads the hook event JSON from stdin, handles it, and writes the hook response to stdout. */
async function updateHookEventCommand(args) {
  let event;
  try {
    const input = new TextDecoder("utf-8", { fatal: true }).decode(readFileSync(0));
    event = JSON.parse(input);
  } catch (error) {
    throw new Error(`Copilot sent invalid JSON to the Crow update hook: ${error.message}`);
  }
  const result = await handleUpdateHookEvent(event, {
    stateDir: args["state-dir"],
    setupStateDir: args["setup-state-dir"]
  });
  if (result.progress) process.stdout.write(`${JSON.stringify(result.progress)}\n`);
  process.stdout.write(`${JSON.stringify(result.output)}\n`);
  if (result.checkResult) {
    markCrowUpdateNotified(args["state-dir"], result.checkResult);
  }
}

/** Stamps the setup state's lastCheckedAt after a freshness check, unless the APM lookup reported an error; returns whether it was written. */
function persistSuccessfulFreshnessCheck(target, state, result, now = new Date()) {
  if (!isRecord(result.crowPackage)) {
    throw new Error("Crow Raven freshness check did not return APM status.");
  }
  if (result.crowPackage.error) return false;
  state.lastCheckedAt = now.toISOString();
  writeJsonAtomic(target.state, state);
  return true;
}

/** Builds the npm command, running npm-cli.js through node on Windows to avoid shell shims. */
function npmInvocation(args) {
  return npmCli
    ? { command: process.execPath, args: [npmCli, ...args] }
    : { command: "npm", args };
}

/** Runs npm through run(), failing the process on error. */
function runNpm(args, options = {}) {
  const invocation = npmInvocation(args);
  return run(invocation.command, invocation.args, options);
}

/** Writes JSON through a temporary file and rename, keeping a backup until the swap succeeds and restoring it on failure; fails the process unless options.throwOnError is set. */
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

/** Reads and parses a JSON file, failing the process with `label` in the message when it is malformed. */
function readJson(path, label) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(`${label} is malformed: ${error.message}`);
  }
}

/** True for a non-null, non-array object. */
function isRecord(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** True for a string that parses as a date. */
function isTimestamp(value) {
  return typeof value === "string" && Number.isFinite(Date.parse(value));
}

/** Validates the recorded Raven install: null, a pinned-source install (ref, 40-hex revision, freshness track) or a bundled release (suite version, matching platform, commit and archive digests). */
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

/** Validates the recorded codebase-memory-mcp install: version, install path, sha512 integrity and entrypoint digest. */
function isCodebaseState(value) {
  return isRecord(value) &&
    /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(value.version || "") &&
    typeof value.installPath === "string" &&
    /^sha512-[A-Za-z0-9+/=]+$/.test(value.integrity || "") &&
    /^[0-9a-f]{64}$/.test(value.entrypointSha256 || "");
}

/** Validates a stored server-catalog snapshot, including that its recorded SHA-256 matches its content. */
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

/** Validates the managed MCP fragment: codebase-memory-mcp plus exactly the selected servers, each with a command and string arguments. */
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

/** Validates one setup-state snapshot as a whole: delivery mode, Raven and codebase-memory records, selected servers, catalog snapshot and managed fragment must agree with each other. */
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

/** Reads installed Raven (bundled release only) and codebase-memory-mcp versions from Crow setup state; nulls when no state exists, and throws when it is malformed. */
function readConfiguredUpdateVersions(stateDir = defaultStateDir) {
  const statePath = join(resolve(stateDir), "state.json");
  if (!existsSync(statePath)) {
    return { raven: null, codebaseMemory: null };
  }
  let state;
  try {
    state = JSON.parse(readFileSync(statePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not read Crow Raven setup state: ${error.message}`);
  }
  if (!isRecord(state) || state.schemaVersion !== 1 || !isStateSnapshot(state)) {
    throw new Error("Crow Raven setup state is malformed or has an unsupported schema.");
  }
  return {
    raven: state.raven?.delivery === "bundled-release"
      ? normalizeUpdateReleaseVersion(state.raven.suiteVersion, "Installed Raven version")
      : null,
    codebaseMemory: state.codebaseMemory
      ? normalizeUpdateReleaseVersion(
        state.codebaseMemory.version,
        "Installed codebase-memory-mcp version"
      )
      : null
  };
}

/**
 * Reads and strictly validates Crow Raven setup state (current and previous
 * snapshots), checks that paths and fragment commands are Crow-managed, and
 * rewrites the fragment file if it drifted from the recorded one. Fails the
 * process when anything is malformed or unmanaged.
 */
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

/** Resolves every Crow Raven state path (state, fragment, pending plan, promotion journal, versions, codebase-memory) from --state-dir or the default. */
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

/** Recovers from an interrupted install: validates the promotion journal's paths are Crow-managed, then removes staging and temporary paths (and unactivated finals), and deletes the journal. */
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

/** Loads Crow's bundled Raven server catalog (assets/raven-servers.json) and fails if its schema is unsupported. */
function catalog() {
  const value = readJson(catalogPath, "Bundled Raven server catalog");
  if (value.schemaVersion !== 1 || !Array.isArray(value.servers)) {
    fail("Bundled Raven server catalog has an unsupported shape.");
  }
  return value;
}

/** Resolves --servers IDs to catalog entries, rejecting duplicates and unknown IDs; --no-raven returns an empty list and cannot be combined with --servers. */
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

/** Fails the process unless the GitHub CLI is authenticated (`gh auth status`). */
function verifyGitHubAuth(runCommand = run) {
  runCommand("gh", ["auth", "status"], { capture: true, timeout: networkTimeoutMs });
}

/** Fails the process when a tool needed for the chosen delivery is missing or unsupported: Node version, npm, and git or gh (authenticated) and tar as required. */
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
    verifyGitHubAuth();
    run("tar", ["--version"], { capture: true });
  }
  runNpm(["--version"], { capture: true });
}

/** Resolves a Raven ref (main, tag or 40-hex commit) to an exact commit SHA with `git ls-remote`; fails when the ref is not found. */
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

/** Queries the npm registry for the latest codebase-memory-mcp version; throws a descriptive error on network, HTTP or version-shape problems. */
async function fetchLatestCodebaseVersion(fetcher = fetch, timeoutMs = networkTimeoutMs) {
  let response;
  try {
    response = await fetcher(npmRegistryUrl, { signal: AbortSignal.timeout(timeoutMs) });
  } catch (error) {
    throw new Error(`Could not query codebase-memory-mcp: ${error.message}`);
  }
  if (!response.ok) {
    throw new Error(`npm registry returned HTTP ${response.status}.`);
  }
  let metadata;
  try {
    metadata = await response.json();
  } catch {
    throw new Error("npm registry returned invalid codebase-memory-mcp metadata.");
  }
  if (!isRecord(metadata) || !isUpdateReleaseVersion(metadata.version)) {
    throw new Error("npm registry returned an invalid codebase-memory-mcp version.");
  }
  return metadata.version;
}

/** Setup-time wrapper over fetchLatestCodebaseVersion that fails the process instead of throwing. */
async function latestCodebaseVersion() {
  try {
    return await fetchLatestCodebaseVersion();
  } catch (error) {
    fail(error.message);
  }
}

/** Fetches a URL and returns its raw bytes with the parsed JSON, so callers can hash the exact content; fails the process on network, HTTP or JSON errors. */
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

/** Checks a Raven release manifest matches the expected version, platform, source repository, archive name, digests and passed smoke tests; fails otherwise. */
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

/** Checks a released server catalog agrees with its manifest (version, Node version, protocol, platform, server count); fails otherwise. */
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

/**
 * Resolves a Raven bundled release (a given version or the latest stable)
 * for this platform. Downloads and cross-checks the release metadata,
 * manifest and catalog digests, and returns the verified release record used
 * in the setup plan. Fails on any mismatch or missing asset.
 */
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

/** Fails unless the version is an exact semantic version (no ranges or tags). */
function validateExactVersion(version) {
  if (!/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(version || "")) {
    fail("--codebase-memory-version must be an exact semantic version.");
  }
}

/** Checks Raven's own .mcp.json launches each selected server with the entrypoint Crow's reviewed catalog expects; fails on any difference. */
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

/**
 * Builds the managed MCP fragment: codebase-memory-mcp plus one entry per
 * selected Raven server, launched through the release launcher (bundled
 * release) or node with the built entrypoint (pinned source). With
 * validatePaths set, fails when a referenced file is missing.
 */
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

/** Returns the command and arguments to start a server for verification, routing Windows .cmd launchers through ComSpec (and refusing extra arguments for them). */
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

/** True when the plan's Raven record fits its delivery mode: absent for codebase-memory-only, an exact revision for pinned source, or a fully consistent release record (version, tag, platform, digests, archive URL) for a bundled release. */
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

/** Validates a pending setup plan's shape, Crow-managed install paths and 24-hour confirmation window; fails the process when anything is invalid or expired. */
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

/** SHA-256 of the plan's JSON, the digest the user approves. */
function planDigest(plan) {
  return createHash("sha256").update(JSON.stringify(plan)).digest("hex");
}

/** Builds a hashed snapshot of the selected catalog entries so later steps can detect catalog changes. */
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

/** Verifies an installed codebase-memory-mcp matches the requested version in its package and lock file, and returns the entrypoint path, integrity and entrypoint digest. */
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

/** Builds the npm install arguments for an exact, production-only codebase-memory-mcp install, skipping scripts on Windows. */
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

/** Runs codebase-memory-mcp's own Windows installer with a longer candidate timeout (patched temporarily, then restored) and a 10-minute overall limit; fails the process on error. */
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

/** Installs codebase-memory-mcp into a staging directory next to the final path and validates it; promotion happens later. */
function stageCodebaseMemory(installPath, version) {
  const stagingPath = `${installPath}.staging-${process.pid}`;
  if (existsSync(stagingPath)) rmSync(stagingPath, { recursive: true, force: true });
  mkdirSync(dirname(installPath), { recursive: true });
  mkdirSync(stagingPath);
  runNpm(codebaseInstallArgs(stagingPath, version));
  if (process.platform === "win32") runCodebaseWindowsInstaller(stagingPath);
  return { stagingPath, ...validateCodebaseInstall(stagingPath, version) };
}

/** Streams a download to a private file with a 5-minute timeout; fails the process on network or HTTP errors. */
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

/** Streams a file and returns its SHA-256 hex digest. */
async function sha256File(path) {
  const hash = createHash("sha256");
  for await (const chunk of createReadStream(path)) hash.update(chunk);
  return hash.digest("hex");
}

/** Computes one SHA-256 over a directory tree (sorted names, types, modes, sizes, link targets and contents), optionally excluding .git, and fails on unsupported entry types. */
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

/** Matches selected catalog servers against the released catalog (entrypoint, version, access, launcher) and returns them with package and launcher added; fails on any difference. */
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

/**
 * Downloads and stages a Raven release bundle: checks the archive SHA-256,
 * verifies the GitHub build attestation, extracts it, and validates the
 * embedded metadata and catalog digest. Returns the staging path; removes
 * partial files and fails the process on any mismatch.
 */
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

/** True if a process with this ID exists (signal 0 probe); a permission error counts as running. */
function isProcessRunning(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    if (error.code === "ESRCH") return false;
    if (error.code === "EPERM") return true;
    throw error;
  }
}

/** Interprets a taskkill result: null when it succeeded or every reported process is gone, otherwise the error detail. */
function taskkillTerminationError(result, rootPid, processIsRunning = isProcessRunning) {
  if (result.status === 0) return null;
  const output = [result.stderr, result.stdout].filter(Boolean).join("\n").trim();
  const detail = output || result.error?.message || `taskkill exited with ${result.status}`;
  const affectedPids = new Set([rootPid]);
  let reportedPid = false;
  for (const match of detail.matchAll(/\bPID\s+(\d+)\b/gi)) {
    affectedPids.add(Number(match[1]));
    reportedPid = true;
  }
  if (new RegExp(String.raw`\bThe process\s+["']?${rootPid}["']?\s+not found\b`, "i").test(detail)) {
    reportedPid = true;
  }
  if (!reportedPid) return detail;
  for (const pid of affectedPids) {
    if (processIsRunning(pid)) return detail;
  }
  return null;
}

/** Stops a child and its descendants (taskkill /T /F on Windows, SIGTERM or SIGKILL elsewhere); returns null on success or a reason string. */
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
    return taskkillTerminationError(result, child.pid);
  }
  const signal = force ? "SIGKILL" : "SIGTERM";
  if (child.kill(signal)) return null;
  return "the process did not accept the termination signal";
}

/** Starts a server and requires it to stay alive for the startup grace period, then stops it; rejects if it fails to start, exits early, or cannot be stopped. */
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

/** Re-verifies an installed snapshot against recorded state: codebase-memory integrity, Raven tree digest, bundle metadata or source revision, and that the managed fragment still matches. Fails on any drift. */
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

/** Startup-checks codebase-memory-mcp and every selected Raven server in a fragment. */
async function verifyFragment(fragment, runtimePath, servers) {
  const codebase = fragment.mcpServers["codebase-memory-mcp"];
  await verifyStartup("codebase-memory-mcp", codebase.command, codebase.args);
  for (const server of servers) {
    const entry = fragment.mcpServers[server.id];
    await verifyStartup(`Raven server '${server.id}'`, entry.command, entry.args, runtimePath);
  }
}

/** Prints the command reference. */
function printHelp() {
  console.log(`Crow Raven setup

Commands:
  list [--group <id>]
  status [--state-dir <path>]
  preflight [--delivery release|source|none] [--sonar]
  plan (--servers <id,...> | --no-raven)
       [--delivery release|source] [--raven-version X.Y.Z]
       [--raven-ref main|vX.Y.Z|sha]
       [--codebase-memory-version X.Y.Z] [--state-dir <path>]
  setup --plan <path> --plan-sha256 <digest> --confirm
  config preview --client copilot|portable [--config <path>] [--state-dir <path>]
  config apply --client copilot|portable [--config <path>]
               [--state-dir <path>] --approval-sha256 <digest> --confirm
  check [--state-dir <path>] [--force]
  rollback [--state-dir <path>] --confirm
  update-check [--state-dir <path>] [--setup-state-dir <path>] [--force]
  update-hook [status|install|replace|decline|remove] [--state-dir <path>]
              [--setup-state-dir <path>] [--hook-dir <path>]
              [--hook-sha256 <status digest>] [--confirm]
  update-hook-event --state-dir <path> [--setup-state-dir <path>]

Plan resolves every mutable version and writes a reviewable pending-plan.json.
Raven uses verified bundled releases by default. Source builds require the
explicit --delivery source fallback. Config preview/apply merges only the
reviewed client configuration: VS Code and Copilot use the same user-level
mcp-config.json, never profile mcp.json or settings.json. Setup does not
collect credentials.
The optional Copilot update hook checks at most once
per day during agent use and never installs updates.`);
}

/** The `list` command: prints catalog servers (id, group, description), optionally for one --group. */
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

/** The `status` command: reconciles any interrupted install, then prints recorded setup state as JSON. */
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

/** The `config preview|apply` command: previews or applies the managed fragment to the chosen client config and prints the result without file bytes. */
function configCommand(args) {
  const action = args._[1];
  if (!["preview", "apply"].includes(action)) fail("Use config preview or config apply.");
  const target = paths(args);
  if (!existsSync(target.state)) fail("Crow Raven setup is not configured.");
  const state = readState(target);
  const options = {
    ...args,
    managedEntries: state.managedFragment.mcpServers,
    previousEntries: state.previous?.managedFragment.mcpServers
  };
  const result = action === "preview"
    ? previewClientConfig(options)
    : applyClientConfig(options);
  const { bytes, content, ...output } = result;
  console.log(JSON.stringify(output, null, 2));
}

/** Describes the supply-chain assurance level of the plan's delivery mode. */
function planAssurance(raven) {
  if (!raven) return "registry-package";
  return raven.delivery === "bundled-release"
    ? "publisher-attestation-required-at-setup"
    : "transitional-source-build";
}

/** Plain-language list of what setup will do for the Raven part of a plan. */
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

/** The exact commands setup will run for the Raven part of a plan, for user review. */
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

/**
 * The `plan` command: validates the option combination and prerequisites,
 * resolves the Raven release or pinned revision and the codebase-memory
 * version, and writes a reviewable pending plan with its digest. Changes
 * nothing else.
 */
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
    requiresSourceNode: includesRaven && requestedDelivery === "source",
    requiresReleaseTools: includesRaven && requestedDelivery === "release"
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

/** Re-checks each planned server's metadata against Crow's reviewed catalog (ignoring release-only package and launcher fields) and returns the planned servers. */
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

/** Fails when the plan's runtime or codebase-memory path is already active or kept as the rollback target. */
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

/** Lists newly added servers and, when there are any, the platform's Raven credential script (if present in the runtime) and documentation link for the next step. */
function credentialSetupResult(state, priorState) {
  const addedServers = state.selectedServers.filter((id) =>
    !priorState?.selectedServers.includes(id));
  if (addedServers.length === 0) return { addedServers, credentialSetup: null };
  let credentialScriptName = null;
  if (process.platform === "win32") credentialScriptName = "setup-credentials.ps1";
  if (process.platform === "darwin") credentialScriptName = "setup-credentials-mac.mjs";
  const candidate = credentialScriptName && state.raven?.runtimePath
    ? join(state.raven.runtimePath, "scripts", credentialScriptName) : null;
  const script = candidate && existsSync(candidate) ? candidate : null;
  return {
    addedServers,
    credentialSetup: {
      script,
      documentation: `${ravenRepositoryUrl}#2-configure-authentication`
    }
  };
}

/** Stages the Raven runtime for a plan: downloads and verifies the bundle, or clones, builds and checks the pinned source revision. No-op without Raven. */
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

/**
 * The `setup` command: requires --confirm and the reviewed plan digest, then
 * stages Raven and codebase-memory under a promotion journal, startup-tests
 * the staged fragment, and only then promotes the new generation and writes
 * state and fragment. Any failure restores the previous state.
 */
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
  console.log(JSON.stringify({
    statePath: target.state, fragmentPath: target.fragment, ...state,
    ...credentialSetupResult(state, priorState)
  }, null, 2));
}

/** The `check` command: re-validates the installation, then (at most daily unless --force) compares Raven, codebase-memory and Crow against their latest versions; exits 10 when an update is available. */
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
  persistSuccessfulFreshnessCheck(target, state, result);
  console.log(JSON.stringify(result, null, 2));
  if (result.crowPackage.error) {
    process.exitCode = 1;
  } else if (
    result.raven?.updateAvailable ||
    result.codebaseMemory.updateAvailable ||
    (result.crowPackage.checked && result.crowPackage.updateAvailable)
  ) {
    process.exitCode = 10;
  }
}

/** The `rollback` command: requires --confirm, re-validates and startup-tests the retained previous setup, then swaps it with the current one in state and fragment. */
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
  checkCrowUpdates,
  createFragment,
  createCrowUpdateHookConfig,
  handleUpdateHookEvent,
  latestCrowVersion,
  latestRavenVersion,
  fetchLatestCodebaseVersion,
  findExecutable,
  markCrowUpdateNotified,
  parseCrowOutdatedOutput,
  resolveInstalledCrowPackage,
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
};

if (import.meta.url === pathToFileURL(resolve(process.argv[1] || "")).href) {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0] || "help";
  switch (command) {
    case "help": printHelp(); break;
    case "list": listCommand(args); break;
    case "status": statusCommand(args); break;
    case "preflight": preflightCommand(args); break;
    case "config": configCommand(args); break;
    case "plan": await planCommand(args); break;
    case "setup": await setupCommand(args); break;
    case "check": await checkCommand(args); break;
    case "rollback": await rollbackCommand(args); break;
    case "update-check": await updateCheckCommand(args); break;
    case "update-hook": crowUpdateHookCommand(args); break;
    case "update-hook-event": await updateHookEventCommand(args); break;
    default: fail(`Unknown command '${command}'. Run 'help' for usage.`);
  }
}
