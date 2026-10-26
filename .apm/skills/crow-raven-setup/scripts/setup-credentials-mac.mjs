#!/usr/bin/env node
// setup-credentials-mac.mjs
// CROW-MODIFIED copy of bcgov/raven scripts/setup-credentials-mac.mjs. Crow
// additions: --set KEY=VALUE for non-secret values supplied by the guided
// setup agent, --sections to prompt only for selected integrations, and
// --raven-runtime to locate Raven's auth module. Secrets are still typed by
// the user into hidden prompts and are never accepted as arguments.
// Stores RAVEN credentials in the macOS login keychain as a single
// generic-password item (service "raven", account "credentials") holding a
// base64-encoded JSON blob — the macOS counterpart of setup-credentials.ps1's
// DPAPI file. The keychain encrypts the blob at rest and scopes it to your
// macOS user; loadEnv() reads it back at server startup.
//
// Usage (from repo root, after `npm run build`):
//   node scripts/setup-credentials-mac.mjs            # create/update
//   node scripts/setup-credentials-mac.mjs --verify   # list stored keys, masked
//
// To delete stored credentials:
//   security delete-generic-password -s raven -a credentials
//
// Set RAVEN_KEYCHAIN_SERVICE to use a scratch service name when testing.
//
// The whole credential record is written in a single `security -i` command;
// `security -i` reads stdin in ~4095-byte chunks, so the encoded record has
// a hard ceiling around that size. writeKeychainRecord() enforces it.

import { createInterface } from "node:readline";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { homedir } from "node:os";
import { createRequire } from "node:module";
const argValues = (flag) => {
  const out = [];
  process.argv.forEach((a, i) => {
    if (a === flag && process.argv[i + 1]) out.push(process.argv[i + 1]);
    else if (a.startsWith(`${flag}=`)) out.push(a.slice(flag.length + 1));
  });
  return out;
};
const runtimeRoot = argValues("--raven-runtime")[0] ?? process.env.RAVEN_RUNTIME;
const authCandidates = [
  ...(runtimeRoot
    ? [
        join(runtimeRoot, "packages", "auth", "dist", "load-env.js"),
        join(runtimeRoot, "runtime", "node_modules", "@nrs", "auth", "dist", "load-env.js"),
      ]
    : []),
  new URL("../packages/auth/dist/load-env.js", import.meta.url).pathname,
  new URL("../runtime/node_modules/@nrs/auth/dist/load-env.js", import.meta.url).pathname,
];
const authPath = authCandidates.find((c) => existsSync(c));
if (!authPath) {
  console.error("Cannot find Raven's auth module. Pass --raven-runtime <installed Raven runtime path>");
  console.error("(the runtimePath shown by `node crow-raven-setup.mjs status`).");
  process.exit(1);
}
const loadEnvModule = pathToFileURL(authPath);
const { parse: parseDotenv } = createRequire(loadEnvModule)("dotenv");
const {
  readKeychainRecord,
  writeKeychainRecord,
  keychainService,
  KEYCHAIN_ACCOUNT,
  KeychainReadError,
} = await import(loadEnvModule);
import { mask, seedDefaults, normalizeAnswer, applyAnswer, validateRecord } from "./setup-credentials-mac.lib.mjs";

/** Values from ~/.raven/.env, used as first-run defaults; {} when absent. */
function readEnvFile() {
  try {
    return parseDotenv(readFileSync(join(homedir(), ".raven", ".env"), "utf-8"));
  } catch {
    return {};
  }
}

/**
 * One readline interface for the whole session — a fresh interface per
 * question would buffer and discard piped stdin, hanging every question
 * after the first. Sensitive questions suppress the echo of typed
 * characters; stdin ending early (Ctrl-D, short pipe) answers blank.
 */
function createPrompter() {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  let muted = false;
  let closed = false;
  let pending = null;
  const write = rl._writeToOutput.bind(rl);
  rl._writeToOutput = (s) => {
    if (!muted) write(s);
  };
  rl.on("close", () => {
    closed = true;
    pending?.("");
  });
  return {
    ask(question, { sensitive = false } = {}) {
      return new Promise((resolve) => {
        // stdin already ended (short pipe / Ctrl-D): keep remaining defaults.
        if (closed) {
          resolve("");
          return;
        }
        pending = resolve;
        if (sensitive) {
          process.stdout.write(`${question}: `);
          muted = true;
        }
        rl.question(sensitive ? "" : `${question}: `, (answer) => {
          if (sensitive) {
            muted = false;
            process.stdout.write("\n");
          }
          pending = null;
          resolve(normalizeAnswer(answer, { sensitive }));
        });
      });
    },
    close() {
      pending = null;
      rl.close();
    },
  };
}

// --- Verify mode ---
if (process.argv.includes("--verify")) {
  let stored;
  try {
    stored = readKeychainRecord();
  } catch (err) {
    if (!(err instanceof KeychainReadError)) throw err;
    console.log(err.message);
    process.exit(1);
  }
  if (!stored) {
    console.log(`No keychain item found (service "${keychainService()}", account "${KEYCHAIN_ACCOUNT}").`);
    console.log("Run this script without --verify to create one.");
    process.exit(1);
  }
  console.log(`Stored credential keys (service "${keychainService()}"):`);
  for (const [key, value] of Object.entries(stored)) {
    console.log(`  ${key}: ${mask(value)}`);
  }
  process.exit(0);
}

// --- Setup mode ---
console.log("");
console.log("RAVEN Credential Setup (macOS Keychain)");
console.log("=======================================");
console.log("Credentials are stored in your login keychain, encrypted at rest and");
console.log("scoped to your macOS user account. Leave any prompt blank to keep the");
console.log("existing value (or skip an optional integration). Type :clear to erase a value.");
console.log("");

// One readline interface for the whole session (see createPrompter's doc
// comment) — created before the existing-record read so it is also
// available for the overwrite confirmation below, if needed.
const prompter = createPrompter();

let existing;
try {
  existing = readKeychainRecord() ?? {};
} catch (err) {
  if (!(err instanceof KeychainReadError)) throw err;
  console.log("Existing keychain item could not be read — continuing will overwrite it.");
  const answer = await prompter.ask("Overwrite the unreadable keychain item? (yes/no)");
  if (answer.trim().toLowerCase() !== "yes") {
    prompter.close();
    process.exit(1);
  }
  existing = {};
}

// Same variables, sections, and order as setup-credentials.ps1.
const SECTIONS = [
  {
    id: "atlassian",
    header: "Atlassian (leave blank to skip)",
    fields: [
      ["ATLASSIAN_BASE_URL", "Atlassian base URL (e.g. https://apps.example.gov.bc.ca)", false],
      ["ATLASSIAN_EMAIL", "IDIR email (e.g. Jane.Smith@gov.bc.ca)", false],
      ["ATLASSIAN_PASSWORD", "Atlassian API token (Classic token for Cloud; IDIR password for internal Basic Auth)", true],
    ],
  },
  {
    id: "server-monitor",
    header: "Server Monitor (leave blank to skip)",
    fields: [
      ["SERVER_A_PASSWORD", "_A account password (leave blank to skip)", true],
    ],
  },
  {
    id: "ado",
    header: "Azure DevOps (leave blank to skip)",
    fields: [
      ["ADO_BASE_URL", "ADO HTTPS base URL (required with PAT; Cloud: https://dev.azure.com)", false],
      ["ADO_DEFAULT_COLLECTION", "ADO Cloud organization or Server collection (e.g. DefaultCollection)", false],
      ["ADO_PAT", "ADO Personal Access Token", true],
      ["ADO_DEFAULT_PROJECT", "ADO default project name (leave blank to skip)", false],
      ["ADO_API_VERSION", "ADO API version (optional; default 7.1)", false],
    ],
  },
  {
    id: "jarvis",
    header: "Jarvis API (leave blank to skip)",
    fields: [
      ["JARVIS_TOKEN", "Jarvis Authorization Token", true],
      ["JARVIS_BASE_URL", "Jarvis base URL (required with token; e.g. https://jarvis-api.example.gov.bc.ca)", false],
    ],
  },
  {
    id: "sonar",
    header: "SonarQube (leave blank to skip)",
    fields: [
      ["SONARQUBE_URL", "SonarQube HTTPS base URL (required with token; Cloud: https://sonarcloud.io)", false],
      ["SONARQUBE_TOKEN", "SonarQube user token", true],
      ["SONAR_SCANNER_BIN", "SonarQube scanner binary path (optional when sonar-scanner is on PATH)", false],
    ],
  },
  {
    id: "rfcbuddy",
    header: "RFC Buddy (leave blank to skip)",
    fields: [
      ["RFCBUDDY_URL", "RFC Buddy base URL (e.g. https://rfcbuddy.example.com/api/v1/)", false],
      ["RFCBUDDY_PAT", "RFC Buddy Personal Access Token (PAT)", true],
    ],
  },
  {
    id: "artifactory",
    header: "Artifactory (leave blank to skip)",
    fields: [
      ["ARTIFACTORY_URL", "Internal Artifactory HTTPS base URL", false],
      ["ARTIFACTORY_EMAIL", "Artifactory IDIR email", false],
      ["ARTIFACTORY_PASSWORD", "Artifactory IDIR password", true],
    ],
  },
  {
    id: "jenkins",
    header: "Jenkins (leave blank to skip; API token is recommended for writes)",
    fields: [
      ["JENKINS_URL", "Jenkins HTTPS base URL (e.g. https://jenkins.example.gov.bc.ca/jenkins)", false],
      ["JENKINS_USER", "Jenkins username", false],
      ["JENKINS_TOKEN", "Jenkins API token", true],
      ["JENKINS_PASSWORD", "Jenkins password (leave blank when using an API token)", true],
    ],
  },
  {
    id: "github",
    header: "GitHub (leave blank to skip)",
    note: "Required token scopes: security_events, issues, pull_requests, contents, metadata",
    fields: [
      ["GITHUB_TOKEN", "GitHub Personal Access Token (PAT)", true],
      ["GITHUB_API_URL", "GitHub API URL (default: https://api.github.com)", false],
      ["GITHUB_REPOSITORY_ALLOWLIST", "GitHub repository allow-list (comma-separated, e.g. octo-org/example-repo,octo-org/*)", false],
      ["GITHUB_ENABLE_AUTOFIX", "Enable GitHub autofix tools? (true/false; default false)", false],
      ["GITHUB_ENABLE_MERGE", "Enable GitHub PR merge tool? (true/false; default false)", false],
      ["GITHUB_TIMEOUT_MS", "GitHub request timeout in ms (default 30000)", false],
    ],
  },
];

const promptedKeys = SECTIONS.flatMap((s) => s.fields.map(([name]) => name));
const envValues = readEnvFile();
// Blank answers keep these: keychain values first, then ~/.raven/.env values
// for prompted keys (first-run migration), plus keychain-only extras.
const defaults = seedDefaults(promptedKeys, envValues, existing);
const record = { ...defaults };

if (Object.keys(existing).length > 0) {
  console.log("Existing keychain credentials found - press Enter to keep each value.");
  console.log("");
}
if (promptedKeys.some((k) => !existing[k] && defaults[k])) {
  console.log("Values found in ~/.raven/.env will be imported for any prompt you leave blank.");
  console.log("");
}

const secretKeys = new Set(SECTIONS.flatMap((sec) => sec.fields.filter((f) => f[2]).map((f) => f[0])));
const provided = {};
for (const pair of argValues("--set")) {
  const eq = pair.indexOf("=");
  const key = eq > 0 ? pair.slice(0, eq) : "";
  if (!promptedKeys.includes(key)) {
    console.error(`Error: --set key "${pair.slice(0, Math.max(eq, 0))}" is not a known credential field.`);
    process.exit(1);
  }
  if (secretKeys.has(key)) {
    console.error(`Error: ${key} is a secret and cannot be passed as an argument. It is entered at the hidden prompt.`);
    process.exit(1);
  }
  provided[key] = pair.slice(eq + 1);
}
const sectionFilter = argValues("--sections").flatMap((v) => v.split(",")).map((v) => v.trim()).filter(Boolean);
const unknownSections = sectionFilter.filter((id) => !SECTIONS.some((sec) => sec.id === id));
if (unknownSections.length > 0) {
  console.error(`Error: unknown section(s): ${unknownSections.join(", ")}. Valid: ${SECTIONS.map((sec) => sec.id).join(", ")}.`);
  process.exit(1);
}
const targetSections = sectionFilter.length > 0 ? SECTIONS.filter((sec) => sectionFilter.includes(sec.id)) : SECTIONS;
const scoped = sectionFilter.length > 0;

for (const section of targetSections) {
  let headerShown = false;
  for (const [name, label, sensitive] of section.fields) {
    if (name in provided) {
      applyAnswer(record, name, provided[name]);
      console.log(`${name}: set`);
      continue;
    }
    // Guided mode: non-secret fields already stored or defaulted are kept without asking again.
    if (scoped && !sensitive && record[name]) continue;
    if (!headerShown && section.header) {
      console.log("");
      console.log(section.header);
      if (section.note) console.log(section.note);
      headerShown = true;
    }
    const hint = existing[name] ? " [Enter to keep; :clear to erase]" : defaults[name] ? " [import from .env; :clear to erase]" : "";
    const answer = await prompter.ask(`${label}${hint}`, { sensitive });
    applyAnswer(record, name, answer);
  }
}
prompter.close();

console.log("");

const validationErrors = validateRecord(record);
if (validationErrors.length > 0) {
  for (const message of validationErrors) {
    console.error(`Error: ${message}`);
  }
  process.exit(1);
}

try {
  writeKeychainRecord(record);
} catch (err) {
  console.error(`Could not write to the login keychain (locked or access denied): ${err.message}`);
  process.exit(1);
}

console.log(`Credentials saved to the login keychain (service "${keychainService()}", account "${KEYCHAIN_ACCOUNT}").`);
console.log("");
console.log("Next steps:");
console.log("  - Remove the values now stored in the keychain from ~/.raven/.env —");
console.log("    the keychain is read first and .env remains a fallback.");
console.log("  - Run this script again with --verify to confirm the stored keys.");
