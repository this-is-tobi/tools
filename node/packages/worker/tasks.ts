/**
 * Fibonacci calculation options
 */
export interface FibonacciOptions {
  /** The position in Fibonacci sequence (0-based) */
  n: number
}

/**
 * Task function type definition
 */
export type TaskFunction<T = any, R = any> = (options: T) => R

/**
 * Calculate Fibonacci number using recursive approach
 * Note: Intentionally slow recursive implementation for demonstration
 * @param options - Fibonacci calculation options
 * @returns The Fibonacci number at position n
 * 
 * @example
 * fibonacci({ n: 0 }) // 0
 * fibonacci({ n: 1 }) // 1
 * fibonacci({ n: 5 }) // 5
 * fibonacci({ n: 10 }) // 55
 */
function fibonacci(options: FibonacciOptions): number {
  const { n } = options
  if (n <= 1) return n
  return fibonacci({ n: n - 1 }) + fibonacci({ n: n - 2 })
}

/**
 * Task implementations
 * Each task is a function that takes an options object and returns a result
 */
export const tasks: Record<string, TaskFunction> = {
  fibonacci,
}
