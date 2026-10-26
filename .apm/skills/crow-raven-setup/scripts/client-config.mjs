/**
 * client-config.mjs (library)
 * =====================================
 *
 * Purpose:
 *     Previews and applies Crow's MCP server fragment to a supported client
 *     configuration file (Copilot's mcp-config.json or a verified portable
 *     mcpServers file). Preview computes the change and an approval digest;
 *     apply re-checks that digest, locks, backs up, writes atomically, verifies
 *     the result, and rolls back on failure. It never writes credentials.
 *
 * Layer: Crow Raven Setup skill, client configuration
 *
 * Usage Examples:
 *     import { previewClientConfig, applyClientConfig } from "./client-config.mjs";
 *     const preview = previewClientConfig({ client: "copilot", fragment: "mcp-fragment.json" });
 *
 * Key Input Dependencies:
 *     Node fs, path, os and crypto; COPILOT_HOME (optional) for the default
 *     Copilot config location; a Crow-generated MCP fragment file.
 *
 * Key Functions:
 *     digest()              SHA-256 hex of a value.
 *     configTarget()        Resolves and validates the client config path.
 *     readConfig()          Reads and validates an existing config file.
 *     readFragment()        Reads and validates the Crow MCP fragment.
 *     previewClientConfig() Computes added, replaced, unchanged, collisions and digest.
 *     applyClientConfig()   Applies an approved preview with lock, backup and rollback.
 *
 * Consumed by:
 *     crow-raven-setup.mjs (config preview and config apply commands).
 */

import { createHash, randomUUID } from "node:crypto";
import {
  existsSync,
  linkSync,
  lstatSync,
  mkdirSync,
  readFileSync,
  renameSync,
  unlinkSync,
  writeFileSync
} from "node:fs";
import { homedir } from "node:os";
import { basename, dirname, join, resolve } from "node:path";
import { isDeepStrictEqual } from "node:util";

/** Returns the SHA-256 hex digest of a string or buffer. */
function digest(value) {
  return createHash("sha256").update(value).digest("hex");
}

/**
 * Resolves which client configuration file to touch.
 * Accepts only --client copilot or portable (portable needs an explicit
 * --config path) and refuses unsupported targets such as settings.json.
 *
 * @param {object} args - Parsed CLI arguments (client, config).
 * @returns {{client: string, path: string, key: string}} The validated target.
 */
function configTarget(args) {
  const client = args.client;
  if (!["copilot", "portable"].includes(client)) {
    throw new Error("Choose --client copilot (also for VS Code) or portable.");
  }
  if (client === "portable" && !args.config) {
    throw new Error("Other clients require an explicitly verified --config <path> and portable mcpServers support.");
  }
  const path = resolve(args.config || join(
    process.env.COPILOT_HOME || join(homedir(), ".copilot"),
    "mcp-config.json"
  ));
  if ((client === "copilot" && basename(path).toLowerCase() !== "mcp-config.json") ||
      basename(path).toLowerCase() === "settings.json") {
    throw new Error("Refusing to write MCP servers to an unsupported configuration file.");
  }
  return { client, path, key: "mcpServers" };
}

/**
 * Reads an existing client config and validates its shape.
 * A missing file yields an empty config. Rejects non-files, malformed JSON,
 * a non-object top-level key, and the wrong "servers" format.
 *
 * @param {string} path - Config file path.
 * @param {string} key - Top-level key holding servers (mcpServers).
 * @returns {{bytes: Buffer|null, config: object}} Raw bytes and parsed config.
 */
function readConfig(path, key) {
  if (!existsSync(path)) return { bytes: null, config: { [key]: {} } };
  if (!lstatSync(path).isFile()) throw new Error(`Configuration is not a regular file: ${path}`);
  const bytes = readFileSync(path);
  let config;
  try {
    config = JSON.parse(bytes.toString("utf8"));
  } catch (error) {
    throw new Error(`MCP configuration is malformed at ${path}: ${error.message}`);
  }
  if (!config || typeof config !== "object" || Array.isArray(config) ||
      (Object.hasOwn(config, key) &&
       (!config[key] || typeof config[key] !== "object" || Array.isArray(config[key])))) {
    throw new Error(`MCP configuration must have a top-level ${key} object: ${path}`);
  }
  if (Object.hasOwn(config, "servers")) {
    throw new Error(`MCP configuration at ${path} uses servers, not the selected client's ${key} format.`);
  }
  return { bytes, config };
}

/**
 * Reads and validates the Crow-generated MCP fragment.
 * Each server must have a string command and a string-array args list.
 *
 * @param {string} fragmentPath - Path of the fragment JSON file.
 * @returns {object} The mcpServers map.
 */
function readFragment(fragmentPath) {
  let fragment;
  try {
    fragment = JSON.parse(readFileSync(fragmentPath, "utf8"));
  } catch (error) {
    throw new Error(`Crow MCP fragment is missing or malformed: ${error.message}`);
  }
  if (!fragment || typeof fragment !== "object" || !fragment.mcpServers ||
      typeof fragment.mcpServers !== "object" || Array.isArray(fragment.mcpServers) ||
      Object.keys(fragment.mcpServers).length === 0 ||
      Object.values(fragment.mcpServers).some((server) =>
        !server || typeof server.command !== "string" ||
        !Array.isArray(server.args) || server.args.some((arg) => typeof arg !== "string"))) {
    throw new Error("Crow MCP fragment contains invalid server definitions.");
  }
  return fragment.mcpServers;
}

/**
 * Computes the change a config apply would make, without writing anything.
 * Classifies each server as added, replaced (only when it still equals the
 * previous Crow-managed entry), unchanged, or a collision (which throws).
 * The approval digest binds client, path, current bytes and proposed content.
 *
 * @param {object} args - Parsed CLI arguments plus optional managedEntries and previousEntries.
 * @returns {object} Preview with changes, proposed content and approvalSha256.
 */
function previewClientConfig(args) {
  const target = configTarget(args);
  const entries = args.managedEntries || readFragment(resolve(args.fragment));
  const { bytes, config } = readConfig(target.path, target.key);
  const existing = config[target.key] || {};
  const added = [];
  const replaced = [];
  const unchanged = [];
  const collisions = [];
  for (const [name, definition] of Object.entries(entries)) {
    if (!Object.hasOwn(existing, name)) added.push(name);
    else if (isDeepStrictEqual(existing[name], definition) ||
      isDeepStrictEqual(existing[name], { type: "stdio", ...definition })) unchanged.push(name);
    else if (Object.hasOwn(args.previousEntries || {}, name) &&
      (isDeepStrictEqual(existing[name], args.previousEntries[name]) ||
       isDeepStrictEqual(existing[name], { type: "stdio", ...args.previousEntries[name] }))) {
      replaced.push(name);
    }
    else collisions.push(name);
  }
  if (collisions.length) {
    throw new Error(`MCP server name collision at ${target.path}: ${collisions.join(", ")}. Existing definitions were not changed.`);
  }
  const merged = { ...config, [target.key]: { ...existing } };
  for (const name of [...added, ...replaced]) {
    merged[target.key][name] = entries[name];
  }
  const content = `${JSON.stringify(merged, null, 2)}\n`;
  const approvalSha256 = digest(JSON.stringify({
    client: target.client, path: target.path,
    before: bytes === null ? null : digest(bytes),
    after: digest(content)
  }));
  return {
    client: target.client,
    configPath: target.path,
    format: target.key,
    added,
    replaced,
    unchanged,
    proposed: Object.fromEntries([...added, ...replaced].map((name) => [name, merged[target.key][name]])),
    beforeSha256: bytes === null ? null : digest(bytes),
    approvalSha256,
    backupRequired: (added.length + replaced.length) > 0 && bytes !== null,
    content,
    bytes
  };
}

/**
 * Applies an approved preview to the client configuration.
 * Requires --confirm and the reviewed digest, takes an exclusive lock,
 * re-previews to detect drift, writes via a temporary file and hard link,
 * keeps a backup of the original, verifies the result, and restores the
 * original if anything fails.
 *
 * @param {object} args - Parsed CLI arguments including confirm and approval-sha256.
 * @returns {object} The preview fields plus applied and backupPath.
 */
function applyClientConfig(args) {
  if (!args.confirm || !/^[a-f0-9]{64}$/i.test(args["approval-sha256"] || "")) {
    throw new Error("Config apply requires --approval-sha256 <reviewed digest> and --confirm after separate client configuration approval.");
  }
  const target = configTarget(args);
  mkdirSync(dirname(target.path), { recursive: true });
  const lock = `${target.path}.crow.lock`;
  writeFileSync(lock, "", { flag: "wx", mode: 0o600 });
  try {
    const preview = previewClientConfig(args);
    if (preview.approvalSha256 !== args["approval-sha256"].toLowerCase()) {
      throw new Error("MCP target, fragment, or configuration changed since preview; review a new preview.");
    }
    if (!preview.added.length && !preview.replaced.length) {
      return { ...preview, content: undefined, bytes: undefined, applied: false, backupPath: null };
    }
    const temporary = `${target.path}.crow-${randomUUID()}.tmp`;
    const backup = `${target.path}.crow-${randomUUID()}.bak`;
    writeFileSync(temporary, preview.content, { flag: "wx", mode: 0o600 });
    let backedUp = false;
    let written = false;
    try {
      if (preview.bytes !== null) {
        renameSync(target.path, backup);
        backedUp = true;
        if (digest(readFileSync(backup)) !== preview.beforeSha256) {
          throw new Error("MCP configuration changed during apply; the original was preserved in the backup.");
        }
      } else if (existsSync(target.path)) {
        throw new Error("MCP configuration was created during apply; review a new preview.");
      }
      linkSync(temporary, target.path);
      written = true;
      const verified = readConfig(target.path, target.key);
      if (!isDeepStrictEqual(verified.config, JSON.parse(preview.content))) {
        throw new Error("Written MCP configuration failed verification.");
      }
    } catch (error) {
      if (backedUp) {
        if (written && existsSync(target.path) &&
            lstatSync(target.path).ino === lstatSync(temporary).ino &&
            lstatSync(target.path).dev === lstatSync(temporary).dev) {
          unlinkSync(target.path);
        }
        if (existsSync(target.path)) {
          throw new Error(`${error.message} Original configuration preserved at ${backup}; destination changed during apply.`);
        }
        linkSync(backup, target.path);
      } else if (written && existsSync(target.path) &&
                 lstatSync(target.path).ino === lstatSync(temporary).ino &&
                 lstatSync(target.path).dev === lstatSync(temporary).dev) {
        unlinkSync(target.path);
      }
      throw error;
    } finally {
      unlinkSync(temporary);
    }
    return { ...preview, content: undefined, bytes: undefined, applied: true, backupPath: backedUp ? backup : null };
  } finally {
    unlinkSync(lock);
  }
}

export { applyClientConfig, previewClientConfig };
