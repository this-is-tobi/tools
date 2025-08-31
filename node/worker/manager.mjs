import { availableParallelism } from 'node:os'
import { Worker } from 'node:worker_threads'

/**
 * @typedef {Object} WorkerInstance
 * @property {number} id - Worker unique identifier
 * @property {boolean} busy - Whether worker is currently processing a task
 * @property {number} jobCount - Number of jobs processed by this worker
 * @property {Function} currentResolve - Promise resolve function for current job
 * @property {Function} currentReject - Promise reject function for current job
 */

/**
 * @typedef {Object} Job
 * @property {string} task - Task type ('sum' or 'fibonacci')
 * @property {Object} data - Task input data
 * @property {Function} resolve - Promise resolve function
 * @property {Function} reject - Promise reject function
 */

/**
 * @typedef {Object} TaskResult
 * @property {*} result - The computed result
 * @property {number} workerId - ID of worker that processed the task
 * @property {string} task - Task type that was executed
 * @property {number} duration - Execution time in milliseconds
 */

/**
 * @typedef {Object} PoolStats
 * @property {number} workers - Total number of workers in pool
 * @property {number} active - Number of currently active jobs
 * @property {number} completed - Total number of completed jobs
 * @property {number} queued - Number of jobs waiting in queue
 * @property {Array<{id: number, busy: boolean, jobs: number}>} workerStats - Individual worker statistics
 */

/**
 * Simple worker pool state management
 * @type {Object}
 * @property {WorkerInstance[]} workers - Array of worker instances
 * @property {Job[]} queue - Queue of pending jobs
 * @property {number} activeJobs - Count of currently active jobs
 * @property {number} completedJobs - Count of completed jobs
 * @property {boolean} initialized - Whether pool has been initialized
 */
const pool = {
  workers: [],
  queue: [],
  activeJobs: 0,
  completedJobs: 0,
  initialized: false
}

/**
 * Initialize worker pool with specified number of workers
 * @param {number} [size=2] - Number of workers to create
 * @returns {Promise<void>} Resolves when pool is initialized
 * 
 * @example
 * await initPool(4) // Create pool with 4 workers
 */
async function initPool(size = availableParallelism()) {
  if (pool.initialized) {
    console.log('Worker pool already initialized')
    return
  }
  console.log(`Intializing pool with ${size} workers...`)
  for (let i = 0; i < size; i++) {
    const worker = new Worker(new URL('./worker.mjs', import.meta.url), {
      workerData: { isWorker: true, id: i }
    })
    worker.id = i
    worker.busy = false
    worker.jobCount = 0
    worker.on('message', (result) => handleResult(worker, result))
    worker.on('error', (error) => console.error(`Worker ${i} error:`, error))
    pool.workers.push(worker)
  }
  pool.initialized = true
  console.log('Worker pool ready')
}

/**
 * Handle result message from worker
 * @param {WorkerInstance} worker - Worker that sent the result
 * @param {Object} result - Result object from worker
 * @param {*} [result.data] - Success result data
 * @param {string} [result.error] - Error message if task failed
 * @returns {void}
 * 
 * @example
 * // Called automatically when worker sends message
 * worker.on('message', (result) => handleResult(worker, result))
 */
function handleResult(worker, result) {
  worker.busy = false
  worker.jobCount++
  pool.activeJobs--
  if (result.error) {
    worker.currentReject(new Error(result.error))
  } else {
    pool.completedJobs++
    worker.currentResolve(result.data)
  }
  processQueue()
}

/**
 * Process next job in queue if workers are available
 * @returns {void}
 * 
 * @example
 * // Called automatically after job completion
 * processQueue()
 */
function processQueue() {
  if (pool.queue.length === 0) return
  const freeWorker = pool.workers.find(w => !w.busy)
  if (!freeWorker) return
  const job = pool.queue.shift()
  runJob(freeWorker, job)
}

/**
 * Execute job on specified worker
 * @param {WorkerInstance} worker - Worker to execute job on
 * @param {Job} job - Job to execute
 * @returns {void}
 * 
 * @example
 * const job = { task: 'fibonacci', data: { n: 10 }, resolve, reject }
 * runJob(availableWorker, job)
 */
function runJob(worker, job) {
  const { task, data } = job
  worker.busy = true
  worker.currentResolve = job.resolve
  worker.currentReject = job.reject
  pool.activeJobs++
  worker.postMessage({
    task,
    data,
  })
}

/**
 * Add task to worker pool for execution
 * @param {string} task - Task to execute in worker
 * @param {Object} data - Task input data
 * @returns {Promise<TaskResult>} Promise that resolves with task result
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
function addTask(task, data) {
  return new Promise((resolve, reject) => {
    if (!pool.initialized) {
      reject(new Error('Pool not initialized'))
      return
    }
    const job = { 
      task,
      data, 
      resolve, 
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
 * @returns {PoolStats} Object containing pool statistics
 * 
 * @example
 * const stats = getStats()
 * console.log(`Active jobs: ${stats.active}, Completed: ${stats.completed}`)
 */
function getStats() {
  return {
    workers: pool.workers.length,
    active: pool.activeJobs,
    completed: pool.completedJobs,
    queued: pool.queue.length,
    workerStats: pool.workers.map(({ id, jobCount, busy }) => ({ id, jobCount, busy }))
  }
}

/**
 * Cleanup and terminate all workers in the pool
 * @returns {Promise<void>} Resolves when cleanup is complete
 * 
 * @example
 * await cleanup()
 */
async function cleanup() {
  console.log('Cleaning up worker pool...')
  for (const worker of pool.workers) {
    await worker.terminate()
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
 * @param {Array<{task: string, data: Object}>} tasks - Array of tasks to execute
 * @returns {Promise<TaskResult[]>} Resolves when demo is complete with all results
 * 
 * @example
 * const tasks = [
 *   { task: 'fibonacci', data: { n: 10 } },
 *   { task: 'fibonacci', data: { n: 15 } }
 * ]
 * const results = await callWorker(tasks)
 * console.log(results) // Array of TaskResult objects
 */
export async function callWorker(tasks) {
  await initPool()
  try {
    console.log('Processing jobs...')
    const startTime = Date.now()
    const results = await Promise.all(tasks.map(({ task, data }) => addTask(task, data)))
    const duration = Date.now() - startTime
    console.log(`All job completed in ${duration}ms`)
    console.log('Worker Stats:\n', JSON.stringify(getStats(), null, 2))
    return results
  } catch (error) {
    console.error('Error:', error)
  } finally {
    await cleanup()
  }
}
