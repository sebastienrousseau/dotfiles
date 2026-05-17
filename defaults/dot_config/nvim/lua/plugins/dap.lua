-- Copyright (c) 2015-2026 Dotfiles. All rights reserved.
-- @module nvim.plugins.dap
-- Debug Adapter Protocol (DAP) Configuration.
-- Provides in-editor debugging with nvim-dap and a VS Code-like UI via dap-ui.
-- js-debug-adapter handles Node/Chrome/Edge; the dev server port defaults to
-- 3000 but can be overridden via DAP_DEV_SERVER_PORT.

-- Layout constants
local SIDEBAR_WIDTH = 40
local BOTTOM_PANEL_HEIGHT = 10
local QUARTER_SIZE = 0.25
local HALF_SIZE = 0.5
local DEFAULT_DEV_SERVER_PORT = tonumber(vim.env.DAP_DEV_SERVER_PORT) or 3000

return {
  -- DAP Core
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "williamboman/mason.nvim",
      "jay-babu/mason-nvim-dap.nvim",
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
    },
    keys = {
      {
        "<leader>db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle Breakpoint",
      },
      {
        "<leader>dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Step Into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_over()
        end,
        desc = "Step Over",
      },
      {
        "<leader>dO",
        function()
          require("dap").step_out()
        end,
        desc = "Step Out",
      },
      {
        "<leader>dr",
        function()
          require("dap").repl.open()
        end,
        desc = "Open REPL",
      },
      {
        "<leader>dl",
        function()
          require("dap").run_last()
        end,
        desc = "Run Last",
      },
      {
        "<leader>dt",
        function()
          require("dap").terminate()
        end,
        desc = "Terminate",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle DAP UI",
      },
    },
    config = function()
      local dap = require("dap")

      -- JavaScript/TypeScript debugging with js-debug-adapter
      -- Requires: MasonInstall js-debug-adapter
      local js_debug_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js"

      for _, adapter in ipairs({ "pwa-node", "pwa-chrome", "node-terminal" }) do
        dap.adapters[adapter] = {
          type = "server",
          host = "localhost",
          port = "${port}",
          executable = {
            command = "node",
            args = { js_debug_path, "${port}" },
          },
        }
      end

      -- JavaScript/TypeScript configurations
      for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
        dap.configurations[lang] = {
          {
            type = "pwa-node",
            request = "launch",
            name = "Launch file",
            program = "${file}",
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-node",
            request = "attach",
            name = "Attach to process",
            processId = require("dap.utils").pick_process,
            cwd = "${workspaceFolder}",
          },
          {
            type = "pwa-chrome",
            request = "launch",
            name = "Launch Chrome",
            url = "http://localhost:" .. DEFAULT_DEV_SERVER_PORT,
            webRoot = "${workspaceFolder}",
          },
        }
      end

      -- Python debugging with debugpy
      -- Requires: MasonInstall debugpy
      dap.adapters.python = function(cb, config)
        if config.request == "attach" then
          local port = (config.connect or config).port
          local host = (config.connect or config).host or "127.0.0.1"
          cb({ type = "server", port = assert(port, "port required for attach"), host = host })
        else
          cb({
            type = "executable",
            command = vim.fn.exepath("python3"),
            args = { "-m", "debugpy.adapter" },
          })
        end
      end

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          cwd = "${workspaceFolder}",
          pythonPath = function()
            -- Use venv if available, else system python
            local venv = os.getenv("VIRTUAL_ENV")
            if venv then
              return venv .. "/bin/python"
            end
            return vim.fn.exepath("python3") or "python3"
          end,
        },
        {
          type = "python",
          request = "launch",
          name = "Launch with arguments",
          program = "${file}",
          args = function()
            local args_str = vim.fn.input("Arguments: ")
            return vim.split(args_str, " +")
          end,
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "Launch module",
          module = function()
            return vim.fn.input("Module: ")
          end,
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "Django",
          program = "${workspaceFolder}/manage.py",
          args = { "runserver", "--noreload" },
          django = true,
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "FastAPI (uvicorn)",
          module = "uvicorn",
          args = function()
            local app = vim.fn.input("App module (e.g. main:app): ", "main:app")
            return { app, "--reload" }
          end,
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "pytest",
          module = "pytest",
          args = { "${file}", "-v", "--tb=short" },
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "attach",
          name = "Attach to remote",
          connect = function()
            local host = vim.fn.input("Host (127.0.0.1): ", "127.0.0.1")
            local port = tonumber(vim.fn.input("Port (5678): ", "5678"))
            return { host = host, port = port }
          end,
        },
      }

      -- Go debugging with delve
      -- Requires: MasonInstall delve
      dap.adapters.delve = {
        type = "server",
        port = "${port}",
        executable = {
          command = "dlv",
          args = { "dap", "-l", "127.0.0.1:${port}" },
        },
      }

      dap.configurations.go = {
        {
          type = "delve",
          name = "Launch file",
          request = "launch",
          program = "${file}",
        },
        {
          type = "delve",
          name = "Launch package",
          request = "launch",
          program = "${workspaceFolder}",
        },
        {
          type = "delve",
          name = "Launch test",
          request = "launch",
          mode = "test",
          program = "${file}",
        },
        {
          type = "delve",
          name = "Launch test (package)",
          request = "launch",
          mode = "test",
          program = "${workspaceFolder}",
        },
        {
          type = "delve",
          name = "Attach to process",
          request = "attach",
          mode = "local",
          processId = require("dap.utils").pick_process,
        },
      }

      -- Rust/C/C++ debugging with codelldb
      -- Requires: MasonInstall codelldb
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = vim.fn.stdpath("data") .. "/mason/bin/codelldb",
          args = { "--port", "${port}" },
        },
      }

      for _, lang in ipairs({ "rust", "c", "cpp" }) do
        dap.configurations[lang] = {
          {
            type = "codelldb",
            request = "launch",
            name = "Launch executable",
            program = function()
              return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
          },
          {
            type = "codelldb",
            request = "launch",
            name = "Launch with arguments",
            program = function()
              return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
            end,
            args = function()
              return vim.split(vim.fn.input("Arguments: "), " +")
            end,
            cwd = "${workspaceFolder}",
          },
        }
      end

      -- Bash debugging with bash-debug-adapter
      -- Requires: MasonInstall bash-debug-adapter
      dap.adapters.bashdb = {
        type = "executable",
        command = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/bash-debug-adapter",
        name = "bashdb",
      }

      dap.configurations.sh = {
        {
          type = "bashdb",
          request = "launch",
          name = "Launch script",
          showDebugOutput = true,
          pathBashdb = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir/bashdb",
          pathBashdbLib = vim.fn.stdpath("data") .. "/mason/packages/bash-debug-adapter/extension/bashdb_dir",
          trace = true,
          file = "${file}",
          program = "${file}",
          cwd = "${workspaceFolder}",
          pathCat = "cat",
          pathBash = "/bin/bash",
          pathMkfifo = "mkfifo",
          pathPkill = "pkill",
          env = {},
          args = {},
        },
      }
    end,
  },

  -- Mason DAP integration
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = {
      ensure_installed = { "js-debug-adapter", "debugpy", "delve", "codelldb", "bash-debug-adapter" },
      automatic_installation = true,
      handlers = {},
    },
  },

  -- DAP UI
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        mappings = {
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
          toggle = "t",
        },
        layouts = {
          {
            elements = {
              { id = "scopes", size = QUARTER_SIZE },
              { id = "breakpoints", size = QUARTER_SIZE },
              { id = "stacks", size = QUARTER_SIZE },
              { id = "watches", size = QUARTER_SIZE },
            },
            size = SIDEBAR_WIDTH,
            position = "left",
          },
          {
            elements = {
              { id = "repl", size = HALF_SIZE },
              { id = "console", size = HALF_SIZE },
            },
            size = BOTTOM_PANEL_HEIGHT,
            position = "bottom",
          },
        },
        floating = {
          border = "rounded",
          mappings = { close = { "q", "<Esc>" } },
        },
      })

      -- Auto open/close DAP UI on debug session lifecycle
      local function open_dapui()
        dapui.open()
      end
      local function close_dapui()
        dapui.close()
      end

      dap.listeners.after.event_initialized["dapui_config"] = open_dapui
      dap.listeners.before.event_terminated["dapui_config"] = close_dapui
      dap.listeners.before.event_exited["dapui_config"] = close_dapui
    end,
  },
}
