import { generateHash, compareToHash } from '../functions.ts';

// Test function to demonstrate scrypt options working
async function testScryptOptions(): Promise<void> {
  const password = 'testPassword123';
  
  console.log('Testing scrypt with different security parameters...\n');
  
  // Test with default options
  console.time('Default options (N=16384, r=8, p=1)');
  const hashDefault = await generateHash(password);
  const isValidDefault = await compareToHash(password, hashDefault);
  console.timeEnd('Default options (N=16384, r=8, p=1)');
  console.log(`Default hash: ${hashDefault}`);
  console.log(`Valid: ${isValidDefault}\n`);
  
  // Test with higher security (different parameters but reasonable)
  console.time('High security (N=16384, r=8, p=2)');
  const hashHigh = await generateHash(password, { N: 16384, r: 8, p: 2 });
  const isValidHigh = await compareToHash(password, hashHigh, { N: 16384, r: 8, p: 2 });
  console.timeEnd('High security (N=16384, r=8, p=2)');
  console.log(`High security hash: ${hashHigh}`);
  console.log(`Valid: ${isValidHigh}\n`);
  
  // Test with longer salt
  console.time('Longer salt (b=32)');
  const hashLongSalt = await generateHash(password, { b: 32 });
  const isValidLongSalt = await compareToHash(password, hashLongSalt);
  console.timeEnd('Longer salt (b=32)');
  console.log(`Long salt hash: ${hashLongSalt}`);
  console.log(`Valid: ${isValidLongSalt}\n`);
  
  // Verify that different options produce different hashes
  console.log('Verifying different options produce different hashes:');
  console.log(`Default != High security: ${hashDefault !== hashHigh}`);
  console.log(`Default != Long salt: ${hashDefault !== hashLongSalt}`);
  
  // Test cross-compatibility (should fail because parameters don't match)
  console.log('\nTesting cross-compatibility (should fail):');
  try {
    // Try to verify high security hash with default parameters (wrong!)
    const isValidCross = await compareToHash(password, hashHigh); // Using default options to verify high security hash
    console.log(`High security hash verified with default options: ${isValidCross}`);
    
    // Try to verify default hash with high security parameters (wrong!)
    const isValidCross2 = await compareToHash(password, hashDefault, { N: 16384, r: 8, p: 2 });
    console.log(`Default hash verified with high security options: ${isValidCross2}`);
  } catch (error) {
    console.log(`Cross-compatibility failed as expected: ${(error as Error).message}`);
  }
}

testScryptOptions().catch(console.error);
