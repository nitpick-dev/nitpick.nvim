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

---Starts a review by pulling back the last stored commit from the config file
---@param start_commit string?
function nitpick.start_review(start_commit)
	assert(nitpick.np ~= nil, "nitpick was not initialized or initialized incorrectly.")

	if start_commit ~= nil then
		diffview.open(start_commit, "HEAD")
		return
	end

	local commit = nitpick.np:start_review()

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
	assert(nitpick.np ~= nil, "nitpick was not initialized or initialized incorrectly.")
	local commit = nitpick.np:end_review()

	vim.notify("Review completed at commit " .. commit, vim.log.levels.INFO)
	diffview.close()
end

return nitpick
