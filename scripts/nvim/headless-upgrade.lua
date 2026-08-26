-- headless-upgrade.lua — plugin/tool refresh for `dot upgrade`.
--
-- Runs Lazy sync and then waits for Mason's async install queue to drain
-- before exiting.  The naive invocation
--     nvim --headless "+Lazy! sync" +qa
-- races on two fronts:
--   1. Lazy's own async ops (git fetch/checkout, `build` hooks) can outlive
--      the `Lazy! sync` command return.
--   2. `mason-nvim-dap` and `mason-lspconfig` fire `ensure_installed` on
--      plugin load; those installs are enqueued to mason.nvim and run
--      async, so `+qa` aborts them mid-download (leaving codelldb / debugpy
--      / delve half-installed, per repeated user reports on `dot upgrade`).
--
-- We explicitly wait for both queues before quitting.

local LAZY_TIMEOUT_MS  = 300000  -- 5 min per phase
local MASON_TIMEOUT_MS = 300000

local function log(msg)
  io.stderr:write(("[headless-upgrade] %s\n"):format(msg))
end

-- ---------------------------------------------------------------------------
-- Phase 1: Lazy sync (blocking)
-- ---------------------------------------------------------------------------
local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  log("lazy.nvim not available; skipping plugin update")
  vim.cmd("quitall!")
  return
end

lazy.sync({ wait = true, show = false })

-- Belt-and-braces: give any residual runner tasks a chance to drain even if
-- `wait = true` returned early on the last task in a batch.
pcall(function()
  local ok_runner, runner = pcall(require, "lazy.manage.runner")
  if not ok_runner then return end
  vim.wait(LAZY_TIMEOUT_MS, function()
    return not (runner.running and runner.running())
  end, 200)
end)

-- ---------------------------------------------------------------------------
-- Phase 2: drain Mason's async install queue
-- ---------------------------------------------------------------------------
pcall(function()
  local ok_reg, registry = pcall(require, "mason-registry")
  if not ok_reg then return end

  -- Refresh the remote registry so ensure_installed picks up latest versions.
  local refreshed = false
  registry.refresh(function() refreshed = true end)
  vim.wait(30000, function() return refreshed end, 200)

  local function any_installing()
    for _, pkg in ipairs(registry.get_all_packages() or {}) do
      if pkg.is_installing and pkg:is_installing() then
        return true
      end
    end
    return false
  end

  -- Small settle time so installs triggered by ensure_installed hooks have
  -- a chance to enter the installing state before we start polling.
  vim.wait(2000, function() return false end, 200)

  local done = vim.wait(MASON_TIMEOUT_MS, function()
    return not any_installing()
  end, 500)

  if not done then
    log(("Mason install queue still active after %ds; exiting anyway"):format(
      MASON_TIMEOUT_MS / 1000))
  end
end)

vim.cmd("quitall!")
