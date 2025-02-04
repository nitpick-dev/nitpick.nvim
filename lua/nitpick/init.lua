local has_diffview, diffview = pcall(require, "diffview")
if not has_diffview then
	vim.notify("Missing nitpick dependency: diffview", vim.log.levels.ERROR)
	return
end

local buffer = require("nitpick.buffer")
local lib = require("nitpick.lib")
local np = require("nitpick.np")
local onboarder = require("nitpick.onboarder")

local np_namespace = vim.api.nvim_create_namespace("Nitpick")

--- @class NitpickOptions
--- @field lib_path? string Overrides the default path for libnitpick.
--- @field data_path? string Overrides the defualt data path for data storage.
--- @field server_url? string Overrides the default nitpick server url.

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
	nitpick.lib = lib:new(repo_name, opts.data_path, opts.server_url)
end

--- Dispatch handler for the next version of nitpick. In this case, the payload
--- should contain a DispatchPayload where the first arg is the name of the next
--- function. The remaining args in the payload are the DispatchPayload args.
--- @param payload DispatchPayload
function nitpick.next(payload)
	-- FIXME: we could create validation for this
	local cmd = table.remove(payload.args, 1)

	local supported_next_cmd = { "comment", "activity" }
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
	if not nitpick.lib:is_tracked_file(file) then
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
			nitpick.lib.ctx,
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
	vim.api.nvim_buf_set_option(buf, "readonly", false)

	-- FIXME: handle error
	np.get_activity(nitpick.lib.ctx, buf_handle)

	-- We don't want users to be able to modify anything in this buffer (or
	-- accidentally save it) after we set the contents, so we set it to readonly.
	vim.api.nvim_buf_set_option(buf, "readonly", true)
end

--- Adds a token for a given host to the config file. The `args` of the payload
--- must be ordered such that args[1] = host, and args[2] = token.
--- @param payload DispatchPayload
function nitpick.authorize(payload)
	assert_nitpick()

	-- FIXME: we could create validation for this
	local host = payload.args[1]
	local token = payload.args[2]

	local authorized = nitpick.lib:authorize(host, token)

	---@type string
	local pattern = authorized
			and "%s was successfully authorized."
			or "failed to authorize %s."

	vim.notify(string.format(pattern, host), vim.log.levels.INFO)
end

-- FIXME: this is not testable. we need to fix that.
---@param payload DispatchPayload
function nitpick.add_comment(payload)
	assert_nitpick()

	---@type string
	local file = vim.fn.expand("%")
	if not nitpick.lib:is_tracked_file(file) then
		-- FIXME: this should be an error, but that triggers an error in the
		-- integration tests.
		vim.notify("Cannot comment on an untracked file.", vim.log.levels.WARN)
		return
	end

	--- @type Comment
	local comment = {
		line_start = payload.line_start,
		-- FIXME: should we just make end be the same as start if it's one line?
		line_end = payload.line_end == payload.line_start and 0 or payload.line_end,
		file = file,
		text = "",
	}

	local buf = buffer.split_make("nitpick comment")
	buffer.add_write_autocmd(buf, function(lines)
		comment.text = table.concat(lines, "\n")
		local success = nitpick.lib:add_comment(comment)

		if not success then
			vim.notify("Unable to add comment.", vim.log.levels.ERROR)
		end
	end)
end

local activity_title = "nitpick activity"
function nitpick.load_activity()
	assert_nitpick()

	local events = nitpick.lib:activity()

	-- FIXME: there will always be another tab that gets open. we'll have to
	-- add some logic to find the open tab and create a new one if it doesn't
	-- exist.
	vim.cmd("tabnew")
	local existing_buf = vim.fn.bufnr(activity_title)

	local buf = existing_buf ~= -1 and existing_buf or vim.api.nvim_create_buf(true, true)
	vim.api.nvim_buf_set_option(buf, "readonly", false)
	vim.api.nvim_set_current_buf(buf)

	local lines = vim.split(events, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	vim.api.nvim_buf_set_name(buf, activity_title)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.api.nvim_buf_set_option(buf, "readonly", true)

	-- FIXME: let's refactor the way we get the activity log so that we don't need
	-- to do as much processing. if we can just have an array of events, we could
	-- build call print on the event and get the block to write out here and
	-- we'll have all the information so we don't have to parse it.
	-- another option would be to call to zig to calculate the positions and
	-- return those. then it's just a mapping funciton here.

	---@class BlockTarget
	---@field file string Path to the target file.
	---@field line_start number Line where the comment begins.
	---@field line_end number? Line where the comment ends. Not always present.

	---@class Block
	---@field line_start number The starting position of the block
	---@field line_end number The ending position of the block
	---@field target BlockTarget

	---@type Block[]
	local blocks = {}

	---@type number[]
	local headers = {}
	for i, line in ipairs(lines) do
		if line:match("^.+%s+added a comment:$") then
			table.insert(headers, i)
		end
	end

	for i, start_pos in ipairs(headers) do
		-- The header will always be followed by the position description of what the
		-- file is and the line numbers.
		local descriptor = lines[start_pos + 1]
		local pattern = "%[([^%]]+)%s+%((%d+)%s*%-?%s*(%d*)%)%]"
		local file, line_start, line_end = descriptor:match(pattern)

		local end_pos = headers[i + 1] or #lines
		table.insert(blocks, {
			line_start = start_pos,
			line_end = end_pos - 1,
			target = {
				file = file,
				line_start = tonumber(line_start),
				line_end = tonumber(line_end),
			},
		})
	end

	vim.api.nvim_buf_clear_namespace(buf, np_namespace, 0, -1)
	for _, block in ipairs(blocks) do
		vim.api.nvim_buf_set_extmark(buf, np_namespace, block.line_start, 0, {
			end_line = block.line_end,
			virt_text = { { "◆", "Comment" } },
			virt_text_pos = "right_align",
		})
	end

	vim.keymap.set("n", "gd",
		function()
			local current_line = vim.api.nvim_win_get_cursor(0)[1]

			for _, block in ipairs(blocks) do
				if current_line >= block.line_start and current_line <= block.line_end then
					local file_buf = vim.fn.bufadd(block.target.file)

					local existing_file_buf = vim.fn.bufwinid(file_buf)
					if existing_file_buf ~= -1 then
						vim.api.nvim_set_current_win(existing_file_buf)
					else
						vim.api.nvim_set_current_buf(file_buf)
					end

					vim.api.nvim_win_set_cursor(0, { block.target.line_start, 0 })
					return
				end
			end
		end,
		{ buffer = buf, desc = "Go to the comment in the file." }
	)
end

function nitpick.open_notes()
	assert_nitpick()

	local note_path = nitpick.lib:notes_path()
	if note_path == "" then
		vim.notify("Could not open notes.", vim.log.levels.ERROR)
		return
	end

	vim.cmd.vsplit()
	vim.cmd.e(note_path)
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

	local commit = nitpick.lib:start_review()
	if commit ~= nil and commit ~= "" then
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

	local commit = nitpick.lib:start_review()
	if commit ~= nil and commit ~= "" then
		vim.cmd(string.format("DiffviewFileHistory --range=%s..HEAD", commit))
	else
		onboarder.start(function(selected_commit)
			vim.cmd(string.format("DiffviewFileHistory --range=%s..HEAD", selected_commit))
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
