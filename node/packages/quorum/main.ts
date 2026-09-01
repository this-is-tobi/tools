import { readFile } from 'node:fs/promises'
import { roleConfig } from './client.ts'
import { runQuorum } from './pipeline.ts'

/**
 * CLI entry point. Reads a diff from the path given as the first argument,
 * or from stdin when no argument is given.
 *
 * @example
 * // bun run quorum ./my.diff
 * // git diff origin/main...HEAD | bun run quorum
 */
async function readDiff(): Promise<string> {
  const path = process.argv[2]
  if (path) return readFile(path, 'utf8')

  const chunks: Buffer[] = []
  for await (const chunk of process.stdin) {
    chunks.push(chunk as Buffer)
  }
  return Buffer.concat(chunks).toString('utf8')
}

async function main(): Promise<void> {
  const diff = await readDiff()

  const research = roleConfig('RESEARCH')
  console.error(`Research (${research.model} @ ${research.baseUrl})...`)

  const voter = roleConfig('VOTER')
  console.error(`Panel will use ${voter.model} @ ${voter.baseUrl}`)

  const result = await runQuorum(diff, (message) => console.error(message))
  console.log(JSON.stringify(result, null, 2))

  if (result.kept.some((v) => v.confidence === 'high')) {
    process.exitCode = 1
  }
}

main().catch((error: Error) => {
  console.error(`Error: ${error.message}`)
  process.exitCode = 1
})
