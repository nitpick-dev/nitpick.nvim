local ffi = require("ffi")

--- @class Comment
--- @field file string
--- @field line_start number
--- @field line_end number
--- @field text string

--- @class NpBuffer
--- @field handle number
--- @field get_text fun(): string

--- @class Location
--- @field line_start number
--- @field line_end number
--- @field file string

