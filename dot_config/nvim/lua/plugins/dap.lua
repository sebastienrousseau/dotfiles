-- Debug Adapter Protocol (DAP) Configuration

-- Layout constants
local SIDEBAR_WIDTH = 40
local BOTTOM_PANEL_HEIGHT = 10
local QUARTER_SIZE = 0.25
local HALF_SIZE = 0.5
local DEFAULT_DEV_SERVER_PORT = 3000

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

      -- JavaScript configurations
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
    end,
  },

  -- Mason DAP integration
  {
    "jay-babu/mason-nvim-dap.nvim",
    dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
    opts = {
      ensure_installed = { "js-debug-adapter" },
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
