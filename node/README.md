# Node.js Modules

This directory contains TypeScript versions of the crypto and worker modules from the parent `node/` directory. These modules are designed to run with [Bun](https://bun.sh/), which provides native TypeScript support out of the box.

The project is organized as a monorepo with separate packages for different functionality.

## Prerequisites

- [Bun](https://bun.sh/) installed on your system

## Project Structure

```
packages/
├── crypto/           # Cryptographic utilities
│   ├── functions.ts  # Core crypto functions
│   ├── main.ts      # Example usage
│   └── utils/       # Additional utilities
│       ├── scrypt-benchmark.ts  # Performance benchmarking
│       ├── scrypt-options.ts    # Options testing
│       └── SCRYPT-PARAMETERS.md # Detailed documentation
├── worker/          # Worker thread utilities
│   ├── manager.ts   # Pool management
│   ├── worker.ts    # Worker implementation
│   ├── tasks.ts     # Task definitions
│   └── main.ts      # Example usage
└── quorum/          # Multi-agent security-review pipeline
    ├── types.ts     # Shared interfaces
    ├── client.ts    # OpenAI-compatible chat completion client
    ├── pipeline.ts  # Research -> dedup -> panel -> quorum orchestration
    └── main.ts      # CLI entry point
```

## Modules

### Crypto Module (`./packages/crypto/`)

A comprehensive cryptographic utility module providing:

- **Password hashing** using scrypt with configurable security parameters
- **Password verification** with timing-safe comparison
- **AES encryption/decryption** with multiple algorithm support
- **Random password generation** with customizable length
- **Scrypt parameter benchmarking** for performance testing
- **Scrypt options validation** for parameter verification

#### Key Features

- Full TypeScript type safety
- Comprehensive JSDoc documentation
- Configurable security parameters
- Error handling with descriptive messages
- Performance benchmarking utilities
- Memory usage calculations

#### Usage

```bash
# Run main crypto example
bun run crypto

# Run scrypt benchmarking
bun run crypto:bench

# Test scrypt options
bun run crypto:opts
```

#### API

```typescript
import { generateHash, compareToHash, encrypt, decrypt, generateRandomPassword } from './packages/crypto/functions.ts'

// Generate and verify password hash
const password = generateRandomPassword(16)
const hash = await generateHash(password, { N: 32768 })
const isValid = await compareToHash(password, hash, { N: 32768 })

// Encrypt and decrypt data
const encrypted = await encrypt('secret data', 'your-32-character-encryption-key')
const decrypted = await decrypt(encrypted, 'your-32-character-encryption-key')
```

#### Scrypt Parameters Reference

**Overview**

scrypt is a password-based key derivation function (PBKDF) designed by Colin Percival. It's specifically designed to be "memory-hard" to make it expensive for attackers to perform large-scale custom hardware attacks.

**Official Documentation Links**

1. **Node.js Crypto Documentation**
   - https://nodejs.org/api/crypto.html#cryptoscryptpassword-salt-keylen-options-callback

2. **RFC 7914 - The scrypt Password-Based Key Derivation Function**
   - https://tools.ietf.org/rfc/rfc7914.txt
   - Official specification with mathematical details

3. **Original scrypt Paper**
   - https://www.tarsnap.com/scrypt/scrypt.pdf
   - Colin Percival's original research paper

4. **OWASP Password Storage Cheat Sheet**
   - https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
   - Security best practices for password storage

**Parameters Explained**

**`N` - CPU/Memory Cost Parameter**
- **Type**: Integer (must be power of 2)
- **Default**: 16384 (2^14)
- **Purpose**: Primary security parameter that determines memory usage and computational cost
- **Memory Impact**: Memory usage ≈ 128 * N * r bytes
- **Common Values:**
  ```typescript
  N: 16384   // Default - Good for most applications (~16MB with default r=8)
  N: 32768   // Higher security (~32MB with default r=8)
  N: 65536   // Very high security (~64MB with default r=8) - May cause issues
  N: 4096    // Lower security, faster computation (~4MB with default r=8)
  ```

**`r` - Block Size Parameter**
- **Type**: Integer
- **Default**: 8
- **Purpose**: Controls the block size for the underlying hash function
- **Memory Impact**: Memory usage ≈ 128 * N * r bytes
- **Common Values:**
  ```typescript
  r: 8       // Default - Standard block size
  r: 16      // Larger blocks, more memory usage, potentially more secure
  r: 4       // Smaller blocks, less memory usage, faster but less secure
  ```

**`p` - Parallelization Parameter**
- **Type**: Integer
- **Default**: 1
- **Purpose**: Number of independent mixing functions (can utilize multiple cores)
- **Memory Impact**: Total memory = p * 128 * N * r bytes
- **Common Values:**
  ```typescript
  p: 1       // Default - Single threaded
  p: 2       // Dual core utilization
  p: 4       // Quad core utilization
  ```

**`b` - Salt Length (Custom Parameter)**
- **Type**: Integer
- **Default**: 16 bytes
- **Purpose**: Length of the random salt in bytes
- **Security Impact**: Longer salts provide better protection against rainbow tables

**Memory Usage Calculator**

```typescript
// Formula: Memory = p * 128 * N * r bytes
function calculateMemoryUsage(N: number, r: number = 8, p: number = 1): string {
  const bytes = p * 128 * N * r;
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)} MB`;
}

// Examples:
calculateMemoryUsage(16384, 8, 1);  // "16.0 MB" - Default
calculateMemoryUsage(32768, 8, 1);  // "32.0 MB" - Higher security
calculateMemoryUsage(16384, 16, 1); // "32.0 MB" - Larger blocks
calculateMemoryUsage(16384, 8, 2);  // "32.0 MB" - Parallel processing
```

**Security Recommendations**

```typescript
// Interactive Applications (Login, etc.) - Fast but secure
const interactive = { N: 16384, r: 8, p: 1 } // ~50ms, 16MB

// Sensitive Data (Password managers, etc.) - Higher security
const sensitive = { N: 32768, r: 8, p: 1 } // ~100ms, 32MB

// Archive/Backup Systems - Maximum security
const archive = { N: 65536, r: 8, p: 1 } // ~200ms, 64MB

// Server Applications - Balanced with parallel processing
const server = { N: 16384, r: 8, p: 2 } // ~100ms, 32MB, uses 2 cores
```

**Performance vs Security Trade-offs**

| Configuration     | Time   | Memory | Security Level | Use Case               |
| ----------------- | ------ | ------ | -------------- | ---------------------- |
| N=4096, r=8, p=1  | ~25ms  | 4MB    | Low            | Development/Testing    |
| N=16384, r=8, p=1 | ~50ms  | 16MB   | Standard       | Web Applications       |
| N=32768, r=8, p=1 | ~100ms | 32MB   | High           | Sensitive Applications |
| N=16384, r=8, p=2 | ~100ms | 32MB   | High           | Server Applications    |
| N=65536, r=8, p=1 | ~200ms | 64MB   | Very High      | Archive Systems        |

**Important Notes:**
1. Parameters must match between hash generation and verification
2. Higher N values exponentially increase both time and memory requirements
3. Memory limits may prevent very high N values (system dependent)
4. Test thoroughly with your target hardware before deployment

### Worker Module (`./packages/worker/`)

A robust worker thread pool implementation for parallel task processing:

- **Worker pool management** with automatic initialization and cleanup
- **Task queuing** with load balancing across workers
- **Performance monitoring** with detailed statistics
- **Error handling** with graceful failure recovery

#### Key Features

- Full TypeScript type safety with strict interfaces
- Automatic CPU core detection for optimal worker count
- Background task processing with non-blocking execution
- Comprehensive performance metrics

#### Usage

```bash
bun run worker
```

#### API

```typescript
import { callWorker, cleanup, type TaskInput } from './packages/worker/manager.ts'

// Process multiple tasks in parallel
const tasks: TaskInput[] = [
  { task: 'fibonacci', data: { n: 10 } },
  { task: 'fibonacci', data: { n: 15 } },
  { task: 'fibonacci', data: { n: 20 } }
]

const results = await callWorker(tasks)
console.log(results) // Array of TaskResult objects

// Clean up worker pool when done
await cleanup()
```

### Quorum Module (`./packages/quorum/`)

A multi-agent security-review pipeline: an LLM proposes candidate vulnerabilities in a diff, then three independent voters — blind to each other's reasoning — each judge the same candidate from a different fixed angle before it's reported. Talks to any OpenAI-compatible `/chat/completions` endpoint, zero third-party dependencies.

**Status**: early / under active iteration. Currently implements the finder + independent panel + code-computed quorum (roughly Phase 0-1 of the design). Escalation on marginal (2/3) splits, cross-model verification, and the patch-generation loop are documented as later phases, not yet built here.

#### Why a panel instead of "ask a second model"

Letting verifiers see each other's reasoning measurably converges results toward agreement rather than correctness, and a verifying model is worse at judging its own confidence than a proposing one is. So the three votes here run fully independently — no shared context between them — and the keep/discard decision plus its confidence ceiling (`3/3` -> `high`, `2/3` -> `medium`, otherwise discarded) is ordinary arithmetic in `pipeline.ts`, never a number a model reports about itself. Three voters is close to the cost-effective floor, not a placeholder for more: self-consistency research shows most of the achievable gain from repeated sampling arrives within a handful of samples, and each additional parallel call has a real latency cost.

This is expected to disagree with itself between runs sometimes — that's inherent to the approach, not a bug. A `2/3` split today is a real, still-open design gap: without the escalation phase, it lands as `medium` confidence and stops there rather than triggering a repanel and a dedicated adversarial pass.

#### Key Features

- Zero dependencies — plain `fetch`, works under Bun or Node
- Model-agnostic per role: point the finder and the panel at different backends (`RESEARCH_*` / `VOTER_*` env vars, `VOTER_*` falls back to `RESEARCH_*`)
- Compiles to a standalone binary via Bun (`bun run quorum:compile`) — no runtime dependency to distribute
- Defensive JSON extraction rather than trusting `response_format` schema enforcement, since OpenAI-compatible servers vary in how much of the real API surface they implement

#### Usage

```bash
# Run against a diff file
RESEARCH_MODEL=qwen3.6:27b bun run quorum ./my.diff

# Or pipe a diff on stdin
git diff origin/main...HEAD | RESEARCH_MODEL=qwen3.6:27b bun run quorum

# Compile to a standalone binary
bun run quorum:compile
./quorum ./my.diff
```

```bash
# Configuration (env vars)
export RESEARCH_BASE_URL="http://localhost:11434/v1"  # default: that (Ollama)
export RESEARCH_API_KEY="not-needed"                   # omit entirely for endpoints with no auth
export RESEARCH_MODEL="qwen3.6:27b"                    # required

# Optional - point the panel at a different backend than the finder
export VOTER_MODEL="gpt-5.4"
export VOTER_BASE_URL="https://api.openai.com/v1"
export VOTER_API_KEY="sk-..."
```

#### API

```typescript
import { runQuorum } from './packages/quorum/pipeline.ts'

const diff = await Bun.file('./my.diff').text()
const { kept, discarded } = await runQuorum(diff, (message) => console.error(message))

for (const finding of kept) {
  console.log(`${finding.file}:${finding.line} [${finding.confidence}] ${finding.summary}`)
}
```
