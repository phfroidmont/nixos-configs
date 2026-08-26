return {
	{
		"folke/persistence.nvim",
		event = "VimEnter",
		opts = {},
		config = function(_, opts)
			local persistence = require("persistence")
			persistence.setup(opts)

			if vim.env.HERDR_ENV ~= "1" then
				return
			end

			local args = vim.fn.argv()
			local restore_project = vim.g.started_with_stdin ~= 1
				and (#args == 0 or (#args == 1 and vim.fn.isdirectory(args[1]) == 1))

			if restore_project then
				vim.schedule(function()
					persistence.load()
				end)
			end

			vim.api.nvim_create_autocmd("Signal", {
				pattern = "SIGUSR1",
				callback = function()
					if not pcall(persistence.save) then
						return
					end

					local runtime_dir = vim.env.XDG_RUNTIME_DIR
					if runtime_dir then
						local checkpoint_dir = runtime_dir .. "/herdr-nvim-checkpoints"
						vim.fn.mkdir(checkpoint_dir, "p")
						vim.fn.writefile({ "ok" }, checkpoint_dir .. "/" .. vim.fn.getpid())
					end

					vim.schedule(function()
						local modified = vim.iter(vim.api.nvim_list_bufs()):any(function(buf)
							return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].modified
						end)

						if not modified then
							persistence.stop()
							if not pcall(vim.cmd, "qall") then
								persistence.start()
							end
						end
					end)
				end,
			})
		end,
	},
}
