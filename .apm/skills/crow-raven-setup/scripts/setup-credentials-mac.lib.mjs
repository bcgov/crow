/**
 * setup-credentials-mac.lib.mjs (library)
 * =====================================
 *
 * Purpose:
 *     Pure helpers for setup-credentials-mac.mjs, split out for unit testing
 *     (same pattern as gen-inventory.lib.mjs). Masks secrets for display,
 *     seeds prompt defaults, normalizes answers, and validates dependent
 *     credential settings. No I/O, so it is safe to import anywhere.
 *
 * Layer: Crow Raven Setup skill, credential entry (macOS) helpers
 *
 * Usage Examples:
 *     import { mask, validateRecord } from "./setup-credentials-mac.lib.mjs";
 *
 * Key Input Dependencies:
 *     None. Takes plain objects and strings.
 *
 * Key Functions:
 *     mask()             Masks a secret for display.
 *     seedDefaults()     Builds prompt defaults from .env and keychain values.
 *     normalizeAnswer()  Normalizes one prompt answer before storing it.
 *     applyAnswer()      Stores, keeps, or clears one record value.
 *     validateRecord()   Reports missing dependent settings.
 *
 * Consumed by:
 *     setup-credentials-mac.mjs
 */

/** Mask a secret for display: first/last two chars, or **** when short. */
export function mask(value) {
  if (value.length <= 4) return "****";
  return value.slice(0, 2) + "*".repeat(value.length - 4) + value.slice(-2);
}

/**
 * Defaults offered at each prompt (kept when the answer is blank).
 * Existing keychain values win over ~/.raven/.env values, and only the
 * prompted credential keys are imported from .env — non-credential tuning
 * config (RATE_LIMIT_*, SMTP_*, …) stays in the plain-text file, where later
 * edits still take effect. Extra keys already in the keychain are preserved.
 */
export function seedDefaults(promptedKeys, envValues, keychainValues) {
  const defaults = {};
  for (const key of promptedKeys) {
    if (envValues[key]) defaults[key] = envValues[key];
  }
  return { ...defaults, ...keychainValues };
}

/**
 * Normalize one prompt answer before it is stored. Sensitive answers
 * (passwords, tokens) are kept verbatim — leading/trailing whitespace can be
 * part of the real secret — except for a trailing "\r" that some terminals
 * leave on the line; readline's `question` callback already strips the
 * newline itself. Non-sensitive answers are trimmed as before.
 */
export function normalizeAnswer(answer, { sensitive = false } = {}) {
  if (sensitive) {
    return answer.endsWith("\r") ? answer.slice(0, -1) : answer;
  }
  return answer.trim();
}

/**
 * Applies one prompt answer to the credential record in place.
 * ":clear" deletes the key, a non-empty answer sets it, and a blank answer
 * keeps whatever value is already there.
 */
export function applyAnswer(record, name, answer) {
  if (answer === ":clear") delete record[name];
  else if (answer) record[name] = answer;
}

/**
 * Validation errors for dependent credential settings, checked after every
 * prompt has resolved so kept values are covered as well as newly typed ones.
 */
export function validateRecord(record) {
  const errors = [];
  if (record.GITHUB_TOKEN && !record.GITHUB_REPOSITORY_ALLOWLIST) {
    errors.push("GITHUB_REPOSITORY_ALLOWLIST is required when configuring GITHUB_TOKEN.");
  }
  if (record.JARVIS_TOKEN && !record.JARVIS_BASE_URL?.trim()) {
    errors.push("JARVIS_BASE_URL is required when configuring JARVIS_TOKEN.");
  }
  if (record.ADO_PAT && !record.ADO_BASE_URL?.trim()) {
    errors.push("ADO_BASE_URL is required when configuring ADO_PAT.");
  }
  if (record.SONARQUBE_TOKEN && !record.SONARQUBE_URL?.trim()) {
    errors.push("SONARQUBE_URL is required when configuring SONARQUBE_TOKEN.");
  }
  return errors;
}
