import { availableParallelism } from 'node:os'
import { Worker } from 'node:worker_threads'
import type { WorkerMessage, WorkerResponse, WorkerResponseData } from './worker.ts'

/**
 * Worker instance with additional metadata
 */
export interface WorkerInstance {
  /** Worker unique identifier */
  id: number
  /** Whether worker is currently processing a task */
  busy: boolean
  /** Number of jobs processed by this worker */
  jobCount: number
  /** Promise resolve function for current job */
  currentResolve?: (value: WorkerResponseData) => void
  /** Promise reject function for current job */
  currentReject?: (reason: Error) => void
  /** Worker thread instance */
  worker: Worker
}

/**
 * Job structure for queuing tasks
 */
export interface Job {
  /** Task type ('fibonacci', etc.) */
  task: string
  /** Task input data */
  data: any
  /** Promise resolve function */
  resolve: (value: WorkerResponseData) => void
  /** Promise reject function */
  reject: (reason: Error) => void
}

/**
 * Task result returned to user
 */
export interface TaskResult {
  /** The computed result */
  result: any
  /** ID of worker that processed the task */
  workerId: number
  /** Task type that was executed */
  task: string
  /** Original input data */
  data: any
  /** Execution time in milliseconds */
  duration: number
}

/**
 * Pool statistics
 */
export interface PoolStats {
  /** Total number of workers in pool */
  workers: number
  /** Number of currently active jobs */
  active: number
  /** Total number of completed jobs */
  completed: number
  /** Number of jobs waiting in queue */
  queued: number
  /** Individual worker statistics */
  workerStats: Array<{
    id: number
    busy: boolean
    jobs: number
  }>
}

/**
 * Task input for batch processing
 */
export interface TaskInput {
  /** Task type to execute */
  task: string
  /** Task input data */
  data: any
}

/**
 * Simple worker pool state management
 */
interface WorkerPool {
  /** Array of worker instances */
  workers: WorkerInstance[]
  /** Queue of pending jobs */
  queue: Job[]
  /** Count of currently active jobs */
  activeJobs: number
  /** Count of completed jobs */
  completedJobs: number
  /** Whether pool has been initialized */
  initialized: boolean
}

const pool: WorkerPool = {
  workers: [],
  queue: [],
  activeJobs: 0,
  completedJobs: 0,
  initialized: false
}

/**
 * Initialize worker pool with specified number of workers
 * @param size - Number of workers to create
 * 
 * @example
 * await initPool(4) // Create pool with 4 workers
 */
async function initPool(size: number = availableParallelism()): Promise<void> {
  if (pool.initialized) {
    console.log('Worker pool already initialized')
    return
  }
  
  console.log(`Initializing pool with ${size} workers...`)
  
  for (let i = 0; i < size; i++) {
    const worker = new Worker(new URL('./worker.ts', import.meta.url), {
      workerData: { isWorker: true, id: i }
    })
    
    const workerInstance: WorkerInstance = {
      id: i,
      busy: false,
      jobCount: 0,
      worker: worker
    }
    
    worker.on('message', (result: WorkerResponse) => handleResult(workerInstance, result))
    worker.on('error', (error: Error) => console.error(`Worker ${i} error:`, error))
    
    pool.workers.push(workerInstance)
  }
  
  pool.initialized = true
  console.log('Worker pool ready')
}

/**
 * Handle result message from worker
 * @param worker - Worker that sent the result
 * @param result - Result object from worker
 * 
 * @example
 * // Called automatically when worker sends message
 * worker.on('message', (result) => handleResult(worker, result))
 */
function handleResult(worker: WorkerInstance, result: WorkerResponse): void {
  worker.busy = false
  worker.jobCount++
  pool.activeJobs--
  
  if (result.error) {
    worker.currentReject?.(new Error(result.error))
  } else if (result.data) {
    pool.completedJobs++
    worker.currentResolve?.(result.data)
  }
  
  processQueue()
}

/**
 * Process next job in queue if workers are available
 * 
 * @example
 * // Called automatically after job completion
 * processQueue()
 */
function processQueue(): void {
  if (pool.queue.length === 0) return
  
  const freeWorker = pool.workers.find(w => !w.busy)
  if (!freeWorker) return
  
  const job = pool.queue.shift()
  if (job) {
    runJob(freeWorker, job)
  }
}

/**
 * Execute job on specified worker
 * @param worker - Worker to execute job on
 * @param job - Job to execute
 * 
 * @example
 * const job = { task: 'fibonacci', data: { n: 10 }, resolve, reject }
 * runJob(availableWorker, job)
 */
function runJob(worker: WorkerInstance, job: Job): void {
  const { task, data } = job
  worker.busy = true
  worker.currentResolve = job.resolve
  worker.currentReject = job.reject
  pool.activeJobs++
  
  const message: WorkerMessage = { task, data }
  worker.worker.postMessage(message)
}

/**
 * Add task to worker pool for execution
 * @param task - Task to execute in worker
 * @param data - Task input data
 * @returns Promise that resolves with task result
 * 
 * @example
 * // Calculate 10th Fibonacci number
 * const result = await addTask('fibonacci', { n: 10 })
 * console.log(result.result) // 55
 * console.log(result.workerId) // 0, 1, 2, or 3 (depending on which worker processed it)
 * console.log(result.duration) // execution time in milliseconds
 * 
 * @example
 * // Process multiple tasks in parallel
 * const tasks = [
 *   addTask('fibonacci', { n: 5 }),
 *   addTask('fibonacci', { n: 8 }),
 *   addTask('fibonacci', { n: 12 })
 * ]
 * const results = await Promise.all(tasks)
 */
function addTask(task: string, data: any): Promise<TaskResult> {
  return new Promise((resolve, reject) => {
    if (!pool.initialized) {
      reject(new Error('Pool not initialized'))
      return
    }
    
    const job: Job = { 
      task,
      data, 
      resolve: (data: WorkerResponseData) => resolve(data as TaskResult), 
      reject 
    }
    
    const freeWorker = pool.workers.find(w => !w.busy)
    if (freeWorker) {
      runJob(freeWorker, job)
    } else {
      pool.queue.push(job)
    }
  })
}

/**
 * Get current pool statistics
 * @returns Object containing pool statistics
 * 
 * @example
 * const stats = getStats()
 * console.log(`Active jobs: ${stats.active}, Completed: ${stats.completed}`)
 */
export function getStats(): PoolStats {
  return {
    workers: pool.workers.length,
    active: pool.activeJobs,
    completed: pool.completedJobs,
    queued: pool.queue.length,
    workerStats: pool.workers.map(({ id, jobCount, busy }) => ({ 
      id, 
      jobs: jobCount, 
      busy 
    }))
  }
}

/**
 * Cleanup and terminate all workers in the pool
 * @returns Promise that resolves when cleanup is complete
 * 
 * @example
 * await cleanup()
 */
export async function cleanup(): Promise<void> {
  console.log('Cleaning up worker pool...')
  
  for (const worker of pool.workers) {
    await worker.worker.terminate()
  }
  
  pool.workers = []
  pool.queue = []
  pool.activeJobs = 0
  pool.completedJobs = 0
  pool.initialized = false
  
  console.log('Cleanup worker pool done')
}

/**
 * Demonstration function showing worker pool capabilities
 * @param tasks - Array of tasks to execute
 * @returns Promise that resolves with all results
 * 
 * @example
 * const tasks = [
 *   { task: 'fibonacci', data: { n: 10 } },
 *   { task: 'fibonacci', data: { n: 15 } }
 * ]
 * const results = await callWorker(tasks)
 * console.log(results) // Array of TaskResult objects
 */
export async function callWorker(tasks: TaskInput[]): Promise<TaskResult[]> {
  await initPool()
  
  try {
    console.log('Processing jobs...')
    const startTime = Date.now()
    
    const results = await Promise.all(
      tasks.map(({ task, data }) => addTask(task, data))
    )
    
    const duration = Date.now() - startTime
    console.log(`All jobs completed in ${duration}ms`)
    
    return results
  } catch (error) {
    console.error('Error:', error)
    await cleanup()
    throw error
  }
}
