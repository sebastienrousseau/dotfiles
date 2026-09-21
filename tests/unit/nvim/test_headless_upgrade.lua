-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- Run with Lua 5.1+; all plugin APIs are offline test doubles.
local root = assert(arg[1], "repository path required")
local cases = {
  { "success", nil },
  { "lazy-missing", "fixture missing lazy" },
  { "lazy-timeout", "Lazy sync timed out" },
  { "lazy-failure", "Lazy task failed" },
  { "lazy-running", "Lazy task still running" },
  { "parser-failure", "Treesitter parser installation failed" },
  { "parser-timeout", "fixture parser timeout" },
  { "mason-refresh-failure", "Mason registry refresh failed" },
  { "mason-refresh-timeout", "Mason registry refresh timed out" },
  { "mason-timeout", "Mason install queue timed out" },
  { "mason-failure", "Mason install failed: fixture" },
  { "mason-incomplete", "Mason install incomplete: fixture" },
}
local failures = 0
for _, case in ipairs(cases) do
  local name, expected_error = case[1], case[2]
  local callback, failed_callback, command
  local waits, polls = 0, 0
  vim = {
    env = { DOTFILES_NVIM_UPGRADE = "1" },
    api = {
      nvim_create_autocmd = function(_, opts)
        callback = opts.callback
      end,
    },
    wait = function(_, predicate)
      return predicate()
    end,
    cmd = function(value)
      command = value
    end,
  }
  local task = {
    running = function()
      return name == "lazy-running"
    end,
    has_errors = function()
      return name == "lazy-failure"
    end,
  }
  local package_fixture = {
    name = "fixture",
    is_installing = function()
      polls = polls + 1
      return name == "mason-timeout" or (name == "mason-incomplete" and polls == 1)
    end,
    is_installed = function()
      return false
    end,
  }
  package.loaded["lazy"] = nil
  package.preload["lazy"] = function()
    assert(name ~= "lazy-missing", "fixture missing lazy")
    return {
      sync = function(opts)
        assert(opts.wait == false, "sync must not block outside the timeout")
        if name ~= "lazy-timeout" then
          callback()
        end
        if name == "mason-failure" then
          failed_callback(package_fixture)
        end
      end,
    }
  end
  package.loaded["lazy.core.config"] = { plugins = { fixture = { _ = { tasks = { task } } } } }
  package.loaded["mason-registry"] = {
    on = function(_, _, cb)
      failed_callback = cb
    end,
    get_all_packages = function()
      return { package_fixture }
    end,
    refresh = function(cb)
      if name ~= "mason-refresh-timeout" then
        cb(name ~= "mason-refresh-failure")
      end
    end,
  }
  local tracker = dofile(root .. "/defaults/dot_config/nvim/lua/config/upgrade.lua")
  package.loaded["config.upgrade"] = tracker
  tracker.track({
    wait = function(_, timeout)
      assert(timeout == 300000)
      waits = waits + 1
      assert(name ~= "parser-timeout", "fixture parser timeout")
      return name ~= "parser-failure"
    end,
  })
  local stderr, logs = io.stderr, {}
  io.stderr = {
    write = function(_, message)
      table.insert(logs, message)
    end,
  }
  local ok, error_message = pcall(dofile, root .. "/scripts/nvim/headless-upgrade.lua")
  io.stderr = stderr
  local passed = ok and command == (expected_error and "cquit 1" or "quitall!")
  if expected_error then
    passed = passed and table.concat(logs):find(expected_error, 1, true) ~= nil
  else
    passed = passed and waits == 1 and #tracker.tasks == 0
  end
  print((passed and "PASS " or "FAIL ") .. name)
  if not passed then
    failures = failures + 1
    print(tostring(error_message) .. table.concat(logs))
  end
end
print(("RESULTS:%d:%d:%d"):format(#cases, #cases - failures, failures))
os.exit(failures == 0 and 0 or 1)
