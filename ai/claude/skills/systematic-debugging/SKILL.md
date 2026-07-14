---
name: systematic-debugging
description: Structured root-cause debugging workflow for bugs that resist a quick fix — reproduce, isolate, then test one hypothesis at a time instead of shotgunning changes. Use when asked to debug, investigate, or root-cause an issue, or when the same symptom keeps coming back after a patch.
---

# Systematic Debugging

Quick fixes that don't hold are almost always caused by skipping a step below, not by the bug being unusually hard. Work the steps in order; don't jump to a fix before step 3.

## 1. Reproduce reliably first

- Find the smallest input/action that triggers the bug every time. A bug you can't reproduce on demand can't be verified as fixed.
- If it's intermittent, capture the conditions that vary between runs that succeed and runs that fail (timing, ordering, state, environment) before doing anything else.

## 2. Read the actual failure, not your assumption of it

- Read the full error/stack trace, not just the top line — the real fault is often several frames away from where it surfaced.
- Check what the code actually does at the failure point (via the debugger, logs, or a print/assert), not what you expect it to do. Most wrong fixes come from an untested assumption about current behavior.

## 3. Isolate with a binary search

- Bisect over whatever axis is cheapest: commits (`git bisect`), code paths (comment out / short-circuit sections), inputs (shrink the reproduction case), or layers (is it the data, the logic, or the caller?).
- Narrow to the smallest unit that still reproduces the bug before forming a hypothesis about *why*.

## 4. Form one hypothesis, then test only that one

- State the specific mechanism you think is responsible, in a sentence you could be wrong about.
- Test that hypothesis directly (add an assertion, log a value, write a failing test) *before* changing behavior. If you change code to "see if it helps," you've stopped debugging and started guessing.
- If the hypothesis is wrong, discard the change completely and form the next one — don't leave it in "just in case."

## 5. Fix the root cause, not the symptom

- Prefer the fix that makes the invalid state impossible over the one that catches it after the fact (validation at the boundary vs. a null check sprinkled at every call site).
- If the real fix is large, it's fine to ship a narrow guard as a stopgap — but say so explicitly rather than presenting it as the root-cause fix.

## 6. Lock it in

- Add a regression test that fails without your fix and passes with it. If the bug had no test coverage, that's the actual root cause of why it shipped.
- Only note the underlying mechanism in a comment if it's genuinely non-obvious (a race, a platform quirk, an upstream bug) — don't narrate the fix itself.

## Anti-patterns

- **Shotgunning**: changing several suspected causes at once. When it "works," you don't know which change mattered, so the next similar bug takes just as long.
- **Symptom-patching**: wrapping the crash site in a try/catch or null check without understanding why the invalid state occurred.
- **Skipping reproduction**: debugging from the stack trace alone, against a mental model of the code instead of its actual current behavior.
- **Silent hypothesis-testing**: editing code to test a theory and leaving the edit in place regardless of whether it confirmed the theory.
