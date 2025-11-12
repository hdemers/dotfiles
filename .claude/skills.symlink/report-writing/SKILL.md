---
name: report-writing
description: Use this still to write reports.
---

This skill allows you to write Markdown reports.

# Standard Operating Procedure

1. Reports are always written to a subfolder under /home/hdemers/Dropbox/Documents/Obsidian/Grubhub/Repositories/.
2. The subdirectory's name shall match the current repository.
3. If there are no current repository, STOP and ASK the user where to store the report.
4. If multiple reports are being written as part of a given session, you shall
   reference the other documents, when applicable, using the markdown notation
      [Link Text](relative path to the file).
5. If this is a failure report (e.g. Azkaban run failures), write the report
   under subdirectory _Failure Reports_, which is itself under this repo's name (see 2 above).
