local M = {}

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  return {
    colorscheme = vim.g.colors_name,
    -- Needed to have the material colorscheme correctly set its style, cf. 'marko-cerovac/material.nvim',
    material_style = vim.g.material_style,
    -- Needed to have the kanagawa colorscheme correctly set its theme, cf. 'rebelot/kanagawa.vim',
    kanagawa_theme = require('kanagawa')._CURRENT_THEME,
  }
end

---Restore the extension state
---@param data table The value returned from on_save
M.on_post_load = function(data)
  -- This is run after the buffers, windows, and tabs are restored
  -- Needed to have the material colorscheme correctly set its style, cf. 'marko-cerovac/material.nvim',
  vim.g.material_style = data.material_style

  if data.colorscheme == 'kanagawa' then
    require('kanagawa').load(data.kanagawa_theme)
  else
    vim.cmd('colorscheme ' .. data.colorscheme)
    vim.defer_fn(function()
      vim.cmd('colorscheme ' .. data.colorscheme)
    end, 1000) -- Delay in milliseconds
  end
end

return M
