import { generateHash, compareToHash } from '../functions.ts'

/**
 * Calculate estimated memory usage for scrypt parameters
 */
export function calculateMemoryUsage(N: number, r: number = 8, p: number = 1): {
  bytes: number
  kb: number
  mb: number
  formatted: string
} {
  const bytes = p * 128 * N * r
  const kb = bytes / 1024
  const mb = bytes / (1024 * 1024)
  
  return {
    bytes,
    kb: Math.round(kb * 10) / 10,
    mb: Math.round(mb * 10) / 10,
    formatted: mb < 1 ? `${kb.toFixed(1)} KB` : `${mb.toFixed(1)} MB`
  }
}

/**
 * Benchmark scrypt parameters to measure actual performance
 */
export async function benchmarkScryptParams(
  password: string = 'benchmark-password',
  paramSets: Array<{name: string, N: number, r?: number, p?: number}>
): Promise<void> {
  console.log('🔍 Benchmarking scrypt parameters...\n')
  
  const results: Array<{
    name: string
    time: string
    memory: string
    status: 'success' | 'error'
    preview?: string
    error?: string
  }> = []
  
  for (const params of paramSets) {
    const { name, N, r = 8, p = 1 } = params
    const memory = calculateMemoryUsage(N, r, p)
    
    try {
      const startTime = performance.now()
      const hash = await generateHash(password, { N, r, p })
      const endTime = performance.now()
      const duration = Math.round(endTime - startTime)
      
      // Verify the hash works
      const isValid = await compareToHash(password, hash, { N, r, p })
      if (!isValid) {
        results.push({
          name,
          time: 'FAIL',
          memory: memory.formatted,
          status: 'error',
          error: 'Hash verification failed'
        })
      } else {
        const hashPreview = hash.substring(0, 16) + '...'
        results.push({
          name,
          time: `${duration}ms`,
          memory: memory.formatted,
          status: 'success',
          preview: hashPreview
        })
      }
    } catch (error) {
      const errorMsg = (error as Error).message
      const shortError = errorMsg.includes('MEMORY_LIMIT_EXCEEDED') 
        ? 'Memory limit exceeded'
        : errorMsg.substring(0, 30) + '...'
        
      results.push({
        name,
        time: 'ERROR',
        memory: memory.formatted,
        status: 'error',
        error: shortError
      })
    }
  }
  
  // Print formatted table
  console.log('┌─────────────────┬────────┬─────────┬───────────────────────┐')
  console.log('│ Configuration   │ Time   │ Memory  │ Result                │')
  console.log('├─────────────────┼────────┼─────────┼───────────────────────┤')
  
  results.forEach(result => {
    const config = result.name.padEnd(15)
    const time = result.time.padEnd(6)
    const memory = result.memory.padEnd(7)
    
    const resultText = result.status === 'success' 
      ? result.preview!
      : result.error!
    const resultPadded = resultText.padEnd(21)
    
    console.log(`│ ${config} │ ${time} │ ${memory} │ ${resultPadded} │`)
  })
  
  console.log('└─────────────────┴────────┴─────────┴───────────────────────┘')
}

/**
 * Recommended parameter sets for different use cases
 */
export const SCRYPT_PRESETS = {
  // Development - fast for testing
  development: { N: 4096, r: 8, p: 1 },
  
  // Interactive - good for user logins
  interactive: { N: 16384, r: 8, p: 1 },
  
  // Sensitive - increased security for important data
  sensitive: { N: 32768, r: 8, p: 1 },
  
  // Server - balanced with parallel processing
  server: { N: 16384, r: 8, p: 2 },
  
  // Maximum - for archive/backup systems
  maximum: { N: 65536, r: 8, p: 1 },
} as const

/**
 * Get recommended parameters based on use case
 */
export function getRecommendedParams(useCase: keyof typeof SCRYPT_PRESETS) {
  return SCRYPT_PRESETS[useCase]
}

// Demo function to show parameter effects
async function demo(): Promise<void> {
  console.log('🧮 Scrypt Parameter Calculator & Benchmark\n')
  
  // Show memory calculations
  console.log('📊 Memory Usage Calculations:')
  const configs = [
    { name: 'Development', N: 4096, r: 8, p: 1 },
    { name: 'Standard', N: 16384, r: 8, p: 1 },
    { name: 'High Security', N: 32768, r: 8, p: 1 },
    { name: 'Server (2 cores)', N: 16384, r: 8, p: 2 },
    { name: 'Large Blocks', N: 16384, r: 16, p: 1 },
    { name: 'Maximum', N: 65536, r: 8, p: 1 },
  ]
  
  configs.forEach(config => {
    const memory = calculateMemoryUsage(config.N, config.r, config.p)
    console.log(`  ${config.name.padEnd(20)}: ${memory.formatted.padStart(8)} (N=${config.N}, r=${config.r}, p=${config.p})`)
  })
  
  console.log('\n')
  
  // Benchmark performance
  await benchmarkScryptParams('test-password', [
    { name: 'Development', N: 4096, r: 8, p: 1 },
    { name: 'Standard', N: 16384, r: 8, p: 1 },
    { name: 'High Security', N: 16384, r: 8, p: 2 }, // Changed to use p=2 instead of N=32768
    { name: 'Server', N: 8192, r: 8, p: 4 }, // More cores, lower N for testing
  ])
  
  console.log('\n📚 For more information, see SCRYPT-PARAMETERS.md')
}

demo().catch(console.error)
