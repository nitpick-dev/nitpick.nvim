local has_diffview, diffview = pcall(require, "diffview")
if not has_diffview then
	vim.notify("Missing nitpick dependency: diffview", vim.log.levels.ERROR)
	return
end

local buffer = require("nitpick.buffer")
local np = require("nitpick.lib")
local onboarder = require("nitpick.onboarder")

--- @class NitpickOptions
--- @field lib_path? string Overrides the default path for libnitpick.
--- @field data_path? string Overrides the defualt data path for data storage.
--- @field server_url? string Overrides the default nitpick server url.

---@class NitpickConfig
---@field ctx NpCtx
local nitpick = {}

---Asserts that the nitpick library has been initialized. This will cause a
---crash, and there is no attempt at recovery.
local function assert_nitpick()
	assert(
		nitpick.ctx ~= nil,
		"nitpick is not initialized or initialized incorrectly."
	)
end

---@param user_opts? NitpickOptions?
function nitpick.setup(user_opts)
	local opts = user_opts or {}

	local ok = np.setup(opts.lib_path)
	if not ok then
		vim.notify("Failed to load libnitpick", vim.log.levels.ERROR)
		return
	end

	local repo_name = vim.fs.basename(vim.fn.getcwd())

	nitpick.ctx = np.new(repo_name, {
		data_path = opts.data_path,
		server_url = opts.server_url,
	})
end

--- Dispatch handler for the next version of nitpick. In this case, the payload
--- should contain a DispatchPayload where the first arg is the name of the next
--- function. The remaining args in the payload are the DispatchPayload args.
--- @param payload DispatchPayload
function nitpick.next(payload)
	-- FIXME: we could create validation for this
	local cmd = table.remove(payload.args, 1)

	local supported_next_cmd = {}
	if not vim.tbl_contains(supported_next_cmd, cmd) then
		vim.notify(
			string.format("%s is not a supported next command.", cmd),
			vim.log.levels.ERROR
		)
		return
	end

	return nitpick[cmd](payload)
end

--- @param payload DispatchPayload
function nitpick.comment(payload)
	assert_nitpick()

	local file = vim.fn.expand("%")
	if not np.is_tracked_file(nitpick.ctx, file) then
		-- FIXME: this should be an error, but that triggers an error in the
		-- integration tests.
		vim.notify("Cannot comment on an untracked file.", vim.log.levels.WARN)
		return
	end

	local buf = buffer.split_make("nitpick comment")
	-- FIXME: the callback to `add_write_autocmd` passes in the contents of the
	-- buffer. we don't need that anymore. we should reconsider if we should keep
	-- doing it. additionally, we could just change this to something like
	-- `add_event_listener` or something less specific to autocmd? not sure if
	-- that matters much though.
	buffer.add_write_autocmd(buf, function()
		local buf_handle = np.make_buf_handle(buf)
		local location = np.make_location(
			file,
			payload.line_start,
			payload.line_end == payload.line_start and 0 or payload.line_end
		)

		local success, err_msg = np.write_comment(
			nitpick.ctx,
			buf_handle,
			location
		)

		if not success then
			vim.notify(err_msg or "Unknown error", vim.log.levels.ERROR)
		end
	end)
end

function nitpick.activity()
	assert_nitpick()

	-- FIXME: this is probably not what we want to do, maybe a popup or a new tab
	-- overall, this logic should be cleaned up.
	local existing_buf = vim.fn.bufnr("nitpick activity")
	local buf = existing_buf ~= -1
			and existing_buf
			or vim.api.nvim_create_buf(false, true)

	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_name(buf, "nitpick activity")

	local buf_handle = np.make_buf_handle(buf)

	-- Before updating the contents of the buffer, we need to make sure that it's
	-- editable. Once the contents have been writte, we can toggle back to a
	-- readonly buffer.
	vim.api.nvim_set_option_value("readonly", false, { buf = buf })

	-- FIXME: handle error
	np.get_activity(nitpick.ctx, buf_handle)

	-- We don't want users to be able to modify anything in this buffer (or
	-- accidentally save it) after we set the contents, so we set it to readonly.
	vim.api.nvim_set_option_value("readonly", true, { buf = buf })
end

--- Adds a token for a given host to the config file. The `args` of the payload
--- must be ordered such that args[1] = host, and args[2] = token.
--- @param payload DispatchPayload
function nitpick.authorize(payload)
	assert_nitpick()

	-- FIXME: we could create validation for this
	local host = payload.args[1]
	local token = payload.args[2]

	local ok = np.authorize(nitpick.ctx, host, token)
	local pattern = ok
			and "%s was successfully authorized."
			or "failed to authorize %s."

	vim.notify(string.format(pattern, host), vim.log.levels.INFO)
end

function nitpick.open_notes()
	assert_nitpick()

	local note_path = np.get_file_path(nitpick.ctx, "notes")
	if note_path == "" then
		vim.notify("Could not open notes.", vim.log.levels.ERROR)
		return
	end

	vim.cmd.vsplit()
	vim.cmd.e(note_path)
end

function nitpick.open_tasks()
	assert_nitpick()

	local todo_path = np.get_file_path(nitpick.ctx, "tasks")
	if todo_path == "" then
		vim.notify("Could not open tasks.", vim.log.levels.ERROR)
		return
	end

	vim.cmd.vsplit()
	vim.cmd.e(todo_path)
end

--- @param payload DispatchPayload
function nitpick.start_review(payload)
	assert_nitpick()

	-- FIXME: we could create validation for this
	local start_commit = payload.args[1]

	if start_commit ~= nil then
		diffview.open(start_commit, "HEAD")
		return
	end

	local commit = np.start_review(nitpick.ctx)
	if commit ~= nil then
		diffview.open(commit, "HEAD")
	else
		onboarder.start(function(selected_commit)
			diffview.open(selected_commit, "HEAD")
		end)
	end
end

-- FIXME: this is experimental. we should figure out the actual api for
-- filhistory and use lua to call. we should also merge with `start_above`
--- @param payload DispatchPayload
function nitpick.range_start_review(payload)
	assert_nitpick()

	-- FIXME: we could create validation for this
	local start_commit = payload.args[1]

	if start_commit ~= nil then
		vim.cmd(string.format("DiffviewFileHistory --range=%s..HEAD", start_commit))
		return
	end

	local commit = np.start_review(nitpick.ctx)
	if commit ~= nil then
		vim.cmd(string.format("DiffviewFileHistory --range=%s..HEAD", commit))
	else
		onboarder.start(function(selected_commit)
			vim.cmd(
				string.format("DiffviewFileHistory --range=%s..HEAD", selected_commit)
			)
		end)
	end
end

function nitpick.end_review()
	assert_nitpick()

	local commit = np.end_review(nitpick.ctx)
	if commit == nil then
		vim.notify("Unable to save current review", vim.log.levels.ERROR)
	end

	vim.notify("Review completed at commit " .. commit, vim.log.levels.INFO)
	diffview.close()
end

return nitpick
