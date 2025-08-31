import crypto from 'node:crypto'
import { promisify } from 'node:util'

// Promisify crypto functions that don't have promise versions
const randomBytes = promisify(crypto.randomBytes)

/**
 * Promisified scrypt function that properly handles options
 */
function scryptAsync(password: string, salt: string, keylen: number, options: { N: number; r: number; p: number }): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    crypto.scrypt(password, salt, keylen, options, (err, derivedKey) => {
      if (err) {
        reject(err)
      } else {
        resolve(derivedKey)
      }
    })
  })
}

/**
 * Security options for scrypt hashing
 * 
 * scrypt is a password-based key derivation function designed to be computationally 
 * intensive and memory-hard to make it costly for attackers to crack passwords.
 * 
 * @see https://nodejs.org/api/crypto.html#cryptoscryptpassword-salt-keylen-options-callback
 * @see https://tools.ietf.org/rfc/rfc7914.txt (RFC 7914 - The scrypt specification)
 */
export interface ScryptOptions {
  /** 
   * Number of bytes for salt (default: 16)
   * Larger salts provide better security against rainbow table attacks.
   */
  b?: number
  
  /** 
   * CPU/Memory cost parameter, must be power of 2 (default: 16384)
   * 
   * Higher values exponentially increase memory usage and computation time.
   * This is the primary parameter that makes scrypt "memory-hard".
   * 
   * Common values:
   * - 16384 (2^14) - Default, good for most applications
   * - 32768 (2^15) - Higher security
   * - 65536 (2^16) - Very high security (may cause memory issues)
   * 
   * Memory usage ≈ 128 * N * r bytes
   */
  N?: number
  
  /** 
   * Block size parameter (default: 8)
   * 
   * Controls the block size for the underlying hash function.
   * Higher values increase memory usage and can improve security
   * but also increase computation time.
   * 
   * Memory usage ≈ 128 * N * r bytes
   * 
   * Common values: 8, 16, 32
   */
  r?: number
  
  /** 
   * Parallelization parameter (default: 1)
   * 
   * Number of independent mixing functions that can run in parallel.
   * Higher values can utilize multiple CPU cores but also increase memory usage.
   * 
   * Memory usage = p * 128 * N * r bytes
   * 
   * Common values: 1, 2, 4
   */
  p?: number
}

/**
 * Encryption options for AES encryption
 */
export interface EncryptionOptions {
  /** Algorithm (default: 'aes-256-cbc') */
  a?: string
  /** Initialization vector length in bytes (default: 16) */
  b?: number
}

/**
 * Decryption options for AES decryption
 */
export interface DecryptionOptions {
  /** Algorithm (default: 'aes-256-cbc') */
  a?: string
}

/**
 * Hash a given password using scrypt with configurable security parameters.
 * @param password - Password to hash.
 * @param options - Security options for scrypt.
 * @returns Hash of input password.
 * 
 * @example
 * // Basic usage with default options
 * const hash = await generateHash('myPassword123')
 * console.log(hash) // "a1b2c3d4:e5f6g7h8..."
 * 
 * @example
 * // Custom security parameters for higher security
 * const strongHash = await generateHash('myPassword123', {
 *   N: 32768,  // Higher memory cost
 *   r: 16,     // Larger block size
 *   p: 2       // More parallelization
 * })
 * 
 * @example
 * // Longer salt for additional security
 * const hashWithLongSalt = await generateHash('myPassword123', {
 *   b: 32  // 32-byte salt instead of default 16
 * })
 */
export async function generateHash(password: string, options: ScryptOptions = {}): Promise<string> {
  const { b = 16, N = 16384, r = 8, p = 1 } = options
  try {
    const salt = (await randomBytes(b)).toString('hex')
    // Use full scrypt with security parameters
    const key = await scryptAsync(password, salt, 64, { N, r, p })
    return `${salt}:${key.toString('hex')}`
  } catch (error) {
    throw new Error(`Error during password hashing: ${(error as Error).message}`)
  }
}

/**
 * Compare given password and hash to test if it match.
 * @param password - Password to compare with hash.
 * @param hash - Hash to compare with password.
 * @param options - Security options for scrypt.
 * @returns Equality of password and hash.
 * 
 * @example
 * // Basic password verification
 * const password = 'myPassword123'
 * const hash = await generateHash(password)
 * const isValid = await compareToHash(password, hash)
 * console.log(isValid) // true
 * 
 * @example
 * // Verification with wrong password
 * const wrongPassword = 'wrongPassword'
 * const isValid = await compareToHash(wrongPassword, hash)
 * console.log(isValid) // false
 * 
 * @example
 * // Verification with custom scrypt parameters (must match generateHash options)
 * const customHash = await generateHash('myPassword123', { N: 32768, r: 16 })
 * const isValid = await compareToHash('myPassword123', customHash, { N: 32768, r: 16 })
 * console.log(isValid) // true
 */
export async function compareToHash(password: string, hash: string, options: ScryptOptions = {}): Promise<boolean> {
  const { N = 16384, r = 8, p = 1 } = options
  try {
    const [salt, storedKeyHex] = hash.split(':')
    if (!salt || !storedKeyHex) {
      throw new Error('Invalid hash format')
    }
    const storedKeyBuffer = Buffer.from(storedKeyHex, 'hex')
    // Use full scrypt with security parameters (must match generateHash)
    const derivedKey = await scryptAsync(password, salt, 64, { N, r, p })
    return crypto.timingSafeEqual(storedKeyBuffer, derivedKey)
  } catch (error) {
    return false
  }
}

/**
 * Encrypt a given value with an encryption key.
 * @param text - Text to encrypt.
 * @param key - Encryption key.
 * @param options - Encryption options.
 * @returns Encrypted text.
 * 
 * @example
 * // Basic encryption with default AES-256-CBC
 * const key = 'a-key-with-exactly-32-characters'
 * const encrypted = await encrypt('Hello, World!', key)
 * console.log(encrypted) // "a1b2c3d4e5f6:9g8h7i6j5k4l..."
 * 
 * @example
 * // Encryption with different algorithm
 * const encryptedAES128 = await encrypt('Secret message', key, {
 *   a: 'aes-128-cbc'  // Use AES-128 instead of AES-256
 * })
 * 
 * @example
 * // Encryption with custom IV length
 * const encryptedCustomIV = await encrypt('Secret data', key, {
 *   b: 12  // Use 12-byte IV instead of default 16
 * })
 * 
 * @example
 * // Full customization
 * const fullyCustom = await encrypt('Top secret', key, {
 *   a: 'aes-192-cbc',  // AES-192 algorithm
 *   b: 16              // 16-byte IV
 * })
 */
export async function encrypt(text: string, key: string, options: EncryptionOptions = {}): Promise<string> {
  const { a = 'aes-256-cbc', b = 16 } = options
  try {
    const iv = await randomBytes(b)
    const cipher = crypto.createCipheriv(a, key, iv)
    let encrypted = cipher.update(text, 'utf8', 'hex')
    encrypted += cipher.final('hex')
    return iv.toString('hex') + ':' + encrypted
  } catch (error) {
    throw new Error(`Encryption failed: ${(error as Error).message}`)
  }
}

/**
 * Decrypt a given value with an encryption key.
 * @param encryptedData - Encrypted text to decrypt.
 * @param key - Encryption key.
 * @param options - Encryption options.
 * @returns Decrypted text.
 * 
 * @example
 * // Basic decryption with default AES-256-CBC
 * const key = 'a-key-with-exactly-32-characters'
 * const encryptedData = 'a1b2c3d4e5f6:9g8h7i6j5k4l...'
 * const decrypted = await decrypt(encryptedData, key)
 * console.log(decrypted) // "Hello, World!"
 * 
 * @example
 * // Decryption with specific algorithm (must match encryption algorithm)
 * const decryptedAES128 = await decrypt(encryptedData, key, {
 *   a: 'aes-128-cbc'  // Use same algorithm as encryption
 * })
 * 
 * @example
 * // Complete encrypt/decrypt workflow
 * const originalText = 'Secret message'
 * const encrypted = await encrypt(originalText, key)
 * const decrypted = await decrypt(encrypted, key)
 * console.log(decrypted === originalText) // true
 */
export async function decrypt(encryptedData: string, key: string, options: DecryptionOptions = {}): Promise<string> {
  const { a = 'aes-256-cbc' } = options
  try {
    const [ivHex, encrypted] = encryptedData.split(':')
    if (!ivHex || !encrypted) {
      throw new Error('Invalid encrypted data format')
    }
    const iv = Buffer.from(ivHex, 'hex')
    const decipher = crypto.createDecipheriv(a, key, iv)
    let decrypted = decipher.update(encrypted, 'hex', 'utf8')
    decrypted += decipher.final('utf8')
    return decrypted
  } catch (error) {
    throw new Error(`Decryption failed: ${(error as Error).message}`)
  }
}

/**
 * Generate a random password
 * @param length - Length of the generated password.
 * @returns Generated password.
 * 
 * @example
 * // Generate a password with default length (24 characters)
 * const password = generateRandomPassword()
 * console.log(password) // "A4k!_XBm9@TzQr3Y#nKp8Wv1"
 * console.log(password.length) // 24
 * 
 * @example
 * // Generate a short password (8 characters)
 * const shortPassword = generateRandomPassword(8)
 * console.log(shortPassword) // "Bx9@Mk2!"
 * 
 * @example
 * // Generate a long password (48 characters)
 * const longPassword = generateRandomPassword(48)
 * console.log(longPassword) // "P7qR@3sT!4uV#6wX?8yZ_1aB*9cD-5eF@7gH!3iJ"
 * 
 * @example
 * // Character set includes: a-z, A-Z, 0-9, ?!@-_#*
 * const pwd = generateRandomPassword(12)
 * // Possible output: "X3m@9Zt!K4pQ"
 */
export function generateRandomPassword(length: number = 24): string {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!@-_#*'
  const randomValues = crypto.getRandomValues(new Uint32Array(length))
  return Array.from(randomValues, (x: number) => chars[x % chars.length]).join('')
}
