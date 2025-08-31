import { parentPort, workerData } from 'node:worker_threads'
import { tasks } from './tasks.ts'

/**
 * Worker message structure for incoming tasks
 */
export interface WorkerMessage {
  /** Task type to execute */
  task: string
  /** Task input data */
  data: any
}

/**
 * Worker response data structure for successful tasks
 */
export interface WorkerResponseData {
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
 * Worker response structure
 */
export interface WorkerResponse {
  /** Success response data */
  data?: WorkerResponseData
  /** Error message if task failed */
  error?: string
}

/**
 * Worker data structure passed when creating worker
 */
export interface WorkerInitData {
  /** Whether this is a worker thread */
  isWorker: boolean
  /** Worker ID */
  id: number
}

/**
 * Worker thread implementation for processing tasks
 * This code runs in separate worker threads, not the main thread
 * Listens for messages from main thread and processes tasks accordingly
 * 
 * @example
 * // This function is called automatically when worker starts
 * // Worker receives messages like: { task: 'fibonacci', data: { n: 10 } }
 * // Worker responds with: { data: { result: 55, workerId: 0, task: 'fibonacci', duration: 5 } }
 */
function startWorker(): void {
  if (!parentPort) {
    throw new Error('This script must be run as a worker thread')
  }

  parentPort.on('message', async (message: WorkerMessage) => {
    const startTime = Date.now()
    const { task, data } = message
    
    try {
      if (!tasks[task]) {
        throw new Error(`Unknown task: ${task}`)
      }
      
      const result = tasks[task](data)
      const duration = Date.now() - startTime
      
      const response: WorkerResponse = { 
        data: { 
          result, 
          workerId: (workerData as WorkerInitData).id,
          task,
          data,
          duration,
        } 
      }
      
      parentPort!.postMessage(response)
    } catch (error) {
      const response: WorkerResponse = { 
        error: (error as Error).message 
      }
      parentPort!.postMessage(response)
    }
  })
}

startWorker()
