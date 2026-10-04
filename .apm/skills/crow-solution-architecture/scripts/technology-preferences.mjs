#!/usr/bin/env node

import { randomUUID } from "node:crypto";
import { closeSync, existsSync, lstatSync, mkdirSync, openSync, readFileSync, realpathSync, renameSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const categories = [
  "deployment-shape", "user-experience", "backend", "web-ui", "transactional-data",
  "api", "hosting", "delivery", "identity", "authorization", "integration",
  "background-work", "observability", "secrets", "caching", "search",
  "object-storage", "ci-cd", "infrastructure-as-code", "testing", "operations"
];

const defaultPath = join(homedir(), ".crow", "technology-preferences.json");
const slug = /^[a-z][a-z0-9-]{0,47}$/;
const choicePattern = /^[A-Za-z0-9.][A-Za-z0-9 .+#-]{0,79}$/;
const datePattern = /^\d{4}-\d{2}-\d{2}$/;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function plainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

export function validate(data) {
  assert(plainObject(data) && data.schema_version === 1 && Array.isArray(data.preferences),
    "Unsupported or malformed technology preferences file.");
  assert(Object.keys(data).sort((a, b) => a.localeCompare(b)).join(",") === "preferences,schema_version",
    "Unknown top-level technology preferences fields.");
  const keys = new Set();
  for (const item of data.preferences) {
    assert(plainObject(item) &&
      Object.keys(item).sort((a, b) => a.localeCompare(b)).join(",") === "category,choice,context,recorded_on,stance",
    "Malformed preference record.");
    assert(categories.includes(item.category), "Unknown technology preference category.");
    assert(typeof item.context === "string" && slug.test(item.context),
      "Context must be a generic lowercase slug (or 'any').");
    assert(typeof item.choice === "string" && choicePattern.test(item.choice) &&
      !item.choice.includes("//") && !item.choice.includes(".."),
    "Choice must be a short technology label, not a URL, path, or note.");
    assert(["prefer", "avoid"].includes(item.stance), "Invalid preference stance.");
    assert(typeof item.recorded_on === "string" && datePattern.test(item.recorded_on) &&
      !Number.isNaN(Date.parse(`${item.recorded_on}T00:00:00Z`)),
    "Invalid preference date.");
    const key = `${item.category}:${item.context}:${item.choice.toLowerCase()}`;
    assert(!keys.has(key), "Duplicate technology preference.");
    keys.add(key);
  }
  return data;
}

export function load(path = defaultPath) {
  if (!existsSync(path)) return { schema_version: 1, preferences: [] };
  assert(lstatSync(path).isFile(), "Technology preferences path must be a regular file.");
  return validate(JSON.parse(readFileSync(path, "utf8")));
}

export function save(data, path = defaultPath) {
  validate(data);
  const folder = dirname(path);
  mkdirSync(folder, { recursive: true, mode: 0o700 });
  assert(!existsSync(path) || lstatSync(path).isFile(),
    "Technology preferences path must be a regular file.");
  const temporary = join(folder, `.technology-preferences-${randomUUID()}.tmp`);
  try {
    const fd = openSync(temporary, "wx", 0o600);
    try {
      writeFileSync(fd, `${JSON.stringify(data, null, 2)}\n`, "utf8");
    } finally {
      closeSync(fd);
    }
    renameSync(temporary, path);
  } finally {
    if (existsSync(temporary)) unlinkSync(temporary);
  }
}

function parseArgs(args) {
  const [command, ...rest] = args;
  const options = {};
  for (let i = 0; i < rest.length; i += 2) {
    const key = rest[i];
    assert(key?.startsWith("--") && rest[i + 1] !== undefined && !rest[i + 1].startsWith("--"),
      `Expected a value after ${key ?? "option"}.`);
    assert(!Object.hasOwn(options, key), `Duplicate option ${key}.`);
    options[key] = rest[i + 1];
  }
  return { command, options };
}

export function run(args, path = defaultPath) {
  const { command, options } = parseArgs(args);
  let allowed = null;
  if (command === "list") allowed = [];
  if (command === "remember") allowed = ["--category", "--choice", "--context", "--stance", "--confirm"];
  if (command === "forget") allowed = ["--category", "--choice", "--context", "--confirm"];
  assert(allowed !== null, "Usage: list | remember | forget. See the technology-preferences module.");
  assert(Object.keys(options).every((key) => allowed.includes(key)), "Unknown option.");
  const data = load(path);
  if (command === "list") return data;
  assert(options["--confirm"] === "yes", "Explicit confirmation is required (--confirm yes).");
  const category = options["--category"];
  const context = options["--context"];
  const choice = options["--choice"];
  assert(categories.includes(category),
    `Unknown category. Allowed categories: ${categories.join(", ")}`);
  assert(typeof context === "string" && slug.test(context) &&
    typeof choice === "string" && choicePattern.test(choice) &&
    !choice.includes("//") && !choice.includes(".."),
    "Provide a generic context slug and short technology label.");
  const matches = (item) => item.category === category && item.context === context &&
    item.choice.toLowerCase() === choice.toLowerCase();
  if (command === "remember") {
    const stance = options["--stance"];
    assert(["prefer", "avoid"].includes(stance), "Specify --stance prefer or avoid.");
    data.preferences = data.preferences.filter((item) => !matches(item));
    data.preferences.push({
      category, context, choice, stance,
      recorded_on: new Date().toISOString().slice(0, 10)
    });
  } else {
    const originalLength = data.preferences.length;
    data.preferences = data.preferences.filter((item) => !matches(item));
    assert(data.preferences.length < originalLength, "Preference not found; nothing was removed.");
  }
  save(data, path);
  return data;
}

if (process.argv[1] && realpathSync(fileURLToPath(import.meta.url)) === realpathSync(process.argv[1])) {
  try {
    console.log(JSON.stringify(run(process.argv.slice(2)), null, 2));
  } catch (error) {
    console.error(`ERROR: ${error.message}`);
    process.exitCode = 1;
  }
}
