# Module: Deserialization & Data Integrity

**Purpose:** Detect insecure deserialization, type confusion, gadget chains, and unsigned data acceptance patterns. SonarQube flags basic `BinaryFormatter` usage but doesn't understand type restriction configurations, gadget chain reachability, or integrity verification gaps.

## Detection Strategy

1. Locate all deserialization points via `search_graph` for deserializer classes/methods
2. For each deserialization point, trace inbound to determine if the data source is untrusted
3. Check whether type restrictions, allowlists, or integrity verification are in place
4. Assess gadget availability in the dependency tree

## Dangerous Deserialization Patterns

### Java

| Pattern | Risk | Mitigation Check |
|---------|------|-----------------|
| `ObjectInputStream.readObject()` on network/file input | CRITICAL | `ObjectInputFilter` configured? |
| `XStream.fromXML(untrusted)` | CRITICAL | `XStream.allowTypes()` or `denyTypes()` configured? |
| `XMLDecoder` with external input | CRITICAL | Almost never safe — flag unless input is verified |
| `SnakeYAML.load(untrusted)` without safe constructor | HIGH | `new Yaml(new SafeConstructor())` used? |
| Jackson with `@JsonTypeInfo` + `enableDefaultTyping()` | HIGH | `PolymorphicTypeValidator` configured? |
| Jackson `ObjectMapper.readValue()` with `Object.class` | HIGH | Specific type target used instead? |

### .NET

| Pattern | Risk | Mitigation Check |
|---------|------|-----------------|
| `BinaryFormatter.Deserialize()` | CRITICAL | Should be replaced entirely (deprecated) |
| `JsonSerializer` with `TypeNameHandling != None` | HIGH | `TypeNameHandling.None` or custom binder? |
| `DataContractSerializer` with unknown types | MEDIUM | Known type list configured? |
| `XmlSerializer` with `[XmlInclude]` on broad types | MEDIUM | Restricted type hierarchy? |
| `Newtonsoft.Json` with `TypeNameHandling.All/Auto` | HIGH | `SerializationBinder` with allowlist? |

### Python

| Pattern | Risk | Mitigation Check |
|---------|------|-----------------|
| `pickle.loads(untrusted)` / `pickle.load(file)` | CRITICAL | Source verified as trusted? |
| `yaml.load(data)` without SafeLoader | HIGH | `yaml.safe_load()` used instead? |
| `shelve.open()` with user-controlled path | HIGH | Path validated? |
| `marshal.loads(untrusted)` | CRITICAL | Almost never safe with external input |
| `dill.loads(untrusted)` | CRITICAL | Same risks as pickle |

### Node.js

| Pattern | Risk | Mitigation Check |
|---------|------|-----------------|
| `node-serialize` / `funcster` with external input | CRITICAL | Remove library entirely |
| `js-yaml.load()` without safe schema | HIGH | `js-yaml.load(data, { schema: SAFE_SCHEMA })` |
| `eval()` / `new Function()` with external data | CRITICAL | Never safe with untrusted input |
| `vm.runInContext(untrusted)` | CRITICAL | Sandbox escape is trivial |

### PHP

| Pattern | Risk | Mitigation Check |
|---------|------|-----------------|
| `unserialize($userInput)` | CRITICAL | `allowed_classes` option set? |
| `unserialize()` without `allowed_classes: false` | HIGH | Restrict to specific classes |

## Data Integrity Checks

### Unsigned Data Acceptance

- JWT tokens accepted without signature verification (`alg: none` attack)
- Webhooks processed without HMAC/signature validation
- Software updates downloaded without checksum verification
- Configuration loaded from external sources without integrity check
- Session data trusted from client-side cookies without server-side signing

### CI/CD Integrity

- Build artifacts without checksums or signing
- Dependencies fetched without lockfile integrity (missing `--frozen-lockfile`)
- Container images pulled by mutable tag (`:latest`) instead of digest
- Deployment scripts modifiable without approval

## What This Catches That SonarQube Doesn't

- Deserialization with type restrictions that may still be exploitable (gadget chains within allowed types)
- Cross-file assessment of whether deserialized data comes from trusted or untrusted source
- Missing integrity verification on webhooks, JWTs, and external config
- CI/CD supply chain integrity gaps
- Gadget chain reachability (dangerous classes in classpath + deserialization point = exploitable)
