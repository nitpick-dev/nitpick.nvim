local ffi = require("ffi")

---@type ffi.namespace*
local libnitpick

ffi.cdef([[
typedef void* np_app;

// NOTE: server_url is optional
np_app np_new(char* repo_name, char* base_path, char* server_url);
void np_free(np_app app);

int np_start_review(np_app app, char* buf);
int np_end_review(np_app app, char* buf);
]])

---@class Nitpick
---@field app ffi.cdata*?
local lib = {
	app = nil,
}

---Load libnitpick
---@param lib_path string? User provided path to libnitpick
---@return boolean success
function lib.load(lib_path)
	local sysname = vim.loop.os_uname().sysname:lower()
	--FIXME: windows support
	local ext = sysname == "linux" and "so" or "dylib"
	local sourced_file = vim.fn.fnamemodify(vim.fs.normalize(debug.getinfo(2, "S").source:sub(2)), ":p")
	local plugin_root = vim.fn.fnamemodify(sourced_file, ":h:h:h")
	local path = lib_path and vim.fn.expand(lib_path) or string.format("%s/libnitpick.%s", plugin_root, ext)

	local ok, library = pcall(ffi.load, path)
	if not ok then
		return false
	end

	libnitpick = library
	return true
end

--HACK: adding these to the global scope to prevent them failing in c land...
--we should probably add a copy over there or something so they can be safely
--cleaned in lua
---@type ffi.cdata*?
local c_server_url = nil
---@type ffi.cdata*
local c_repo_name
---@type ffi.cdata*
local c_np_data_path

---@param repo_name string
---@param np_data_path string
---@param server_url? string
---@return Nitpick
function lib:new(repo_name, np_data_path, server_url)
	c_repo_name = ffi.new("char[?]", #repo_name + 1)
	c_np_data_path = ffi.new("char[?]", #np_data_path + 1)

	ffi.copy(c_repo_name, repo_name)
	ffi.copy(c_np_data_path, np_data_path)

	if server_url ~= nil then
		c_server_url = ffi.new("char[?]", #server_url + 1)
		ffi.copy(c_server_url, server_url)
	end

	local app = libnitpick.np_new(c_repo_name, c_np_data_path, server_url)
	ffi.gc(app, libnitpick.np_free)

	---@type Nitpick
	local np = {
		app = app,
	}

	setmetatable(np, self);
	self.__index = self

	return np
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
