local ffi = require("ffi")

ffi.cdef([[
typedef void* np_ctx;

typedef struct {
	const uint16_t line_start;
	const uint16_t line_end;
	const char* file;
} np_location;

typedef void* np_editor_handle;

// Get the contents of the buffer.
typedef char* (*np_buf_get_text_fn)(np_editor_handle handle);

typedef struct {
	// The editor specific identifier. Not sure if this is useful yet.
	np_editor_handle handle;

	np_buf_get_text_fn get_text;
} np_buf_handle;

bool np_write_comment(np_ctx ctx, np_buf_handle* handle, np_location* location);
]])

local bindings = {}

--- An abstraction defined by libnitpick to allow the library to update,
--- decorate, and read text from an editor buffer.
--- @class NpBufHandle

-- FIXME: this "location" name is not very descriptive. we can probably come up
-- with something better.
--
--- A common structure for specifiying metadata for an event.
--- @class NpLocation

-- FIXME: should the a neovim buffer be created with this as well? should we
-- just make all the buffer operactions with a buf handle? should there be a
-- separation?
--
--- Create a new buffer handle to pass to libnitpick.
--- @param buf VimBuffer
--- @return NpBufHandle
function bindings.make_np_buf_handle(buf)
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
	})

	return handle
end

--- @param file string
--- @param line_start number
--- @param line_end number
function bindings.make_np_location(file, line_start, line_end)
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
function bindings.write_comment(ctx, buf_handle, location)
	-- FIXME: this is copied directly from the `lib/init.lua` and modified for
	-- development specific use. we should have a single set up. right now, we're
	-- just playing around with how this could be built differently
	local default_lib_path = string.format("./zig-out/bin/libnitpick.so")
	local lib_path = vim.fn.expand(default_lib_path)

	local ok, library = pcall(ffi.load, lib_path)
	if not ok then
		return false
	end

	-- FIXME: let's update this so that it returns an error code. if there's an
	-- error, we'll get a message and return that.
	local success = library.np_write_comment(ctx, buf_handle, location)

	--- @type string?
	local err_msg = nil
	if not success then
		err_msg = "Unable to add comment."
	end

	return success, err_msg
end

return bindings
