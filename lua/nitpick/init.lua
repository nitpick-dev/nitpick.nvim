local diffview = require("diffview")

local np = require("nitpick.np")

---@class NitpickOptions
---@field lib_path string? Overrides the default path for libnitpick

---@class NitpickConfig
---@field np Nitpick?
local nitpick = {
	np = nil,
}

---@param user_opts NitpickOptions?
function nitpick.setup(user_opts)
	local opts = user_opts or {}

	local ok = np.load(opts.lib_path)
	if not ok then
		vim.notify("Failed to load libnitpick", vim.log.levels.ERROR)
		return
	end

	local repo_name = vim.fs.basename(vim.fn.getcwd())
	local np_data_path = vim.fn.stdpath("data");
	nitpick.np = np:new(repo_name, np_data_path)
end

---Get the file for the repo
---@param mode string
---@return file*?
local function get_config_file(mode)
	local nitpick_dir = string.format("%s/nitpick", vim.fn.stdpath("data"))
	local dir = vim.fs.basename(vim.fn.getcwd())
	local repo_file = string.format("%s/%s", nitpick_dir, dir)

	local file = io.open(repo_file, mode)
	if not file then
		vim.fn.mkdir(nitpick_dir, "p")
		file = io.open(repo_file, "w")
	end

	return file
end

---Get the current _short_ commit hash
---@return string
local function get_commit()
	return vim.fn.system("git rev-parse --short HEAD")
end

---Starts a review by pulling back the last stored commit from the config file
---@param start_commit string?
function nitpick.start_review(start_commit)
	if start_commit ~= nil then
		diffview.open(start_commit, "HEAD")
		return
	end

	local commit
	if nitpick.np ~= nil then
		commit = nitpick.np:start_review()
	else
		--NOTE: this path is not tested
		local config_file = get_config_file("r")
		if not config_file then
			vim.notify("Unable to start a review", vim.log.levels.ERROR)
			return
		end

		-- HACK: this reads a single line. for now, we can assume that's fine, but we
		-- might prefer to read the whole file...
		commit = config_file:read("l") or ""
		config_file:close()
	end

	-- FIXME: make a better experience for starting a review if there hasn't been
	-- one done yet
	if commit == "" then
		vim.notify("You have not conducted a review yet...")
		return
	end

	diffview.open(commit, "HEAD")
end

---Completes the review by saving the current commit to the config file
function nitpick.end_review()
	local commit
	if nitpick.np ~= nil then
		commit = nitpick.np:end_review()
	else
		local config_file = get_config_file("w")
		if not config_file then
			vim.notify("Unable to complete a review", vim.log.levels.ERROR)
			return
		end

		commit = get_commit()
		config_file:write(commit)
		config_file:close()
	end

	vim.notify("Review completed at commit " .. commit, vim.log.levels.INFO)
	diffview.close()
end

return nitpick
