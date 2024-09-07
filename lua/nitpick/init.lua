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

function nitpick.deactivate()
	assert_nitpick()

	-- HACK: add confirmation. For now, we can leave it out of the commands, so a
	-- user will have to go through lua and require it to delete. If they're going
	-- through those motions, we can just assume it was a very intentional kind of
	-- thing. but it would be better to just add confirmation either way.
	local deactivated = nitpick.lib:deactivate()
	if not deactivated then
		vim.notify("Deactivate failed. Please try again later.", vim.log.levels.INFO)
		return
	end

	vim.notify("Your account has been deactivated.", vim.log.levels.INFO)
end

---@param username string
function nitpick.signup(username)
	assert_nitpick()

	local access_token = nitpick.lib:signup(username)
	if access_token == nil then
		-- FIXME: we could maybe give some reasoning. It'd be nice to return an
		-- error code or sometihng from the library, then we can call back to get
		-- the value. then our messagees will be consistent between editors.
		vim.notify("Sign up failed. Please try again later.", vim.log.levels.INFO)
		return
	end

	vim.notify(string.format([[Welcome %s! Here's your access token: "%s".
This has been added to your config file, but you need to keep it in a safe place forever. It's your only log in mechanism.
Don't lose it, and don't share it.]], username, access_token), vim.log.levels.INFO)
end

return nitpick
