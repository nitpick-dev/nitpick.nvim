--- A set of utilities for common interactions with vim buffers. This could be
--- considered the "ui" for nitpick.

local np_group = vim.api.nvim_create_augroup("NitpickGroup", { clear = true })

local buffer = {}

-- FIXME: figure out what this type is or where we can pull it from
--- @class VimBuffer

--- Opens a split and returns the new buffer.
--- @param name string The name for the buffer that will be created.
--- @return VimBuffer buf
function buffer.split_make(name)
	-- FIXME: screen size logic: a new split should open vertically when there's
	-- enough space, horizontally otherwise.
	-- potentially, we could do it off a user setting
	vim.cmd("vnew")

	--- @type VimBuffer
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_name(buf, name)

	return buf
end

--- Opens a special buffer that triggers an action when and only when the buffer
--- is written and closed.
--- @param buf VimBuffer
--- @param on_close fun(contents: string[]) The lines of the buffer
function buffer.add_write_autocmd(buf, on_close)
	vim.api.nvim_buf_set_option(buf, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

	-- FIXME: we only call to trigger the on close if the buffer is being written
	-- and closed. if the buffer is just written, we don't want to do anything. we
	-- need to figure out what the right autocmd for that is.
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		group = np_group,
		buffer = buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

			on_close(lines)

			vim.api.nvim_buf_set_option(buf, "modified", false)
			return true
		end,
	})
end

return buffer
