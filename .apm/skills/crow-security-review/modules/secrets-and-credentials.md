# Module: Secrets & Credentials

**Purpose:** Detect secrets in locations SonarQube doesn't effectively scan — infrastructure files, CI/CD configs, environment files, Docker layers, and non-code artifacts. SonarQube's secret detection covers source code well but misses operational and deployment secrets.

## Detection Strategy

1. Search non-code files: `.env*`, `docker-compose*.yml`, `Dockerfile*`, CI config files, Kubernetes manifests, Terraform/Pulumi files, Helm charts
2. Check for committed secrets that should be in vaults or environment injection
3. Verify `.gitignore` covers secret-bearing files
4. Check for secret rotation mechanisms

## File Locations to Scan (Beyond Source Code)

| File Type | Location Patterns | Common Secrets |
|-----------|------------------|----------------|
| Environment files | `.env`, `.env.local`, `.env.production` | DB passwords, API keys, JWT secrets |
| Docker Compose | `docker-compose*.yml` | Service passwords, connection strings |
| Dockerfile | `Dockerfile*` | Build args with secrets, embedded credentials |
| CI/CD Config | `.github/workflows/*.yml`, `Jenkinsfile`, `.gitlab-ci.yml`, `azure-pipelines.yml` | Deploy keys, registry passwords, cloud credentials |
| Kubernetes | `k8s/*.yaml`, `manifests/*.yaml` | Secrets in plain YAML (not sealed/encrypted) |
| Terraform | `*.tf`, `*.tfvars` | Provider credentials, state backend keys |
| Helm | `values*.yaml` | Service passwords, TLS certs |
| Infrastructure | `ansible/**`, `playbooks/**` | SSH keys, vault passwords |
| Config files | `appsettings*.json`, `application*.yml`, `config/*.json` | Connection strings with embedded passwords |

## Secret Detection Patterns

| Category | Search Patterns | Severity If Found |
|----------|----------------|-------------------|
| Private keys | `BEGIN RSA PRIVATE KEY`, `BEGIN EC PRIVATE KEY`, `BEGIN OPENSSH PRIVATE KEY` | CRITICAL |
| AWS credentials | `AKIA[0-9A-Z]{16}`, `aws_secret_access_key` | CRITICAL |
| Azure credentials | `AccountKey=`, `client_secret`, `DefaultEndpointsProtocol` | CRITICAL |
| GCP credentials | `"type": "service_account"`, `private_key_id` | CRITICAL |
| Connection strings | `://.*:.*@` (with inline password), `Password=` in connection string | HIGH |
| JWT secrets | `JWT_SECRET`, `TOKEN_SECRET` with literal values | HIGH |
| Generic API keys | `sk-[a-zA-Z0-9]{20,}`, `key-[a-zA-Z0-9]{20,}` | HIGH |
| Webhook secrets | `WEBHOOK_SECRET`, `SIGNING_SECRET` with literal values | HIGH |

## Classification Criteria

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Production credentials, private keys, cloud access keys with literal values |
| **HIGH** | Database passwords, service account credentials in committed files |
| **MEDIUM** | Development/test credentials that follow production naming patterns |
| **LOW** | Placeholder values clearly marked (`changeme`, `your-key-here`, `TODO`) |
| **NOT A FINDING** | Environment variable references (`${DB_PASSWORD}`, `process.env.SECRET`), vault references, KMS ARNs |

## False Positive Prevention

- Do NOT flag environment variable references — these are the correct pattern
- Do NOT flag password field names in HTML forms or UI labels
- Do NOT flag hashed passwords (bcrypt, SHA-256 hashes stored in seed data)
- Do NOT flag test fixture data clearly in test directories with obvious fake values
- Do NOT flag vault paths, KMS key ARNs, or secret manager references
- DO flag connection strings even if they appear to be "dev" — they may be reused
- DO flag `.env` files that are NOT in `.gitignore`

## Rotation & Lifecycle Checks

- Are secret values rotatable without code changes? (env vars = good, hardcoded = bad)
- Is there evidence of secret rotation (multiple keys, versioned secrets)?
- Are secrets scoped minimally (per-service keys vs. shared master key)?
- Are there expiry/TTL configurations for tokens and certificates?

## What This Catches That SonarQube Doesn't

- Secrets in Docker, CI/CD, and infrastructure-as-code files
- Committed `.env` files not covered by `.gitignore`
- Kubernetes secrets in plain YAML (vs. sealed secrets or external secret operators)
- Cloud credentials in Terraform state or variable files
- Connection strings with embedded passwords in non-code config
