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

function digest(value) {
  return createHash("sha256").update(value).digest("hex");
}

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

function previewClientConfig(args) {
  const target = configTarget(args);
  const entries = args.managedEntries || readFragment(resolve(args.fragment));
  const { bytes, config } = readConfig(target.path, target.key);
  const existing = config[target.key] || {};
  const added = [];
  const unchanged = [];
  const collisions = [];
  for (const [name, definition] of Object.entries(entries)) {
    if (!Object.hasOwn(existing, name)) added.push(name);
    else if (isDeepStrictEqual(existing[name], definition) ||
      isDeepStrictEqual(existing[name], { type: "stdio", ...definition })) unchanged.push(name);
    else collisions.push(name);
  }
  if (collisions.length) {
    throw new Error(`MCP server name collision at ${target.path}: ${collisions.join(", ")}. Existing definitions were not changed.`);
  }
  const merged = { ...config, [target.key]: { ...existing } };
  for (const name of added) {
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
    unchanged,
    proposed: Object.fromEntries(added.map((name) => [name, merged[target.key][name]])),
    beforeSha256: bytes === null ? null : digest(bytes),
    approvalSha256,
    backupRequired: added.length > 0 && bytes !== null,
    content,
    bytes
  };
}

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
    if (!preview.added.length) return { ...preview, content: undefined, bytes: undefined, applied: false, backupPath: null };
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
