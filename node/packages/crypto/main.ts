import { generateRandomPassword, generateHash, compareToHash, encrypt, decrypt } from './functions.ts'

// encryptionKey should have an exact length of 32 characters
const encryptionKey = 'a-key-with-exactly-32-characters'; // process.env.ENCRYPTION_KEY

// Test function
async function test(): Promise<void> {
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
