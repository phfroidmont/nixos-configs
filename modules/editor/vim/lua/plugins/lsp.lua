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
						mcpClient = "opencode",
						millScript = vim.fn.exepath("mill"),
						showImplicitArguments = false,
						startMcpServer = true,
						useGlobalExecutable = true,
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

					local default_apply_edit = vim.lsp.handlers["workspace/applyEdit"]
					local function apply_edit_and_save(err, params, ctx, config)
						local function fail(reason)
							reason = tostring(reason)
							vim.notify("Metals workspace edit: " .. reason, vim.log.levels.ERROR)
							return { applied = false, failureReason = reason }
						end

						if err then
							return fail(err.message or tostring(err))
						end
						if type(params) ~= "table" or type(params.edit) ~= "table" then
							return fail("invalid workspace edit")
						end

						local targets, versions = {}, {}
						local seen = {}
						local function add_target(uri, version)
							if type(uri) ~= "string" or not uri:match("^file:") then
								error("refusing non-file URI " .. vim.inspect(uri))
							end

							local path = vim.uri_to_fname(uri)
							local existing = vim.fn.bufnr(path, false)
							if existing > 0 and vim.bo[existing].modified then
								error("refusing modified buffer " .. path)
							end

							if not seen[uri] then
								seen[uri] = true
								targets[#targets + 1] = { uri = uri, path = path }
							end
							if type(version) == "number" and version > 0 then
								versions[#versions + 1] = { uri = uri, version = version }
							end
						end

						local edit = params.edit
						local collected, collect_error = pcall(function()
							if edit.documentChanges ~= nil then
								for _, change in ipairs(edit.documentChanges) do
									if change.kind then
										error("refusing resource operation " .. tostring(change.kind))
									end
									if type(change.textDocument) ~= "table" then
										error("invalid text document edit")
									end
									add_target(change.textDocument.uri, change.textDocument.version)
								end
							else
								for uri in pairs(edit.changes or {}) do
									add_target(uri)
								end
							end
						end)
						if not collected then
							return fail(collect_error)
						end

						local prepared, prepare_error = pcall(function()
							for _, target in ipairs(targets) do
								local stat = vim.uv.fs_stat(target.path)
								if not stat or stat.type ~= "file" then
									error("refusing missing or non-file target " .. target.path)
								end
								target.bufnr = vim.uri_to_bufnr(target.uri)
								vim.fn.bufload(target.bufnr)
								local changedtick = vim.api.nvim_buf_get_changedtick(target.bufnr)
								vim.cmd("checktime " .. target.bufnr)
								-- Reloading changes the text the server's edit was computed against.
								if vim.api.nvim_buf_get_changedtick(target.bufnr) ~= changedtick then
									error("file changed on disk; retry the edit: " .. target.path)
								end
								if vim.bo[target.bufnr].buftype ~= "" then
									error("refusing non-normal buffer " .. target.path)
								end
								if not vim.bo[target.bufnr].modifiable then
									error("refusing nonmodifiable buffer " .. target.path)
								end
								if vim.bo[target.bufnr].readonly then
									error("refusing readonly buffer " .. target.path)
								end
								if vim.bo[target.bufnr].modified then
									error("buffer changed while checking the file on disk: " .. target.path)
								end
							end

							for _, document in ipairs(versions) do
								local bufnr = vim.uri_to_bufnr(document.uri)
								if vim.lsp.util.buf_versions[bufnr] > document.version then
									error("refusing stale versioned edit for " .. vim.uri_to_fname(document.uri))
								end
							end
						end)
						if not prepared then
							return fail(prepare_error)
						end

						local handled, result = pcall(default_apply_edit, err, params, ctx, config)
						if not handled then
							return fail(result)
						end
						if type(result) ~= "table" or not result.applied then
							return fail((result and result.failureReason) or "default handler did not apply the edit")
						end

						for _, target in ipairs(targets) do
							if not vim.api.nvim_buf_is_valid(target.bufnr) then
								fail("edit applied, but a target buffer was removed before saving: " .. target.path)
								return result
							end
							if vim.bo[target.bufnr].modified then
								local previous_autoformat = vim.b[target.bufnr].autoformat
								local written, write_error = pcall(function()
									vim.b[target.bufnr].autoformat = false
									vim.api.nvim_buf_call(target.bufnr, function()
										vim.cmd("write")
									end)
								end)
								local restored, restore_error = pcall(function()
									vim.b[target.bufnr].autoformat = previous_autoformat
								end)
								if not written or not restored then
									local reason = written and restore_error or write_error
									fail(
										"edit applied, but saving failed after possible partial writes: "
											.. tostring(reason)
									)
									-- The edits remain applied; do not invite the server to apply them twice.
									return result
								end
							end
						end

						return result
					end

					metals_config.handlers = metals_config.handlers or {}
					metals_config.handlers["workspace/applyEdit"] = apply_edit_and_save

					local metals_setup = require("metals.setup")
					local initialize_or_attach = metals_setup.initialize_or_attach
					local function initialize_workspace(config)
						-- nvim-metals mutates and caches its input, including the generated command.
						config = vim.deepcopy(config or metals_config)
						local find_root = config.find_root_dir or require("metals.rootdir").find_root_dir
						config.find_root_dir = function(patterns, filename, nesting)
							filename = vim.uv.fs_realpath(filename) or filename
							local root = find_root(patterns, filename, nesting) or vim.fn.getcwd()
							root = assert(vim.uv.fs_realpath(root), "Cannot resolve Metals workspace root: " .. root)
							-- Metals 1.6.8 derives Bloop's address from XDG_DATA_HOME. Keep socket paths short.
							local data_home = vim.fn.stdpath("data") .. "/metals/" .. vim.fn.sha256(root):sub(1, 20)
							config.cmd_env =
								vim.tbl_extend("force", config.cmd_env or {}, { XDG_DATA_HOME = data_home })
							return root
						end
						initialize_or_attach(config)
					end
					-- Cover both FileType initialization and nvim-metals' cached start entry point.
					metals_setup.initialize_or_attach = initialize_workspace
					metals.initialize_or_attach = initialize_workspace

					-- The installed nvim-metals restart helpers otherwise select clients globally.
					metals.restart_build_server = function()
						local clients = vim.lsp.get_clients({ bufnr = 0, name = "metals" })
						if #clients ~= 1 then
							vim.notify(
								"Bloop restart requires exactly one Metals client on this buffer",
								vim.log.levels.WARN
							)
							return
						end
						clients[1]:request(
							"workspace/executeCommand",
							{ command = "metals.build-restart" },
							function(err)
								if err then
									vim.notify("Bloop restart: " .. err.message, vim.log.levels.ERROR)
								end
							end
						)
					end
					metals.restart_metals = function()
						local clients = vim.lsp.get_clients({ bufnr = 0, name = "metals" })
						if #clients == 0 then
							vim.notify("No Metals client attached to this buffer", vim.log.levels.WARN)
						end
						for _, client in ipairs(clients) do
							-- Same restart as Neovim 0.12's :lsp restart, retaining this client's config/buffers.
							client:_restart(client.exit_timeout)
						end
					end

					local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
					vim.api.nvim_create_autocmd("FileType", {
						pattern = { "scala", "sbt", "mill" },
						callback = function()
							metals.initialize_or_attach()
						end,
						group = nvim_metals_group,
					})
					return true
				end,
			},
		},
	},
}
