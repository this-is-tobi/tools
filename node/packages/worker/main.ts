import { callWorker, cleanup, getStats, type TaskInput } from './manager.ts'

// Test function
async function test(): Promise<void> {
  const fibonacciTasks: TaskInput[] = Array
    .from({ length: 40 }, (_, i) => i + 1)
    .map((n) => ({ task: 'fibonacci', data: { n } }))
    
  const results = await callWorker(fibonacciTasks)
  
  console.log('\nJob Results:')
  console.table(results)
  console.log('\nWorkers Stats:')
  console.table(getStats().workerStats)
  
  await cleanup()
}

test().catch(console.error)
