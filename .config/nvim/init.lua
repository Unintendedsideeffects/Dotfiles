-- bootstrap lazy
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- basic settings
vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true

-- plugins
require("lazy").setup({
    "nvim-telescope/telescope.nvim",
    "nvim-treesitter/nvim-treesitter",
    "VonHeikemen/lsp-zero.nvim",
    "folke/which-key.nvim",
    -- add more here
})
