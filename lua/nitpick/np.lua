local ffi = require("ffi")

--FIXME: remove hardcoded path. let's make this an option so we can have one
--path for local dev, another for releases
local ok, libnitpick = pcall(ffi.load, "./zig-out/lib/libnitpick.so")
if not ok then
	return false
end

ffi.cdef [[
typedef void* np_app;

np_app np_new(char* repo_name, char* base_path);
void np_free(np_app app);

int np_start_review(np_app app, char* buf);
int np_end_review(np_app app, char* buf);
]]

---@class Nitpick
---@field app ffi.cdata*?
local lib = {
	app = nil,
}

--HACK: adding these to the global scope to prevent them failing in c land...
--we should probably add a copy over there or something so they can be safely
--cleaned in lua
local c_repo_name
local c_np_data_path

---@param repo_name string
---@param np_data_path string
---@return Nitpick
function lib:new(repo_name, np_data_path)
	c_repo_name = ffi.new("char[?]", #repo_name + 1)
	c_np_data_path = ffi.new("char[?]", #np_data_path + 1)

	ffi.copy(c_repo_name, repo_name)
	ffi.copy(c_np_data_path, np_data_path)

	local app = libnitpick.np_new(c_repo_name, c_np_data_path)
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
