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

bool np_is_tracked_file(np_ctx ctx, char* file_path);

int np_start_review(np_ctx ctx, char* buf);
int np_end_review(np_ctx ctx, char* buf);

// NOTE: this is an experimental feature. the api is likely to change.
int np_notes_path(np_ctx ctx, char* buf);
int np_tasks_path(np_ctx ctx, char* buf);
]])

--- @class Nitpick
--- @field ctx ffi.cdata*?
local lib = {
	ctx = nil,
}

--- @param legacy_lib ffi.namespace* The loaded lib. This is initialized in the newer `np.lua` file and forwarded here for backwoard compatibilty
function lib.setup(legacy_lib)
	libnitpick = legacy_lib
end

--- @param ctx NpCtx
--- @return Nitpick
function lib:new(ctx)
	--- @type Nitpick
	local np = {
		ctx = ctx
	}

	setmetatable(np, self);
	self.__index = self

	return np
end

--- @param file_path string
--- @return boolean
function lib:is_tracked_file(file_path)
	local c_file_path = ffi.new("char[?]", #file_path + 1)
	ffi.copy(c_file_path, file_path)

	return libnitpick.np_is_tracked_file(self.ctx, c_file_path)
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
function lib:tasks_path()
	local buf = ffi.new("char[?]", 500)
	local len = libnitpick.np_tasks_path(self.ctx, buf)

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

return lib
