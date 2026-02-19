local map = vim.keymap.set

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move Lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

-- Buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clean hlsearch" })

-- Save file
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save file" })

-- Better indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Lazy
map("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })

-- Quick access (User Customizations)
map("n", "<leader>w", ":w<CR>", { desc = "Save file" })
map("n", "<leader>q", ":q<CR>", { desc = "Quit" })

-- Python specific
map("n", "<leader>pr", ":w<CR>:!python3 %<CR>", { desc = "Run Python file" })
map("n", "<leader>pi", ":VenvSelect<CR>", { desc = "Select Python Env" })
map("n", "<leader>pt", ":!pytest<CR>", { desc = "Run Pytest" })

-- LSP (Global fallback, though logic primarily handled by specific plugins)
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
map("n", "<leader>cf", vim.lsp.buf.format, { desc = "Format code" })
map("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Rename symbol" })

-- Telescope
map("n", "<leader>ff", ":Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", ":Telescope live_grep<CR>", { desc = "Find text" })
map("n", "<leader>fb", ":Telescope file_browser<CR>", { desc = "File browser" })
map("n", "<leader>fp", ":Telescope project<CR>", { desc = "Projects" })
map("n", "<leader>gw", ":Telescope git_worktree git_worktrees<CR>", { desc = "Worktrees" })
map("n", "<leader>gW", ":Telescope git_worktree create_git_worktree<CR>", { desc = "Create worktree" })

-- Terminal (ToggleTerm)
map("n", "<leader>tt", ":ToggleTerm direction=float<CR>", { desc = "Toggle terminal" })
map("t", "<Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Testing (Neotest)
map("n", "<leader>tn", ":TestNearest<CR>", { desc = "Test nearest" })
map("n", "<leader>tf", ":TestFile<CR>", { desc = "Test file" })
map("n", "<leader>ts", ":TestSuite<CR>", { desc = "Test suite" })

-- Debugging (DAP)
map("n", "<F5>", function()
  require("dap").continue()
end, { desc = "Continue" })
map("n", "<F10>", function()
  require("dap").step_over()
end, { desc = "Step over" })
map("n", "<F11>", function()
  require("dap").step_into()
end, { desc = "Step into" })
map("n", "<F12>", function()
  require("dap").step_out()
end, { desc = "Step out" })
