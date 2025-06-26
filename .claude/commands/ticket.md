# Create/Update/Transition a ticket

Create or update or transition a ticket using the `ticket` mcp tool.

## Usage:
- `/ticket create <parameters>` - Create a new ticket
- `/ticket update <ticket> <parameters` - Update an existing ticket
- `/ticket transition <ticket> <state>` - Transition an existing ticket.

### Parameters
- Epic: The epic of that ticket, if not specified, leave blank.
- Sprint: active sprint if not specified
- Assignee: if not specified: me
- Point: the number of points, if not specified, leave blank.
- Description: if the user does not provide a description, observed the changes
  made on the current branch and use that as the basis for the description.

## Template:
{*}Brief description{*}:

* Work needed

{*}Expected work product{*}:

* Document? Metric? Code/Repo?

{*}Dependencies{*}:

* Meetings? Another ticket? Peer review?

{*}Any background context you want to provide{*}:

* Detail that supports work needed

## Creation Process:
1. Use the template.
2. Use future tense.
3. Use Markdown formatting where appropriate.
4. Write the ticket as if the work is to be done.
5. The summary of the ticket should be prefixed with `[repo-name]`.
6. If the user has provided an epic, a sprint, a number of points, etc., use those.

## Update process:
1. Update the provided parameters for that ticket.
2. If unsure leave blank.

## Transition process:
1. The transitions are:
    New -> Refined -> In Dev -> In Review -> Merged -> Closed
2. You need to go through each in turn.
