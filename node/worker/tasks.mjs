/**
 * Calculate Fibonacci number using recursive approach
 * Note: Intentionally slow recursive implementation for demonstration
 * @param {Object} options - Encryption options.
 * @param {number} options.n - The position in Fibonacci sequence (0-based)
 * @returns {number} The Fibonacci number at position n
 * 
 * @example
 * fibonacci(0) // 0
 * fibonacci(1) // 1
 * fibonacci(5) // 5
 * fibonacci(10) // 55
 */
function fibonacci(options) {
  const { n } = options
  if (n <= 1) return n
  return fibonacci({ n: n - 1 }) + fibonacci({ n: n - 2 })
}

/**
 * Task implementations
 * Each task is a function that takes an options object and returns a result
 * @type {Object.<string, Function>}
 */
export const tasks = {
  fibonacci,
}
