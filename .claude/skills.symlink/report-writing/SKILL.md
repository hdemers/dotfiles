---
name: report-writing
description: Use this still to write reports.
allowed-tools: Bash(awk:*)
---

This skill allows you to write Markdown reports.

# Standard Operating Procedure

1. Write report under
   /home/hdemers/Dropbox/Claude/<category>/!`awk 'BEGIN{print (ENVIRON["PWD"] ~ /[Gg]rubhub/ ? "grubhub" : "personal")}'`/!`awk 'BEGIN{n=split(ENVIRON["PWD"],a,"/"); print a[n]}'`/
   where <category> is either 'brainstorm' or 'failure'.
2. Report filenames shall be kebab-case with the following pattern: YYYY-MM-DD-<descriptive-name>.
3. If multiple reports are being written as part of a given session, you shall
   reference the other documents, when applicable, using the markdown notation
   [Link Text](relative path to the file).
4. User can comment on the report by highlighting words and referencing a comment found at the end:

   ```
      ==highlighted text==[^1]

      [^1] Comment on highlighted text.
   ```

5. If user mentions "comments added" or something to that effec, it means the
   user has added comments to the report. Read the file back and answer
   those comments live, do not modify the file until user says so.
