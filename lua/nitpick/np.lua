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

// NOTE: data_path and server_url are optional
np_ctx np_new(char* repo_name, char* data_path, char* server_url);
void np_free(np_ctx ctx);

bool np_authorize(np_ctx ctx, char* host, char* token);
bool np_is_tracked_file(np_ctx ctx, char* file_path);

int np_start_review(np_ctx, char* buf);
int np_end_review(np_ctx, char* buf);

np_error_code np_get_activity(np_ctx ctx, np_buf_handle* handle);
np_error_code np_write_comment(np_ctx ctx, np_buf_handle* handle, np_location* location);
char* np_get_error_msg(np_error_code);

// These are our experimental features for some long term nitpick stuff. They
// can be used, but the data format and the apis are likely to change.
int np_notes_path(np_ctx ctx, char* buf);
int np_tasks_path(np_ctx ctx, char* buf);
]])

--- Holds the context for the current nitpick instance.
--- @alias NpCtx ffi.cdata*

local np = {
	--- @type ffi.namespace*
	lib = nil,
}

--- @type ffi.namespace*?
local lib = nil

--- Load the libnitpick library
--- @param lib_path_override string? User profivded path to libnitpick.
--- @return boolean ok
function np.setup(lib_path_override)
	local ext = vim.uv.os_uname().sysname:lower() == "linux" and "so" or "dylib"

	local default_lib_path = string.format("~/.local/bin/libnitpick.%s", ext)
	local lib_path = vim.fn.expand(lib_path_override or default_lib_path)

	local ok, library = pcall(ffi.load, lib_path)
	if not ok then
		return false
	end

	-- FIXME: we should remove this an use np.lib
	lib = library
	np.lib = library

	return true
end

--- Allocates a new c string from an optional string. When no string is
--- provided, nil will always be returned.
---
--- The data should be cleaned by normal garbage collection.
--- @param str? string The string to convert to a c string.
--- @return ffi.cdata* | nil
local function create_c_str(str)
	if str == nil then
		return nil
	end

	local c_str = ffi.new("char[?]", #str + 1)
	ffi.copy(c_str, str)

	return c_str
end

--- User provided overrides for the nitpick editor instance. This is mostly
--- useful for development purposes, but users are free to configure all, some,
--- or none of them.
--- @class NpOverrides
--- @field data_path? string Path to data storage. Defaults to nitpick data dir.
--- @field server_url? string Path to server instance. Defaults to main instance.

--- Create a new isntace of nitpick. There should only ever be one per editor
--- instance, though there is nothing preventing a user from createing multiple.
--- @param repo_name string
--- @param overrides NpOverrides
--- @return NpCtx
function np.new(repo_name, overrides)
	local c_repo_name = create_c_str(repo_name)
	local c_data_path = create_c_str(overrides.data_path)
	local c_server_url = create_c_str(overrides.server_url)

	local ctx = np.lib.np_new(c_repo_name, c_data_path, c_server_url)

	-- Ensure that the context is removed before neovim exits.
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			np.lib.np_free(ctx)
		end,
	})

	return ctx
end

--- Configure authentication for a particular host.
--- @param ctx NpCtx
--- @param host string
--- @param token string A PAT or other token defined by the host.
--- @return boolean succeess
function np.authorize(ctx, host, token)
	assert(host ~= nil, "A host is required.")
	assert(token ~= nil, "A token is required.")

	local c_host = create_c_str(host)
	local c_token = create_c_str(token)

	return np.lib.np_authorize(ctx, c_host, c_token)
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
	-- FIXME: assert the lib was set up correctly
	if lib == nil then
		return false, "Failed to load library"
	end

	local error_code = np.lib.np_get_activity(ctx, buf_handle)
	local success = tonumber(error_code) == 0

	--- @type string?
	local error_msg = nil
	if not success then
		error_msg = ffi.string(lib.np_get_error_msg(error_code))
	end

	return success, error_msg
end

--- Determine if the file at the `file_path` is tracked in version control.
--- @param ctx NpCtx
--- @param file_path string
--- @return boolean
function np.is_tracked_file(ctx, file_path)
	local c_file_path = ffi.new("char[?]", #file_path + 1)
	ffi.copy(c_file_path, file_path)

	return np.lib.np_is_tracked_file(ctx, c_file_path)
end

--- Load the last reviewed commit. If no review has been saved, a nil value is
--- returned.
--- @param ctx NpCtx
--- @return string? commit The commit to open in diff.
function np.start_review(ctx)
	--- FIXME: we should enforce that this is a 7 character array.
	local buf = ffi.new("char[?]", 100)
	local len = np.lib.np_start_review(ctx, buf)

	if len == 0 then
		return nil
	end

	return ffi.string(buf, len)
end

--- Save the current version control commit to become the starting point for the
--- next `start_review` call.
--- @param ctx NpCtx
--- @return string? commit The saved commit. A `nil` response means nothing was saved.
function np.end_review(ctx)
	--- FIXME: we should enforce that this is a 7 character array.
	local buf = ffi.new("char[?]", 100)
	local len = np.lib.np_end_review(ctx, buf)

	return ffi.string(buf, len)
end

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
	if lib == nil then
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

--- Load the path to nitpick custom data for the repo.
---
--- This is an experimental feature that is likely to change. There are no
--- protections around it. It is just a file on the file system, allow a user to
--- do whatever they want with it, with the directory it is in, or really
--- anything that could be thought of. We will not, for now, be defending
--- against that. If a user messes it up, that is the fault of the user.
--- @param ctx NpCtx
--- @param file_type "notes" | "tasks"
--- @return string? path The path to the requested file.
function np.get_file_path(ctx, file_type)
	assert(
		file_type == "notes" or file_type == "tasks",
		"File type must be one of \"notes\" or \"tasks\""
	)

	local buf = ffi.new("char[?]", 100)
	--- @type number
	local len

	if file_type == "notes" then
		len = np.lib.np_notes_path(ctx, buf)
	elseif file_type == "tasks" then
		len = np.lib.np_tasks_path(ctx, buf)
	end

	return ffi.string(buf, len)
end

return np
