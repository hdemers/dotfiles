# Create/Update/Transition a ticket

Create or update or transition a ticket using the `ticket` mcp tool.

Note: this is a Jujutsu repo.

## Usage:
- `/ticket create <parameters>` - Create a new ticket
- `/ticket update <ticket> <parameters>` - Update an existing ticket
- `/ticket transition <ticket> <state>` - Transition an existing ticket.

## Template:
{*}Brief description{*}:

* Work needed

{*}Expected work product{*}:

* Document? Metric? Code/Repo?

{*}Dependencies{*}:

* Meetings? Another ticket? Peer review?

{*}Any background context you want to provide{*}:

* Detail that supports work needed

## Create process:
1. Use the template.
2. Use future tense.
3. Use Markdown formatting where appropriate.
4. Write the ticket as if the work is to be done.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If the user has provided an epic, a sprint, a number of points, etc., use those.
7. If the user has NOT provided a parameter, leave blank. Do NOT guess.
8. Read the commit messages:
   - Command: `jj log -r "trunk()..<branch>" -T description --no-graph`
9. Understand the changes by looking at the diff:
   - Command: `jj diff --git -r "trunk()..<branch>"`
10. Use the messages and the diffs as the basis for the description of the ticket.
11. Have the user review the ticket.
12. Create the ticket.

## Update process:
1. Update the provided parameters for that ticket.
2. If unsure leave blank.

## Transition process:
1. The transitions are:
    New -> Refined -> In Dev -> In Review -> Merged -> Closed
2. You need to go through each in turn.
