local activity = require("nitpick.activity")

local test = it

describe("activity", function()
	test("parse events", function()
		---@type Event[]
		local events = {
			{ kind = "COMMENT_ADD", actor = "user-1", description = "this is a comment" },
			{ kind = "COMMENT_ADD", actor = "user-2", description = "this is another comment" },
		}

		local log = activity.parse(events)
		assert.are_same({
				"user-1 added a comment:",
				"this is a comment",
				"",
				"user-2 added a comment:",
				"this is another comment",
				"",
			},
			log
		)
	end)
end)
