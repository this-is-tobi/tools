import { chatJSON, UNTRUSTED_CONTENT_NOTICE } from './client.ts'
import type { Finding, Lens, LensVote, QuorumResult, Verdict, Vote } from './types.ts'

/**
 * The three fixed, orthogonal angles every panel vote is judged from. Three
 * is not an arbitrary round number: self-consistency research shows most of
 * the achievable gain from repeated sampling arrives by roughly five to ten
 * samples on a capable model, and running votes in parallel has a real
 * latency cost - three independent, non-debating, differently-angled votes
 * is close to the cost-effective floor, not a placeholder for "more agents
 * later".
 */
export const LENSES: readonly Lens[] = [
  {
    angle: 'reachability',
    question: 'Is this sink actually reachable from untrusted input in normal flow - not just syntactically present?',
  },
  {
    angle: 'impact',
    question: 'If reached, is the impact real - not just bad-looking code?',
  },
  {
    angle: 'defenses',
    question: 'Do existing checks elsewhere already neutralize this?',
  },
]

/**
 * Ask the research role to propose candidate findings in a diff.
 *
 * @example
 * const candidates = await research(diffText)
 */
export async function research(diff: string): Promise<Finding[]> {
  const shape = '{"findings":[{"file":string,"line":number,"category":string,"sink":string,"summary":string}]}'
  const prompt = [
    'Review this diff for security vulnerabilities. For each candidate, cite the exact',
    'file and line, quote the sink, name a category/CWE, and summarize why it looks wrong.',
    `Respond with ONLY JSON matching: ${shape}`,
    '',
    UNTRUSTED_CONTENT_NOTICE,
    '',
    '--- diff ---',
    diff,
  ].join('\n')

  const { findings } = await chatJSON<{ findings: Finding[] }>('RESEARCH', prompt)
  return findings ?? []
}

/**
 * Drop candidates that independent lenses (once there is more than one) or
 * repeated runs rediscovered at the same location - plain code, not a
 * model, same as the quorum tally below.
 *
 * @example
 * dedup([a, b, a]) // -> [a, b], keyed by file:line:category
 */
export function dedup(findings: Finding[]): Finding[] {
  const seen = new Set<string>()
  return findings.filter((finding) => {
    const key = `${finding.file}:${finding.line}:${finding.category}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

/**
 * Cast one voter's ballot on one finding, from one fixed lens. The voter
 * never sees the other two votes or their reasoning - independence is the
 * point, not an oversight. Letting verifiers see each other's reasoning
 * measurably converges results toward consensus rather than correctness.
 */
async function vote(finding: Finding, lens: Lens): Promise<LensVote> {
  const shape = '{"keep":boolean,"reasoning":string}'
  const prompt = [
    `One vote in a 3-voter panel - you do not see the other votes. Refutation angle: ${lens.angle}.`,
    lens.question,
    '',
    `Finding: ${finding.file}:${finding.line} [${finding.category}]`,
    `Sink: ${finding.sink}`,
    `Why flagged: ${finding.summary}`,
    '',
    `Default keep=false unless genuinely convinced. Respond with ONLY JSON matching: ${shape}`,
    '',
    UNTRUSTED_CONTENT_NOTICE,
  ].join('\n')

  try {
    const result = await chatJSON<Vote>('VOTER', prompt)
    return { angle: lens.angle, vote: result, error: null }
  } catch (error) {
    return { angle: lens.angle, vote: null, error: (error as Error).message }
  }
}

/**
 * Run the independent 3-voter panel on one finding and compute the quorum
 * verdict. The keep/discard decision and the confidence ceiling are
 * ordinary arithmetic here, not something any voter's self-reported
 * confidence gets to override: verifiers are measurably worse at judging
 * their own confidence than proposers are, so confidence is derived from
 * the vote split instead - unanimous 3/3 is a ceiling of 'high', a 2/3
 * split is capped at 'medium' no matter how certain any one voter sounded.
 *
 * @example
 * const verdict = await panel(finding)
 * if (verdict.confidence) console.log(`kept: ${verdict.confidence}`)
 */
export async function panel(finding: Finding): Promise<Verdict> {
  const votes = await Promise.all(LENSES.map((lens) => vote(finding, lens)))
  const keptVotes = votes.filter((v) => v.vote?.keep).length
  const confidence = keptVotes === 3 ? 'high' : keptVotes === 2 ? 'medium' : undefined
  return { ...finding, keptVotes, confidence, votes }
}

/**
 * Full pipeline: find candidates in a diff, then panel-verify each
 * independently before reporting.
 *
 * @example
 * const { kept, discarded } = await runQuorum(diffText)
 * console.log(`${kept.length} kept, ${discarded.length} discarded by panel`)
 */
export async function runQuorum(diff: string, onProgress?: (message: string) => void): Promise<QuorumResult> {
  const log = onProgress ?? (() => {})

  const candidates = dedup(await research(diff))
  log(`${candidates.length} candidate(s) after dedup`)

  const verdicts = await Promise.all(candidates.map(panel))
  const kept = verdicts.filter((v) => v.confidence)
  const discarded = verdicts.filter((v) => !v.confidence)
  log(`${kept.length} kept, ${discarded.length} discarded by panel`)

  return { kept, discarded }
}
