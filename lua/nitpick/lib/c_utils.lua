local ffi = require("ffi")

local utils = {}

--- Allocates a new c string from an optional string. When no string is
--- provided, nil will always be returned.
---
--- The data should be cleaned by normal garbage collection.
--- @param str? string The string to convert to a c string.
--- @return ffi.cdata* | nil
function utils.create_c_str(str)
	if str == nil then
		return nil
	end

	local c_str = ffi.new("char[?]", #str + 1)
	ffi.copy(c_str, str)

	return c_str
end

return utils
