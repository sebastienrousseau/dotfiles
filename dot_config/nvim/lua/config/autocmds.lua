-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- Check if we need to reload the file when it changed
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  command = "checktime",
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
})

-- Resize splits if window got resized
vim.api.nvim_create_autocmd({ "VimResized" }, {
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Go to last loc when opening a buffer
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close some filetypes with <q>
vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "PlenaryTestPopup",
    "help",
    "lspinfo",
    "man",
    "notify",
    "qf",
    "spectre_panel",
    "startuptime",
    "tsplayground",
    "neotest-output",
    "checkhealth",
    "neotest-summary",
    "neotest-output-panel",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Auto create dir when saving a file, in case some intermediate directory does not exist
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  callback = function(event)
    if event.match:match("^%w%w+://") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Theme hot-reload: clear cached modules and reapply colorscheme on LazyReload.
-- Prevents stale theme state when dot-theme-sync sends a colorscheme change.
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyReload",
  callback = function()
    local theme = vim.env.DOTFILES_THEME or "macos-monterey-dark"
    -- Clear cached theme modules so setup() runs fresh
    for name, _ in pairs(package.loaded) do
      if
        name:match("^catppuccin")
        or name:match("^tokyonight")
        or name:match("^kanagawa")
        or name:match("^gruvbox")
        or name:match("^rose%-pine")
        or name:match("^solarized")
        or name:match("^onedark")
        or name:match("^nord")
        or name:match("^dracula")
        or name:match("^everforest")
      then
        package.loaded[name] = nil
      end
    end
    -- Defer to let lazy.nvim finish its reload cycle
    vim.defer_fn(function()
      local cs = theme:match("^catppuccin") and "catppuccin" or theme:match("^tokyonight") and theme or theme
      pcall(vim.cmd.colorscheme, cs)
    end, 5)
  end,
})

-- Cursorline only on focused window
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
  callback = function()
    vim.wo.cursorline = true
  end,
})
vim.api.nvim_create_autocmd({ "WinLeave" }, {
  callback = function()
    vim.wo.cursorline = false
  end,
})
