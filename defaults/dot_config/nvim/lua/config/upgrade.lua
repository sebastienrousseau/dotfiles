-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- Keep asynchronous parser work observable to the headless upgrade driver.
local M = { tasks = {} }

function M.track(task)
  if vim.env.DOTFILES_NVIM_UPGRADE == "1" then
    table.insert(M.tasks, task)
  end
end

function M.wait(timeout)
  for _, task in ipairs(M.tasks) do
    assert(task:wait(timeout) == true, "Treesitter parser installation failed")
  end
  M.tasks = {}
end

return M
