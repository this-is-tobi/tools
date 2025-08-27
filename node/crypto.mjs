import crypto from 'node:crypto'

// encryptionKey should have an exact length of 32 characters
const encryptionKey = 'a-key-with-exactly-32-characters' // process.env.ENCRYPTION_KEY
const ivLength = 16

/**
 * Hash a given password using scrypt with configurable security parameters.
 * @function generateHash
 * @param {string} password - Password to hash.
 * @param {Object} options - Security options for scrypt.
 * @param {number} options.N - Memory cost (default: 16384)
 * @param {number} options.r - Block size (default: 8)
 * @param {number} options.p - Parallelization (default: 1)
 * @returns {Promise<string>} Hash of input password.
 */
export async function generateHash(password, options = {}) {
  const { N = 16384, r = 8, p = 1 } = options
  
  try {
    // Generate a random salt of 16 bytes
    const salt = crypto.randomBytes(16).toString('hex')
    
    // Use scrypt with configurable security parameters via crypto.promises
    const key = await crypto.promises.scrypt(
      password, 
      salt, 
      64, 
      { 
        N, // Memory cost (must be a power of 2)
        r, // Block size
        p  // Parallelization
      }
    )
    
    return `${salt}:${key.toString('hex')}`
  } catch (error) {
    throw new Error(`Error during password hashing: ${error.message}`)
  }
}

/**
 * Compare given password and hash to test if it match.
 * @function compareToHash
 * @param {string} password - Password to compare with hash.
 * @param {string} hash - Hash to compare with password.
 * @param {Object} options - Security options for scrypt.
 * @param {number} options.N - Memory cost (default: 16384)
 * @param {number} options.r - Block size (default: 8)
 * @param {number} options.p - Parallelization (default: 1)
 * @returns {Promise<boolean>} Equality of password and hash.
 */
export async function compareToHash(password, hash, options = {}) {
  const { N = 16384, r = 8, p = 1 } = options
  
  try {
    const [salt, storedKeyHex] = hash.split(':')
    
    if (!salt || !storedKeyHex) {
      throw new Error('Invalid hash format')
    }
    
    const storedKeyBuffer = Buffer.from(storedKeyHex, 'hex')
    
    // Generate the key from password with configurable security parameters
    const derivedKey = await crypto.promises.scrypt(
      password, 
      salt, 
      64, 
      { 
        N,
        r,
        p
      }
    )
    
    // Secure comparison
    return crypto.timingSafeEqual(storedKeyBuffer, derivedKey)
  } catch (error) {
    // Do not reveal internal error information
    return false
  }
}

/**
 * Encrypt a given value with an encryption key.
 * @function encrypt
 * @param {string} text - Text to encrypt.
 * @returns {promise} Encrypted text.
 */
export function encrypt(text) {
  return new Promise((resolve, reject) => {
    try {
      const iv = crypto.randomBytes(ivLength)
      const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(encryptionKey), iv)
      let encrypted = cipher.update(text)
      encrypted = Buffer.concat([encrypted, cipher.final()])
      resolve(`${iv.toString('hex')}:${encrypted.toString('hex')}`)
    } catch (err) {
      reject(err)
    }
  })
}

/**
 * Decrypt a given value with an encryption key.
 * @function decrypt
 * @param {string} text - Encrypted text to decrypt.
 * @returns {promise} Decrypted text.
 */
export function decrypt(text) {
  return new Promise((resolve, reject) => {
    try {
      const textParts = text.split(':')
      const iv = Buffer.from(textParts.shift(), 'hex')
      const encryptedText = Buffer.from(textParts.join(':'), 'hex')
      const decipher = crypto.createDecipheriv('aes-256-cbc', Buffer.from(encryptionKey), iv)
      let decrypted = decipher.update(encryptedText)
      decrypted = Buffer.concat([decrypted, decipher.final()])
      resolve(decrypted.toString())
    } catch (err) {
      reject(err)
    }
  })
}

/**
 * Generate a random password
 * @function generateRandomPassword
 * @param {number} [length] - Length of the generated password.
 * @returns {string} Generated password.
 */
export function generateRandomPassword(length = 24) {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789?!@-_#*'
  return Array.from(crypto.getRandomValues(new Uint32Array(length)))
    .map(x => chars[x % chars.length])
    .join('')
}

// Test functions
(async () => {
  const password = 'Password42!'

  const hash = await generateHash(password)
  const isHashEqual = await compareToHash(password, hash)

  const encrypted = await encrypt(password)
  const decrypted = await decrypt(encrypted)

  const generatedPassword = generateRandomPassword()

  console.log({
    password,
    encryptionKey,
    hash,
    isHashEqual,
    encrypted,
    decrypted,
    generatedPassword,
  })
})()
