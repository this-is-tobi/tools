import crypto from 'node:crypto'
import { promisify } from 'node:util'

// Promisify crypto functions that don't have promise versions
const randomBytes = promisify(crypto.randomBytes)
const scrypt = promisify(crypto.scrypt)

// encryptionKey should have an exact length of 32 characters
const encryptionKey = 'a-key-with-exactly-32-characters' // process.env.ENCRYPTION_KEY

/**
 * Hash a given password using scrypt with configurable security parameters.
 * @param {string} password - Password to hash.
 * @param {Object} [options={}] - Security options for scrypt.
 * @param {number} [options.b=16] - Number of bytes for salt.
 * @param {number} [options.n=16384] - Memory cost, must be power of 2.
 * @param {number} [options.r=8] - Block size.
 * @param {number} [options.p=1] - Parallelization.
 * @returns {Promise<string>} Hash of input password.
 * 
 * @example
 * // Basic usage with default options
 * const hash = await generateHash('myPassword123')
 * console.log(hash) // "a1b2c3d4:e5f6g7h8..."
 * 
 * @example
 * // Custom security parameters for higher security
 * const strongHash = await generateHash('myPassword123', {
 *   n: 32768,  // Higher memory cost
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
export async function generateHash(password, options = {}) {
  const { b = 16, n = 16384, r = 8, p = 1 } = options
  try {
    const salt = (await randomBytes(b)).toString('hex')
    const key = await scrypt(password, salt, 64, { n, r, p })
    return `${salt}:${key.toString('hex')}`
  } catch (error) {
    throw new Error(`Error during password hashing: ${error.message}`)
  }
}

/**
 * Compare given password and hash to test if it match.
 * @param {string} password - Password to compare with hash.
 * @param {string} hash - Hash to compare with password.
 * @param {Object} [options={}] - Security options for scrypt.
 * @param {number} [options.n=16384] - Memory cost, must be power of 2.
 * @param {number} [options.r=8] - Block size.
 * @param {number} [options.p=1] - Parallelization.
 * @returns {Promise<boolean>} Equality of password and hash.
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
 * const customHash = await generateHash('myPassword123', { n: 32768, r: 16 })
 * const isValid = await compareToHash('myPassword123', customHash, { n: 32768, r: 16 })
 * console.log(isValid) // true
 */
export async function compareToHash(password, hash, options = {}) {
  const { n = 16384, r = 8, p = 1 } = options
  try {
    const [salt, storedKeyHex] = hash.split(':')
    if (!salt || !storedKeyHex) {
      throw new Error('Invalid hash format')
    }
    const storedKeyBuffer = Buffer.from(storedKeyHex, 'hex')
    const derivedKey = await scrypt(password, salt, 64, { n, r, p })
    return crypto.timingSafeEqual(storedKeyBuffer, derivedKey)
  } catch (error) {
    return false
  }
}

/**
 * Encrypt a given value with an encryption key.
 * @param {string} text - Text to encrypt.
 * @param {string} key - Encryption key.
 * @param {Object} [options={}] - Encryption options.
 * @param {string} [options.a='aes-256-cbc'] - Algorithm.
 * @param {number} [options.b=16] - Initialization vector length in bytes.
 * @returns {promise} Encrypted text.
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
export async function encrypt(text, key, options = {}) {
  const { a = 'aes-256-cbc', b = 16 } = options
  try {
    const iv = await randomBytes(b)
    const cipher = crypto.createCipheriv(a, key, iv)
    let encrypted = cipher.update(text, 'utf8', 'hex')
    encrypted += cipher.final('hex')
    return iv.toString('hex') + ':' + encrypted
  } catch (error) {
    throw new Error(`Encryption failed: ${error.message}`)
  }
}

/**
 * Decrypt a given value with an encryption key.
 * @param {string} text - Encrypted text to decrypt.
 * @param {string} key - Encryption key.
 * @param {Object} [options={}] - Encryption options.
 * @param {string} [options.a='aes-256-cbc'] - Algorithm.
 * @returns {promise} Decrypted text.
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
export async function decrypt(encryptedData, key, options = {}) {
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
    throw new Error(`Decryption failed: ${error.message}`)
  }
}

/**
 * Generate a random password
 * @param {number} [length=24] - Length of the generated password.
 * @returns {string} Generated password.
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
export function generateRandomPassword(length = 24) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!@-_#*'
  return Array.from(crypto.getRandomValues(new Uint32Array(length)))
    .map(x => chars[x % chars.length])
    .join('')
}

// Test function
async function test() {
  const password = generateRandomPassword()
  const hash = await generateHash(password)
  const isHashEqual = await compareToHash(password, hash)
  const encrypted = await encrypt(password, encryptionKey)
  const decrypted = await decrypt(encrypted, encryptionKey)

  console.log({
    password,
    encryptionKey,
    hash,
    isHashEqual,
    encrypted,
    decrypted,
  })
}

test().catch(console.error)
