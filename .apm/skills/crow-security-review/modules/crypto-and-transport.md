# Module: Cryptography & Transport Security

**Purpose:** Detect cryptographic misuse, key management flaws, and transport security gaps. SonarQube flags obvious weak algorithm usage (MD5, DES) but doesn't assess key management practices, protocol configuration correctness, or context-appropriate algorithm selection.

## Detection Strategy

1. Use `search_graph` to locate all cryptographic operations (encryption, hashing, signing, RNG)
2. Assess whether algorithms are appropriate for their context (password hashing vs. integrity vs. encryption)
3. Check key management: hardcoded keys, key derivation, storage location, rotation
4. Review TLS/transport configuration for downgrade risks

## Algorithm Assessment (Context-Dependent)

### Password Hashing

| Algorithm | Assessment | Notes |
|-----------|-----------|-------|
| bcrypt, scrypt, argon2, PBKDF2 (high iterations) | SAFE | Appropriate for password storage |
| SHA-256/SHA-512 with unique salt | MEDIUM risk | Acceptable but bcrypt/argon2 preferred |
| SHA-256/SHA-512 without salt | HIGH risk | Rainbow table vulnerable |
| MD5, SHA-1 (for passwords) | CRITICAL | Trivially crackable |
| Custom/home-grown hashing | HIGH risk | Almost always flawed |

### Encryption

| Pattern | Risk | Notes |
|---------|------|-------|
| AES-GCM, AES-CCM, ChaCha20-Poly1305 | SAFE | Authenticated encryption |
| AES-CBC with separate HMAC | SAFE if HMAC-then-decrypt | Verify decrypt only after MAC check |
| AES-CBC without MAC | HIGH | Padding oracle attacks possible |
| AES-ECB mode | HIGH | Pattern leakage |
| DES, 3DES, RC4, Blowfish | HIGH | Deprecated algorithms |
| RSA-PKCS1v1.5 for encryption | MEDIUM | Bleichenbacher attacks; use OAEP |
| RSA < 2048 bits | HIGH | Insufficient key length |

### Integrity / Signatures

| Algorithm | Assessment |
|-----------|-----------|
| SHA-256+, HMAC-SHA256 | SAFE |
| SHA-1 for signatures | MEDIUM (collision attacks feasible) |
| MD5 for integrity | HIGH (trivially forgeable) |
| MD5/SHA-1 for non-security checksums (cache keys, ETags) | NOT A FINDING |

### Random Number Generation

| Pattern | Risk | Context |
|---------|------|---------|
| `SecureRandom` (Java), `RandomNumberGenerator` (.NET), `secrets` (Python), `crypto.randomBytes` (Node) | SAFE | Cryptographic RNG |
| `Math.random()`, `Random()`, `rand()` | HIGH if used for security tokens/IDs | NOT a finding for UI/shuffle |
| Seeded PRNG with predictable seed | HIGH for security use | Check what the seed source is |

## Key Management Checks

| Issue | Severity | What to Look For |
|-------|----------|-----------------|
| Hardcoded encryption keys | CRITICAL | Literal byte arrays or strings used as keys |
| Hardcoded IVs/nonces | HIGH | Static IV reuse negates encryption security |
| Keys derived from passwords without KDF | HIGH | Direct use of password bytes as key |
| Key material in source control | CRITICAL | `.pem`, `.key`, `.p12` files committed |
| Key material in config files | HIGH | Base64-encoded keys in `appsettings.json` etc. |
| No key rotation mechanism | MEDIUM | Single key used indefinitely |
| Symmetric key shared across services | MEDIUM | Compromise of one service exposes all |

## Transport / TLS Configuration

| Issue | Severity | Detection |
|-------|----------|-----------|
| TLS 1.0/1.1 enabled | HIGH | Check web server config, framework SSL settings |
| Certificate validation disabled | CRITICAL | `TrustAllCerts`, `verify=False`, `NODE_TLS_REJECT_UNAUTHORIZED=0` |
| Hostname verification disabled | CRITICAL | `AllowAllHostnameVerifier`, `check_hostname=False` |
| Mixed content (HTTP resources on HTTPS page) | MEDIUM | Check CSP, resource URLs |
| Missing HSTS | MEDIUM | Check security headers |
| Self-signed certs in production | HIGH | Check certificate configuration |
| Hardcoded TLS cipher suites (outdated) | MEDIUM | Check if weak ciphers included |

### Language-Specific TLS Disable Patterns

| Language | Dangerous Pattern |
|----------|------------------|
| Java | `TrustManager` that returns empty `checkServerTrusted`, `ALLOW_ALL_HOSTNAME_VERIFIER` |
| C# | `ServicePointManager.ServerCertificateValidationCallback = (s, c, ch, e) => true` |
| Python | `requests.get(url, verify=False)`, `ssl._create_unverified_context()` |
| Node.js | `process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0'`, `rejectUnauthorized: false` |
| Go | `InsecureSkipVerify: true` in `tls.Config` |
| Ruby | `OpenSSL::SSL::VERIFY_NONE` |

## What This Catches That SonarQube Doesn't

- Context-inappropriate algorithms (SHA-256 without salt for passwords — SonarQube only flags MD5/SHA1)
- AES-CBC without authentication (padding oracle risk)
- Key management lifecycle issues (rotation, sharing, storage)
- Hardcoded IVs that negate encryption security
- TLS configuration issues at the infrastructure level
- Certificate validation disabled in specific client configurations (not globally)
