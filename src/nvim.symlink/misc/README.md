# Misc.nvim ShowMe and Tour

`require('misc')` exposes lazy two-window annotations and guided code tours:

```lua
local misc = require 'misc'

misc.ShowMe('/absolute/path/to/example.lua', { 12, 18 }, 'Explain this range.', 'left')
misc.ClearShowMe 'left'
misc.ClearShowMe() -- clear both sides

misc.Tour({
  {
    left = {
      filename = '/absolute/path/to/before.lua',
      range = { 12, 18 },
      message = 'The input is normalized here.',
    },
    right = {
      filename = '/absolute/path/to/after.lua',
      range = { 20, 27 },
      message = 'The normalized value is consumed here.',
    },
  },
  {
    left = {
      filename = '/absolute/path/to/before.lua',
      range = { 30, 34 },
      message = 'This is the next left-only step.',
    },
  },
})
```

`ShowMe(filename, inclusive_1_based_range, message, side)` validates the requested
readable file, inclusive 1-based range, message, and `'left'` or `'right'` side before
changing the UI. The first valid ShowMe or Tour opens one owned presentation tab with
exactly two side-by-side normal editing windows; it works from nofile, floating,
one-window, and arbitrary split callers without changing their tabs, windows, buffers,
cursors, or views. Later ShowMe calls reuse that tab, compose its two sides, and focus
it. The requested file is loaded without reloading an already-open buffer.

Each side has an independent annotation, including when both windows show the same
buffer. The source range receives a background-only highlight and the plain-text message
is display-width wrapped beneath it. Each message row fills the target window's text
area (excluding gutters) and is repadded on resize. Standalone ShowMe installs frozen
quit and annotation keys, `<leader>tq` and `<leader>ta`. `ClearShowMe(side)` clears one
side and `ClearShowMe()` clears both, but keeps the presentation tab and its default
frozen mappings. A valid ShowMe interrupts a tour and becomes standalone; invalid calls
leave an existing presentation or tour untouched.

## Feedback

Each active report keeps one comment per highlighted file/range, shared across panes and
scenes showing that same range. Press `<leader>ta` in a highlighted pane to add or edit
its comment in the wrapped floating editor. Saved text is prefilled, with the cursor
ready to append. It starts in insert mode: Enter creates newlines and paragraphs. Press
Esc for normal mode, then Enter to save or `q` to cancel. Saving replaces that range's
comment instead of adding another. Blank submissions, cancellation, and closing the
editor leave any saved comment unchanged; ending or replacing the presentation discards
only its unfinished draft. The editor follows viewport resizing and never writes a
source file.

Saved comments appear below the agent explanation and before a Tour footer, and remain
visible when a scene is revisited. Each save commits the range, source excerpt, scene,
and side captured when that edit began; subsequent code changes do not rewrite saved
context. Programs perform the same add-or-replace operation without opening the editor:

```lua
local accepted = misc.AnnotateShowMe 'First paragraph.\n\nSecond paragraph.'
```

`ShowMe` and `Tour` return a string feedback report ID. Repeated standalone `ShowMe`
calls reuse their active report and frozen keys; a new Tour always starts a report with
a new ID. A report completes when its presentation ends, is replaced, or an active Tour
is cleared.

Reports are stored on disk, one JSON file per report, so they survive Neovim restarts
and crashes and can be read while the tour is still open:

```text
<stdpath('state')>/misc/reports/<report id>.json      # e.g. ~/.local/state/nvim/misc/reports/
```

The file is written when the report is created, on every saved comment, when the
presentation ends, and on acknowledge. Each write goes to a temporary dotfile in the same
directory and is then renamed over the target, so a reader never sees a partial file.
Besides the fields below, the file records `acknowledged`, `acknowledged_at`,
`created_at`, `updated_at` (epoch milliseconds) and the writer's `pid`; these are never
returned by the API. The disk is the source of truth for the two functions below. Live
presentation state (annotations, drafts, active report) stays in memory.

```lua
local reports = misc.GetTourComments()        -- pending reports with comments
local one = misc.GetTourComments(report_id)   -- optional non-destructive filter
local acknowledged = misc.AcknowledgeTourComments(report_id)
```

A report is *pending* when it has at least one saved comment and has not been
acknowledged. `GetTourComments` reads the directory, so any Neovim instance sees reports
created by another instance, including one that crashed. Its `status` is `"in_progress"`
while the tour or ShowMe is open (comments saved so far are included, and more may
follow) and `"completed"` once it ended. A crashed instance leaves its report
`"in_progress"` forever.

`AcknowledgeTourComments` works from any instance and after a restart. It **marks** the
file (`acknowledged = true`) rather than deleting it, so handled feedback stays on disk
for recovery and audit; acknowledged reports are no longer returned. It returns `true`
for a completed report (idempotent), and `false` for an unknown ID, a malformed ID, or a
report that is still `"in_progress"` (its owner may still add comments). Acknowledged
files are never pruned automatically; delete them by hand if desired.

`GetTourComments` always returns an array (including `[]` when empty), creates or
focuses no UI, and returns fresh decoded copies. Reads never acknowledge or remove
feedback. Both APIs reject a non-string report ID when supplied. Nothing is pushed
automatically.

The stable returned JSON-compatible schema is:

```json
[
  {
    "id": "tour-1234-5678-1",
    "kind": "tour",
    "status": "completed",            // or "in_progress" while the tour is open
    "ended_by": "finished",           // absent while "in_progress"
    "comments": [
      {
        "report_id": "tour-1234-5678-1",
        "kind": "tour",
        "step": 1,
        "side": "left",
        "filename": "/absolute/path/example.lua",
        "range": { "first": 12, "last": 18 },
        "message": "This range needs a follow-up.",
        "excerpt": "source snapshot when comment entry begins"
      }
    ]
  }
]
```

Completed reports and their comments are immutable. Reports without comments are not
returned as pending feedback. `ended_by` is only present once the report completed.

## Tour

`Tour(scenes, options)` immediately displays scene 1. Each scene has `left`, `right`, or
both entries; an entry has `filename`, `range = { first, last }`, and a plain-text
`message`. All scene files, ranges, options, and the owned presentation layout are
validated before an active tour is replaced. Files are resolved when the tour starts, so
later working-directory changes do not affect navigation.

Every active annotation includes a `Step i/N` footer with the previous, next/finish, and
quit keys. `TourNext()` advances both sides together and, on the last scene, closes only
the owned presentation tab. `TourPrev()` is a no-op on the first scene. `TourStop()`
also dismisses a standalone presentation. When these actions are invoked from another
tab, navigation reveals the presentation; finishing from another tab closes it without
stealing focus. Quitting from the presentation returns to its origin when it remains
available, otherwise Neovim keeps a fallback tab alive. Closing the owned tab manually
also clears its presentation state; a later request starts a fresh tab. Presented
buffers remain loaded even with `nohidden` or destructive `bufhidden` settings,
including when the owned tab is closed from another tab.

An omitted side clears only its annotation and leaves that window's displayed file and
viewport unchanged. This also means backwards navigation cannot show an annotation from
a future scene. If the owned tab's two-pane layout is manually changed, advancing or
replaying a scene reports that its presentation layout is no longer usable; quit and
final finish still dismiss the owned tab. Ordinary tabs are never repurposed or closed.

Normal-mode buffer-local mappings are installed in shown tour buffers only while the
presentation tab is current:

- `]t`: next
- `[t`: previous
- `<leader>tq`: quit
- `<leader>ta`: annotate the highlighted pane

Customize any of those with the optional `next`, `prev`, `stop`, and `annotate` keys:

```lua
misc.Tour(scenes, {
  next = ']c', prev = '[c', stop = '<leader>cq', annotate = '<leader>ca'
})
```

Keys must be distinct after Neovim keycode normalization (`<CR>`, `<Enter>`, and `<C-M>`
therefore collide). `<leader>` and `<localleader>` are expanded and frozen when `Tour`
starts; the footer shows those frozen keys. Existing buffer-local mappings (including
callback, expression, silent, script, and recursive behavior) are restored on TabLeave,
quit, stop, replacement, and manual presentation-tab close, then reinstalled on
TabEnter. Global mappings are never copied into or changed by the tour.

## Neovim Requirement

ShowMe and Tour were tested with Neovim 0.12.2 and require the experimental
`nvim__ns_set(..., { wins = { winid } })` API. They use one persistent namespace per
target window so virtual lines remain independent when both windows display the same
buffer. Neovim reports a clear Lua error if that API is unavailable.

`MiscShowMeBackground` defaults to only the resolved `CursorLine` `bg` and `ctermbg`; it
never copies foregrounds or styles and has no fallback palette. `MiscShowMeMessage`
defaults to a link to `DiagnosticVirtualTextInfo` for ShowMe explanations and Tour
footers.

On `ColorScheme`, an empty group or one still matching Misc's last normalized default is
refreshed. Any nonempty user or colorscheme definition of either group—including one
made with `default = true` before or after ShowMe/Tour—is an override and is retained.

## Tests

The tests launch real embedded Neovim instances and attach a line-grid UI:

```sh
uv run --with pynvim python3 src/nvim.symlink/misc/tests/test_showme.py
```
