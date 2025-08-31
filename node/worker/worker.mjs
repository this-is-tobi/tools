import { parentPort, workerData } from 'node:worker_threads'
import { tasks } from './tasks.mjs'

/**
 * @typedef {Object} WorkerMessage
 * @property {string} task - Task type to execute
 * @property {Object} data - Task input data
 */

/**
 * @typedef {Object} WorkerResponse
 * @property {Object} [data] - Success response data
 * @property {*} data.result - The computed result
 * @property {number} data.workerId - ID of worker that processed the task
 * @property {string} data.task - Task type that was executed
 * @property {Object} data.data - Original input data
 * @property {number} data.duration - Execution time in milliseconds
 * @property {string} [error] - Error message if task failed
 */

/**
 * Worker thread implementation for processing tasks
 * This code runs in separate worker threads, not the main thread
 * Listens for messages from main thread and processes tasks accordingly
 * @returns {void}
 * 
 * @example
 * // This function is called automatically when worker starts
 * // Worker receives messages like: { task: 'fibonacci', data: { n: 10 } }
 * // Worker responds with: { data: { result: 55, workerId: 0, task: 'fibonacci', duration: 5 } }
 */
function startWorker() {
  parentPort.on('message', async (message) => {
    const startTime = Date.now()
    const { task, data } = message
    try {
      if (!tasks[task]) {
        throw new Error(`Unknown task: ${task}`)
      }
      const result = tasks[task](data)
      const duration = Date.now() - startTime
      parentPort.postMessage({ 
        data: { 
          result, 
          workerId: workerData.id,
          task,
          data,
          duration,
        } 
      })
    } catch (error) {
      parentPort.postMessage({ error: error.message })
    }
  })
}

startWorker()
