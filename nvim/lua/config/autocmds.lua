-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Global theme (~/.config/themes): `theme set <id>` sends SIGUSR1 to every running nvim
vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = function()
    vim.schedule(function()
      if vim.g.colors_name == "theme" then
        vim.cmd.colorscheme("theme")
      end
    end)
  end,
})
