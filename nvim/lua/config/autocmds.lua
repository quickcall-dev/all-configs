-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Image buffers: snacks.image injects render placeholders -> buffer looks "modified"
-- and nvim nags to save on close. Images are read-only views; never mark modified.
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
  callback = function(e)
    if vim.bo[e.buf].filetype == "image" then
      vim.bo[e.buf].modified = false
    end
  end,
})
