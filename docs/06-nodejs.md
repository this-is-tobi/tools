# Nodejs

This section provides a collection of Node.js utilities for various tasks, including cryptography and worker management.

## Prerequisites

- **[Bun](https://bun.sh/)** - Fast JavaScript runtime (recommended)
  - Install: `curl -fsSL https://bun.sh/install | bash`
- **Alternative**: Node.js 18+ with npm
- **TypeScript knowledge** - All modules are written in TypeScript

## Available Packages

| Name                              | Description                |
| --------------------------------- | -------------------------- |
| [crypto](../node/packages/crypto) | *set of crypto functions.* |
| [worker](../node/packages/worker) | *set of worker functions.* |

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
└── worker/          # Worker thread utilities
    ├── manager.ts   # Pool management
    ├── worker.ts    # Worker implementation
    ├── tasks.ts     # Task definitions
    └── main.ts      # Example usage
```

## Modules

### Crypto Module (`../packages/crypto/`)

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
import { generateHash, compareToHash, encrypt, decrypt, generateRandomPassword } from '../packages/crypto/functions.ts'

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

### Worker Module (`../packages/worker/`)

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
import { callWorker, cleanup, type TaskInput } from '../packages/worker/manager.ts'

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

## Getting Started

```sh
# Clone repository
git clone https://github.com/this-is-tobi/tools.git
cd tools/node

# Run examples
bun run crypto    # Crypto module example
bun run worker    # Worker module example
bun run crypto:bench  # Scrypt benchmarking
```

## Integration

### Copy to Your Project

**Crypto Module:**
```sh
mkdir -p lib/crypto
curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/node/packages/crypto/functions.ts" \
  -o "lib/crypto/functions.ts"
```

**Worker Module:**
```sh
mkdir -p lib/worker
for file in manager worker tasks; do
  curl -fsSL "https://raw.githubusercontent.com/this-is-tobi/tools/main/node/packages/worker/$file.ts" \
    -o "lib/worker/$file.ts"
done
```

### Use as Submodule

```sh
git submodule add https://github.com/this-is-tobi/tools.git vendor/tools
```

## Usage Examples

### Crypto Module

**Password Management:**
```typescript
import { generateHash, compareToHash, generateRandomPassword } from './packages/crypto/functions.ts'

const password = generateRandomPassword(16)
const hash = await generateHash(password, { N: 32768 })
const isValid = await compareToHash(password, hash, { N: 32768 })
```

**Data Encryption:**
```typescript
import { encrypt, decrypt } from './packages/crypto/functions.ts'

const key = 'your-32-character-secret-key!'  // Must be 32 chars
const encrypted = await encrypt('sensitive data', key)
const decrypted = await decrypt(encrypted, key)
```

### Worker Module

**Parallel Processing:**
```typescript
import { callWorker, cleanup } from './packages/worker/manager.ts'

const tasks = [
  { task: 'fibonacci', data: { n: 30 } },
  { task: 'fibonacci', data: { n: 35 } }
]

const results = await callWorker(tasks)
await cleanup()
```

## Troubleshooting

### Crypto Module

**Hash generation slow:**
- Reduce `N` parameter (trade-off with security)
- Memory usage = `128 * N * r * p` bytes

**Encryption key error:**
```typescript
const key = 'a'.repeat(32)  // Must be exactly 32 characters
```

**compareToHash fails:**
- Use same parameters for hash and compare
- Verify hash string is unmodified

### Worker Module

**Workers not starting:**
- Check worker.ts file path
- Verify Bun/Node.js supports worker threads

**Performance not improved:**
- Verify tasks are CPU-bound (not I/O-bound)
- Ensure tasks are independent
- Call `cleanup()` when done

## Best Practices

### Crypto

- Use minimum `N=16384` for production
- Never hardcode encryption keys
- Store keys in environment variables or vaults
- Use `aes-256-gcm` for authenticated encryption

### Worker

- Keep tasks CPU-intensive
- Make tasks independent (no shared state)
- Cleanup pool when application exits
- Batch process multiple tasks at once
