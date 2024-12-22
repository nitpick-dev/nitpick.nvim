local ffi = require("ffi")

---@type ffi.namespace*
local libnitpick


ffi.cdef([[
typedef void* np_app;

typedef struct {
	const uint16_t line_start;
	const uint16_t line_end;
	const char* file;
	const char* text;
} np_comment;

typedef enum { comment_add } event_kind;

// NOTE: data_path and server_url are optional
np_app np_new(char* repo_name, char* data_path, char* server_url);
void np_free(np_app app);

bool np_authorize(np_app app, char* host, char* token);

bool np_add_comment(np_app app, np_comment* comment);
int np_activity(np_app app, char* buf);

int np_start_review(np_app app, char* buf);
int np_end_review(np_app app, char* buf);
]])

--- @class Nitpick
--- @field app ffi.cdata*?
local lib = {
	app = nil,
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

	local app = libnitpick.np_new(c_repo_name, c_data_path, c_server_url)
	ffi.gc(app, libnitpick.np_free)

	---@type Nitpick
	local np = {
		app = app,
	}

	setmetatable(np, self);
	self.__index = self

	return np
end

---@param host string
---@param token string
---@return boolean success
function lib:authorize(host, token)
	local c_host = ffi.new("char[?]", #host + 1)
	ffi.copy(c_host, host)

	local c_token = ffi.new("char[?]", #token + 1)
	ffi.copy(c_token, token)

	-- FIXME: return an error code so we can display a message why the operation
	-- failed
	return libnitpick.np_authorize(self.app, c_host, c_token)
end

---@param comment Comment
---@return boolean success
function lib:add_comment(comment)
	local c_comment = ffi.new("np_comment", comment)

	return libnitpick.np_add_comment(self.app, c_comment)
end

---@return string
function lib:activity()
	local buf = ffi.new("char[?]", 5120)

	-- FIXME: at some point, it'll probably be good for this to be async
	local len = libnitpick.np_activity(self.app, buf)
	return ffi.string(buf, len)
end

---Starts a review. If a review was previously conducted, this will start from
---the ending commit of the previous review. Nothing is returned otherwise.
---@return string
function lib:start_review()
	local buf = ffi.new("char[?]", 100)
	local len = libnitpick.np_start_review(self.app, buf)

	return ffi.string(buf, len)
end

---Ends a review. The current commit will become the starting commit the next
---time a review is started. The current commit is returned.
---@return string
function lib:end_review()
	local buf = ffi.new("char[?]", 100)
	local len = libnitpick.np_end_review(self.app, buf)

	return ffi.string(buf, len)
end

return lib
