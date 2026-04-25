local exzos_root = vim.fs.normalize(vim.fn.expand("~/Projects/foyer/exzos"))
local pms_root = exzos_root .. "/foyer-pms"
local pms_settings = pms_root .. "/settings.gradle"

local included_builds = nil

local function get_included_builds()
  if included_builds then
    return included_builds
  end

  included_builds = {}
  if vim.fn.filereadable(pms_settings) == 0 then
    return included_builds
  end

  for _, line in ipairs(vim.fn.readfile(pms_settings)) do
    local without_comments = line:gsub("//.*$", "")
    local relative_path = without_comments:match("includeBuild%s+['\"]([^'\"]+)['\"]")
    if relative_path then
      local absolute_path = vim.fs.normalize(pms_root .. "/" .. relative_path)
      included_builds[absolute_path] = true
    end
  end

  return included_builds
end

local function is_in_exzos(path)
  if not path or path == "" then
    return false
  end
  local normalized = vim.fs.normalize(path)
  return normalized == exzos_root or vim.startswith(normalized, exzos_root .. "/")
end

local function normalize_java_home(path)
  if not path or path == "" then
    return nil
  end

  local normalized = vim.fs.normalize(path)
  local nix_java_home = normalized .. "/lib/openjdk"
  if vim.fn.executable(nix_java_home .. "/bin/java") == 1 then
    return nix_java_home
  end

  return normalized
end

local function get_exzos_java_root(path)
  if not is_in_exzos(path) then
    return nil
  end

  local normalized = vim.fs.normalize(path)
  if normalized == pms_root or vim.startswith(normalized, pms_root .. "/") then
    return pms_root
  end

  local project_root = vim.fs.root(normalized, { "settings.gradle", "settings.gradle.kts", ".git" })
  if not project_root then
    return nil
  end

  project_root = vim.fs.normalize(project_root)
  if get_included_builds()[project_root] then
    return pms_root
  end

  return nil
end

return {
  recommended = function()
    return LazyVim.extras.wants({
      ft = "scala",
      root = { "build.sbt", "build.mill", "build.sc", "build.gradle", "pom.xml" },
    })
  end,
  {
    "scalameta/nvim-metals",
    ft = { "scala", "sbt", "mill" },
    config = function() end,
  },
  {
    "mfussenegger/nvim-jdtls",
    optional = true,
    opts = function(_, opts)
      local default_root_dir = opts.root_dir
      opts.root_dir = function(path)
        local exzos_java_root = get_exzos_java_root(path)
        if exzos_java_root then
          return exzos_java_root
        end
        if type(default_root_dir) == "function" then
          return default_root_dir(path)
        end
      end

      local previous_jdtls = opts.jdtls
      opts.jdtls = function(config)
        if type(previous_jdtls) == "function" then
          config = previous_jdtls(config) or config
        elseif previous_jdtls then
          config = vim.tbl_deep_extend("force", config, previous_jdtls)
        end

        if is_in_exzos(config.root_dir) then
          local gradle_java_home = normalize_java_home(vim.env.JDTLS_GRADLE_JAVA_HOME)
            or normalize_java_home(vim.env.GRADLE_JAVA_HOME)
            or normalize_java_home(vim.env.JAVA_HOME)

          if gradle_java_home then
            config.cmd_env = vim.tbl_extend("force", config.cmd_env or {}, {
              JAVA_HOME = gradle_java_home,
              GRADLE_JAVA_HOME = gradle_java_home,
              JDTLS_GRADLE_JAVA_HOME = gradle_java_home,
            })

            config.settings = vim.tbl_deep_extend("force", config.settings or {}, {
              java = {
                import = {
                  gradle = {
                    arguments = { "--no-daemon" },
                    java = {
                      home = gradle_java_home,
                    },
                  },
                },
              },
            })
          end
        end

        return config
      end

      return opts
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        metals = {
          settings = {
            serverVersion = "1.6.5",
            showImplicitArguments = false,
            startMcpServer = true,
          },
        },
        elixirls = {
          cmd = { "elixir-ls" },
        },
      },
      setup = {
        metals = function(_, opts)
          local metals = require("metals")
          local metals_config = vim.tbl_deep_extend("force", metals.bare_config(), opts)
          metals_config.on_attach = LazyVim.has("nvim-dap") and metals.setup_dap or nil

          local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
          vim.api.nvim_create_autocmd("FileType", {
            pattern = { "scala", "sbt", "mill" },
            callback = function()
              metals.initialize_or_attach(metals_config)
            end,
            group = nvim_metals_group,
          })
          return true
        end,
      },
    },
  },
}
