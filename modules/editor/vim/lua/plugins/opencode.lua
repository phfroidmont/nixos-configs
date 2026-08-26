return {
  "NickvanDyke/opencode.nvim",
  config = function()
    local function open_opencode_in_terminal()
      vim.fn.jobstart({
        vim.env.TERMINAL,
        "--directory",
        vim.fn.getcwd(),
        "sh",
        "-lc",
        "opencode --port",
      }, { detach = true })
    end

    local function focus_herdr_opencode()
      if vim.env.HERDR_ENV ~= "1" then
        open_opencode_in_terminal()
        return
      end

      vim.system({ "herdr", "agent", "list" }, { text = true }, function(result)
        if result.code ~= 0 then
          vim.schedule(function()
            vim.notify("Unable to list Herdr agents", vim.log.levels.ERROR)
          end)
          return
        end

        local ok, response = pcall(vim.json.decode, result.stdout)
        local agents = ok and response.result and response.result.agents or {}
        local target

        for _, agent in ipairs(agents) do
          if agent.workspace_id == vim.env.HERDR_WORKSPACE_ID and agent.agent == "opencode" then
            target = agent.name or agent.pane_id
            break
          end
        end

        vim.schedule(function()
          if not target then
            vim.notify("No OpenCode agent is running in this Herdr workspace", vim.log.levels.WARN)
            return
          end

          vim.system({ "herdr", "agent", "focus", target }, { text = true }, function(focus_result)
            if focus_result.code ~= 0 then
              vim.schedule(function()
                vim.notify("Unable to focus OpenCode in Herdr", vim.log.levels.ERROR)
              end)
            end
          end)
        end)
      end)
    end

    local function start_opencode()
      if vim.env.HERDR_ENV == "1" then
        vim.system({ "herdr-project", vim.fn.getcwd() }, { text = true }, function(result)
          if result.code ~= 0 then
            vim.schedule(function()
              vim.notify("Unable to start OpenCode in Herdr", vim.log.levels.ERROR)
            end)
          end
        end)
      else
        open_opencode_in_terminal()
      end
    end

    ---@type opencode.Opts
    vim.g.opencode_opts = {
      server = {
        start = start_opencode,
      },
      events = {
        permissions = {
          enabled = false,
        },
      },
    }
    vim.o.autoread = true

    vim.keymap.set({ "n", "x" }, "<leader>oa", function()
      require("opencode").ask("@this: ", { submit = true })
    end, { desc = "Ask opencode" })

    vim.keymap.set({ "n", "x" }, "<leader>oo", function()
      require("opencode").select()
    end, { desc = "Execute opencode action…" })

    vim.keymap.set({ "n", "x" }, "<leader>os", function()
      require("opencode").prompt("@this")
    end, { desc = "Add to opencode" })

    vim.keymap.set({ "n", "t" }, "<leader>o.", function()
      focus_herdr_opencode()
    end, { desc = "Focus opencode" })
  end,
}
