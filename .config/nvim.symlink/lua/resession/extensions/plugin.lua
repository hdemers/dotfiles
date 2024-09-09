local M = {}

---Get the saved data for this extension
---@param opts resession.Extension.OnSaveOpts Information about the session being saved
---@return any
M.on_save = function(opts)
  return {
    colorscheme = vim.g.colors_name,
  }
end

---Restore the extension state
---@param data table The value returned from on_save
M.on_post_load = function(data)
  -- This is run after the buffers, windows, and tabs are restored
  vim.cmd('colorscheme ' .. data.colorscheme)
end

return M
