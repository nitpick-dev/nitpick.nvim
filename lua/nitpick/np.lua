local ffi = require("ffi")

ffi.cdef([[
typedef void* np_ctx;

typedef struct {
	const uint16_t line_start;
	const uint16_t line_end;
	const char* file;
} np_location;

typedef void* np_editor_handle;

typedef char* (*np_buf_get_text_fn)(np_editor_handle handle);
typedef void (*np_buf_set_text_fn)(np_editor_handle handle);

typedef struct {
	// The editor specific identifier. Not sure if this is useful yet.
	np_editor_handle handle;

	np_buf_get_text_fn get_text;
	np_buf_set_text_fn set_text;
} np_buf_handle;

typedef enum {
	none,
	comment_write_failure,
} np_error_code;

np_error_code np_get_activity(np_ctx ctx, np_buf_handle* handle);
np_error_code np_write_comment(np_ctx ctx, np_buf_handle* handle, np_location* location);
char* np_get_error_msg(np_error_code);
]])

local np = {}

--- @return boolean ok
--- @return ffi.namespace*? lib
function np.setup()
	-- FIXME: this should be called once at startup of the app. for now, we'll
	-- allow it to be called per fucntion. additionally, we're looking for an env
	-- var. this is only intended for development purposes while we're building
	-- out this alternative file. we should rely on the user's configuration like
	-- we do in `lib/init.lua`.
	local lib_path = vim.fn.expand(vim.env.LIB_PATH)
	return pcall(ffi.load, lib_path)
end

--- An abstraction defined by libnitpick to allow the library to update,
--- decorate, and read text from an editor buffer.
--- @class NpBufHandle

-- FIXME: this "location" name is not very descriptive. we can probably come up
-- with something better.
--
--- A common structure for specifiying metadata for an event.
--- @class NpLocation

--- @param buf_handle NpBufHandle
--- @param ctx ffi.cdata*
--- @return boolean success `true` if the operation is successfule, `false` otherwise. When `false`, `error_message` will be present.
--- @return string? error_message Human readible error message provided by the library. This will only be present when `success` is true.
function np.get_activity(ctx, buf_handle)
	local ok, lib = np.setup()
	if not ok  or lib == nil then
		return false, "Failed to load library"
	end

	local error_code = lib.np_get_activity(ctx, buf_handle)
	local success = tonumber(error_code) == 0

	--- @type string?
	local error_msg = nil
	if not success then
		error_msg = ffi.string(lib.np_get_error_msg(error_code))
	end

	return success, error_msg
end

-- FIXME: should the a neovim buffer be created with this as well? should we
-- just make all the buffer operactions with a buf handle? should there be a
-- separation?
--
--- Create a new buffer handle to pass to libnitpick.
--- @param buf VimBuffer
--- @return NpBufHandle
function np.make_buf_handle(buf)
	--- @type NpBufHandle
	local handle = ffi.new("np_buf_handle", {
		handle = ffi.cast("np_editor_handle", buf),
		get_text = ffi.cast("np_buf_get_text_fn", function()
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			local contents = table.concat(lines, "\n");
			local c_contents = ffi.new("char[?]", #contents + 1)
			ffi.copy(c_contents, contents)

			return c_contents
		end),
		set_text = ffi.cast("np_buf_set_text_fn", function(text)
			local lines = vim.split(ffi.string(text), "\n")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		end),
	})

	return handle
end

--- @param file string
--- @param line_start number
--- @param line_end number
function np.make_location(file, line_start, line_end)
	return ffi.new("np_location", {
		file = file,
		line_start = line_start,
		line_end = line_end,
	})
end

--- @param buf_handle NpBufHandle
--- @param ctx ffi.cdata*
--- @param location NpLocation
--- @return boolean success `true` if the operation is successfule, `false` otherwise. When `false`, `error_message` will be present.
--- @return string? error_message Human readible error message provided by the library. This will only be present when `success` is true.
function np.write_comment(ctx, buf_handle, location)
	local ok, lib = np.setup()
	if not ok  or lib == nil then
		return false, "Failed to load library"
	end

	local error_code = lib.np_write_comment(ctx, buf_handle, location)
	local success = tonumber(error_code) == 0

	--- @type string?
	local error_msg = nil
	if not success then
		error_msg = ffi.string(lib.np_get_error_msg(error_code))
	end

	return success, error_msg
end

return np
