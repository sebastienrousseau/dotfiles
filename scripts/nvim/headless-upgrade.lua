-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- Complete observable plugin/parser/tool work before reporting success.
local TIMEOUT_MS = 300000

local function log(message)
  io.stderr:write(("[headless-upgrade] %s\n"):format(message))
end

local function run()
  local lazy = require("lazy") -- Missing configuration is a failure, not a no-op.
  local has_mason, registry = pcall(require, "mason-registry")
  local mason_failures, installing = {}, {}
  local function observe_mason()
    local active = false
    for _, package in ipairs(registry.get_all_packages()) do
      if package:is_installing() then
        installing[package.name] = package
        active = true
      end
    end
    return active
  end
  if has_mason then
    registry:on("package:install:failed", function(package)
      table.insert(mason_failures, package.name)
    end)
    observe_mason()
  end

  local synced = false
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazySync",
    once = true,
    callback = function()
      synced = true
    end,
  })
  lazy.sync({ wait = false, show = false })
  assert(
    vim.wait(TIMEOUT_MS, function()
      return synced
    end, 100),
    "Lazy sync timed out"
  )
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    for _, task in ipairs(plugin._.tasks or {}) do
      assert(not task:running(), "Lazy task still running: " .. name)
      assert(not task:has_errors(), "Lazy task failed: " .. name)
    end
  end

  local has_tracker, tracker = pcall(require, "config.upgrade")
  if has_tracker then
    tracker.wait(TIMEOUT_MS)
  end

  if has_mason then
    local refreshed, refresh_ok = false, false
    registry.refresh(function(success)
      refreshed, refresh_ok = true, success
    end)
    assert(
      vim.wait(30000, function()
        return refreshed
      end, 100),
      "Mason registry refresh timed out"
    )
    assert(refresh_ok, "Mason registry refresh failed")
    -- Let ensure_installed callbacks enqueue before testing for an empty queue.
    vim.wait(2000, function()
      observe_mason()
      return false
    end, 100)
    assert(
      vim.wait(TIMEOUT_MS, function()
        return not observe_mason()
      end, 200),
      "Mason install queue timed out"
    )
    assert(#mason_failures == 0, "Mason install failed: " .. table.concat(mason_failures, ", "))
    for name, package in pairs(installing) do
      assert(package:is_installed(), "Mason install incomplete: " .. name)
    end
  end
end

local ok, error_message = pcall(run)
if not ok then
  log(tostring(error_message))
  vim.cmd("cquit 1")
  return
end
log("plugin sync and tracked installations completed")
vim.cmd("quitall!")
