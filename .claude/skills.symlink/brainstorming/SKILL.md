---
name: brainstorming
description: Proactively use when brainstorming potential solutions to difficult problems.
tools: 
---

## Standard Operating Procedure

### Phase 1: Low-Handing Fruits

1. Generate 4-5 solutions
2. Do not assume backward compatibility, we want to explore the full space of
   solutions.
3. Follow the best practices below
4. STOP and ASK: validate solutions with user. DO NOT move to phase 2.

### Phase 2: Advanced Solutions

1. Only engage in phase 2 if user wants more advances solutions.
2. Do not assume backward compatibility, we want to explore the full space of
   solutions.
3. Launch 4-5 subagents each tasked with a slightly different possible solution.
4. Subagent tasks:
     1. Each subagents shall test their proposed solution with a throw-away
        script demonstrating the validity of their approach.
     2. Subagents shall not stop until they have a valid solution.
     3. Subagents shall follow the best practices found below.
5. Summarize and rank each solutions
6. STOP and ASK: validate solutions with user. DO NOT move to phase 3.

### Phase 3: Randomized Search Over Solution Space

1. Only engage in phase 3 if user wants more solutions.
2. Do not assume backward compatibility, we want to explore the full space of
   solutions.
3. Launch 4-5 subagents each tasked with the exact same ask/prompt.
4. Subagent tasks:
     1. Each subagents shall test their proposed solution with a throw-away
        script demonstrating the validity of their approach.
     2. Subagents shall not stop until they have a valid solution.
     3. Subagents shall follow the best practices found below.
5. Summarize and rank each solutions
6. STOP and ASK: validate solutions with user. DO NOT move to phase 3.

## Best Practices

1. Implementing a solution is not the goal, rather writing a report is.
2. Use the report-writing skill.
3. When evolving a solution, amend the existing report instead of writing a new one.
4. Complex solutions should be validated with throw-away scripts.
5. Throw-away scripts shall be written to subdirectory ,scratch. The comma
   prefix is not a typo.
6. We do not care about implementation complexity.
7. We do not care about level-of-effort.
8. Reports shall have the following structure:
   
   ```markdown
    # Title

    **Date**:
    **Repository**:

    ## Problem/Goal Statement

    ### Constraints
    
    ## Solutions

    ### Solution 1

    Describe the solution works with code examples. Provide examples of how it
    would be used in practices.

    **Advantages**:
    - First advantage
    - Second advantage

    **Disadvantages**:
    - First disadvantage
    - Second disadvantage


    ### Solution 2


    ## Recommendation

    Provide a recommendation with a short explanation of why. We do not care
    about recommendation matrices.
   ```
