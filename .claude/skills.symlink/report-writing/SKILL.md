---
name: report-writing
description: Use this still to write reports.
---

This skill allows you to write Markdown reports.

# Standard Operating Procedure

1. Reports are always written to a subfolder under
   /home/hdemers/Dropbox/Documents/Obsidian/Grubhub/Repositories/.
2. The subdirectory's name shall match the current repository.
3. If there are no current repository, STOP and ASK the user where to store the report.
4. If multiple reports are being written as part of a given session, you shall
   reference the other documents, when applicable, using the markdown notation
      [Link Text](relative path to the file).
5. If this is a failure report (e.g. Azkaban run failures), write the report
   under subdirectory _Failure Reports_, which is itself under this repo's name (see 2 above).
6. User can comment on the report by highlighting words and referencing a comment found at the end:
      ==highlighted text==[^1]

      [^1] Comment on highlighted text.
7. If user mentions "comments added" or something to that effec, it means the
   user has added comments to the report. Read the file back and answer
   those comments live, do not modify the file until user says oo.
