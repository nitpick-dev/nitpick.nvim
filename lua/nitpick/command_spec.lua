local stub = require("luassert.stub")

local nitpick = require("nitpick")
local command = require("nitpick.command")

local test = it

describe("command", function()
	describe("completions", function()
		test("return all completions when cmd is emtpy", function()
			local cmp = command.complete("Nitpick ")
			assert.are_same({"start_review", "end_review",}, cmp)
		end)

		test("filter by leading characters", function()
			local cmp = command.complete("Nitpick s")
			assert.are_same({"start_review",}, cmp)

			cmp = command.complete("Nitpick e")
			assert.are_same({"end_review",}, cmp)

			cmp = command.complete("Nitpick friggin")
			assert.are_same({}, cmp)
		end)
	end)

	describe("dispatch", function()
		test("dispatch the start command", function()
			local start = stub(nitpick, "start_review")

			assert.is_true(command.dispatch({"start_review",}))
			assert.is_true(start:called(1))
		end)

		test("dispatch the start command with an arg", function()
			local start = stub(nitpick, "start_review")

			assert.is_true(command.dispatch({"start_review", "abc123" }))
			assert.is_true(start:called(1))
			assert.stub(start).was.called_with("abc123")
		end)

		test("dispatch the end command", function()
			local end_cmd = stub(nitpick, "end_review")

			assert.is_true(command.dispatch({"end_review",}))
			assert.is_true(end_cmd:called(1))
		end)

		test("dispatch unknown command fails", function()
			assert.is_false(command.dispatch({"notarealcommand",}))
		end)
	end)
end)
