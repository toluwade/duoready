# Contributing to DuoReady

Thanks for helping. DuoReady stays useful only if developers trust its findings, so a rule that is
precise matters more than a rule that catches everything.

## Development

```sh
swift build
swift test
swift run duoready scan Tests/DuoReadyIntegrationTests/Fixtures/SampleApp
```

## Reporting a false positive

False-positive reports are the most valuable issues you can file. Use the **False positive**
issue template and include the smallest code snippet that reproduces the finding.

## Adding a rule

1. **Propose it first.** Open an issue describing the pattern, why it causes layout problems, and
   one or more legitimate uses that resemble it.
2. **Pick the next free ID** (`DR003`, `DR004`, …). IDs are never reused.
3. **Implement `SwiftRule`** in `Sources/DuoReadyRules/<Category>/`. Use a `SyntaxVisitor` and
   report findings with `finding(at:in:message:)`. Rules must not read files, use the network, or
   know about output formats.
4. **Register it** in `Sources/DuoReadyRules/DefaultRules.swift`.
5. **Test four cases** in `Tests/DuoReadyRulesTests/`:
   - a clearly problematic example (flagged)
   - the corrected version (not flagged)
   - a legitimate exception that looks like the problem (not flagged)
   - an edge case: formatting, `#if` blocks, closures, optional chaining
6. **Document it** in `RULES.md` with a `## DRxxx` section that covers why, what is flagged, the
   fix and its limitations. A test fails if this section is missing.
7. **Update the golden test** in `Tests/DuoReadyIntegrationTests` if the fixture app should now
   produce new findings.

New rules start at `info` severity or with medium confidence until they have been run against
real projects.

## Code style

Follow the surrounding code. Keep rules small and declarative, and put shared syntax helpers in
`Sources/DuoReadyRules/Shared/`.
