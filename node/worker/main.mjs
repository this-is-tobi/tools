import { callWorker } from './manager.mjs'

// Test function
async function test() {
  const fibonacciTasks = Array
    .from({ length: 40 }, (_, i) => i + 1)
    .map((n) => ({ task: 'fibonacci', data: { n } }))
  const results = await callWorker(fibonacciTasks)
  console.log('\nJob Results:')
  console.table(results)
}

test().catch(console.error)
