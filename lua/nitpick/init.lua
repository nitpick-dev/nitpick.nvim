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

	local authorized = nitpick.lib:authorize(host, token)

	---@type string
	local pattern = authorized
			and "%s was successfully authorized."
			or "failed to authorize %s."

	vim.notify(string.format(pattern, host), vim.log.levels.INFO)
end

-- FIXME: this is not testable. we need to fix that.
-- FIXME: passing the comment is temporary. we should open a split buffer to
-- leave the comment
---@param ...string
function nitpick.add_comment(...)
	assert_nitpick()

	-- FIXME: this will only stop trying to add a comment at the root of the
	-- project. we should have a smater way to detect this. maybe that can be
	-- offloaded to the lib
	---@type string
	local file = vim.fn.expand("%")
	if file == "" then
		-- FIXME: need a test case
		-- FIXME: we should throw a similar error on a version control ignored file
		vim.notify("Comments are only allowed in project files.", vim.log.levels.INFO)
		return
	end

	local success = nitpick.lib:add_comment({
		file = file,
		text = table.concat({ ... }, " "),
		line = vim.api.nvim_win_get_cursor(0)[1],
	})

	if not success then
		vim.notify("Unable to add comment.", vim.log.levels.ERROR)
	end
end

function nitpick.load_activity()
	assert_nitpick()

	local events = nitpick.lib:activity()

	vim.cmd("tabnew")

	local buf = vim.api.nvim_create_buf(true, true)
	vim.api.nvim_set_current_buf(buf)

	local lines = vim.split(events, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.api.nvim_buf_set_name(buf, "Nitpick Activity")
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.api.nvim_buf_set_option(buf, "readonly", true)
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
