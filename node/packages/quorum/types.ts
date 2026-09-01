/**
 * Shared types for the Quorum security-review pipeline.
 *
 * @see ../../README.md for the module overview and usage.
 */

/**
 * Which side of the pipeline a model call belongs to: the finder that reads
 * a diff and proposes candidates, or a voter that independently judges one
 * candidate from a single fixed angle.
 */
export type Role = 'RESEARCH' | 'VOTER'

/**
 * Resolved connection settings for one role. VOTER falls back to the
 * RESEARCH_* env vars when its own are unset, so a single-backend setup only
 * needs to configure RESEARCH_*.
 */
export interface RoleConfig {
  /** Base URL of an OpenAI-compatible endpoint, e.g. http://localhost:11434/v1 for Ollama. */
  baseUrl: string
  /** Bearer token. Use any placeholder for endpoints that don't require auth. */
  apiKey: string
  /** Model name/tag as the endpoint expects it, e.g. 'qwen3.6:27b' or 'gpt-5.4'. */
  model: string
}

/**
 * A candidate issue proposed by the research role, before panel review.
 */
export interface Finding {
  file: string
  line: number
  category: string
  /** The exact offending code, quoted verbatim from the diff. */
  sink: string
  summary: string
}

/**
 * One voter's independent judgment on a single finding.
 */
export interface Vote {
  keep: boolean
  reasoning: string
}

/** One of the three fixed, orthogonal angles a voter is assigned. */
export interface Lens {
  angle: 'reachability' | 'impact' | 'defenses'
  question: string
}

/** One lens's vote, or the error if that call failed. */
export interface LensVote {
  angle: Lens['angle']
  vote: Vote | null
  error: string | null
}

/**
 * A finding after the panel has voted on it. `confidence` is derived from
 * the vote split, never self-reported by a model: 3/3 -> 'high', 2/3 ->
 * 'medium', anything else -> discarded (confidence undefined).
 */
export interface Verdict extends Finding {
  keptVotes: number
  confidence?: 'high' | 'medium'
  votes: LensVote[]
}

/** Final pipeline output. */
export interface QuorumResult {
  kept: Verdict[]
  discarded: Verdict[]
}
