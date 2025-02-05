local ffi = require("ffi")

---@type ffi.namespace*
local libnitpick


ffi.cdef([[
typedef void* np_ctx;

typedef struct {
	const uint16_t line_start;
	const uint16_t line_end;
	const char* file;
	const char* text;
} np_comment;

typedef enum { comment_add } event_kind;

// NOTE: data_path and server_url are optional
np_ctx np_new(char* repo_name, char* data_path, char* server_url);
void np_free(np_ctx ctx);

bool np_authorize(np_ctx ctx, char* host, char* token);

bool np_is_tracked_file(np_ctx ctx, char* file_path);
bool np_add_comment(np_ctx ctx, np_comment* comment);
int np_activity(np_ctx ctx, char* buf);

int np_start_review(np_ctx ctx, char* buf);
int np_end_review(np_ctx ctx, char* buf);

// NOTE: this is an experimental feature. the api is likely to change.
int np_notes_path(np_ctx ctx, char* buf);
int np_todos_path(np_ctx ctx, char* buf);
]])

--- @class Nitpick
--- @field ctx ffi.cdata*?
local lib = {
	ctx = nil,
}

--- Load libnitpick
--- @param lib_path_override string? User provided override path to libnitpick.
--- @return boolean success
function lib.load(lib_path_override)
	--FIXME: windows support
	local ext = vim.loop.os_uname().sysname:lower() == "linux" and "so" or "dylib"

	local default_lib_path = string.format("~/.local/bin/libnitpick.%s", ext)
	local lib_path = vim.fn.expand(lib_path_override or default_lib_path)

	local ok, library = pcall(ffi.load, lib_path)
	if not ok then
		return false
	end

	libnitpick = library
	return true
end

--- @param repo_name string
--- @param data_path_override? string User provided path to override data storage.
--- @param server_url_override? string User provided server url.
--- @return Nitpick
function lib:new(repo_name, data_path_override, server_url_override)
	--- @type ffi.cdata*
	local c_server_url = nil

	--- @type ffi.cdata*
	local c_data_path = nil

	local c_repo_name = ffi.new("char[?]", #repo_name + 1)

	ffi.copy(c_repo_name, repo_name)

	if data_path_override ~= nil then
		c_data_path = ffi.new("char[?]", #data_path_override + 1)
		ffi.copy(c_data_path, data_path_override)
	end

	if server_url_override ~= nil then
		c_server_url = ffi.new("char[?]", #server_url_override + 1)
		ffi.copy(c_server_url, server_url_override)
	end

	--- @type Nitpick
	local np = {
		ctx = libnitpick.np_new(c_repo_name, c_data_path, c_server_url),
	}

	-- Ensure that a call the clean up happens before neovim exists.
	vim.api.nvim_create_autocmd("VimLeavePre", {
		callback = function()
			libnitpick.np_free(np.ctx)
		end,
	})

	setmetatable(np, self);
	self.__index = self

	return np
end

--- @param host string
--- @param token string
--- @return boolean success
function lib:authorize(host, token)
	local c_host = ffi.new("char[?]", #host + 1)
	ffi.copy(c_host, host)

	local c_token = ffi.new("char[?]", #token + 1)
	ffi.copy(c_token, token)

	-- FIXME: return an error code so we can display a message why the operation
	-- failed
	return libnitpick.np_authorize(self.ctx, c_host, c_token)
end

--- @param file_path string
--- @return boolean
function lib:is_tracked_file(file_path)
	local c_file_path = ffi.new("char[?]", #file_path + 1)
	ffi.copy(c_file_path, file_path)

	return libnitpick.np_is_tracked_file(self.ctx, c_file_path)
end

--- @param comment Comment
--- @return boolean success
function lib:add_comment(comment)
	local c_comment = ffi.new("np_comment", comment)

	return libnitpick.np_add_comment(self.ctx, c_comment)
end

--- @return string
function lib:activity()
	local buf = ffi.new("char[?]", 5120)

	-- FIXME: at some point, it'll probably be good for this to be async
	local len = libnitpick.np_activity(self.ctx, buf)
	return ffi.string(buf, len)
end

--- Starts a review. If a review was previously conducted, this will start from
--- the ending commit of the previous review. Nothing is returned otherwise.
--- @return string
function lib:start_review()
	local buf = ffi.new("char[?]", 100)
	local len = libnitpick.np_start_review(self.ctx, buf)

	return ffi.string(buf, len)
end

--- Ends a review. The current commit will become the starting commit the next
--- time a review is started. The current commit is returned.
--- @return string
function lib:end_review()
	local buf = ffi.new("char[?]", 100)
	local len = libnitpick.np_end_review(self.ctx, buf)

	return ffi.string(buf, len)
end

--- Loads the path to the notes file for the repo.
--- @returns string
function lib:notes_path()
	local buf = ffi.new("char[?]", 500)
	local len = libnitpick.np_notes_path(self.ctx, buf)

	return ffi.string(buf, len)
end

--- Loads the path to the notes file for the repo.
--- @returns string
function lib:todos_path()
	local buf = ffi.new("char[?]", 500)
	local len = libnitpick.np_todos_path(self.ctx, buf)

	return ffi.string(buf, len)
end

function lib.create_buffer(buf)
	return ffi.new("np_buf_handle", {
		handle = ffi.cast("np_editor_handle", buf),
		get_text = ffi.cast("np_buf_get_text_fn", function()
			local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
			local contents = table.concat(lines, "\n");
			local c_contents = ffi.new("char[?]", #contents + 1)
			ffi.copy(c_contents, contents)
			return c_contents
		end),
	})
end

-- FIXME: the buffer should be cdata, can we do that?
--- @param buf NpBuffer
--- @param location Location
function lib:write_comment(buf, location)
	return libnitpick.np_write_comment(
		self.ctx,
		buf,
		ffi.new("np_location", location)
	)
end

return lib
