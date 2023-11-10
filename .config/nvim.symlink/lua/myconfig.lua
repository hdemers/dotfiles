require("coverage").setup({
  highlights = {
    covered = { fg = "#2aa198" },   -- supports style, fg, bg, sp (see :h highlight-gui)
    uncovered = { fg = "#dc322f" },
  },
  auto_reload = true,
})
