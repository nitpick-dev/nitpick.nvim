local diffview = require("diffview")

local lib = require("nitpick.lib")
local onboarder = require("nitpick.onboarder")

---@class NitpickOptions
---@field lib_path? string Overrides the default path for libnitpick
---@field server_url? string Overrides the default nitpick server url

---@class NitpickConfig
---@field lib Nitpick?
local nitpick = {
	lib = nil,
}

---Asserts that the nitpick library has been initialized. This will cause a
---crash, and there is no attempt at recovery.
local function assert_nitpick()
	assert(nitpick.lib ~= nil, "nitpick was not initialized or initialized incorrectly.")
end

---@param user_opts? NitpickOptions?
function nitpick.setup(user_opts)
	local opts = user_opts or {}

	local ok = lib.load(opts.lib_path)
	if not ok then
		vim.notify("Failed to load libnitpick", vim.log.levels.ERROR)
		return
	end

	local repo_name = vim.fs.basename(vim.fn.getcwd())
	local np_data_path = vim.fn.stdpath("data");
	nitpick.lib = lib:new(repo_name, np_data_path, opts.server_url)
end

---@param host string
---@param token string
function nitpick.authorize(host, token)
	assert_nitpick()

	local authorized = lib:authorize(host, token)

	---@type string
	local pattern = authorized
			and "%s was successfully authorized."
			or "failed to authorize %s."

	vim.notify(string.format(pattern, host), vim.log.levels.INFO)
end

---@param start_commit string?
function nitpick.start_review(start_commit)
	assert_nitpick()

	if start_commit ~= nil then
		diffview.open(start_commit, "HEAD")
		return
	end

	local commit = nitpick.lib:start_review()
	if commit ~= nil and commit ~= "" then
		diffview.open(commit, "HEAD")
	else
		onboarder.start(function(selected_commit)
			diffview.open(selected_commit, "HEAD")
		end)
	end
end

function nitpick.end_review()
	assert_nitpick()

	local commit = nitpick.lib:end_review()

	vim.notify("Review completed at commit " .. commit, vim.log.levels.INFO)
	diffview.close()
end

return nitpick
