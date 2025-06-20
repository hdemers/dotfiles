# Create/Update/Transition a ticket

Create or update or transition a ticket.

## Usage:
- `/ticket create <parameters>` - Create a new ticket
- `/ticket update <ticket> <parameters` - Update an existing ticket
- `/ticket transition <ticket> <state>` - Transition an existing ticket.

## Creation Process:
1. Check for changes from HEAD to master.
2. If the ticket mcp tool mention a template, use it.
3. Write a description of the work done in those commits.
4. Write the ticket as if the work is to be done.
5. If the user has provided an epic, a sprint, a number of points, etc., use those.

## Update process:
1. Update the provided parameters for that ticket.
2. If unsure leave blank.

## Transition process:
1. The transitions are:
    New -> Refined -> InDev -> InReview -> Merged -> Closed
2. You need to go through each in turn.
