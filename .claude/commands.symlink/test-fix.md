# Unit Test Fix

Unit test fixing workflow.

## Usage
- `/test-fix <test_file>`

## Process:

@context-prime.md

## Plan
1. Run the failing test file.
2. Read the unit test file.
3. Read the corresponding code file.
4. Understand the issue.
5. Do NOT plan on modifying the code file, only the test file.
5. Propose plan to user for approval.

## Fix Process
1. Implement the plan.
2. Re-run the test file.
3. Do not stop until all tests from test file are passing.
4. Do NOT modify the corresponding code file.

## Best Practices:
- Keep tests simple.
- Re-use existing test patterns.
