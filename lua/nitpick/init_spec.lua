local diffview = require("diffview")
local stub = require("luassert.stub")

local nitpick = require("nitpick")
local np = require("nitpick.np")

local test = it

describe("nitpick", function()
	before_each(function()
		nitpick.np = np
	end)

	test("start a review", function()
		local diffview_open = stub(diffview, "open")

		local start_review = stub(np, "start_review")
		start_review.returns("abc123")

		nitpick.start_review()

		assert.stub(diffview_open).was.called_with("abc123", "HEAD")
	end)

	test("start a review from arbitrary commit", function()
		local diffview_open = stub(diffview, "open")
		local start_review = stub(np, "start_review")

		nitpick.start_review("xyz123")

		assert.stub(diffview_open).was.called_with("xyz123", "HEAD")
		assert.stub(start_review).called(0)
	end)

	test("end a review", function()
		local diffview_close = stub(diffview, "close")
		local end_review = stub(np, "end_review")
		end_review.returns("xyz123")

		nitpick.end_review()

		assert.stub(end_review).called(1)
		assert.stub(diffview_close).called(1)
	end)
end)
