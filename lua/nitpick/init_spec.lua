local diffview = require("diffview")
local stub = require("luassert.stub")

local nitpick = require("nitpick")
local lib = require("nitpick.lib")
local onboarder = require("nitpick.onboarder")

local test = it

describe("nitpick", function()
	before_each(function()
		nitpick.lib = lib
	end)

	test("authorize a host", function()
		local log = stub(vim, "notify")

		local authorize = stub(lib, "authorize")
		authorize.returns(true)

		nitpick.authorize("github", "some_token")
		assert.stub(log).was.called_with(
			"github was successfully authorized.",
			vim.log.levels.INFO
		)

		log:clear()

		authorize.returns(false)
		nitpick.authorize("github", "some_token")
		assert.stub(log).was.called_with(
			"failed to authorize github.",
			vim.log.levels.INFO
		)
	end)

	test("start onboarding if no previous review was found", function()
		local onboarder_start = stub(onboarder, "start")

		local start_review = stub(lib, "start_review")
		start_review.returns("")

		nitpick.start_review()

		assert.stub(onboarder_start).called(1)
	end)

	test("start a review", function()
		local diffview_open = stub(diffview, "open")

		local start_review = stub(lib, "start_review")
		start_review.returns("abc123")

		nitpick.start_review()

		assert.stub(diffview_open).was.called_with("abc123", "HEAD")
	end)

	test("start a review from arbitrary commit", function()
		local diffview_open = stub(diffview, "open")
		local start_review = stub(lib, "start_review")

		nitpick.start_review("xyz123")

		assert.stub(diffview_open).was.called_with("xyz123", "HEAD")
		assert.stub(start_review).called(0)
	end)

	test("end a review", function()
		local diffview_close = stub(diffview, "close")
		local end_review = stub(lib, "end_review")
		end_review.returns("xyz123")

		nitpick.end_review()

		assert.stub(end_review).called(1)
		assert.stub(diffview_close).called(1)
	end)
end)
