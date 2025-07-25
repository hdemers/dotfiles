# Create a ticket from plan

Create a ticket from the plan using the `ticket` mcp tool. Be as detailed as
possible for Claude Code to execute that ticket at a later date.

## Usage:
- `/create-ticket <parameters>` - Create a new ticket

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
3. Use Markdown formatting.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If the user has provided an epic, a sprint, a number of points, etc., use
   those, otherwise leave blank.
7. The description of the ticket is the plan made for this work.
8. Be as detailed as possible for Claude Code to execute this at a later date.
