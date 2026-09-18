-- Run from the repository root:
-- NVIM_METALS_RTP=/path/to/nvim-metals nvim --headless -u NONE -i NONE -l tests/metals-isolation.test.lua
-- nvim-metals performs real initialization, config validation and root lookup.
-- Transport, client queries, optional integrations and JVM-option input are stubbed.
local uv = vim.uv
local repo = vim.fn.getcwd()
assert(uv.fs_stat("/tmp/opencode"), "/tmp/opencode must already exist")
local tmp = assert(uv.fs_mkdtemp("/tmp/opencode/metals-isolation-XXXXXX"))
local real_get_clients, real_get_client_by_id

local function equal(actual, expected, message)
	assert(
		vim.deep_equal(actual, expected),
		message .. "\nexpected: " .. vim.inspect(expected) .. "\nactual: " .. vim.inspect(actual)
	)
end

local function fixture(relative, lines)
	local filename = tmp .. "/" .. relative
	assert(not relative:find("..", 1, true), "fixture path must stay in the sandbox")
	vim.fn.mkdir(vim.fs.dirname(filename), "p")
	equal(vim.fn.writefile(lines or { "object Main {}" }, filename), 0, "write fixture")
	return filename
end

local function run()
	vim.o.swapfile = false
	vim.o.backup = false
	vim.o.writebackup = false
	vim.o.undofile = false
	-- Keep plugin logs and any other runtime writes inside this run's sandbox.
	vim.env.XDG_DATA_HOME = tmp .. "/data"
	vim.env.XDG_CACHE_HOME = tmp .. "/cache"
	vim.env.XDG_STATE_HOME = tmp .. "/state"
	if vim.env.NVIM_METALS_RTP then
		vim.opt.runtimepath:prepend(vim.env.NVIM_METALS_RTP)
	end
	local environment = {
		data = vim.fn.stdpath("data"),
		xdg = vim.env.XDG_DATA_HOME,
		path = vim.env.PATH,
		java = vim.env.JAVA_HOME,
		rtp = vim.o.runtimepath,
	}
	local function unchanged_environment()
		equal(vim.fn.stdpath("data"), environment.data, "stdpath(data) must not change")
		equal(vim.env.XDG_DATA_HOME, environment.xdg, "global XDG_DATA_HOME must not change")
		equal(vim.env.PATH, environment.path, "global PATH must not change")
		equal(vim.env.JAVA_HOME, environment.java, "global JAVA_HOME must not change")
		equal(vim.o.runtimepath, environment.rtp, "plugin runtimepath must not change")
	end

	local function no_process()
		error("tests must not launch child processes")
	end
	uv.spawn = no_process
	vim.system = no_process
	vim.fn.jobstart = no_process
	vim.fn.system = no_process
	vim.fn.systemlist = no_process
	local executable = vim.fn.executable
	vim.fn.executable = function(name)
		return name == "metals" and 1 or executable(name)
	end
	local notifications = {}
	vim.notify = function(message, level)
		notifications[#notifications + 1] = { message = message, level = level }
	end
	_G.LazyVim = {
		has = function(name)
			return name == "nvim-dap"
		end,
	}
	package.preload.dap = function()
		return { adapters = {} }
	end

	local starts = {}
	local function capture_start(config)
		starts[#starts + 1] = config -- Keep the actual table, not just a snapshot.
		return #starts
	end
	vim.lsp.start = capture_start
	local metals = require("metals")
	local rootdir = require("metals.rootdir")
	-- The installed plugin's .jvmopts reader incorrectly passes an iterator to table.concat.
	-- Supply deterministic per-root input to test command regeneration independently of that bug.
	require("metals.jvmopts").java_opts = function(root)
		local path = root .. "/.jvmopts"
		return vim.fn.filereadable(path) == 1 and vim.fn.readfile(path) or {}
	end
	local native_apply_edit = vim.lsp.handlers["workspace/applyEdit"]
	local extra_handler = function() end
	local inherited_env = { PATH = "/test/inherited/bin", JAVA_HOME = "/test/inherited/java", KEEP_ME = "yes" }

	local function configure(overrides)
		local specs = dofile(repo .. "/modules/editor/vim/lua/plugins/lsp.lua")
		local spec
		for _, candidate in ipairs(specs) do
			if candidate[1] == "neovim/nvim-lspconfig" then
				spec = candidate
			end
		end
		assert(spec, "missing nvim-lspconfig spec")
		local opts = spec.opts.servers.metals
		opts.cmd_env = inherited_env
		opts.handlers = { ["test/custom"] = extra_handler }
		for key, value in pairs(overrides or {}) do
			opts[key] = value
		end
		local before = vim.deepcopy(opts)
		equal(spec.opts.setup.metals("metals", opts), true, "Metals setup must take ownership")
		equal(opts, before, "setup must not mutate server options")
		return opts, before
	end

	local function select_file(filename)
		local bufnr = vim.fn.bufadd(filename)
		vim.fn.bufload(bufnr)
		vim.api.nvim_set_current_buf(bufnr)
		return bufnr
	end
	local function initialize(filename, cached)
		select_file(filename)
		local count = #starts
		if cached == "public" then
			metals.start_server()
		elseif cached then
			require("metals.setup").initialize_or_attach()
		else
			vim.api.nvim_exec_autocmds("FileType", { pattern = "scala" })
		end
		equal(#starts, count + 1, "real Metals initialization must reach vim.lsp.start exactly once")
		return starts[#starts]
	end
	local function check_config(config, root)
		root = assert(uv.fs_realpath(root))
		local address = environment.data .. "/metals/" .. vim.fn.sha256(root):sub(1, 20)
		equal(
			config.cmd_env and config.cmd_env.XDG_DATA_HOME,
			address,
			"missing or incorrect workspace cmd_env.XDG_DATA_HOME"
		)
		equal(config.root_dir, root, "root must be canonical")
		for key, value in pairs(inherited_env) do
			equal(config.cmd_env[key], value, "inherited cmd_env." .. key .. " must survive")
		end
		equal(config.settings.metals.mcpClient, "opencode", "preserve MCP client")
		equal(config.settings.metals.startMcpServer, true, "preserve MCP server")
		equal(config.settings.metals.useGlobalExecutable, true, "preserve global executable")
		equal(config.settings.metals.showImplicitArguments, false, "preserve existing settings")
		equal(config.init_options.debuggingProvider, true, "preserve DAP capability")
		assert(type(config.on_attach) == "function", "preserve wrapped DAP on_attach without executing it")
		assert(config.on_attach ~= metals.setup_dap, "real validation must wrap on_attach")
		equal(config.handlers["test/custom"], extra_handler, "preserve inherited handlers")
		local apply_edit = config.handlers["workspace/applyEdit"]
		assert(type(apply_edit) == "function" and apply_edit ~= native_apply_edit, "preserve custom applyEdit handler")
		local rejected = apply_edit(nil, {}, {}, {})
		equal(rejected.applied, false, "custom applyEdit must reject invalid edits")
		assert(rejected.failureReason:find("invalid workspace edit", 1, true), "preserve applyEdit validation")
		unchanged_environment()
		return address
	end
	local function check_jvmopts(config, own, other)
		assert(vim.tbl_contains(config.cmd, "-J-Dworkspace=" .. own), "missing workspace " .. own .. " JVM options")
		assert(
			not vim.tbl_contains(config.cmd, "-J-Dworkspace=" .. other),
			"leaked workspace " .. other .. " JVM options"
		)
	end

	local a = tmp .. "/left/same-name"
	local b = tmp .. "/right/same-name"
	fixture("left/same-name/build.sbt", {})
	fixture("right/same-name/build.sbt", {})
	fixture("left/same-name/.jvmopts", { "-Dworkspace=A" })
	fixture("right/same-name/.jvmopts", { "-Dworkspace=B" })
	local file_a = fixture("left/same-name/src/Main.scala")
	local file_b = fixture("right/same-name/src/Main.scala")
	fixture("left/same-name/src/Alias.scala")
	assert(uv.fs_symlink(a, tmp .. "/alias"))
	local opts, original_opts = configure()
	local client_a = initialize(file_a)
	local address_a = check_config(client_a, a)
	check_jvmopts(client_a, "A", "B")
	local original_a = vim.deepcopy(client_a)
	local client_b = initialize(file_b)
	local address_b = check_config(client_b, b)
	check_jvmopts(client_b, "B", "A")
	assert(address_a ~= address_b, "same-basename workspaces need distinct data homes")
	assert(client_a ~= client_b and client_a.cmd_env ~= client_b.cmd_env, "workspace configs must be fresh tables")
	equal(client_a, original_a, "initializing B must not mutate A's config, command, or environment")
	local original_b = vim.deepcopy(client_b)

	-- The plugin's no-argument start path otherwise reuses B's validated config.
	local cached_a = initialize(file_a, true)
	check_config(cached_a, a)
	check_jvmopts(cached_a, "A", "B")
	equal(cached_a.cmd, original_a.cmd, "cached start must rebuild A's command, not reuse B's")
	assert(cached_a ~= client_a and cached_a ~= client_b, "cached initialization must also use a fresh config")
	equal(client_b, original_b, "cached start from A must not mutate B")
	local public_b = initialize(file_b)
	local public_b_before = vim.deepcopy(public_b)
	local public_a = initialize(file_a, "public")
	check_config(public_a, a)
	equal(public_a.cmd, original_a.cmd, "public start_server must rebuild A's command after B")
	assert(public_a ~= public_b and public_a ~= cached_a, "public start_server must use a fresh config")
	equal(public_b, public_b_before, "public start_server must not mutate B")
	equal(check_config(initialize(file_a), a), address_a, "reopening A must preserve its address")
	equal(
		check_config(initialize(tmp .. "/alias/src/Alias.scala"), a),
		address_a,
		"symlink alias must share A's address"
	)
	equal(client_a, original_a, "subsequent initializations must not mutate the first client")
	equal(opts, original_opts, "validation must not mutate the original options or cmd_env")

	fixture("left/same-name/module/build.sbt", {})
	check_config(initialize(fixture("left/same-name/module/src/Nested.scala")), a)
	fixture("left/same-name/deep/module/build.sbt", {})
	local deep_file = fixture("left/same-name/deep/module/src/Deep.scala")
	check_config(initialize(deep_file), a .. "/deep/module")
	fixture("left/same-name/scala-cli/.scala-build/marker", {})
	check_config(initialize(fixture("left/same-name/scala-cli/Main.scala")), a .. "/scala-cli")
	local orphan = fixture("unmarked/Main.scala")
	local fallback = vim.fs.dirname(fixture("fallback/marker", {}))
	vim.api.nvim_set_current_dir(fallback)
	check_config(initialize(orphan), fallback)

	-- Client methods deliberately require ':' calls, matching Neovim's API.
	local current_buf = select_file(file_a)
	local other_buf = select_file(file_b)
	select_file(file_a)
	local requests, restarts = {}, {}
	local function mock_client(id, name, bufnr, timeout)
		local client = { id = id, name = name, attached_buffers = { [bufnr] = true }, exit_timeout = timeout }
		function client:exec_cmd()
			error("Metals 1.6.8 does not advertise the prefixed command; send a raw request like nvim-metals")
		end
		function client:request(method, params, handler)
			equal(self, client, "request must receive its client")
			equal(method, "workspace/executeCommand", "build restart request method")
			equal(params.command, "metals.build-restart", "build restart command")
			assert(type(handler) == "function", "build restart must handle errors")
			handler({ message = "test error" })
			equal(notifications[#notifications].message, "Bloop restart: test error", "report restart errors")
			requests[#requests + 1] = self.id
			return true, #requests
		end
		function client:_restart(exit_timeout)
			equal(self, client, "_restart must receive its client")
			equal(exit_timeout, self.exit_timeout, "restart must preserve the client's exit_timeout")
			restarts[#restarts + 1] = self.id
		end
		client.stop = function()
			error("restart must use native _restart, not stop plus cached initialization")
		end
		return client
	end
	local clients = {
		mock_client(2, "metals", other_buf, 200),
		mock_client(3, "other-lsp", current_buf, 300),
		mock_client(1, "metals", current_buf, 100),
	}
	real_get_clients, real_get_client_by_id = vim.lsp.get_clients, vim.lsp.get_client_by_id
	vim.lsp.get_clients = function(filter)
		filter = filter or {}
		assert(filter.buffer == nil, "get_clients uses bufnr, not buffer")
		local bufnr = filter.bufnr == 0 and vim.api.nvim_get_current_buf() or filter.bufnr
		return vim.tbl_filter(function(client)
			return (not filter.name or client.name == filter.name) and (not bufnr or client.attached_buffers[bufnr])
		end, clients)
	end
	vim.lsp.get_client_by_id = function(id)
		for _, client in ipairs(clients) do
			if client.id == id then
				return client
			end
		end
	end
	metals.restart_build_server()
	equal(requests, { 1 }, "build restart must target only the current buffer's Metals client")
	metals.restart_metals()
	equal(restarts, { 1 }, "Metals restart must target only the current buffer's Metals client")
	clients[#clients + 1] = mock_client(4, "metals", current_buf, false)
	local ambiguous_notices = #notifications
	metals.restart_build_server()
	equal(requests, { 1 }, "ambiguous build restart must not affect either client")
	assert(#notifications > ambiguous_notices, "ambiguous build restart must warn")
	restarts = {}
	metals.restart_metals()
	table.sort(restarts)
	equal(restarts, { 1, 4 }, "restart all and only Metals clients attached to the current buffer")
	select_file(orphan)
	local notices = #notifications
	metals.restart_build_server()
	metals.restart_metals()
	equal(requests, { 1 }, "no-client build restart must not fall back to another workspace")
	equal(restarts, { 1, 4 }, "no-client restart must not affect other workspaces")
	assert(#notifications > notices, "no-client restart must warn safely")

	-- Exercise the supported custom resolver and its exact calling convention.
	local calls = {}
	local patterns = { "build.sbt" }
	local custom_opts, custom_before = configure({
		root_patterns = patterns,
		find_root_dir_max_project_nesting = 2,
		find_root_dir = function(received_patterns, filename, nesting)
			calls[#calls + 1] = filename
			equal(received_patterns, patterns, "forward configured root patterns")
			equal(nesting, 2, "forward configured maximum nesting")
			equal(filename, uv.fs_realpath(filename), "canonicalize filenames before calling original resolver")
			local root = rootdir.find_root_dir(received_patterns, filename, nesting)
			return root == a and tmp .. "/alias" or root
		end,
	})
	check_config(initialize(deep_file), a)
	check_config(initialize(tmp .. "/alias/src/Alias.scala"), a)
	check_config(initialize(orphan), fallback)
	equal(#calls, 3, "original find_root_dir must be called for every initialization")
	equal(custom_opts, custom_before, "custom resolver options must not mutate")
	local explicit = vim.deepcopy(original_opts)
	explicit.cmd = { "custom-metals", "--custom-argument" }
	local explicit_before = vim.deepcopy(explicit)
	select_file(file_a)
	local count = #starts
	metals.initialize_or_attach(explicit)
	equal(#starts, count + 1, "explicit config must initialize")
	equal(starts[#starts].cmd, explicit.cmd, "preserve explicit custom command")
	equal(explicit, explicit_before, "explicit config must not mutate")
	local previous = vim.deepcopy(starts)
	explicit.find_root_dir = function()
		return tmp .. "/nonexistent-root"
	end
	pcall(metals.initialize_or_attach, explicit) -- Canonicalization may raise or report an error.
	equal(#starts, count + 1, "unresolvable root must not launch Metals")
	equal(starts, previous, "failed canonicalization must not mutate any previous client metadata")
	equal(vim.lsp.start, capture_start, "production must not globally replace vim.lsp.start")
	unchanged_environment()
end

local ok, failure = xpcall(run, debug.traceback)
if real_get_clients then
	vim.lsp.get_clients, vim.lsp.get_client_by_id = real_get_clients, real_get_client_by_id
end
vim.api.nvim_set_current_dir(repo)
-- Never delete the shared parent, an arbitrary tempname, or a resolved symlink.
assert(tmp:match("^/tmp/opencode/metals%-isolation%-[%w]+$"), "unsafe cleanup path")
assert(uv.fs_realpath(tmp) == tmp, "sandbox must not become a symlink")
equal(vim.fn.delete(tmp, "rf"), 0, "sandbox cleanup")
assert(not uv.fs_stat(tmp), "sandbox must be removed after success or failure")
if not ok then
	error(failure, 0)
end
print("metals-isolation: all tests passed; sandbox removed")
