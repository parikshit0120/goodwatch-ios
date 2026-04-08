# Swift Concurrency Agent Skill

## Core Purpose
The skill addresses: data races, callback-to-async/await conversion, actor isolation patterns, Sendable conformance, and Swift 6 migration guidance.

## Key Activation Triggers
Use this skill when developers mention: async/await, actors, tasks, Swift Concurrency patterns, thread safety issues, closure refactoring, @MainActor, Sendable, actor isolation, or concurrency linter warnings.

## Fast Path Protocol
Before proposing fixes:

1. **Analyze project configuration** – Examine Package.swift or .pbxproj for language mode, strict concurrency level, default isolation, and upcoming features
2. **Identify exact diagnostics** – Capture the precise compiler message and affected symbol
3. **Map isolation boundaries** – Determine @MainActor, custom actor, instance isolation, or nonisolated context
4. **Verify intent** – Confirm UI-bound versus background work designation

## Critical Guardrails
- Never blanket-apply @MainActor without justification
- Prefer structured concurrency; use Task.detached only with documented rationale
- Any unsafe escape hatches require safety invariants and removal plans
- Pursue smallest safe changes without architectural refactoring
- Reference materials support learning, not primary guidance

## Diagnostic Routing
The skill maps eight common diagnostics (Main actor isolation violations, protocol conformance failures, Sendable issues, etc.) to specific reference documents and smallest-safe-fix approaches.

## Reference Architecture
Fifteen specialized guides cover: async/await basics, task lifecycle, actor patterns, Sendable conformance, threading models, async sequences, algorithms, testing, performance, memory management, Core Data patterns, migration strategies, and linting rules.

## Swift 6 Migration Validation
Implement iterative cycles: Build → Fix (one category) → Rebuild → Test → Proceed only after complete resolution per file/module.
