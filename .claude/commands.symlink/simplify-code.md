---
description: Simplify existing code.
model: opus
---

Instructions to simplify code that was recently added or modified. 

# Standard Operating Procedure

1. Identify which revisions to analyze. If unsure stop and ask the user.
2. Generate the diff of those revisions
3. Make a plan.
4. Seek user approval.

# Best Practices

- Preserve functionality, never change what the code does, only how it does
  it. All original features, outputs, and behaviors must remain intact.
- Apply project standards. Use idiomatic patterns.
- Prioritize readable, explicit code over overly compact solutions. This is
  delicate balance that you have mastered.
- Enhance clarity by:
   - Reducing unnecessary complexity and nesting
   - Eliminating redundant code and unused abstractions
   - Improving readability through clear variable and function names
   - Consolidating related logic
   - Removing unnecessary comments that describe obvious code
   - Choose clarity over brevity - explicit code is often better than overly compact code
- Maintain balance by avoiding over-simplification that could:
   - Reduce code clarity or maintainability
   - Create overly clever solutions that are hard to understand
   - Combine too many concerns into single functions or components
   - Remove helpful abstractions that improve code organization
   - Prioritize "fewer lines" over readability (e.g., nested ternaries, dense one-liners)
   - Make the code harder to debug or extend
- Do not re-invent the wheel. Search the following for functionalities to reuse:
    - Existing codebase
    - Standard library
    - Third-party libraries
- MANDATORY: don't make any changes if the code is already meeting the above
  criteria.
