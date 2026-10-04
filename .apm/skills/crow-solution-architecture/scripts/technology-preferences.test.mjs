import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, test } from "node:test";
import { fileURLToPath } from "node:url";
import { load, run } from "./technology-preferences.mjs";

const directory = mkdtempSync(join(tmpdir(), "crow-technology-preferences-"));
const path = join(directory, "user", "technology-preferences.json");
after(() => rmSync(directory, { recursive: true, force: true }));

test("missing memory is empty without creating a file", () => {
  assert.deepEqual(run(["list"], path), { schema_version: 1, preferences: [] });
  assert.equal(existsSync(path), false);
});

test("CLI entry point handles invalid commands instead of silently succeeding", () => {
  const cli = fileURLToPath(new URL("./technology-preferences.mjs", import.meta.url));
  const result = spawnSync(process.execPath, [cli, "invalid"], { encoding: "utf8" });
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Usage: list \| remember \| forget/);
});

test("confirmed choices are added, updated, and forgotten with exact scope", () => {
  assert.throws(() => run(["remember", "--category", "backend", "--choice", ".NET LTS",
    "--context", "workflow-web", "--stance", "prefer"], path), /confirmation/);
  run(["remember", "--category", "backend", "--choice", ".NET LTS",
    "--context", "workflow-web", "--stance", "prefer", "--confirm", "yes"], path);
  run(["remember", "--category", "backend", "--choice", "Java LTS",
    "--context", "existing-jvm-team", "--stance", "prefer", "--confirm", "yes"], path);
  run(["remember", "--category", "backend", "--choice", ".NET LTS",
    "--context", "workflow-web", "--stance", "avoid", "--confirm", "yes"], path);
  assert.equal(load(path).preferences.length, 2);
  assert.equal(load(path).preferences[0].choice, "Java LTS");
  assert.equal(load(path).preferences[1].stance, "avoid");
  assert.match(readFileSync(path, "utf8"), /"schema_version": 1/);
  run(["forget", "--category", "backend", "--choice", ".NET LTS",
    "--context", "workflow-web", "--confirm", "yes"], path);
  assert.equal(load(path).preferences.length, 1);
  assert.throws(() => run(["forget", "--category", "backend", "--choice", ".NET LTS",
    "--context", "workflow-web", "--confirm", "yes"], path), /not found/);
});

test("unsafe and unknown input is rejected without changing the file", () => {
  const before = readFileSync(path, "utf8");
  for (const choice of ["https://internal.example", "C:/secret", "../secret", "a@b.com"]) {
    assert.throws(() => run(["remember", "--category", "identity", "--choice", choice,
      "--context", "any", "--stance", "prefer", "--confirm", "yes"], path));
  }
  assert.throws(() => run(["remember", "--category", "unknown", "--choice", "ok",
    "--context", "any", "--stance", "prefer", "--confirm", "yes"], path),
  /Allowed categories/);
  for (const context of ["Workflow-Web", "workflow web", "123-bad", ""]) {
    assert.throws(() => run(["remember", "--category", "identity", "--choice", "OIDC",
      "--context", context, "--stance", "prefer", "--confirm", "yes"], path),
    /generic context slug/);
  }
  assert.throws(() => run(["remember", "--category", "identity", "--choice", "OIDC",
    "--context", "any", "--stance", "prefer", "--confirm", "no"], path), /confirmation/);
  assert.deepEqual(readFileSync(path, "utf8"), before);
});

test("malformed and unsupported memory fails visibly rather than being overwritten", () => {
  for (const malformed of [
    "{", '{"schema_version":2,"preferences":[]}',
    '{"schema_version":1,"preferences":[{"category":"backend","choice":"x"}]}'
  ]) {
    writeFileSync(path, malformed);
    assert.throws(() => run(["list"], path));
    assert.throws(() => run(["remember", "--category", "backend", "--choice", "Java",
      "--context", "any", "--stance", "prefer", "--confirm", "yes"], path));
    assert.equal(readFileSync(path, "utf8"), malformed);
  }
});
